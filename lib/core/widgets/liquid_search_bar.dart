import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:rutas_cancun/core/theme/app_colors.dart';
import 'package:rutas_cancun/core/widgets/glass_surface.dart';

/// Barra de búsqueda centrada — cristal sobre mapa claro.
class LiquidSearchBar extends StatelessWidget {
  const LiquidSearchBar({
    super.key,
    required this.onTap,
    this.hint = '¿A dónde vas en Cancún?',
  });

  final VoidCallback onTap;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      forMapOverlay: true,
      borderRadius: BorderRadius.circular(28),
      blur: 24,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          SvgPicture.asset(
            'assets/icons/search.svg',
            width: 22,
            height: 22,
            colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(hint, style: MapOverlayStyle.hint(context)),
          ),
        ],
      ),
    );
  }
}
