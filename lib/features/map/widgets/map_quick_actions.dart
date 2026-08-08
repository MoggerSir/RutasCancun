import 'package:flutter/material.dart';
import 'package:rutas_cancun/core/theme/app_colors.dart';

/// CTA principal bajo la búsqueda — una sola acción clara y grande.
///
/// Antes había un segundo botón "Planificar" aquí, duplicado con el tab
/// "Planificar" del dock inferior Y con el tap en la barra de búsqueda
/// (las tres llevaban al mismo lugar). Se dejó solo "Ruta cercana": es la
/// única acción de valor distinto (usa el GPS directo, sin escribir nada).
class MapQuickActions extends StatelessWidget {
  const MapQuickActions({super.key, required this.onFindNearby});

  final VoidCallback onFindNearby;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(18),
        elevation: 0,
        shadowColor: AppColors.glowPrimary,
        child: InkWell(
          onTap: onFindNearby,
          borderRadius: BorderRadius.circular(18),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.near_me_rounded, size: 22, color: Colors.white),
                SizedBox(width: 10),
                Text(
                  'Encontrar mi ruta más cercana',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
