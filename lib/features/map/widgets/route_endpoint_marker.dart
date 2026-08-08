import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:rutas_cancun/core/theme/app_colors.dart';

/// Marcador de inicio (A) o fin (B) con halo blanco para no confundir con la línea.
class RouteEndpointMarker extends StatelessWidget {
  const RouteEndpointMarker({
    super.key,
    required this.isStart,
    required this.large,
    this.routeColor,
  });

  final bool isStart;
  final bool large;
  final Color? routeColor;

  @override
  Widget build(BuildContext context) {
    final ring = isStart ? AppColors.accent : AppColors.primary;
    final size = large ? 40.0 : 28.0;
    final fontSize = large ? 13.0 : 10.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: large ? 3 : 2.5),
        boxShadow: [
          BoxShadow(
            color: (routeColor ?? ring).withValues(alpha: 0.35),
            blurRadius: large ? 10 : 6,
          ),
          const BoxShadow(
            color: Color(0x40000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        isStart ? 'A' : 'B',
        style: TextStyle(
          color: ring,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}

/// Punto de parada numerada — encima de la polilínea.
class RouteStopMarker extends StatelessWidget {
  const RouteStopMarker({
    super.key,
    required this.sequence,
    required this.color,
    this.large = false,
  });

  final int sequence;
  final Color color;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final size = large ? 38.0 : 32.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: large ? 3 : 2.5),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 2)),
          const BoxShadow(color: Color(0x26000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '$sequence',
        style: TextStyle(
          color: color,
          fontSize: large ? 12 : 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

LatLng? endpointFromPoints(List<LatLng> points, {required bool start}) {
  if (points.isEmpty) return null;
  return start ? points.first : points.last;
}
