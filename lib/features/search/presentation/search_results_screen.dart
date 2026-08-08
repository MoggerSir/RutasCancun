import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rutas_cancun/core/theme/app_colors.dart';
import 'package:rutas_cancun/core/widgets/glass_surface.dart';
import 'package:rutas_cancun/core/widgets/service_hours_badge.dart';
import 'package:rutas_cancun/features/routes/domain/route_colors.dart';
import 'package:rutas_cancun/features/routes/data/routes_repository.dart';
import 'package:rutas_cancun/features/routes/domain/route_service_hours.dart';

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
  SearchResult? _result;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _search();
  }

  Future<void> _search() async {
    final repo = ref.read(routesRepositoryProvider);
    final result = await repo.search(
      originLat: (widget.origin['lat'] as num).toDouble(),
      originLng: (widget.origin['lng'] as num).toDouble(),
      destLat: (widget.destination['lat'] as num).toDouble(),
      destLng: (widget.destination['lng'] as num).toDouble(),
      originLabel: widget.origin['label'] as String?,
      destLabel: widget.destination['label'] as String?,
    );
    if (mounted) {
      setState(() {
        _result = result;
        if (result.incidentsAvailable) {
          _tabs.dispose();
          _tabs = TabController(length: 3, vsync: this);
        }
      });
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.origin['label'];
    final d = widget.destination['label'];

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resultados', style: Theme.of(context).textTheme.titleMedium),
            Text(
              '$o → $d',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
        bottom: _result == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: GlassSurface(
                    borderRadius: BorderRadius.circular(18),
                    blur: 20,
                    padding: EdgeInsets.zero,
                    child: TabBar(
                      controller: _tabs,
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      indicator: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: AppColors.primary.withValues(alpha: 0.18),
                      ),
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
                ),
              ),
      ),
      body: _result == null
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2.5),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: GlassSurface(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      _result!.disclaimer,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                            fontStyle: FontStyle.italic,
                            height: 1.35,
                          ),
                    ),
                  ),
                ),
                if (_result!.journeys.isNotEmpty)
                  _JourneyRecommendations(journeys: _result!.journeys),
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
            ),
    );
  }
}

class _JourneyRecommendations extends StatelessWidget {
  const _JourneyRecommendations({required this.journeys});

  final List<JourneyOption> journeys;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 154,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        itemCount: journeys.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final journey = journeys[index];
          return Container(
            width: 248,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: index == 0
                    ? AppColors.primary.withValues(alpha: 0.65)
                    : AppColors.glassBorder,
                width: index == 0 ? 2 : 1,
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
                    if (index == 0)
                      const Padding(
                        padding: EdgeInsets.only(right: 7),
                        child: Icon(Icons.auto_awesome_rounded,
                            size: 16, color: AppColors.primary),
                      ),
                    Expanded(
                      child: Text(
                        journey.legs.map((leg) => leg.routeCode).join('  →  '),
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
