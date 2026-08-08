import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Capa de flujo continuo — solo destellos sobre la polilínea (sin duplicar la línea base).
class RouteFlowOverlay extends StatefulWidget {
  const RouteFlowOverlay({
    super.key,
    required this.controller,
    required this.segments,
  });

  final MapController controller;
  final List<FlowSegment> segments;

  @override
  State<RouteFlowOverlay> createState() => _RouteFlowOverlayState();
}

class _RouteFlowOverlayState extends State<RouteFlowOverlay>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  double _dashOffset = 0;
  StreamSubscription<MapEvent>? _mapSub;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      // Offset continuo — evita el salto al reiniciar AnimationController.repeat().
      _dashOffset = elapsed.inMicroseconds / 1e6 * 36;
      if (mounted) setState(() {});
    })
      ..start();
    _mapSub = widget.controller.mapEventStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _mapSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.segments.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: RouteFlowPainter(
            camera: widget.controller.camera,
            segments: widget.segments,
            dashOffset: _dashOffset,
          ),
        ),
      ),
    );
  }
}

class RouteFlowPainter extends CustomPainter {
  RouteFlowPainter({
    required this.camera,
    required this.segments,
    required this.dashOffset,
  });

  final MapCamera camera;
  final List<FlowSegment> segments;
  final double dashOffset;

  static const _dash = 14.0;
  static const _gap = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    for (final seg in segments) {
      if (seg.dimmed) continue;
      _paintFlow(canvas, seg);
    }
  }

  void _paintFlow(Canvas canvas, FlowSegment seg) {
    if (!camera.zoom.isFinite || camera.zoom <= 0) return;

    final points = <Offset>[];
    for (final p in seg.points) {
      try {
        final pt = camera.latLngToScreenPoint(p);
        if (!pt.x.isFinite || !pt.y.isFinite) continue;
        points.add(Offset(pt.x, pt.y));
      } catch (_) {}
    }
    if (points.length < 2) return;

    final path = ui.Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final glowPaint = Paint()
      ..color = seg.color.withValues(alpha: 0.28)
      ..strokeWidth = seg.strokeWidth * 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawPath(path, glowPaint);

    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = seg.strokeWidth * 0.42
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final period = _dash + _gap;
    final startOffset = dashOffset % period;

    for (final metric in path.computeMetrics()) {
      var dist = -startOffset;
      while (dist < metric.length) {
        if (dist + _dash > 0) {
          final from = math.max(0.0, dist);
          final to = math.min(dist + _dash, metric.length);
          if (to > from) {
            canvas.drawPath(metric.extractPath(from, to), dashPaint);
          }
        }
        dist += period;
      }

      if (seg.showVehicle && metric.length > 50) {
        final vehicleDistance = (dashOffset * 0.72) % metric.length;
        final tangent = metric.getTangentForOffset(vehicleDistance);
        if (tangent != null) _paintVehicle(canvas, tangent, seg.color);
      }
    }
  }

  void _paintVehicle(Canvas canvas, ui.Tangent tangent, Color routeColor) {
    final angle = math.atan2(tangent.vector.dy, tangent.vector.dx);
    canvas.save();
    canvas.translate(tangent.position.dx, tangent.position.dy);
    canvas.rotate(angle);

    // Sombra separada del mapa: hace que la combi se perciba 2.5D.
    canvas.drawOval(
      const Rect.fromLTWH(-15, -5, 32, 14),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-16, -9, 32, 18),
      const Radius.circular(7),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFE6F0F2)],
        ).createShader(body.outerRect),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..color = routeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    // Franja de la ruta y cabina panorámica.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-8, -8, 14, 16), const Radius.circular(3)),
      Paint()..color = routeColor.withValues(alpha: 0.92),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(8, -6, 6, 12), const Radius.circular(2.5)),
      Paint()..color = const Color(0xFF123B4A),
    );
    canvas.drawLine(const Offset(10, 0), const Offset(14, 0),
        Paint()..color = Colors.white24);

    // Ventanas y ruedas compactas, legibles incluso con poco zoom.
    final glass = Paint()..color = const Color(0xFF275B6A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-5, -6, 8, 4), const Radius.circular(1.5)),
      glass,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-5, 2, 8, 4), const Radius.circular(1.5)),
      glass,
    );
    final wheel = Paint()..color = const Color(0xFF172126);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-10, -11, 7, 3), const Radius.circular(2)),
      wheel,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-10, 8, 7, 3), const Radius.circular(2)),
      wheel,
    );

    // Faro delantero para reforzar la dirección de avance.
    canvas.drawCircle(
        const Offset(15, -4.5), 1.4, Paint()..color = const Color(0xFFFFE082));
    canvas.drawCircle(
        const Offset(15, 4.5), 1.4, Paint()..color = const Color(0xFFFFE082));
    canvas.restore();
  }

  @override
  bool shouldRepaint(RouteFlowPainter oldDelegate) =>
      oldDelegate.dashOffset != dashOffset ||
      oldDelegate.camera != camera ||
      oldDelegate.segments != segments;
}

class FlowSegment {
  FlowSegment({
    required this.points,
    required this.color,
    this.strokeWidth = 5,
    this.dimmed = false,
    this.showVehicle = false,
  });

  final List<LatLng> points;
  final Color color;
  final double strokeWidth;
  final bool dimmed;
  final bool showVehicle;
}
