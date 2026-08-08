import 'package:flutter/material.dart';

/// Paleta premium — azul petróleo, blanco roto, acento turquesa/ámbar.
abstract final class AppColors {
  static const primary = Color(0xFF0D3B4C);
  static const primaryLight = Color(0xFF1A5568);
  static const secondary = Color(0xFF3D6B7A);
  static const accent = Color(0xFF2EC4B6);
  static const accentWarm = Color(0xFFE9A319);
  static const bg = Color(0xFFFAF9F7);
  static const surface = Color(0xFFF3F1EC);
  static const surfaceElevated = Color(0xFFFFFFFF);
  static const text = Color(0xFF1C2830);
  static const textMuted = Color(0xFF5C6B73);
  static const danger = Color(0xFFD64545);

  /// Tarjetas de ruta
  static const cardRouteNormal = Color(0xFFE8F4F8);
  static const cardRouteFavorite = Color(0xFFE0F7F5);
  static const cardRouteFeatured = Color(0xFFFFF8E8);

  /// UI flotante sobre mapa — blanco roto translúcido.
  static const mapOverlayFill = Color(0xF5FAF9F7);
  static const mapOverlayFillAlt = Color(0xFFF0EDE8);
  static const mapOverlayBorder = Color(0x550D3B4C);
  static const mapOverlayShadow = Color(0x350D3B4C);
  static const mapOverlayText = Color(0xFF1C2830);
  static const mapOverlayTextMuted = Color(0xFF5C6B73);

  static const glassFill = Color(0xEEFAFAF8);
  static const glassFillStrong = Color(0xF8FFFFFF);
  static const glassBorder = Color(0x330D3B4C);
  static const glassHighlight = Color(0x142EC4B6);

  static const glowPrimary = Color(0x260D3B4C);
  static const glowAccent = Color(0x302EC4B6);

  /// Punto GPS en vivo sobre el mapa.
  static const locationLive = Color(0xFF22C55E);

  static const mapWater = Color(0xFF0D3B4C);
  static const mapLand = Color(0xFFF5F3EF);
  static const mapPark = Color(0xFFD8EED8);
  static const mapRoadMajor = Color(0xFFFFFCF5);
  static const mapLabel = Color(0xFF5C6B73);

  static const curveSpring = Cubic(0.34, 1.56, 0.64, 1);
  static const curvePremium = Cubic(0.22, 1, 0.36, 1);
  static const curveCupertino = Cubic(0.32, 0.72, 0, 1);
}

enum RouteCardVariant { normal, favorite, featured }

Color routeCardColor(RouteCardVariant variant) => switch (variant) {
      RouteCardVariant.normal => AppColors.cardRouteNormal,
      RouteCardVariant.favorite => AppColors.cardRouteFavorite,
      RouteCardVariant.featured => AppColors.cardRouteFeatured,
    };
