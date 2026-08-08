import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:rutas_cancun/core/theme/app_colors.dart';
import 'package:rutas_cancun/core/widgets/glass_surface.dart';

/// Overlay de carga con blur sobre el mapa.
class MapLoadingOverlay extends StatelessWidget {
  const MapLoadingOverlay({
    super.key,
    this.message = 'Cargando…',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            color: AppColors.mapOverlayFill.withValues(alpha: 0.55),
            alignment: Alignment.center,
            child: GlassSurface(
              forMapOverlay: true,
              blur: 16,
              borderRadius: BorderRadius.circular(20),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    message,
                    style: MapOverlayStyle.title(context).copyWith(fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
