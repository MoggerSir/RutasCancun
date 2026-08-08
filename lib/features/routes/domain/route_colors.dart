import 'package:flutter/material.dart';
import 'package:rutas_cancun/core/theme/app_colors.dart';

export 'package:rutas_cancun/core/theme/app_colors.dart' show RouteCardVariant, routeCardColor;

/// Colores de trazo — diferenciación por ruta (estilo apps de transporte).
const routeColorByCode = <String, Color>{
  'R0': Color(0xFF5C7A8A),
  'R1': Color(0xFF0D3B4C),
  'R2': Color(0xFF2EC4B6),
  'R4': Color(0xFF3D7EA6),
  'R5': Color(0xFFE9A319),
  'R6': Color(0xFF1F8A70),
  'R11': Color(0xFF2B6CB0),
  'R15': Color(0xFF6B5B95),
  'R17': Color(0xFF38A169),
  'R27': Color(0xFF3182CE),
  'R44': Color(0xFFDD6B20),
  'R48': Color(0xFF319795),
};

const _fallbackColors = [
  Color(0xFF0D3B4C),
  Color(0xFF2EC4B6),
  Color(0xFFE9A319),
  Color(0xFF3D7EA6),
  Color(0xFF1F8A70),
  Color(0xFF6B5B95),
];

Color routeColor(String code, int index) =>
    routeColorByCode[code.toUpperCase()] ?? _fallbackColors[index % _fallbackColors.length];

RouteCardVariant routeCardVariant({required bool selected, required bool featured}) {
  if (selected) return RouteCardVariant.favorite;
  if (featured) return RouteCardVariant.featured;
  return RouteCardVariant.normal;
}
