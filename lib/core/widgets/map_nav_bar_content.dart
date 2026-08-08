import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:rutas_cancun/core/theme/app_colors.dart';
import 'package:rutas_cancun/core/widgets/glass_surface.dart';

enum MapNavAction { planTrip, nearby, nightRoutes }

/// Fila de tabs del mapa — sin contenedor glass (para integrar en dock).
class MapNavBarContent extends StatelessWidget {
  const MapNavBarContent({
    super.key,
    required this.onAction,
    required this.current,
    this.compact = false,
  });

  final ValueChanged<MapNavAction> onAction;
  final MapNavAction? current;
  final bool compact;

  static const _tabs = [
    _TabSpec(MapNavAction.planTrip, 'assets/icons/nav-arrow-right.svg',
        'Cómo llegar'),
    _TabSpec(MapNavAction.nearby, 'assets/icons/map-pin.svg', 'Cercanas'),
    _TabSpec(
        MapNavAction.nightRoutes, 'assets/icons/moon-sat.svg', 'Nocturnas'),
  ];

  @override
  Widget build(BuildContext context) {
    final isNight = current == MapNavAction.nightRoutes;
    final idx = _tabs.indexWhere((t) => t.action == current);

    return LayoutBuilder(
      builder: (context, constraints) {
        final tabW = constraints.maxWidth / _tabs.length;
        return SizedBox(
          height: compact ? 64 : 58,
          child: Stack(
            children: [
              if (idx >= 0)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 420),
                  curve: AppColors.curveSpring,
                  left: idx * tabW + 4,
                  width: tabW - 8,
                  top: 3,
                  bottom: 3,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: AppColors.primary
                          .withValues(alpha: isNight ? 0.22 : 0.1),
                    ),
                  ),
                ),
              Row(
                children: [
                  for (final tab in _tabs)
                    Expanded(
                      child: _NavItem(
                        icon: tab.icon,
                        label: tab.label,
                        selected: current == tab.action,
                        onTap: () => onAction(tab.action),
                        lightOnDark: isNight,
                        compact: compact,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TabSpec {
  const _TabSpec(this.action, this.icon, this.label);
  final MapNavAction action;
  final String icon;
  final String label;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.lightOnDark = false,
    this.compact = false,
  });

  final String icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool lightOnDark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final idleColor =
        lightOnDark ? Colors.white70 : AppColors.mapOverlayTextMuted;
    final selectedColor = lightOnDark ? Colors.white : AppColors.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: compact ? 10 : 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                icon,
                width: compact ? 23 : 22,
                height: compact ? 23 : 22,
                colorFilter: ColorFilter.mode(
                  selected ? selectedColor : idleColor,
                  BlendMode.srcIn,
                ),
              ),
              SizedBox(height: compact ? 4 : 4),
              Text(
                label,
                style: MapOverlayStyle.label(selected: selected).copyWith(
                  color: selected ? selectedColor : idleColor,
                  fontSize: compact ? 12 : 11,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
