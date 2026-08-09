import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rutas_cancun/core/theme/app_colors.dart';

/// Cristal líquido — variantes para pantallas normales y overlays sobre mapa claro.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.padding,
    this.margin,
    this.blur = 28,
    this.tint,
    this.onTap,
    this.forMapOverlay = false,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blur;
  final Color? tint;
  final VoidCallback? onTap;

  /// Alta opacidad + bordes oscuros para no perderse sobre mapa claro.
  final bool forMapOverlay;

  @override
  Widget build(BuildContext context) {
    final decoration =
        forMapOverlay ? _mapOverlayDecoration() : _standardDecoration();

    final content = DecoratedBox(
      decoration: decoration,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 16,
            right: 16,
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: forMapOverlay
                      ? [
                          AppColors.primary.withValues(alpha: 0.12),
                          Colors.transparent,
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.85),
                          Colors.transparent,
                        ],
                ),
              ),
            ),
          ),
          Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ],
      ),
    );

    // Un BackdropFilter grande sobre el mapa vuelve a procesar todas las
    // teselas que quedan detrás en cada movimiento. En navegador usamos una
    // superficie opaca/translúcida equivalente, sin blur en tiempo real.
    final glass = ClipRRect(
      borderRadius: borderRadius,
      child: kIsWeb
          ? content
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: content,
            ),
    );

    final wrapped =
        margin != null ? Padding(padding: margin!, child: glass) : glass;

    if (onTap == null) return wrapped;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        splashColor: AppColors.primary.withValues(alpha: 0.12),
        highlightColor: AppColors.primary.withValues(alpha: 0.06),
        child: wrapped,
      ),
    );
  }

  BoxDecoration _mapOverlayDecoration() {
    return BoxDecoration(
      borderRadius: borderRadius,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.mapOverlayFill,
          AppColors.mapOverlayFillAlt.withValues(alpha: 0.96),
        ],
      ),
      border: Border.all(color: AppColors.mapOverlayBorder, width: 1.5),
      boxShadow: const [
        BoxShadow(
          color: AppColors.mapOverlayShadow,
          blurRadius: 20,
          offset: Offset(0, 6),
        ),
        BoxShadow(
          color: Color(0x18000000),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    );
  }

  BoxDecoration _standardDecoration() {
    final fill = tint ?? Colors.white;
    return BoxDecoration(
      borderRadius: borderRadius,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          fill.withValues(alpha: 0.78),
          fill.withValues(alpha: 0.58),
        ],
      ),
      border:
          Border.all(color: Colors.white.withValues(alpha: 0.55), width: 1.2),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.10),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}

/// Estilos de texto para widgets flotantes sobre el mapa.
abstract final class MapOverlayStyle {
  static TextStyle title(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium!.copyWith(
            color: AppColors.mapOverlayText,
            fontWeight: FontWeight.w600,
          );

  static TextStyle body(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium!.copyWith(
            color: AppColors.mapOverlayTextMuted,
          );

  static TextStyle hint(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium!.copyWith(
            color: AppColors.mapOverlayTextMuted,
            fontWeight: FontWeight.w500,
          );

  static TextStyle label({bool selected = false}) => TextStyle(
        fontSize: 11,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        color:
            selected ? AppColors.mapOverlayText : AppColors.mapOverlayTextMuted,
      );
}
