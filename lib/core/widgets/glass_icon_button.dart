import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:rutas_cancun/core/theme/app_colors.dart';
import 'package:rutas_cancun/core/widgets/glass_surface.dart';

class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    this.iconAsset,
    this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 44,
    this.highlight = false,
  }) : assert(iconAsset != null || icon != null);

  final String? iconAsset;
  final IconData? icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final double size;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final iconColor = highlight ? AppColors.accent : AppColors.primary;

    return Semantics(
      button: true,
      label: tooltip,
      child: GlassSurface(
        forMapOverlay: true,
        borderRadius: BorderRadius.circular(size / 2),
        blur: 24,
        onTap: onPressed,
        padding: EdgeInsets.all(size * 0.26),
        child: icon != null
            ? Icon(icon, size: size * 0.42, color: iconColor)
            : SvgPicture.asset(
                iconAsset!,
                width: size * 0.42,
                height: size * 0.42,
                colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              ),
      ),
    );
  }
}
