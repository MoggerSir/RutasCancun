import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:rutas_cancun/core/theme/app_colors.dart';
import 'package:rutas_cancun/core/widgets/glass_surface.dart';
import 'package:rutas_cancun/core/widgets/service_hours_badge.dart';
import 'package:rutas_cancun/features/routes/domain/route_colors.dart';
import 'package:rutas_cancun/features/routes/data/routes_repository.dart';
import 'package:rutas_cancun/features/routes/domain/route_service_hours.dart';
import 'package:rutas_cancun/features/map/widgets/institutional_map_tiles.dart';

class SearchResultsScreen extends ConsumerStatefulWidget {
  const SearchResultsScreen({
    super.key,
    required this.origin,
    required this.destination,
  });

  final Map<String, dynamic> origin;
  final Map<String, dynamic> destination;

  @override
  ConsumerState<SearchResultsScreen> createState() =>
      _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final MapController _mapController = MapController();
  SearchResult? _result;
  int _selectedJourneyIndex = 0;
  bool _panelExpanded = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _search();
  }

  Future<void> _search() async {
    try {
      final repo = ref.read(routesRepositoryProvider);
      final result = await repo.search(
        originLat: (widget.origin['lat'] as num).toDouble(),
        originLng: (widget.origin['lng'] as num).toDouble(),
        destLat: (widget.destination['lat'] as num).toDouble(),
        destLng: (widget.destination['lng'] as num).toDouble(),
        originLabel: widget.origin['label'] as String?,
        destLabel: widget.destination['label'] as String?,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        if (result.incidentsAvailable) {
          _tabs.dispose();
          _tabs = TabController(length: 3, vsync: this);
        }
      });
      _fitSelectedJourney();
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'No pudimos calcular el recorrido. Revisa tu conexión e intenta de nuevo.');
      }
    }
  }

  JourneyOption? get _selectedJourney {
    final journeys = _result?.journeys ?? const <JourneyOption>[];
    if (journeys.isEmpty) return null;
    return journeys[_selectedJourneyIndex.clamp(0, journeys.length - 1)];
  }

  LatLng get _origin => LatLng(
        (widget.origin['lat'] as num).toDouble(),
        (widget.origin['lng'] as num).toDouble(),
      );

  LatLng get _destination => LatLng(
        (widget.destination['lat'] as num).toDouble(),
        (widget.destination['lng'] as num).toDouble(),
      );

  List<LatLng> _legPoints(JourneyLeg leg) =>
      leg.geometry.map((point) => LatLng(point.lat, point.lng)).toList();

  void _fitSelectedJourney() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final points = <LatLng>[_origin, _destination];
      final journey = _selectedJourney;
      if (journey != null) {
        for (final leg in journey.legs) {
          points.addAll(_legPoints(leg));
        }
      }
      if (points.length < 2) return;
      try {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(points),
            padding: EdgeInsets.fromLTRB(
              42,
              120,
              42,
              MediaQuery.sizeOf(context).height *
                  (_panelExpanded ? 0.42 : 0.12),
            ),
          ),
        );
      } catch (_) {}
    });
  }

  List<Polyline> _journeyPolylines() {
    final journey = _selectedJourney;
    if (journey == null) return const [];
    final lines = <Polyline>[];
    for (var index = 0; index < journey.legs.length; index++) {
      final leg = journey.legs[index];
      final points = _legPoints(leg);
      if (points.length < 2) continue;
      lines.add(
        Polyline(
          points: points,
          color: routeColor(leg.routeCode, index),
          strokeWidth: 7,
          borderColor: Colors.white,
          borderStrokeWidth: 3,
          strokeCap: StrokeCap.round,
          strokeJoin: StrokeJoin.round,
        ),
      );
    }

    void addWalk(LatLng from, LatLng to, Color color) {
      lines.add(
        Polyline(
          points: [from, to],
          color: color,
          strokeWidth: 4,
          pattern: StrokePattern.dashed(segments: const [7, 7]),
          strokeCap: StrokeCap.round,
        ),
      );
    }

    final first = journey.legs.first;
    final last = journey.legs.last;
    if (first.boardPoint != null) {
      addWalk(
        _origin,
        LatLng(first.boardPoint!.lat, first.boardPoint!.lng),
        const Color(0xFF18A66A),
      );
    }
    for (var index = 0; index < journey.legs.length - 1; index++) {
      final from = journey.legs[index].alightPoint;
      final to = journey.legs[index + 1].boardPoint;
      if (from != null && to != null) {
        addWalk(LatLng(from.lat, from.lng), LatLng(to.lat, to.lng),
            const Color(0xFF50646D));
      }
    }
    if (last.alightPoint != null) {
      addWalk(
        LatLng(last.alightPoint!.lat, last.alightPoint!.lng),
        _destination,
        const Color(0xFFE34C4C),
      );
    }
    return lines;
  }

  List<Marker> _journeyMarkers() {
    final markers = <Marker>[];
    final journey = _selectedJourney;
    if (journey != null) {
      for (var index = 0; index < journey.legs.length; index++) {
        final leg = journey.legs[index];
        final points = _legPoints(leg);
        if (points.isEmpty) continue;
        final color = routeColor(leg.routeCode, index);
        markers.add(
          Marker(
            point: points[points.length ~/ 2],
            width: 82,
            height: 38,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: Text(
                leg.routeCode,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        );
      }
    }

    Marker endpoint(LatLng point, String label, Color color) => Marker(
          point: point,
          width: 82,
          height: 72,
          alignment: Alignment.topCenter,
          rotate: true,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color, width: 1.5),
                ),
                child: Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.w900)),
              ),
              Icon(Icons.location_on_rounded, color: color, size: 40),
            ],
          ),
        );

    // Se agregan al final para conservar el z-index superior.
    markers.add(endpoint(_origin, 'SALIDA', const Color(0xFF18A66A)));
    markers.add(endpoint(_destination, 'DESTINO', const Color(0xFFE34C4C)));
    return markers;
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _origin,
              initialZoom: 12.5,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              const VividMapTiles(),
              const MapAttribution(),
              if (_selectedJourney != null)
                PolylineLayer(
                  polylines: _journeyPolylines(),
                  simplificationTolerance: 0.5,
                ),
              if (_selectedJourney != null)
                MarkerLayer(markers: _journeyMarkers()),
            ],
          ),
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 3,
                  child: IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                ),
              ),
            ),
          ),
          if (_result == null && _error == null)
            const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2.5),
            ),
          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: GlassSurface(
                  child: Text(_error!, textAlign: TextAlign.center),
                ),
              ),
            ),
          if (_result != null) _buildResultsPanel(context),
        ],
      ),
    );
  }

  Widget _buildResultsPanel(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final panelHeight = _panelExpanded ? height * 0.40 : 106.0;
    final journey = _selectedJourney;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      left: 10,
      right: 10,
      // Se suma el inset inferior del sistema (gestos/barra de navegación)
      // para que el panel no quede tapado ni pegado detrás de ella.
      bottom: 10 + MediaQuery.of(context).padding.bottom,
      height: panelHeight,
      child: Material(
        color: Colors.white.withValues(alpha: 0.97),
        elevation: 14,
        shadowColor: const Color(0x55000000),
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            InkWell(
              onTap: () {
                setState(() => _panelExpanded = !_panelExpanded);
                _fitSelectedJourney();
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 14, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            journey == null
                                ? 'Sin conexión disponible'
                                : journey.legs
                                    .map((leg) => leg.routeCode)
                                    .join('  →  '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                          if (journey != null)
                            Text(
                              '~${journey.estimatedDurationMin} min · ${journey.totalWalkKm.toStringAsFixed(1)} km caminando',
                              style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                    ),
                    Icon(_panelExpanded
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded),
                  ],
                ),
              ),
            ),
            if (_panelExpanded) ...[
              if (_result!.journeys.isNotEmpty)
                _JourneyRecommendations(
                  journeys: _result!.journeys,
                  selectedIndex: _selectedJourneyIndex,
                  onSelected: (index) {
                    setState(() => _selectedJourneyIndex = index);
                    _fitSelectedJourney();
                  },
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TabBar(
                  controller: _tabs,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textMuted,
                  tabs: [
                    const Tab(text: 'Cobertura'),
                    const Tab(text: 'Distancia'),
                    if (_result!.incidentsAvailable)
                      const Tab(text: 'Incidentes'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _ResultsList(
                      results: [..._result!.results]..sort((a, b) =>
                          a.rankByCoverage.compareTo(b.rankByCoverage)),
                      rankLabel: (r) => '#${r.rankByCoverage} cobertura',
                      rankAccent: AppColors.primary,
                    ),
                    _ResultsList(
                      results: [..._result!.results]..sort((a, b) =>
                          a.rankByDistance.compareTo(b.rankByDistance)),
                      rankLabel: (r) =>
                          '#${r.rankByDistance} · ${r.distanceKm} km',
                      rankAccent: AppColors.secondary,
                    ),
                    if (_result!.incidentsAvailable)
                      _ResultsList(
                        results: [..._result!.results]..sort((a, b) =>
                            (a.rankByIncidents ?? 99)
                                .compareTo(b.rankByIncidents ?? 99)),
                        rankLabel: (r) =>
                            '${r.recentIncidentClusters} reportes recientes',
                        rankAccent: AppColors.accent,
                      ),
                  ].whereType<Widget>().toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _JourneyRecommendations extends StatelessWidget {
  const _JourneyRecommendations({
    required this.journeys,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<JourneyOption> journeys;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        itemCount: journeys.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final journey = journeys[index];
          return GestureDetector(
            onTap: () => onSelected(index),
            child: Container(
              width: 248,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: index == selectedIndex
                      ? AppColors.primary.withValues(alpha: 0.65)
                      : AppColors.glassBorder,
                  width: index == selectedIndex ? 2 : 1,
                ),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x16000000),
                      blurRadius: 12,
                      offset: Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (index == selectedIndex)
                        const Padding(
                          padding: EdgeInsets.only(right: 7),
                          child: Icon(Icons.auto_awesome_rounded,
                              size: 16, color: AppColors.primary),
                        ),
                      Expanded(
                        child: Text(
                          journey.legs
                              .map((leg) => leg.routeCode)
                              .join('  →  '),
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                      ),
                      Text('~${journey.estimatedDurationMin} min',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    journey.transfers == 0
                        ? 'Ruta directa'
                        : '${journey.transfers} transbordo · caminar entre paradas',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${journey.totalWalkKm.toStringAsFixed(1)} km caminando · '
                    '${journey.transitDistanceKm.toStringAsFixed(1)} km en transporte',
                    maxLines: 2,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    '${journey.legs.first.boardStop} → ${journey.legs.last.alightStop}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({
    required this.results,
    required this.rankLabel,
    required this.rankAccent,
  });

  final List<RankedRoute> results;
  final String Function(RankedRoute) rankLabel;
  final Color rankAccent;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No hay rutas para este trayecto',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: results.length,
      itemBuilder: (context, i) {
        final r = results[i];
        final duration = r.durationText();
        final color = routeColor(r.routeCode, i);
        final service = RouteServiceHours.forCode(r.routeCode);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassSurface(
            borderRadius: BorderRadius.circular(22),
            blur: 22,
            onTap: () => context.push('/routes/${r.routeCode}'),
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.45),
                        color.withValues(alpha: 0.15),
                      ],
                    ),
                    border: Border.all(color: color.withValues(alpha: 0.5)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    r.routeCode.replaceAll('R', ''),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.text,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              r.routeName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontSize: 15),
                            ),
                          ),
                          ServiceHoursBadge(
                              routeCode: r.routeCode, compact: true),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: rankAccent.withValues(alpha: 0.12),
                        ),
                        child: Text(
                          rankLabel(r),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: rankAccent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Recorrido ~${r.distanceKm} km',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (duration.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(duration,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                      if (service?.hasNightService == true) ...[
                        const SizedBox(height: 6),
                        Text(
                          service!.summary,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color:
                                    AppColors.secondary.withValues(alpha: 0.95),
                                fontSize: 11,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: AppColors.textMuted.withValues(alpha: 0.7)),
              ],
            ),
          ),
        );
      },
    );
  }
}
