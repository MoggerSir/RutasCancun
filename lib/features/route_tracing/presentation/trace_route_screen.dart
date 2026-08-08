import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:rutas_cancun/features/routes/providers/routes_providers.dart';
import 'package:rutas_cancun/features/route_tracing/data/route_tracks_repository.dart';
import 'package:rutas_cancun/features/route_tracing/data/track_local_store.dart';
import 'package:rutas_cancun/features/route_tracing/services/location_tracker.dart';
import 'package:rutas_cancun/features/route_tracing/services/track_sync_service.dart';
import 'package:rutas_cancun/features/routes/data/routes_repository.dart';

enum _TracePhase { setup, recording, paused, uploading, done }

enum _GpsQuality { good, fair, poor, weak, unknown }

class TraceRouteScreen extends ConsumerStatefulWidget {
  const TraceRouteScreen({super.key});

  @override
  ConsumerState<TraceRouteScreen> createState() => _TraceRouteScreenState();
}

class _TraceRouteScreenState extends ConsumerState<TraceRouteScreen> {
  final _customCodeController = TextEditingController();
  final _mapController = MapController();
  final _tracker = LocationTracker();

  _TracePhase _phase = _TracePhase.setup;
  String? _selectedCode;
  bool _useCustomCode = false;
  String? _trackId;
  String? _error;
  String? _finishNote;

  final _recordedPoints = <LatLng>[];
  final _recentAccuracyM = <double>[];
  int _uploadedCount = 0;
  int _pendingUnsynced = 0;
  int _completedTracksOnDevice = 0;
  Timer? _uploadTimer;
  bool _weakGpsWarned = false;

  RouteDetail? _previewRoute;
  List<LatLng> _officialPolyline = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIncompleteSession();
      _loadCompletedCount();
    });
  }

  @override
  void dispose() {
    _uploadTimer?.cancel();
    _tracker.dispose();
    _customCodeController.dispose();
    super.dispose();
  }

  String? get _routeCode {
    if (_useCustomCode) {
      final c = _customCodeController.text.trim().toUpperCase();
      return c.isEmpty ? null : c;
    }
    return _selectedCode;
  }

  _GpsQuality get _gpsQuality {
    if (_recentAccuracyM.isEmpty) return _GpsQuality.unknown;
    final avg = _recentAccuracyM.reduce((a, b) => a + b) / _recentAccuracyM.length;
    if (avg <= 25) return _GpsQuality.good;
    if (avg <= 50) return _GpsQuality.fair;
    if (avg <= 100) return _GpsQuality.poor;
    return _GpsQuality.weak;
  }

  Future<void> _loadCompletedCount() async {
    final count = await ref.read(trackLocalStoreProvider).completedSessionCount();
    if (mounted) setState(() => _completedTracksOnDevice = count);
  }

  Future<void> _checkIncompleteSession() async {
    final session = await ref.read(trackLocalStoreProvider).findIncompleteSession();
    if (session == null || !mounted) return;

    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Trazado sin terminar'),
        content: Text(
          'Hay un trazado de ${session.routeCode} con ${session.pointCount} puntos '
          '(${session.unsyncedCount} sin subir). ¿Qué deseas hacer?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('Descartar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'upload_close'),
            child: const Text('Subir y cerrar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'continue'),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    switch (action) {
      case 'continue':
        await _resumeFromLocal(session);
      case 'upload_close':
        await _uploadAndCloseSession(session);
      case 'discard':
        await ref.read(trackLocalStoreProvider).clearSession(session.remoteTrackId);
      default:
        break;
    }
  }

  Future<void> _loadOfficialPreview(String code, String? routeId) async {
    setState(() {
      _previewRoute = null;
      _officialPolyline = [];
    });
    try {
      final detail = await ref.read(routesRepositoryProvider).getRoute(routeId ?? code);
      final coords = detail.polyline?['coordinates'] as List?;
      final points = coords
              ?.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
              .toList() ??
          [];
      if (mounted) {
        setState(() {
          _previewRoute = detail;
          _officialPolyline = points;
        });
      }
    } catch (_) {}
  }

  void _onPointCaptured(TrackPointPayload point) async {
    if (_trackId == null) return;
    await ref.read(trackLocalStoreProvider).insertPoint(_trackId!, point);

    if (point.accuracyM != null) {
      _recentAccuracyM.add(point.accuracyM!);
      if (_recentAccuracyM.length > 8) _recentAccuracyM.removeAt(0);
    }

    if (mounted) {
      setState(() {
        _recordedPoints.add(LatLng(point.lat, point.lng));
        _pendingUnsynced++;
      });
      if (_recordedPoints.length == 1) {
        _mapController.move(LatLng(point.lat, point.lng), 15);
      }
      if (!_weakGpsWarned && _gpsQuality == _GpsQuality.weak) {
        _weakGpsWarned = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Señal GPS débil — el trazado puede ser impreciso'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _startTracing() async {
    final code = _routeCode;
    if (code == null) {
      setState(() => _error = 'Elige o escribe un código de ruta');
      return;
    }

    final incomplete = await ref.read(trackLocalStoreProvider).findIncompleteSession();
    if (incomplete != null) {
      setState(() => _error = 'Termina o descarta el trazado anterior antes de iniciar uno nuevo');
      return;
    }

    setState(() {
      _error = null;
      _finishNote = null;
      _phase = _TracePhase.uploading;
    });

    final ok = await _tracker.ensurePermission();
    if (!ok) {
      setState(() {
        _error = 'Activa GPS y permisos de ubicación';
        _phase = _TracePhase.setup;
      });
      return;
    }

    try {
      final summary = await ref.read(routeTracksRepositoryProvider).start(code);
      _trackId = summary.id;
      _recordedPoints.clear();
      _recentAccuracyM.clear();
      _weakGpsWarned = false;
      _uploadedCount = 0;
      _pendingUnsynced = 0;

      await ref.read(trackLocalStoreProvider).createSession(
            remoteTrackId: summary.id,
            routeCode: code,
          );

      _tracker.start(_onPointCaptured);
      _uploadTimer = Timer.periodic(const Duration(seconds: 20), (_) => _flushPoints());

      setState(() => _phase = _TracePhase.recording);
    } catch (e) {
      setState(() {
        _error = 'No se pudo iniciar: $e';
        _phase = _TracePhase.setup;
      });
    }
  }

  Future<void> _flushPoints() async {
    if (_trackId == null) return;
    if (_phase != _TracePhase.recording && _phase != _TracePhase.paused) return;

    final result = await ref.read(trackSyncServiceProvider).syncPending(_trackId!);
    if (!mounted) return;
    setState(() {
      if (result.serverPointCount != null) _uploadedCount = result.serverPointCount!;
      _pendingUnsynced = result.remainingUnsynced;
    });
  }

  Future<void> _resumeFromLocal(LocalTraceSession session) async {
    setState(() => _phase = _TracePhase.uploading);

    final ok = await _tracker.ensurePermission();
    if (!ok) {
      setState(() {
        _error = 'Activa GPS y permisos de ubicación';
        _phase = _TracePhase.setup;
      });
      return;
    }

    _trackId = session.remoteTrackId;
    _selectedCode = session.routeCode;
    _useCustomCode = false;

    final localPoints = await ref.read(trackLocalStoreProvider).getAllPoints(session.remoteTrackId);
    _recordedPoints
      ..clear()
      ..addAll(localPoints.map((p) => LatLng(p.lat, p.lng)));
    _pendingUnsynced = session.unsyncedCount;

    await _flushPoints();

    if (session.status == 'paused') {
      await ref.read(routeTracksRepositoryProvider).updateStatus(_trackId!, 'recording');
      await ref.read(trackLocalStoreProvider).updateSessionStatus(_trackId!, 'recording');
    }

    _tracker.start(_onPointCaptured);
    _uploadTimer = Timer.periodic(const Duration(seconds: 20), (_) => _flushPoints());

    if (_recordedPoints.isNotEmpty) {
      _mapController.move(_recordedPoints.last, 15);
    }

    setState(() => _phase = _TracePhase.recording);
  }

  Future<void> _uploadAndCloseSession(LocalTraceSession session) async {
    setState(() => _phase = _TracePhase.uploading);
    _trackId = session.remoteTrackId;

    await ref.read(trackSyncServiceProvider).syncPending(session.remoteTrackId);
    final pending = await ref.read(trackLocalStoreProvider).countUnsynced(session.remoteTrackId);

    try {
      if (pending == 0) {
        await ref.read(routeTracksRepositoryProvider).updateStatus(session.remoteTrackId, 'completed');
      } else {
        await ref.read(routeTracksRepositoryProvider).updateStatus(session.remoteTrackId, 'paused');
      }
    } catch (_) {}

    await ref.read(trackLocalStoreProvider).markSessionCompletedLocally(session.remoteTrackId);
    await _loadCompletedCount();

    if (!mounted) return;
    setState(() {
      _finishNote = pending > 0
          ? '$pending puntos quedaron sin subir — se reintentará al abrir la app con internet'
          : 'Track subido correctamente';
      _phase = _TracePhase.done;
    });
  }

  Future<void> _pause() async {
    _uploadTimer?.cancel();
    _tracker.pause();
    await _flushPoints();
    if (_trackId != null) {
      await ref.read(routeTracksRepositoryProvider).updateStatus(_trackId!, 'paused');
      await ref.read(trackLocalStoreProvider).updateSessionStatus(_trackId!, 'paused');
    }
    setState(() => _phase = _TracePhase.paused);
  }

  Future<void> _resume() async {
    _tracker.start(_onPointCaptured);
    if (_trackId != null) {
      await ref.read(routeTracksRepositoryProvider).updateStatus(_trackId!, 'recording');
      await ref.read(trackLocalStoreProvider).updateSessionStatus(_trackId!, 'recording');
    }
    _uploadTimer = Timer.periodic(const Duration(seconds: 20), (_) => _flushPoints());
    setState(() => _phase = _TracePhase.recording);
  }

  Future<void> _finish() async {
    _uploadTimer?.cancel();
    _tracker.pause();
    setState(() => _phase = _TracePhase.uploading);

    if (_trackId == null) return;

    await ref.read(trackSyncServiceProvider).syncPending(_trackId!);
    var pending = await ref.read(trackLocalStoreProvider).countUnsynced(_trackId!);

    // Reintento agresivo al finalizar
    for (var i = 0; i < 3 && pending > 0; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      await ref.read(trackSyncServiceProvider).syncPending(_trackId!);
      pending = await ref.read(trackLocalStoreProvider).countUnsynced(_trackId!);
    }

    try {
      final summary = await ref.read(routeTracksRepositoryProvider).updateStatus(
            _trackId!,
            pending == 0 ? 'completed' : 'paused',
          );
      await ref.read(trackLocalStoreProvider).markSessionCompletedLocally(_trackId!);
      await _loadCompletedCount();

      setState(() {
        _uploadedCount = summary.pointCount;
        _pendingUnsynced = pending;
        _finishNote = pending > 0
            ? '$pending puntos sin subir — se guardaron localmente y se reintentarán con internet'
            : null;
        _phase = _TracePhase.done;
      });
    } catch (e) {
      await ref.read(trackLocalStoreProvider).updateSessionStatus(_trackId!, 'paused');
      setState(() {
        _error = 'Error al subir: $e. Los puntos siguen guardados en el dispositivo.';
        _phase = _TracePhase.paused;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final routesAsync = ref.watch(routesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trazar ruta'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _phase == _TracePhase.recording ? null : () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          if (_phase != _TracePhase.setup) ...[
            Expanded(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _recordedPoints.isNotEmpty
                      ? _recordedPoints.last
                      : (_officialPolyline.isNotEmpty
                          ? _officialPolyline.first
                          : const LatLng(21.155, -86.82)),
                  initialZoom: 14,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.rutascancun.app',
                  ),
                  if (_officialPolyline.length >= 2)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _officialPolyline,
                          color: Colors.blue.withValues(alpha: 0.45),
                          strokeWidth: 4,
                        ),
                      ],
                    ),
                  if (_recordedPoints.length >= 2)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _recordedPoints,
                          color: Colors.red,
                          strokeWidth: 5,
                        ),
                      ],
                    ),
                  if (_recordedPoints.isNotEmpty)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _recordedPoints.last,
                          width: 24,
                          height: 24,
                          child: const Icon(Icons.my_location, color: Colors.red, size: 28),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            _StatusBar(
              routeCode: _routeCode ?? '—',
              phase: _phase,
              localPoints: _recordedPoints.length,
              uploadedPoints: _uploadedCount,
              pendingUnsynced: _pendingUnsynced,
              gpsQuality: _gpsQuality,
            ),
          ] else
            Expanded(
              child: routesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error cargando rutas: $e')),
                data: (routes) => Column(
                  children: [
                    Expanded(
                      child: _SetupPanel(
                        routes: routes,
                        selectedCode: _selectedCode,
                        useCustomCode: _useCustomCode,
                        customController: _customCodeController,
                        error: _error,
                        previewRoute: _previewRoute,
                        officialPolyline: _officialPolyline,
                        onSelectCode: (r) {
                          setState(() {
                            _selectedCode = r.code;
                            _useCustomCode = false;
                            _error = null;
                          });
                          _loadOfficialPreview(r.code, r.id);
                        },
                        onToggleCustom: (v) => setState(() {
                          _useCustomCode = v;
                          _previewRoute = null;
                          _officialPolyline = [];
                          _error = null;
                        }),
                      ),
                    ),
                    if (_officialPolyline.length >= 2)
                      SizedBox(
                        height: 180,
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: _officialPolyline.first,
                            initialZoom: 13,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.rutascancun.app',
                            ),
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: _officialPolyline,
                                  color: Colors.blue.withValues(alpha: 0.7),
                                  strokeWidth: 4,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (_phase == _TracePhase.done && _finishNote != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(_finishNote!, style: Theme.of(context).textTheme.bodySmall),
            ),
          if (_phase == _TracePhase.done && _completedTracksOnDevice > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Tracks completados en este dispositivo: $_completedTracksOnDevice',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          _Controls(
            phase: _phase,
            onStart: _startTracing,
            onPause: _pause,
            onResume: _resume,
            onFinish: _finish,
            onDone: () => context.pop(),
          ),
        ],
      ),
    );
  }
}

class _SetupPanel extends StatelessWidget {
  const _SetupPanel({
    required this.routes,
    required this.selectedCode,
    required this.useCustomCode,
    required this.customController,
    required this.error,
    required this.previewRoute,
    required this.officialPolyline,
    required this.onSelectCode,
    required this.onToggleCustom,
  });

  final List<RouteSummary> routes;
  final String? selectedCode;
  final bool useCustomCode;
  final TextEditingController customController;
  final String? error;
  final RouteDetail? previewRoute;
  final List<LatLng> officialPolyline;
  final ValueChanged<RouteSummary> onSelectCode;
  final ValueChanged<bool> onToggleCustom;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Sube al camión/combi y graba el recorrido real con GPS. '
              'Los puntos se guardan en el teléfono al instante y se suben en segundo plano.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('¿Qué ruta estás recorriendo?', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('Otra ruta (escribir código)'),
          value: useCustomCode,
          onChanged: onToggleCustom,
        ),
        if (useCustomCode)
          TextField(
            controller: customController,
            decoration: const InputDecoration(
              labelText: 'Código (ej. R15, R44)',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.characters,
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: routes.map((r) {
              final selected = selectedCode == r.code;
              return ChoiceChip(
                label: Text(r.code),
                selected: selected,
                onSelected: (_) => onSelectCode(r),
              );
            }).toList(),
          ),
        if (previewRoute != null && officialPolyline.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Vista previa: ${previewRoute!.name} (línea azul = ruta oficial)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ],
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.routeCode,
    required this.phase,
    required this.localPoints,
    required this.uploadedPoints,
    required this.pendingUnsynced,
    required this.gpsQuality,
  });

  final String routeCode;
  final _TracePhase phase;
  final int localPoints;
  final int uploadedPoints;
  final int pendingUnsynced;
  final _GpsQuality gpsQuality;

  @override
  Widget build(BuildContext context) {
    final status = switch (phase) {
      _TracePhase.recording => 'Grabando…',
      _TracePhase.paused => 'Pausado',
      _TracePhase.uploading => 'Subiendo…',
      _TracePhase.done => 'Completado',
      _ => '',
    };

    final (icon, color, label) = switch (gpsQuality) {
      _GpsQuality.good => (Icons.gps_fixed, Colors.green, 'GPS bueno'),
      _GpsQuality.fair => (Icons.gps_not_fixed, Colors.lightGreen, 'GPS aceptable'),
      _GpsQuality.poor => (Icons.gps_not_fixed, Colors.orange, 'GPS débil'),
      _GpsQuality.weak => (Icons.gps_off, Colors.red, 'GPS muy débil'),
      _ => (Icons.gps_not_fixed, Colors.grey, 'GPS…'),
    };

    return Material(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 22),
                Text(label, style: TextStyle(fontSize: 10, color: color)),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$routeCode · $status\n'
                'Puntos: $localPoints local · $uploadedPoints servidor'
                '${pendingUnsynced > 0 ? ' · $pendingUnsynced pendientes' : ''}',
              ),
            ),
            if (phase == _TracePhase.recording)
              const Icon(Icons.fiber_manual_record, color: Colors.red, size: 14),
          ],
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.phase,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onFinish,
    required this.onDone,
  });

  final _TracePhase phase;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onFinish;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: switch (phase) {
          _TracePhase.setup => SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.gps_fixed),
                label: const Text('Iniciar trazado'),
              ),
            ),
          _TracePhase.recording => Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPause,
                    icon: const Icon(Icons.pause),
                    label: const Text('Pausar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onFinish,
                    icon: const Icon(Icons.stop),
                    label: const Text('Finalizar'),
                  ),
                ),
              ],
            ),
          _TracePhase.paused => Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onResume,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Reanudar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onFinish,
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Subir y terminar'),
                  ),
                ),
              ],
            ),
          _TracePhase.uploading => const Center(child: CircularProgressIndicator()),
          _TracePhase.done => SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onDone,
                child: const Text('Listo'),
              ),
            ),
        },
      ),
    );
  }
}
