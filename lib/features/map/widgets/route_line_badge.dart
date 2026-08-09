import 'package:flutter/material.dart';

/// Etiqueta de número de ruta sobre el trazo (sentido de circulación).
class RouteLineBadge extends StatelessWidget {
  const RouteLineBadge({
    super.key,
    required this.code,
    required this.color,
    this.large = false,
  });

  final String code;
  final Color color;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final separator = code.indexOf('-');
    final label = separator > 0 && separator < code.length - 1
        ? '${code.substring(0, separator)}\n${code.substring(separator + 1).replaceAll('-', ' ')}'
        : code;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: large ? 10 : 8, vertical: large ? 5 : 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.45),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Text(
        label,
        maxLines: 2,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: large ? 12 : 10,
          fontWeight: FontWeight.w800,
          height: 0.92,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
