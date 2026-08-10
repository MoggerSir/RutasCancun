import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
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
    required this.onHideAll,
    required this.allRoutesVisible,
    required this.vehicleFilter,
    required this.onVehicleFilterChanged,
    required this.detailFor,
    required this.navAction,
    required this.onNavAction,
    required this.onOpenInfo,
    this.collapsedHint,
    this.nearbyRouteCodes = const {},
    this.nearbyFilterActive = false,
  });

  final List<RouteSummary> routes;
  final String? selectedCode;
  final Color Function(String code, int index) routeColor;
  final ValueChanged<String> onRouteTap;
  final VoidCallback onShowAll;
  final VoidCallback onHideAll;
  final bool allRoutesVisible;
  final RouteVehicleType? vehicleFilter;
  final ValueChanged<RouteVehicleType?> onVehicleFilterChanged;
  final RouteDetail? Function(RouteSummary summary) detailFor;
  final MapNavAction? navAction;
  final ValueChanged<MapNavAction> onNavAction;
  final VoidCallback onOpenInfo;
  final String? collapsedHint;
  final Set<String> nearbyRouteCodes;
  final bool nearbyFilterActive;

  static const headerHeight = 58.0;
  static const showAllButtonHeight = 54.0;
  static const navHeight = 64.0;
  static const tileHeight = 76.0;
  static const maxListHeight = 286.0;

  @override
  State<MapBottomDock> createState() => _MapBottomDockState();
}

class _MapBottomDockState extends State<MapBottomDock>
    with SingleTickerProviderStateMixin {
  // Resorte físico real (masa-resorte-amortiguador) en vez de una curva
  // bezier de duración fija: la velocidad de arrastre se transmite tal
  // cual al soltar, y el asentamiento final varía según qué tan lejos
  // esté del reposo — así se siente orgánico en vez de mecánico. La
  // proporción de amortiguamiento (0.68) deja un rebote leve pero
  // perceptible: se nota, sin llegar al "boing" de un resorte muy suelto.
  static final _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 420,
    ratio: 0.68,
  );

  late final AnimationController _ctrl;
  late final ScrollController _routeListScrollCtrl;
  Animation<double> get _expand => _ctrl;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
    _routeListScrollCtrl = ScrollController();
  }

  /// Anima `_ctrl` hasta [target] con el resorte físico, arrancando desde
  /// [velocity] (en unidades de progreso/segundo) para continuar con
  /// naturalidad el gesto de arrastre que soltó al usuario.
  void _springTo(double target, {double velocity = 0}) {
    _ctrl.animateWith(
      SpringSimulation(_spring, _ctrl.value, target, velocity),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _routeListScrollCtrl.dispose();
    super.dispose();
  }

  double get _listHeight {
    if (widget.routes.isEmpty) return 0;
    final sectionHeaders =
        _showNearbySection ? (_otherRoutes.isNotEmpty ? 52.0 : 28.0) : 0.0;
    final tileCount =
        _showNearbySection ? _listItemCount : widget.routes.length;
    const filtersHeight = 96.0;
    final raw = tileCount * MapBottomDock.tileHeight +
        sectionHeaders +
        filtersHeight +
        4;
    return raw.clamp(0, MapBottomDock.maxListHeight);
  }

  bool get _showNearbySection =>
      widget.nearbyFilterActive &&
      widget.routes.any(
        (route) => widget.nearbyRouteCodes.contains(route.code),
      );

  // Botón siempre visible: alterna entre mostrar y ocultar todas las
  // rutas, sin importar si hay un filtro o selección activa.
  bool get _showToggleButton => true;

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

  void _setExpanded(bool value, {double velocity = 0}) {
    // Antes, si el valor no cambiaba se salía sin animar — un arrastre que
    // soltaba a medio camino y confirmaba el mismo estado en el que ya
    // estaba (p. ej. `_expanded` seguía en true) dejaba el panel a medias,
    // sin terminar de asentarse. Ahora siempre se dispara el resorte hacia
    // el extremo correspondiente.
    if (_expanded != value) setState(() => _expanded = value);
    _springTo(value ? 1.0 : 0.0, velocity: velocity);
  }

  void _toggle() => _setExpanded(!_expanded);

  void _onVerticalDragEnd(DragEndDetails details) {
    final vy = details.velocity.pixelsPerSecond.dy;
    final range = _listHeight;
    // Velocidad de progreso (0..1 por segundo): negativa porque arrastrar
    // hacia arriba (vy < 0) equivale a aumentar el progreso de expansión.
    final progressVelocity = range > 0 ? -vy / range : 0.0;
    if (vy < -240) {
      _setExpanded(true, velocity: progressVelocity);
    } else if (vy > 240) {
      _setExpanded(false, velocity: progressVelocity);
    } else {
      _setExpanded(_expand.value > 0.4, velocity: progressVelocity);
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
    // Cursor con la posición vertical acumulada dentro de la lista — se
    // usa para saber, sin medir nada (ni RenderBox ni GlobalKey), en qué
    // punto del scroll aparece cada fila. Es aritmética simple con las
    // mismas alturas que ya definen el tamaño del panel en `_listHeight`,
    // así que no hay una segunda fuente de verdad que se pueda desincronizar.
    var cursor = 96.0; // alto aproximado de _VehicleFilterBar

    final children = <Widget>[
      _VehicleFilterBar(
        selected: widget.vehicleFilter,
        onChanged: widget.onVehicleFilterChanged,
      ),
    ];

    void addTile(RouteSummary r, {required bool isNearby}) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 5));
        cursor += 5;
      }
      final globalIndex = widget.routes.indexOf(r);
      children.add(
        _ScrollCascadeTile(
          scrollController: _routeListScrollCtrl,
          topOffset: cursor,
          itemHeight: MapBottomDock.tileHeight,
          viewportHeight: _listHeight,
          child: _RouteTile(
            summary: r,
            detail: widget.detailFor(r),
            color: widget.routeColor(r.code, globalIndex),
            selected: widget.selectedCode == r.code,
            onTap: () => widget.onRouteTap(r.code),
            isNearby: isNearby,
          ),
        ),
      );
      cursor += MapBottomDock.tileHeight;
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
    cursor += 28;
    for (final r in _nearbyRoutes) {
      addTile(r, isNearby: true);
    }
    if (_otherRoutes.isNotEmpty) {
      children.add(const SizedBox(height: 8));
      cursor += 8;
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
      cursor += 24;
      for (final r in _otherRoutes) {
        addTile(r, isNearby: false);
      }
    }
    return children;
  }

  String get _title => widget.selectedCode != null
      ? 'Ruta ${widget.selectedCode}'
      : 'Rutas disponibles';

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
            // El resorte es levemente subamortiguado y puede pasarse un
            // poco de 0/1 al asentarse — se recorta sólo donde alimenta un
            // tamaño (una altura negativa, aunque sea por un frame,
            // truena el layout). El chevron sí usa el valor sin recortar:
            // ahí ese pasadito de más es justamente lo que se ve orgánico.
            final expandClamped = _expand.value.clamp(0.0, 1.0);
            final listH = _listHeight * expandClamped;
            final totalH = MapBottomDock.headerHeight +
                (_showToggleButton ? MapBottomDock.showAllButtonHeight : 0) +
                listH +
                (expandClamped > 0.01 ? 1 : 0) +
                MapBottomDock.navHeight +
                2; // margen contra desajustes de redondeo en la animación

            // Cuánto se pasó el resorte del rango [0,1]: positivo al abrir
            // (rebasa 1 antes de asentarse), negativo al cerrar (rebasa 0).
            // Se usa sólo como transform decorativo — el tamaño real del
            // panel (totalH) ya quedó a salvo arriba con el valor recortado,
            // así que este "pasadito de más" nunca puede volverse una
            // altura negativa; sólo se ve como un leve estirón/rebote.
            final overshoot = _expand.value - expandClamped;
            final stretch = overshoot > 0 ? 1 + overshoot * 0.045 : 1.0;
            final dip = overshoot < 0 ? -overshoot * 30 : 0.0;

            return Transform.translate(
              offset: Offset(0, dip),
              child: Transform.scale(
                scale: stretch,
                alignment: Alignment.bottomCenter,
                child: SizedBox(
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
                                  margin:
                                      const EdgeInsets.only(top: 8, bottom: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.textMuted
                                        .withValues(alpha: 0.28),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(10),
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style:
                                                  MapOverlayStyle.title(context)
                                                      .copyWith(
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
                                      const SizedBox(width: 6),
                                      IconButton(
                                        onPressed: widget.onOpenInfo,
                                        tooltip:
                                            'Información, privacidad y términos',
                                        icon: const Icon(
                                            Icons.info_outline_rounded),
                                        iconSize: 21,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      Transform.rotate(
                                        // Gira con el mismo valor del resorte
                                        // frame a frame, en vez de una segunda
                                        // animación implícita superpuesta con
                                        // su propia curva y duración fijas —
                                        // así el chevron y el panel se mueven
                                        // exactamente al unísono.
                                        angle: _expand.value * math.pi,
                                        child: Container(
                                          width: 30,
                                          height: 30,
                                          decoration: BoxDecoration(
                                            color: AppColors.textMuted
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(10),
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
                        if (_showToggleButton)
                          SizedBox(
                            height: MapBottomDock.showAllButtonHeight,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
                              child: widget.allRoutesVisible
                                  ? FilledButton.tonalIcon(
                                      onPressed: widget.onHideAll,
                                      icon: const Icon(
                                          Icons.visibility_off_rounded,
                                          size: 20),
                                      label:
                                          const Text('Ocultar todas las rutas'),
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size.fromHeight(44),
                                        textStyle: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                      ),
                                    )
                                  : FilledButton.tonalIcon(
                                      onPressed: widget.onShowAll,
                                      icon: const Icon(Icons.route_rounded,
                                          size: 20),
                                      label: const Text('Ver todas las rutas'),
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size.fromHeight(44),
                                        textStyle: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        if (expandClamped > 0.01) ...[
                          SizedBox(
                            height: listH,
                            child: ListView(
                              controller: _routeListScrollCtrl,
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
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Aparición gradual de una fila conforme entra o sale por los bordes del
/// área visible al hacer scroll.
///
/// Antes esto se medía con `RenderBox.localToGlobal` en cada notificación
/// de scroll, para las ~17 filas a la vez: caro (recorre el árbol de
/// renderizado fila por fila) y, si algo no llegaba a estar "attached" a
/// tiempo, la fila se quedaba invisible para siempre. Aquí es aritmética
/// simple con el offset de scroll y la posición acumulada de la fila
/// ([topOffset], calculada una sola vez al construir la lista) — nada que
/// medir, nada que se pueda quedar pegado en cero, y mucho más liviano.
/// Al no depender de un "ya se mostró", se repite igual si el usuario baja
/// y vuelve a subir.
class _ScrollCascadeTile extends StatelessWidget {
  const _ScrollCascadeTile({
    required this.scrollController,
    required this.topOffset,
    required this.itemHeight,
    required this.viewportHeight,
    required this.child,
  });

  final ScrollController scrollController;
  final double topOffset;
  final double itemHeight;
  final double viewportHeight;
  final Widget child;

  // Zona de desvanecido en cada borde del área visible, en px. Amplia a
  // propósito (poco menos que una fila) para que la cascada se sienta
  // suave y ligera en vez de un parpadeo brusco al cruzar el borde.
  static const _edgeMargin = 70.0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scrollController,
      builder: (context, _) {
        final offset =
            scrollController.hasClients ? scrollController.offset : 0.0;
        final center = topOffset - offset + itemHeight / 2;
        final distanceToTop = center;
        final distanceToBottom = viewportHeight - center;
        final edge = math.min(distanceToTop, distanceToBottom);
        final t = (edge / _edgeMargin).clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 12),
            child: child,
          ),
        );
      },
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
            color: selected
                ? AppColors.cardRouteFavorite
                : AppColors.surfaceElevated,
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
                width: 68,
                height: 52,
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _routeBadgeLabel(summary.code),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        height: 0.94,
                        color: Colors.white,
                        letterSpacing: 0.1,
                      ),
                    ),
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
                          Icon(Icons.near_me_rounded,
                              size: 13, color: color.withValues(alpha: 0.85)),
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
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted),
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

String _routeBadgeLabel(String code) {
  final separator = code.indexOf('-');
  if (separator <= 0 || separator == code.length - 1) return code;
  final base = code.substring(0, separator);
  final variant = code.substring(separator + 1).replaceAll('-', ' ');
  return '$base\n$variant';
}

class _VehicleFilterBar extends StatelessWidget {
  const _VehicleFilterBar({required this.selected, required this.onChanged});

  final RouteVehicleType? selected;
  final ValueChanged<RouteVehicleType?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 91,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 2, 2, 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FilterChip(
                  selected: selected == null,
                  avatar: const Icon(Icons.route_rounded, size: 17),
                  label: const Text('Todas'),
                  onSelected: (_) => onChanged(null),
                ),
                const SizedBox(width: 7),
                FilterChip(
                  selected: selected == RouteVehicleType.bus,
                  avatar: const Icon(Icons.directions_bus_rounded, size: 17),
                  label: const Text('Camiones'),
                  onSelected: (_) => onChanged(RouteVehicleType.bus),
                ),
                const SizedBox(width: 7),
                FilterChip(
                  selected: selected == RouteVehicleType.combi,
                  avatar: const Icon(Icons.airport_shuttle_rounded, size: 17),
                  label: const Text('Combis'),
                  onSelected: (_) => onChanged(RouteVehicleType.combi),
                ),
              ],
            ),
            const SizedBox(height: 2),
            const Tooltip(
              message: 'Este tipo de transporte estará disponible después',
              child: Chip(
                avatar: Icon(Icons.local_taxi_rounded, size: 17),
                label: Text('Pochis · Próximamente'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
