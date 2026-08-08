import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:rutas_cancun/core/theme/app_colors.dart';
import 'package:rutas_cancun/core/widgets/glass_surface.dart';
import 'package:rutas_cancun/core/widgets/map_nav_bar_content.dart';
import 'package:rutas_cancun/core/widgets/service_hours_badge.dart';
import 'package:rutas_cancun/features/map/domain/route_map_ui_helpers.dart';
import 'package:rutas_cancun/features/routes/data/routes_repository.dart';

/// Dock inferior unificado: rutas (expandible) + navegación en un solo bloque glass.
class MapBottomDock extends StatefulWidget {
  const MapBottomDock({
    super.key,
    required this.routes,
    required this.selectedCode,
    required this.routeColor,
    required this.onRouteTap,
    required this.onShowAll,
    required this.detailFor,
    required this.navAction,
    required this.onNavAction,
    this.collapsedHint,
    this.nearbyRouteCodes = const {},
    this.nearbyFilterActive = false,
  });

  final List<RouteSummary> routes;
  final String? selectedCode;
  final Color Function(String code, int index) routeColor;
  final ValueChanged<String> onRouteTap;
  final VoidCallback onShowAll;
  final RouteDetail? Function(RouteSummary summary) detailFor;
  final MapNavAction? navAction;
  final ValueChanged<MapNavAction> onNavAction;
  final String? collapsedHint;
  final Set<String> nearbyRouteCodes;
  final bool nearbyFilterActive;

  static const headerHeight = 58.0;
  static const navHeight = 64.0;
  static const tileHeight = 76.0;
  static const maxListHeight = 236.0;

  @override
  State<MapBottomDock> createState() => _MapBottomDockState();
}

class _MapBottomDockState extends State<MapBottomDock> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _expand;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _expand = CurvedAnimation(parent: _ctrl, curve: AppColors.curveSpring);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double get _listHeight {
    if (widget.routes.isEmpty) return 0;
    final sectionHeaders = _showNearbySection ? (_otherRoutes.isNotEmpty ? 52.0 : 28.0) : 0.0;
    final tileCount = _showNearbySection ? _listItemCount : widget.routes.length;
    final raw = tileCount * MapBottomDock.tileHeight + sectionHeaders + 4;
    return raw.clamp(0, MapBottomDock.maxListHeight);
  }

  bool get _showNearbySection =>
      widget.nearbyFilterActive && widget.nearbyRouteCodes.isNotEmpty;

  List<RouteSummary> get _nearbyRoutes => widget.routes
      .where((r) => widget.nearbyRouteCodes.contains(r.code))
      .toList()
    ..sort((a, b) => a.code.compareTo(b.code));

  List<RouteSummary> get _otherRoutes => widget.routes
      .where((r) => !widget.nearbyRouteCodes.contains(r.code))
      .toList()
    ..sort((a, b) => a.code.compareTo(b.code));

  List<RouteSummary> get _orderedRoutes {
    if (!_showNearbySection) {
      return [...widget.routes]..sort((a, b) => a.code.compareTo(b.code));
    }
    return [..._nearbyRoutes, ..._otherRoutes];
  }

  void _setExpanded(bool value) {
    if (_expanded == value) return;
    setState(() => _expanded = value);
    value ? _ctrl.forward() : _ctrl.reverse();
  }

  void _toggle() => _setExpanded(!_expanded);

  void _onVerticalDragEnd(DragEndDetails details) {
    final vy = details.velocity.pixelsPerSecond.dy;
    if (vy < -240) {
      _setExpanded(true);
    } else if (vy > 240) {
      _setExpanded(false);
    } else {
      _setExpanded(_expand.value > 0.4);
    }
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    final range = _listHeight;
    if (range <= 0) return;
    _ctrl.value = (_ctrl.value - details.delta.dy / range).clamp(0.0, 1.0);
  }

  int get _listItemCount {
    if (!_showNearbySection) return widget.routes.length;
    var count = _nearbyRoutes.length;
    if (_otherRoutes.isNotEmpty) count += 1 + _otherRoutes.length;
    return count;
  }

  List<Widget> _buildRouteListChildren() {
    final children = <Widget>[];

    void addTile(RouteSummary r, {required bool isNearby}) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 5));
      final globalIndex = widget.routes.indexOf(r);
      children.add(
        _RouteTile(
          summary: r,
          detail: widget.detailFor(r),
          color: widget.routeColor(r.code, globalIndex),
          selected: widget.selectedCode == r.code,
          onTap: () => widget.onRouteTap(r.code),
          isNearby: isNearby,
        ),
      );
    }

    if (!_showNearbySection) {
      for (final r in _orderedRoutes) {
        addTile(r, isNearby: false);
      }
      return children;
    }

    children.add(
      const Padding(
        padding: EdgeInsets.fromLTRB(4, 2, 4, 6),
        child: Text(
          'Cerca de ti',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
      ),
    );
    for (final r in _nearbyRoutes) {
      addTile(r, isNearby: true);
    }
    if (_otherRoutes.isNotEmpty) {
      children.add(const SizedBox(height: 8));
      children.add(
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 2, 4, 6),
          child: Text(
            'Todas las rutas',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
        ),
      );
      for (final r in _otherRoutes) {
        addTile(r, isNearby: false);
      }
    }
    return children;
  }

  String get _title =>
      widget.selectedCode != null ? 'Ruta ${widget.selectedCode}' : 'Rutas disponibles';

  String get _subtitle {
    final n = widget.routes.length;
    final count = '$n ruta${n == 1 ? '' : 's'}';
    if (widget.collapsedHint != null && widget.collapsedHint!.isNotEmpty) {
      return widget.collapsedHint!;
    }
    if (_expanded) return 'Desliza abajo o toca para ocultar';
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final isNight = widget.navAction == MapNavAction.nightRoutes;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        child: AnimatedBuilder(
          animation: _expand,
          builder: (context, _) {
            final listH = _listHeight * _expand.value;
            final totalH = MapBottomDock.headerHeight +
                listH +
                (_expand.value > 0.01 ? 1 : 0) +
                MapBottomDock.navHeight +
                2; // margen contra desajustes de redondeo en la animación

            return SizedBox(
              height: totalH,
              child: GlassSurface(
                forMapOverlay: !isNight,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                  bottom: Radius.circular(24),
                ),
                blur: 28,
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _toggle,
                      onVerticalDragUpdate: _onVerticalDragUpdate,
                      onVerticalDragEnd: _onVerticalDragEnd,
                      child: SizedBox(
                        height: MapBottomDock.headerHeight,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 40,
                              height: 4,
                              margin: const EdgeInsets.only(top: 8, bottom: 4),
                              decoration: BoxDecoration(
                                color: AppColors.textMuted.withValues(alpha: 0.28),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: SvgPicture.asset(
                                        'assets/icons/bus.svg',
                                        width: 17,
                                        height: 17,
                                        colorFilter: const ColorFilter.mode(
                                          AppColors.primary,
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: MapOverlayStyle.title(context).copyWith(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        Text(
                                          _subtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textMuted,
                                            height: 1.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (widget.selectedCode != null)
                                    _ChipButton(label: 'Todas', onTap: widget.onShowAll),
                                  const SizedBox(width: 6),
                                  AnimatedRotation(
                                    turns: _expand.value * 0.5,
                                    duration: const Duration(milliseconds: 380),
                                    curve: AppColors.curveSpring,
                                    child: Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: AppColors.textMuted.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.keyboard_arrow_up_rounded,
                                        size: 24,
                                        color: AppColors.text,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_expand.value > 0.01) ...[
                      SizedBox(
                        height: listH,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                          physics: _expanded
                              ? const BouncingScrollPhysics()
                              : const NeverScrollableScrollPhysics(),
                          children: _buildRouteListChildren(),
                        ),
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: AppColors.glassBorder.withValues(alpha: 0.6),
                      ),
                    ],
                    MapNavBarContent(
                      current: widget.navAction,
                      onAction: widget.onNavAction,
                      compact: true,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ChipButton extends StatelessWidget {
  const _ChipButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: AppColors.accent.withValues(alpha: 0.12),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _RouteTile extends StatelessWidget {
  const _RouteTile({
    required this.summary,
    required this.detail,
    required this.color,
    required this.selected,
    required this.onTap,
    this.isNearby = false,
  });

  final RouteSummary summary;
  final RouteDetail? detail;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final bool isNearby;

  @override
  Widget build(BuildContext context) {
    final corridor = routeCorridorLabel(detail);
    final duration = routeDurationLabel(detail);
    final distance = routeDistanceLabel(detail);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: MapBottomDock.tileHeight,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: selected ? AppColors.cardRouteFavorite : AppColors.surfaceElevated,
            border: Border.all(
              color: selected ? color : AppColors.glassBorder,
              width: selected ? 2 : 1,
            ),
          ),
          // Badge circular con el código de la ruta como ancla visual — antes
          // era solo texto de color + una barrita de 3px, que se explora
          // mucho más lento con la mirada que una forma sólida y coloreada
          // (principio de "pop-out" en búsqueda visual: color+forma juntos
          // se detectan antes que color solo).
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  summary.code,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            corridor,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                        if (isNearby) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.near_me_rounded, size: 13, color: color.withValues(alpha: 0.85)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    ServiceHoursBadge(routeCode: summary.code, compact: true),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    duration.replaceAll('Duración estimada', '—'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  if (distance.isNotEmpty)
                    Text(
                      distance,
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
