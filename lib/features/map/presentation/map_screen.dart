import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:rutas_cancun/core/theme/app_colors.dart';
import 'package:rutas_cancun/core/widgets/glass_icon_button.dart';
import 'package:rutas_cancun/core/widgets/map_nav_bar_content.dart';
import 'package:rutas_cancun/core/widgets/liquid_search_bar.dart';
import 'package:rutas_cancun/core/widgets/map_loading_overlay.dart';
import 'package:rutas_cancun/features/map/data/map_route_cache.dart';
import 'package:rutas_cancun/features/map/domain/route_polyline_utils.dart';
import 'package:rutas_cancun/features/map/domain/route_visual_state.dart';
import 'package:rutas_cancun/features/map/widgets/map_bottom_dock.dart';
import 'package:rutas_cancun/features/map/widgets/user_location_pulse_marker.dart';
import 'package:rutas_cancun/features/map/widgets/institutional_map_tiles.dart';
import 'package:rutas_cancun/features/map/widgets/map_quick_actions.dart';
import 'package:rutas_cancun/features/map/widgets/route_flow_overlay.dart';
import 'package:rutas_cancun/features/map/widgets/route_info_sheet.dart';
import 'package:rutas_cancun/features/map/widgets/route_line_badge.dart';
import 'package:rutas_cancun/features/map/widgets/route_endpoint_marker.dart';
import 'package:rutas_cancun/features/map/widgets/route_startup_reveal_overlay.dart';
import 'package:rutas_cancun/features/routes/data/routes_repository.dart';
import 'package:rutas_cancun/features/routes/domain/route_colors.dart';
import 'package:rutas_cancun/features/routes/domain/route_service_hours.dart';
import 'package:rutas_cancun/features/routes/providers/routes_providers.dart';

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routesAsync = ref.watch(routesListProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: routesAsync.when(
        loading: () => const _MapLoadingShell(),
        error: (e, _) => _MapErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(routesListProvider),
        ),
        data: (routes) => routes.isEmpty
            ? _EmptyDriverMap(
                onRefresh: () => ref.invalidate(routesListProvider))
            : _PremiumMapBody(
                routes: routes,
                onRefresh: () {
                  MapRouteCache.instance.clear();
                  ref.invalidate(routesListProvider);
                },
              ),
      ),
    );
  }
}

class _MapLoadingShell extends StatelessWidget {
  const _MapLoadingShell();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: LatLng(21.155, -86.82),
            initialZoom: 12.5,
          ),
          children: [VividMapTiles()],
        ),
        Center(
          child: CircularProgressIndicator(
              color: AppColors.primary, strokeWidth: 2.5),
        ),
      ],
    );
  }
}

class _MapErrorState extends StatelessWidget {
  const _MapErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const FlutterMap(
          options: MapOptions(
            initialCenter: LatLng(21.155, -86.82),
            initialZoom: 12.5,
          ),
          children: [VividMapTiles()],
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'No pudimos cargar las rutas.\nRevisa tu conexión e intenta de nuevo.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyDriverMap extends StatelessWidget {
  const _EmptyDriverMap({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const FlutterMap(
          options: MapOptions(
            initialCenter: LatLng(21.155, -86.82),
            initialZoom: 12.5,
          ),
          children: [VividMapTiles()],
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: LiquidSearchBar(onTap: () => context.push('/search')),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.route_outlined,
                    size: 52, color: AppColors.primary.withValues(alpha: 0.8)),
                const SizedBox(height: 14),
                Text(
                  'Sin rutas todavía',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Las rutas aparecen cuando un chofer las graba y envía desde Rutas Chofer.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Actualizar mapa'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PremiumMapBody extends ConsumerStatefulWidget {
  const _PremiumMapBody({required this.routes, required this.onRefresh});

  final List<RouteSummary> routes;
  final VoidCallback onRefresh;

  @override
  ConsumerState<_PremiumMapBody> createState() => _PremiumMapBodyState();
}

class _PremiumMapBodyState extends ConsumerState<_PremiumMapBody>
    with SingleTickerProviderStateMixin {
  final _mapController = MapController();
  final _cache = MapRouteCache.instance;
  final _details = <String, RouteDetail>{};
  final LayerHitNotifier<String> _polylineHitNotifier = ValueNotifier(null);

  String? _selectedCode;
  bool _fitPending = true;
  bool _nightBoundsApplied = false;
  MapNavAction? _navAction;
  String? _filterHint;
  bool _isLoading = false;
  String _loadingMessage = 'Cargando…';
  LatLng? _userLocation;
  StreamSubscription<Position>? _locationSub;
  bool _bundleReady = false;
  bool _startupAnimationDone = false;
  bool _nearbyFilterActive = false;
  bool _showAllFarRoutes = false;
  Set<String> _nearbyRouteCodes = {};
  String? _nearbyFallbackMessage;
  List<String>? _ambiguousCodes;
  bool _initialGpsFixApplied = false;
  bool _planningMode = false;
  LatLng? _planningOrigin;
  LatLng? _planningDestination;
  _PlannerPoint _activePlannerPoint = _PlannerPoint.destination;
  Set<String> _plannedRouteCodes = {};
  JourneyOption? _plannedJourney;
  bool _planningConfirmed = false;
  bool _planningCalculating = false;
  String? _planningError;

  // Fundido cruzado de opacidad al seleccionar/deseleccionar una ruta —
  // sin esto, las demás rutas aparecían/desaparecían de golpe en vez de
  // desvanecerse, y se sentía brusco en vez de premium.
  late final AnimationController _visualFadeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  )..value = 1.0;
  Map<String, double> _alphaFrom = {};
  Map<String, double> _alphaTo = {};

  static const _tapTolerancePx = 20.0;

  MapTileTheme get _mapTheme => _navAction == MapNavAction.nightRoutes
      ? MapTileTheme.night
      : MapTileTheme.day;

  @override
  void initState() {
    super.initState();
    _details.addAll(_cache.allDetails);
    _loadMapBundle();
    _startUserLocationTracking();
    _visualFadeCtrl.addListener(_onFadeTick);
  }

  void _onFadeTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _visualFadeCtrl.dispose();
    super.dispose();
  }

  void _handlePolylineHits(List<String> codes) {
    if (codes.isEmpty) return;
    if (codes.length == 1) {
      _selectRoute(codes.first, openSheet: true);
    } else {
      setState(() => _ambiguousCodes = codes);
    }
  }

  Future<void> _startUserLocationTracking() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return;
    }
    if (!await Geolocator.isLocationServiceEnabled()) return;

    final last = await Geolocator.getLastKnownPosition();
    if (last != null && mounted) {
      _applyGpsFix(LatLng(last.latitude, last.longitude));
    }

    _locationSub?.cancel();
    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 6,
      ),
    ).listen((pos) {
      if (!mounted) return;
      setState(() => _userLocation = LatLng(pos.latitude, pos.longitude));
    });
  }

  void _applyGpsFix(LatLng here) {
    setState(() => _userLocation = here);
    if (_initialGpsFixApplied || !_bundleReady) return;
    _initialGpsFixApplied = true;
    _computeNearbyFilter(here);
  }

  void _computeNearbyFilter(LatLng here) {
    final allDetails =
        widget.routes.map(_detailFor).whereType<RouteDetail>().toList();
    if (allDetails.isEmpty) return;

    final near = RoutePolylineUtils.filterNearbyRouteCodes(
        user: here, routes: allDetails);
    if (near.isEmpty) {
      setState(() {
        _nearbyFilterActive = false;
        _nearbyRouteCodes = {};
        _nearbyFallbackMessage =
            'No hay rutas cerca de ti — mostrando todas las disponibles';
      });
      return;
    }

    setState(() {
      _nearbyFilterActive = true;
      _nearbyRouteCodes = near;
      _nearbyFallbackMessage = null;
      _showAllFarRoutes = false;
    });
  }

  Future<void> _withLoading(Future<void> Function() task,
      {String message = 'Cargando…'}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadingMessage = message;
    });
    try {
      await task();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _syncDetailsFromCache() {
    _details
      ..clear()
      ..addAll(_cache.allDetails);
  }

  List<RouteSummary> get _visibleRoutes {
    var routes = widget.routes;
    if (_navAction == MapNavAction.nightRoutes) {
      routes = routes
          .where((r) => RouteServiceHours.matchesNightFilter(r.code))
          .toList();
    }
    return routes;
  }

  Future<void> _loadMapBundle() async {
    if (_bundleReady && _details.isNotEmpty) {
      _scheduleFitBounds();
      return;
    }

    await _withLoading(() async {
      final repo = ref.read(routesRepositoryProvider);
      await _cache.loadMapBundle(
        repo,
        routesFallback: widget.routes,
        onUpdated: () {
          if (!mounted) return;
          _syncDetailsFromCache();
          setState(() => _bundleReady = true);
        },
      );
      _syncDetailsFromCache();
      if (mounted) {
        setState(() => _bundleReady = true);
        _scheduleFitBounds();
        if (_userLocation != null) _applyGpsFix(_userLocation!);
      }
    }, message: 'Cargando mapa…');
  }

  void _onStartupAnimationComplete() {
    if (!mounted) return;
    setState(() => _startupAnimationDone = true);
    if (_userLocation != null && !_initialGpsFixApplied) {
      _applyGpsFix(_userLocation!);
    }
  }

  void _scheduleFitBounds() {
    if (!_fitPending) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final points = _allPolylinePoints(forRoutes: _visibleRoutes);
      if (points.length < 2) return;
      _safeFitCamera(points);
      _fitPending = false;
    });
  }

  List<LatLng> _allPolylinePoints({List<RouteSummary>? forRoutes}) {
    final routes = forRoutes ?? widget.routes;
    final points = <LatLng>[];
    for (final r in routes) {
      points.addAll(_routePoints(r));
    }
    return points;
  }

  RouteDetail? _detailFor(RouteSummary summary) =>
      _details[summary.id] ?? _cache.detail(summary.id);

  List<LatLng> _routePoints(RouteSummary summary) {
    final detail = _detailFor(summary);
    if (detail == null) return [];
    return _renderableSegments(detail).expand((seg) => seg.points).toList();
  }

  List<LatLng> _polylineToLatLng(Map<String, dynamic> poly) {
    return (poly['coordinates'] as List)
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();
  }

  List<({List<LatLng> points, bool isVuelta})> _renderableSegments(
      RouteDetail detail) {
    final segments = <({List<LatLng> points, bool isVuelta})>[];

    if (detail.polylines != null && detail.polylines!.isNotEmpty) {
      for (final seg in detail.polylines!) {
        final points = _polylineToLatLng(seg.polyline);
        segments.add((points: points, isVuelta: seg.direction == 'vuelta'));
      }
      return segments;
    }

    if (detail.polyline != null) {
      segments
          .add((points: _polylineToLatLng(detail.polyline!), isVuelta: false));
    }
    return segments;
  }

  RouteVisualState _visualStateFor(String code) {
    if (_plannedRouteCodes.contains(code)) return RouteVisualState.selected;
    return visualStateForRoute(
      code: code,
      selectedCode: _selectedCode,
      nearbyCodes: _nearbyRouteCodes,
      nearbyFilterActive: _nearbyFilterActive && _startupAnimationDone,
    );
  }

  double _targetAlphaFor(String code) => opacityForRouteVisual(
        _visualStateFor(code),
        showAllFar: _showAllFarRoutes,
        hasSelection: _selectedCode != null,
      );

  /// Valor de opacidad actualmente en pantalla para [code], interpolado
  /// entre el estado previo y el nuevo mientras corre `_visualFadeCtrl`.
  double _currentAlpha(String code) {
    final to = _alphaTo[code] ?? _targetAlphaFor(code);
    final from = _alphaFrom[code];
    if (from == null) return to;
    final t = AppColors.curvePremium.transform(_visualFadeCtrl.value);
    return from + (to - from) * t;
  }

  /// Detecta cambios en la opacidad objetivo de cualquier ruta (por ejemplo,
  /// al seleccionar una ruta y que las demás deban esconderse) y arranca un
  /// fundido cruzado de 380ms en vez de saltar directo al valor final.
  void _syncVisualFade() {
    final targets = <String, double>{
      for (final r in widget.routes) r.code: _targetAlphaFor(r.code),
    };
    final sameSize = _alphaTo.length == targets.length;
    final changed =
        !sameSize || targets.entries.any((e) => _alphaTo[e.key] != e.value);
    if (!changed) return;

    final snapshot = <String, double>{
      for (final code in targets.keys) code: _currentAlpha(code),
    };
    _alphaFrom = snapshot;
    _alphaTo = targets;
    _visualFadeCtrl.forward(from: 0);
  }

  bool _isRouteDrawable(String code) => _currentAlpha(code) > 0.001;

  Future<void> _selectRoute(String code,
      {bool openSheet = false, bool moveCamera = true}) async {
    final summary = widget.routes.where((r) => r.code == code).firstOrNull;
    if (summary == null) return;

    setState(() {
      _selectedCode = code;
      _ambiguousCodes = null;
    });

    if (openSheet && mounted) {
      final summary = widget.routes.where((r) => r.code == code).firstOrNull;
      final detail = summary != null ? _detailFor(summary) : null;
      if (summary != null && detail != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          RouteInfoSheet.show(
            context,
            summary: summary,
            detail: detail,
            routeColor:
                routeColor(summary.code, widget.routes.indexOf(summary)),
          );
        });
      }
    }

    if (moveCamera) {
      final points = _routePoints(summary);
      if (points.length >= 2) _safeFitCamera(points);
    }

    final detail = _detailFor(summary);
    if (detail != null && !detail.fullPrecisionLoaded) {
      try {
        final full = await _cache.ensureFullDetail(
            summary.id, ref.read(routesRepositoryProvider));
        if (mounted) {
          setState(() => _details[summary.id] = full);
        }
      } catch (_) {}
    }
  }

  void _focusRoute(String code, {bool moveCamera = true}) {
    _selectRoute(code, moveCamera: moveCamera);
  }

  void _safeFitCamera(List<LatLng> points) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || points.length < 2) return;
      try {
        final bounds = _boundsOf(points);
        final latSpan = (bounds.north - bounds.south).abs();
        final lngSpan = (bounds.east - bounds.west).abs();
        if (latSpan < 1e-5 && lngSpan < 1e-5) {
          _mapController.move(points.first, 14);
          return;
        }
        _mapController.fitCamera(
          CameraFit.coordinates(
            coordinates: points,
            padding: const EdgeInsets.fromLTRB(40, 130, 40, 160),
            maxZoom: 15,
          ),
        );
      } catch (_) {
        _mapController.move(points.first, 13);
      }
    });
  }

  ({double north, double south, double east, double west}) _boundsOf(
      List<LatLng> points) {
    var north = points.first.latitude;
    var south = north;
    var east = points.first.longitude;
    var west = east;
    for (final p in points.skip(1)) {
      if (p.latitude > north) north = p.latitude;
      if (p.latitude < south) south = p.latitude;
      if (p.longitude > east) east = p.longitude;
      if (p.longitude < west) west = p.longitude;
    }
    return (north: north, south: south, east: east, west: west);
  }

  void _showAllRoutes() {
    setState(() {
      _selectedCode = null;
      _navAction = null;
      _filterHint = null;
      _nightBoundsApplied = false;
      _fitPending = true;
      _nearbyFilterActive = false;
      _showAllFarRoutes = true;
      _nearbyFallbackMessage = null;
    });
    _scheduleFitBounds();
  }

  void _toggleShowAllFar() {
    setState(() => _showAllFarRoutes = !_showAllFarRoutes);
  }

  Future<void> _handleNavAction(MapNavAction action) async {
    switch (action) {
      case MapNavAction.planTrip:
        _startPlanning();
        return;
      case MapNavAction.nearby:
        await _focusNearbyRoute();
        return;
      case MapNavAction.nightRoutes:
        _applyNightFilter();
        return;
    }
  }

  void _startPlanning() {
    final center = _mapCenterLatLng() ?? const LatLng(21.155, -86.82);
    final origin = _userLocation ?? center;
    final destination =
        LatLng(center.latitude - 0.012, center.longitude + 0.016);
    setState(() {
      _planningMode = true;
      _navAction = MapNavAction.planTrip;
      _selectedCode = null;
      _planningOrigin = origin;
      _planningDestination = destination;
      _activePlannerPoint = _PlannerPoint.destination;
      _plannedRouteCodes = {};
      _plannedJourney = null;
      _planningConfirmed = false;
      _planningError = null;
      _filterHint = null;
    });
    _safeFitCamera([origin, destination]);
  }

  void _cancelPlanning() {
    setState(() {
      _planningMode = false;
      _planningOrigin = null;
      _planningDestination = null;
      _plannedRouteCodes = {};
      _plannedJourney = null;
      _planningConfirmed = false;
      _planningError = null;
      _selectedCode = null;
      _navAction = null;
    });
  }

  void _movePlannerPoint(_PlannerPoint target, LatLng point) {
    setState(() {
      _activePlannerPoint = target;
      _plannedRouteCodes = {};
      _plannedJourney = null;
      _planningConfirmed = false;
      _planningError = null;
      _selectedCode = null;
      if (target == _PlannerPoint.origin) {
        _planningOrigin = point;
      } else {
        _planningDestination = point;
      }
    });
  }

  void _dragPlannerPoint(_PlannerPoint target, DragUpdateDetails details) {
    final current =
        target == _PlannerPoint.origin ? _planningOrigin : _planningDestination;
    if (current == null) return;
    try {
      final screen = _mapController.camera.latLngToScreenPoint(current);
      final moved = _mapController.camera.pointToLatLng(
        math.Point<double>(
          screen.x + details.delta.dx,
          screen.y + details.delta.dy,
        ),
      );
      _movePlannerPoint(target, moved);
    } catch (_) {}
  }

  Future<void> _confirmPlanning() async {
    final origin = _planningOrigin;
    final destination = _planningDestination;
    if (origin == null || destination == null) return;
    final separationM = const Distance().distance(origin, destination);
    if (separationM < 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Separa el origen y el destino al menos 100 metros.')),
      );
      return;
    }
    setState(() {
      _planningCalculating = true;
      _planningError = null;
    });
    try {
      final result = await ref.read(routesRepositoryProvider).search(
            originLat: origin.latitude,
            originLng: origin.longitude,
            destLat: destination.latitude,
            destLng: destination.longitude,
            originLabel: 'Punto de partida',
            destLabel: 'Destino elegido',
          );
      if (!mounted) return;

      final journey = result.journeys.firstOrNull;
      final codes =
          journey?.legs.map((leg) => leg.routeCode).toSet() ?? <String>{};
      if (codes.isEmpty) {
        setState(() => _planningError =
            'Todavía no hay una ruta registrada que conecte estos puntos.');
        return;
      }

      setState(() {
        _plannedJourney = journey;
        _plannedRouteCodes = codes;
        _planningConfirmed = true;
        _selectedCode = codes.first;
      });
      final fitPoints = <LatLng>[origin, destination];
      for (final summary in widget.routes) {
        if (codes.contains(summary.code)) {
          fitPoints.addAll(_routePoints(summary));
        }
      }
      _safeFitCamera(fitPoints);
    } catch (_) {
      if (mounted) {
        setState(() => _planningError =
            'No pudimos calcular el viaje. Revisa tu conexión e intenta nuevamente.');
      }
    } finally {
      if (mounted) setState(() => _planningCalculating = false);
    }
  }

  void _showPlannedJourneyDetails() {
    final journey = _plannedJourney;
    if (journey == null) return;
    final details = <String, RouteDetail>{};
    for (final summary in widget.routes) {
      if (_plannedRouteCodes.contains(summary.code)) {
        final detail = _detailFor(summary);
        if (detail != null) details[summary.code] = detail;
      }
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (_) => _JourneyDetailsSheet(journey: journey, details: details),
    );
  }

  void _applyNightFilter() {
    final nightRoutes = widget.routes
        .where((r) => RouteServiceHours.matchesNightFilter(r.code))
        .toList();

    setState(() {
      _navAction = MapNavAction.nightRoutes;
      _selectedCode = null;
      _filterHint = nightRoutes.isEmpty
          ? 'Sin rutas nocturnas cargadas'
          : RouteServiceHours.nightFilterHint(
              count: nightRoutes.length,
              now: DateTime.now(),
            );
    });

    if (!_nightBoundsApplied && nightRoutes.isNotEmpty) {
      _fitPending = true;
      _scheduleFitBounds();
      _nightBoundsApplied = true;
    }
  }

  void _applyNearbyFromCache(NearbyCacheEntry cached) {
    _focusRoute(cached.routeCode, moveCamera: false);
    setState(() {
      _navAction = MapNavAction.nearby;
      _filterHint =
          'Ruta más cercana · ${cached.distanceKm.toStringAsFixed(1)} km (caché)';
    });
  }

  Future<void> _focusNearbyRoute() async {
    final cached = _cache.nearbyIfValid(null);
    if (cached != null && _bundleReady) {
      _applyNearbyFromCache(cached);
      return;
    }

    await _withLoading(() async {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) {
          setState(
              () => _filterHint = 'Activa ubicación para ver rutas cercanas');
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition();
      final here = LatLng(pos.latitude, pos.longitude);
      if (mounted) setState(() => _userLocation = here);

      final cachedAtLocation = _cache.nearbyIfValid(here);
      if (cachedAtLocation != null && _bundleReady) {
        _applyNearbyFromCache(cachedAtLocation);
        return;
      }

      if (!_bundleReady) {
        await _loadMapBundle();
      }

      RouteSummary? closest;
      var bestDist = double.infinity;
      for (final r in widget.routes) {
        for (final p in _routePoints(r)) {
          final d = const Distance().distance(here, p);
          if (d < bestDist) {
            bestDist = d;
            closest = r;
          }
        }
      }

      if (closest != null && mounted) {
        _cache.saveNearby(
          lat: here.latitude,
          lng: here.longitude,
          routeCode: closest.code,
          distanceM: bestDist,
        );
        _mapController.move(here, 14);
        _focusRoute(closest.code, moveCamera: false);
        setState(() {
          _navAction = MapNavAction.nearby;
          _filterHint =
              'Ruta más cercana · ${(bestDist / 1000).toStringAsFixed(1)} km';
        });
      }
    }, message: 'Buscando rutas cercanas…');
  }

  Future<void> _centerOnMyLocation() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Activa ubicación para centrarte en el mapa')),
        );
      }
      return;
    }
    final pos = await Geolocator.getCurrentPosition();
    final here = LatLng(pos.latitude, pos.longitude);
    if (mounted) setState(() => _userLocation = here);
    _mapController.move(here, 14.5);
  }

  void _handleMapTap(TapPosition tapPosition, LatLng point) {
    if (_planningMode) {
      _movePlannerPoint(_activePlannerPoint, point);
      return;
    }
    final hit = _polylineHitNotifier.value;
    if (hit != null && hit.hitValues.isNotEmpty) {
      _handlePolylineHits(hit.hitValues.toSet().toList());
      return;
    }

    final camera = _mapController.camera;
    final tapPx = tapPosition.relative ?? tapPosition.global;

    final hits = <String, double>{};
    for (final summary in _visibleRoutes) {
      if (!_isRouteDrawable(summary.code)) continue;
      final detail = _detailFor(summary);
      if (detail == null) continue;

      for (final seg in _renderableSegments(detail)) {
        final dist = _screenDistanceToPolyline(tapPx, seg.points, camera);
        if (dist < _tapTolerancePx) {
          hits[summary.code] =
              math.min(hits[summary.code] ?? double.infinity, dist);
        }
      }
    }

    if (hits.isEmpty) return;
    final sorted = hits.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final codes = sorted.map((e) => e.key).toList();
    if (codes.length == 1) {
      _selectRoute(codes.first, openSheet: true);
    } else {
      setState(() => _ambiguousCodes = codes.take(4).toList());
    }
  }

  double _screenDistanceToPolyline(
      Offset tap, List<LatLng> points, MapCamera camera) {
    if (points.length < 2) return double.infinity;
    var minDist = double.infinity;
    for (var i = 0; i < points.length - 1; i++) {
      final aPt = camera.latLngToScreenPoint(points[i]);
      final bPt = camera.latLngToScreenPoint(points[i + 1]);
      final a = Offset(aPt.x, aPt.y);
      final b = Offset(bPt.x, bPt.y);
      final d = _pointToSegmentDistance(tap, a, b);
      if (d < minDist) minDist = d;
    }
    return minDist;
  }

  double _pointToSegmentDistance(Offset p, Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    if (dx == 0 && dy == 0) return (p - a).distance;
    final t = ((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / (dx * dx + dy * dy);
    final clamped = t.clamp(0.0, 1.0);
    final proj = Offset(a.dx + clamped * dx, a.dy + clamped * dy);
    return (p - proj).distance;
  }

  List<Polyline<String>> _buildPolylines() {
    final polylines = <Polyline<String>>[];
    final routes = [..._visibleRoutes];
    routes.sort((a, b) {
      final sa = _visualStateFor(a.code).index;
      final sb = _visualStateFor(b.code).index;
      return sa.compareTo(sb);
    });

    for (final summary in routes) {
      if (!_isRouteDrawable(summary.code)) continue;
      final detail = _detailFor(summary);
      if (detail == null) continue;

      final color = routeColor(summary.code, widget.routes.indexOf(summary));
      final visual = _visualStateFor(summary.code);
      final alpha = _currentAlpha(summary.code);
      if (alpha <= 0.001) continue;

      final width = visual == RouteVisualState.selected ? 7.0 : 4.5;

      void addSegment(List<LatLng> pts, {bool isVuelta = false}) {
        if (pts.length < 2) return;
        // Halo de color suave y ancho detrás de la ruta seleccionada — la
        // separa claramente del resto del mapa (glow, look "premium").
        if (visual == RouteVisualState.selected) {
          polylines.add(
            Polyline<String>(
              points: pts,
              hitValue: summary.code,
              color: color.withValues(alpha: 0.20 * alpha),
              strokeWidth: width + 16,
              strokeCap: StrokeCap.round,
              strokeJoin: StrokeJoin.round,
            ),
          );
        }
        polylines.add(
          Polyline<String>(
            points: pts,
            hitValue: summary.code,
            color: Colors.white.withValues(alpha: alpha * 0.92),
            strokeWidth: width + 4,
            strokeCap: StrokeCap.round,
            strokeJoin: StrokeJoin.round,
          ),
        );
        polylines.add(
          Polyline<String>(
            points: pts,
            hitValue: summary.code,
            color: Color.lerp(color, Colors.black, 0.15)!
                .withValues(alpha: alpha * 0.35),
            strokeWidth: width + 1.5,
            strokeCap: StrokeCap.round,
            strokeJoin: StrokeJoin.round,
          ),
        );
        polylines.add(
          Polyline<String>(
            points: pts,
            hitValue: summary.code,
            color: color.withValues(alpha: alpha),
            strokeWidth: isVuelta ? width - 1 : width,
            strokeCap: StrokeCap.round,
            strokeJoin: StrokeJoin.round,
            pattern: isVuelta
                ? StrokePattern.dashed(segments: const [12, 10])
                : const StrokePattern.solid(),
          ),
        );
      }

      for (final seg in _renderableSegments(detail)) {
        addSegment(seg.points, isVuelta: seg.isVuelta);
      }
    }
    if (_planningConfirmed && _plannedJourney != null) {
      final firstCode = _plannedJourney!.legs.first.routeCode;
      final lastCode = _plannedJourney!.legs.last.routeCode;
      final originJoin = _nearestPointOnRoute(firstCode, _planningOrigin);
      final destinationJoin =
          _nearestPointOnRoute(lastCode, _planningDestination);
      if (_planningOrigin != null && originJoin != null) {
        polylines.add(
          Polyline<String>(
            points: [_planningOrigin!, originJoin],
            color: const Color(0xFF18A66A).withValues(alpha: 0.9),
            strokeWidth: 4,
            strokeCap: StrokeCap.round,
            pattern: StrokePattern.dashed(segments: const [7, 7]),
          ),
        );
      }
      if (_planningDestination != null && destinationJoin != null) {
        polylines.add(
          Polyline<String>(
            points: [destinationJoin, _planningDestination!],
            color: const Color(0xFFE34C4C).withValues(alpha: 0.9),
            strokeWidth: 4,
            strokeCap: StrokeCap.round,
            pattern: StrokePattern.dashed(segments: const [7, 7]),
          ),
        );
      }
    }
    return polylines;
  }

  LatLng? _nearestPointOnRoute(String code, LatLng? target) {
    if (target == null) return null;
    final summary =
        widget.routes.where((route) => route.code == code).firstOrNull;
    if (summary == null) return null;
    LatLng? nearest;
    var bestDistance = double.infinity;
    for (final point in _routePoints(summary)) {
      final distance = const Distance().distance(target, point);
      if (distance < bestDistance) {
        bestDistance = distance;
        nearest = point;
      }
    }
    return nearest;
  }

  List<FlowSegment> _buildFlowSegments() {
    if (!_startupAnimationDone) return [];
    final segments = <FlowSegment>[];
    var vehicleAssigned = false;
    for (final summary in _visibleRoutes) {
      if (!_isRouteDrawable(summary.code)) continue;
      final detail = _detailFor(summary);
      if (detail == null) continue;

      final color = routeColor(summary.code, widget.routes.indexOf(summary));
      final visual = _visualStateFor(summary.code);
      final dimmed = visual != RouteVisualState.selected;

      for (final seg in _renderableSegments(detail)) {
        final showVehicle = !dimmed && !vehicleAssigned && !seg.isVuelta;
        segments.add(
          FlowSegment(
            points: seg.points,
            color: color,
            strokeWidth: seg.isVuelta ? 4 : 5,
            dimmed: dimmed,
            showVehicle: showVehicle,
          ),
        );
        if (showVehicle) vehicleAssigned = true;
      }
    }
    return segments;
  }

  List<StartupRevealSegment> _buildStartupSegments() {
    final segments = <StartupRevealSegment>[];
    for (final summary in _visibleRoutes) {
      final detail = _detailFor(summary);
      if (detail == null) continue;
      if (_nearbyFilterActive && !_nearbyRouteCodes.contains(summary.code)) {
        continue;
      }

      final color = routeColor(summary.code, widget.routes.indexOf(summary));
      for (final seg in _renderableSegments(detail)) {
        final km = detail.directions
                ?.where((d) => d.direction == (seg.isVuelta ? 'vuelta' : 'ida'))
                .firstOrNull
                ?.distanceKm ??
            (detail.metadata?['distanceKm'] as num?)?.toDouble() ??
            5.0;
        segments.add(
          StartupRevealSegment(
            points: seg.points,
            color: color,
            distanceKm: km,
            strokeWidth: seg.isVuelta ? 4 : 5,
            isDashed: seg.isVuelta,
          ),
        );
      }
    }
    return segments;
  }

  LatLng? _mapCenterLatLng() {
    try {
      return _mapController.camera.center;
    } catch (_) {
      return null;
    }
  }

  List<Marker> _buildMapMarkers() {
    final markers = <Marker>[];
    final center = _mapCenterLatLng();

    if (_userLocation != null) {
      markers.add(
        Marker(
          point: _userLocation!,
          width: UserLocationPulseMarker.size,
          height: UserLocationPulseMarker.size,
          rotate: false,
          alignment: Alignment.center,
          child: const RepaintBoundary(child: UserLocationPulseMarker()),
        ),
      );
    }

    if (_planningMode) {
      if (_planningOrigin != null) {
        markers.add(
          Marker(
            point: _planningOrigin!,
            width: 64,
            height: 76,
            alignment: Alignment.topCenter,
            child: _DraggablePlannerMarker(
              kind: _PlannerPoint.origin,
              selected: _activePlannerPoint == _PlannerPoint.origin,
              onSelected: () =>
                  setState(() => _activePlannerPoint = _PlannerPoint.origin),
              onDragUpdate: (details) =>
                  _dragPlannerPoint(_PlannerPoint.origin, details),
            ),
          ),
        );
      }
      if (_planningDestination != null) {
        markers.add(
          Marker(
            point: _planningDestination!,
            width: 64,
            height: 76,
            alignment: Alignment.topCenter,
            child: _DraggablePlannerMarker(
              kind: _PlannerPoint.destination,
              selected: _activePlannerPoint == _PlannerPoint.destination,
              onSelected: () => setState(
                  () => _activePlannerPoint = _PlannerPoint.destination),
              onDragUpdate: (details) =>
                  _dragPlannerPoint(_PlannerPoint.destination, details),
            ),
          ),
        );
      }
    }

    for (final summary in _visibleRoutes) {
      if (!_isRouteDrawable(summary.code)) continue;
      final detail = _detailFor(summary);
      if (detail == null) continue;

      final color = routeColor(summary.code, widget.routes.indexOf(summary));
      final visual = _visualStateFor(summary.code);
      final alpha = _currentAlpha(summary.code);
      if (alpha <= 0.001) continue;

      if (visual == RouteVisualState.selected) {
        for (final stop in detail.stops) {
          markers.add(
            Marker(
              point: LatLng(stop.lat, stop.lng),
              width: 38,
              height: 38,
              alignment: Alignment.center,
              child: RouteStopMarker(
                sequence: stop.sequence,
                color: color,
                large: true,
              ),
            ),
          );
        }
      }

      for (final seg in _renderableSegments(detail)) {
        if (seg.isVuelta || seg.points.length < 2) continue;
        final midIdx = _badgeIndexClosestToCenter(seg.points, center);
        final mid = seg.points[midIdx];
        markers.add(
          Marker(
            point: mid,
            width: visual == RouteVisualState.selected ? 52 : 44,
            height: visual == RouteVisualState.selected ? 30 : 26,
            alignment: Alignment.center,
            child: Opacity(
              opacity: alpha,
              child: RouteLineBadge(
                code: summary.code,
                color: color.withValues(
                    alpha: visual == RouteVisualState.selected ? 1 : 0.75),
                large: visual == RouteVisualState.selected,
              ),
            ),
          ),
        );
        break;
      }
    }

    return markers;
  }

  int _badgeIndexClosestToCenter(List<LatLng> points, LatLng? center) {
    if (center == null || points.isEmpty) return points.length ~/ 2;
    var best = 0;
    var bestD = double.infinity;
    for (var i = 0; i < points.length; i++) {
      final d = const Distance().distance(center, points[i]);
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    _syncVisualFade();
    final flowSegments = _buildFlowSegments();
    final polylines = _buildPolylines();
    final mapMarkers = _buildMapMarkers();
    final startupSegments = _buildStartupSegments();

    return Stack(
      fit: StackFit.expand,
      children: [
        FlutterMap(
          key: ValueKey(_mapTheme),
          mapController: _mapController,
          options: MapOptions(
            initialCenter: const LatLng(21.155, -86.82),
            initialZoom: 12.5,
            interactionOptions:
                const InteractionOptions(flags: InteractiveFlag.all),
            onTap: _handleMapTap,
          ),
          children: [
            VividMapTiles(theme: _mapTheme),
            if (polylines.isNotEmpty)
              PolylineLayer(
                polylines: polylines,
                hitNotifier: _polylineHitNotifier,
              ),
            if (mapMarkers.isNotEmpty) MarkerLayer(markers: mapMarkers),
          ],
        ),
        if (!_startupAnimationDone && _bundleReady)
          Positioned.fill(
            child: RouteStartupRevealOverlay(
              controller: _mapController,
              segments: startupSegments,
              active: true,
              onComplete: _onStartupAnimationComplete,
            ),
          ),
        if (_startupAnimationDone)
          Positioned.fill(
            child: RouteFlowOverlay(
                controller: _mapController, segments: flowSegments),
          ),
        if (_isLoading) MapLoadingOverlay(message: _loadingMessage),
        SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Antes el botón de ubicación se posicionaba con un offset
              // manual (Positioned top:8) mientras la barra de búsqueda tiene
              // su propio padding interno de otra altura — quedaban con
              // centros verticales distintos ("descuadrado"). Un Row con
              // centrado vertical alinea ambos sin importar la altura exacta
              // de cada uno.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child:
                          LiquidSearchBar(onTap: () => context.push('/search')),
                    ),
                    const SizedBox(width: 10),
                    GlassIconButton(
                      icon: Icons.my_location_rounded,
                      tooltip: 'Mi ubicación',
                      highlight: true,
                      onPressed: _centerOnMyLocation,
                    ),
                  ],
                ),
              ),
              if (_nearbyFallbackMessage != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Text(
                    _nearbyFallbackMessage!,
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(fontSize: 11, color: AppColors.accent),
                  ),
                ),
              if (_nearbyFilterActive &&
                  _startupAnimationDone &&
                  !_showAllFarRoutes)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: ActionChip(
                    label: const Text('Ver todas'),
                    onPressed: _toggleShowAllFar,
                  ),
                ),
              const SizedBox(height: 10),
              MapQuickActions(
                onFindNearby: () => _handleNavAction(MapNavAction.nearby),
              ),
            ],
          ),
        ),
        if (_ambiguousCodes != null)
          Center(
            child: RouteAmbiguousPicker(
              codes: _ambiguousCodes!,
              onPick: (c) => _selectRoute(c, openSheet: true),
              onDismiss: () => setState(() => _ambiguousCodes = null),
            ),
          ),
        if (_planningMode)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: _TripPlannerPanel(
              activePoint: _activePlannerPoint,
              onSelectOrigin: () =>
                  setState(() => _activePlannerPoint = _PlannerPoint.origin),
              onSelectDestination: () => setState(
                  () => _activePlannerPoint = _PlannerPoint.destination),
              onConfirm: _confirmPlanning,
              onCancel: _cancelPlanning,
              confirmed: _planningConfirmed,
              calculating: _planningCalculating,
              error: _planningError,
              routeCodes: _plannedRouteCodes.toList(),
              journey: _plannedJourney,
              onEdit: () => setState(() {
                _planningConfirmed = false;
                _plannedRouteCodes = {};
                _plannedJourney = null;
                _selectedCode = null;
              }),
              onOpenDetails: _showPlannedJourneyDetails,
            ),
          ),
        if (!_planningMode)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MapBottomDock(
              routes: _visibleRoutes,
              selectedCode: _selectedCode,
              routeColor: routeColor,
              collapsedHint: _filterHint,
              detailFor: _detailFor,
              onRouteTap: _focusRoute,
              onShowAll: _showAllRoutes,
              navAction: _navAction,
              onNavAction: _handleNavAction,
              nearbyRouteCodes: _nearbyRouteCodes,
              nearbyFilterActive: _nearbyFilterActive && _startupAnimationDone,
            ),
          ),
      ],
    );
  }
}

enum _PlannerPoint { origin, destination }

class _DraggablePlannerMarker extends StatelessWidget {
  const _DraggablePlannerMarker({
    required this.kind,
    required this.selected,
    required this.onSelected,
    required this.onDragUpdate,
  });

  final _PlannerPoint kind;
  final bool selected;
  final VoidCallback onSelected;
  final GestureDragUpdateCallback onDragUpdate;

  @override
  Widget build(BuildContext context) {
    final isOrigin = kind == _PlannerPoint.origin;
    final color = isOrigin ? const Color(0xFF18A66A) : const Color(0xFFE34C4C);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onSelected,
      onPanStart: (_) => onSelected(),
      onPanUpdate: onDragUpdate,
      child: AnimatedScale(
        scale: selected ? 1.08 : 1,
        duration: const Duration(milliseconds: 180),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(color: Color(0x33000000), blurRadius: 8)
                ],
              ),
              child: Text(
                isOrigin ? 'SALIDA' : 'DESTINO',
                style: TextStyle(
                    color: color, fontSize: 9, fontWeight: FontWeight.w900),
              ),
            ),
            Icon(Icons.location_on_rounded,
                color: color,
                size: 42,
                shadows: const [
                  Shadow(
                      color: Color(0x55000000),
                      blurRadius: 6,
                      offset: Offset(0, 3)),
                ]),
          ],
        ),
      ),
    );
  }
}

class _TripPlannerPanel extends StatelessWidget {
  const _TripPlannerPanel({
    required this.activePoint,
    required this.onSelectOrigin,
    required this.onSelectDestination,
    required this.onConfirm,
    required this.onCancel,
    required this.confirmed,
    required this.calculating,
    required this.error,
    required this.routeCodes,
    required this.journey,
    required this.onEdit,
    required this.onOpenDetails,
  });

  final _PlannerPoint activePoint;
  final VoidCallback onSelectOrigin;
  final VoidCallback onSelectDestination;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final bool confirmed;
  final bool calculating;
  final String? error;
  final List<String> routeCodes;
  final JourneyOption? journey;
  final VoidCallback onEdit;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF073B4C).withValues(alpha: 0.24),
            blurRadius: 30,
            spreadRadius: 2,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                        confirmed ? 'Tu mejor recorrido' : 'Elige tu recorrido',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  IconButton(
                      onPressed: onCancel,
                      icon: const Icon(Icons.close_rounded)),
                ],
              ),
              if (confirmed) ...[
                InkWell(
                  onTap: onOpenDetails,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.route_rounded,
                                color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                routeCodes.join('  →  '),
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w900),
                              ),
                            ),
                            if (journey != null)
                              Text('~${journey!.estimatedDurationMin} min',
                                  style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w800)),
                            const SizedBox(width: 3),
                            const Icon(Icons.keyboard_arrow_up_rounded,
                                color: AppColors.primary),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          journey == null
                              ? 'Se muestra la mejor ruta disponible con los datos actuales.'
                              : journey!.transfers == 0
                                  ? 'Ruta directa · ${journey!.totalWalkKm.toStringAsFixed(1)} km caminando'
                                  : '${journey!.transfers} transbordo · ${journey!.totalWalkKm.toStringAsFixed(1)} km caminando',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Toca para ver el viaje paso a paso',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_location_alt_rounded),
                    label: const Text('Modificar puntos'),
                  ),
                ),
              ] else ...[
                Text(
                  'Arrastra los marcadores o selecciona uno y toca el mapa.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _PlannerPointButton(
                        label: 'Punto de partida',
                        color: const Color(0xFF18A66A),
                        selected: activePoint == _PlannerPoint.origin,
                        onTap: onSelectOrigin,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _PlannerPointButton(
                        label: 'Destino',
                        color: const Color(0xFFE34C4C),
                        selected: activePoint == _PlannerPoint.destination,
                        onTap: onSelectDestination,
                      ),
                    ),
                  ],
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Color(0xFFE34C4C), fontSize: 12)),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: calculating ? null : onConfirm,
                    icon: calculating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.route_rounded),
                    label: Text(
                        calculating ? 'Calculando…' : 'Calcular mejores rutas'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _JourneyDetailsSheet extends StatelessWidget {
  const _JourneyDetailsSheet({required this.journey, required this.details});

  final JourneyOption journey;
  final Map<String, RouteDetail> details;

  List<RouteStop> _stopsForLeg(JourneyLeg leg) {
    final stops = details[leg.routeCode]?.stops ?? const <RouteStop>[];
    if (stops.isEmpty) return const [];
    final board = stops.indexWhere((stop) => stop.name == leg.boardStop);
    final alight = stops.indexWhere((stop) => stop.name == leg.alightStop);
    if (board < 0 || alight < 0) return stops;
    if (board <= alight) return stops.sublist(board, alight + 1);
    return stops.sublist(alight, board + 1).reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.48,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF9FCFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 30,
                  offset: Offset(0, -8)),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 34),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tu viaje paso a paso',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                )),
                        const SizedBox(height: 4),
                        Text(
                          journey.legs
                              .map((leg) => leg.routeCode)
                              .join('  →  '),
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 17,
                              fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _JourneyMetric(
                      icon: Icons.schedule_rounded,
                      label: '~${journey.estimatedDurationMin} min'),
                  _JourneyMetric(
                      icon: Icons.directions_walk_rounded,
                      label:
                          '${journey.totalWalkKm.toStringAsFixed(1)} km caminando'),
                  _JourneyMetric(
                      icon: Icons.swap_horiz_rounded,
                      label: journey.transfers == 0
                          ? 'Sin transbordos'
                          : '${journey.transfers} transbordo'),
                ],
              ),
              const SizedBox(height: 22),
              _JourneyStep(
                icon: Icons.trip_origin_rounded,
                color: const Color(0xFF18A66A),
                title: 'Camina al punto de abordaje',
                subtitle:
                    '${journey.accessWalkKm.toStringAsFixed(1)} km hasta ${journey.legs.first.boardStop}',
              ),
              for (var index = 0; index < journey.legs.length; index++) ...[
                _RouteJourneyStep(
                  leg: journey.legs[index],
                  color: routeColor(journey.legs[index].routeCode, index),
                  stops: _stopsForLeg(journey.legs[index]),
                ),
                if (index < journey.legs.length - 1)
                  _JourneyStep(
                    icon: Icons.directions_walk_rounded,
                    color: AppColors.accent,
                    title: 'Haz el transbordo',
                    subtitle:
                        'Camina ${journey.transferWalkKm.toStringAsFixed(1)} km hacia ${journey.legs[index + 1].boardStop}',
                  ),
              ],
              _JourneyStep(
                icon: Icons.location_on_rounded,
                color: const Color(0xFFE34C4C),
                title: journey.egressWalkKm < 0.05
                    ? 'Llegaste a tu destino'
                    : 'Camina hasta tu destino',
                subtitle: journey.egressWalkKm < 0.05
                    ? 'La ruta te deja en el punto elegido.'
                    : '${journey.egressWalkKm.toStringAsFixed(1)} km desde ${journey.legs.last.alightStop}',
              ),
              const SizedBox(height: 10),
              Text(
                'Tiempo estimado sin tráfico ni frecuencias en vivo. Mejorará conforme se registren más rutas y horarios.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _JourneyMetric extends StatelessWidget {
  const _JourneyMetric({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _JourneyStep extends StatelessWidget {
  const _JourneyStep({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 3),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteJourneyStep extends StatelessWidget {
  const _RouteJourneyStep(
      {required this.leg, required this.color, required this.stops});

  final JourneyLeg leg;
  final Color color;
  final List<RouteStop> stops;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(14)),
            alignment: Alignment.center,
            child: Text(leg.routeCode,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w900)),
          ),
          title: Text(leg.routeName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              '${leg.boardStop}  →  ${leg.alightStop}\n${leg.distanceKm.toStringAsFixed(1)} km en la ruta',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
          children: [
            const Divider(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Por dónde pasa',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      )),
            ),
            const SizedBox(height: 10),
            if (stops.isEmpty)
              Text('Aún no hay paradas detalladas para esta ruta.',
                  style: Theme.of(context).textTheme.bodySmall)
            else
              for (var index = 0; index < stops.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index == 0 || index == stops.length - 1
                              ? color
                              : Colors.white,
                          border: Border.all(color: color, width: 2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(stops[index].name)),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _PlannerPointButton extends StatelessWidget {
  const _PlannerPointButton({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 0.16 : 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color, width: selected ? 2 : 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.circle, color: color, size: 11),
            const SizedBox(width: 7),
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, color: color)),
            ),
          ],
        ),
      ),
    );
  }
}
