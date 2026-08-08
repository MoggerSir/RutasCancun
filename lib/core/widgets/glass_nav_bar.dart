import 'package:flutter/material.dart';
import 'package:rutas_cancun/core/widgets/glass_surface.dart';
import 'package:rutas_cancun/core/widgets/map_nav_bar_content.dart';

export 'package:rutas_cancun/core/widgets/map_nav_bar_content.dart' show MapNavAction;

/// Nav flotante standalone (pantallas sin dock unificado).
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({
    super.key,
    required this.onAction,
    required this.current,
  });

  final ValueChanged<MapNavAction> onAction;
  final MapNavAction? current;

  @override
  Widget build(BuildContext context) {
    final isNight = current == MapNavAction.nightRoutes;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: GlassSurface(
          forMapOverlay: !isNight,
          borderRadius: BorderRadius.circular(28),
          blur: 24,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: MapNavBarContent(
            current: current,
            onAction: onAction,
          ),
        ),
      ),
    );
  }
}
