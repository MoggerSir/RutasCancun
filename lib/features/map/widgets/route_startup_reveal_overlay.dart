import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Revelado progresivo de rutas al arranque (0.7s delay, velocidad ∝ longitud).
class RouteStartupRevealOverlay extends StatefulWidget {
  const RouteStartupRevealOverlay({
    super.key,
    required this.controller,
    required this.segments,
    required this.active,
    required this.onComplete,
    this.drawSpeedKmPerSec = 18,
    this.startDelay = const Duration(milliseconds: 700),
  });

  final MapController controller;
  final List<StartupRevealSegment> segments;
  final bool active;
  final VoidCallback onComplete;
  final double drawSpeedKmPerSec;
  final Duration startDelay;

  @override
  State<RouteStartupRevealOverlay> createState() => _RouteStartupRevealOverlayState();
}

class StartupRevealSegment {
  const StartupRevealSegment({
    required this.points,
    required this.color,
    required this.distanceKm,
    this.strokeWidth = 5,
    this.isDashed = false,
  });

  final List<LatLng> points;
  final Color color;
  final double distanceKm;
  final double strokeWidth;
  final bool isDashed;
}

class _RouteStartupRevealOverlayState extends State<RouteStartupRevealOverlay>
    with SingleTickerProviderStateMixin {
  late final List<_SegmentAnim> _anims;
  Timer? _delayTimer;
  Ticker? _ticker;
  StreamSubscription<MapEvent>? _mapSub;
  bool _started = false;
  bool _completed = false;
  final _elapsed = <int, Duration>{};

  @override
  void initState() {
    super.initState();
    _anims = widget.segments
        .map(
          (s) => _SegmentAnim(
            segment: s,
            duration: Duration(
              milliseconds: math.max(
                400,
                (s.distanceKm / widget.drawSpeedKmPerSec * 1000).round(),
              ),
            ),
          ),
        )
        .toList();

    if (widget.active) {
      _scheduleStart();
    }
    _mapSub = widget.controller.mapEventStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant RouteStartupRevealOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active && !_started) {
      _scheduleStart();
    }
  }

  void _scheduleStart() {
    _delayTimer?.cancel();
    _delayTimer = Timer(widget.startDelay, _startAnimation);
  }

  void _startAnimation() {
    if (_started || !mounted) return;
    _started = true;
    final start = Duration.zero;
    _ticker = createTicker((elapsed) {
      var allDone = true;
      for (var i = 0; i < _anims.length; i++) {
        final anim = _anims[i];
        final t = elapsed - start;
        _elapsed[i] = t;
        if (t < anim.duration) allDone = false;
      }
      if (mounted) setState(() {});
      if (allDone && !_completed) {
        _completed = true;
        widget.onComplete();
        _ticker?.stop();
      }
    })..start();
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _ticker?.dispose();
    _mapSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_started || _completed) return const SizedBox.shrink();

    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _StartupRevealPainter(
            camera: widget.controller.camera,
            anims: _anims,
            elapsedByIndex: _elapsed,
          ),
        ),
      ),
    );
  }
}

class _SegmentAnim {
  _SegmentAnim({required this.segment, required this.duration});
  final StartupRevealSegment segment;
  final Duration duration;
}

class _StartupRevealPainter extends CustomPainter {
  _StartupRevealPainter({
    required this.camera,
    required this.anims,
    required this.elapsedByIndex,
  });

  final MapCamera camera;
  final List<_SegmentAnim> anims;
  final Map<int, Duration> elapsedByIndex;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < anims.length; i++) {
      final anim = anims[i];
      final elapsed = elapsedByIndex[i] ?? Duration.zero;
      final progress = (elapsed.inMilliseconds / anim.duration.inMilliseconds).clamp(0.0, 1.0);
      if (progress <= 0 || anim.segment.points.length < 2) continue;

      final revealed = _extractPath(anim.segment.points, progress);
      if (revealed.length < 2) continue;

      final paint = Paint()
        ..color = anim.segment.color
        ..strokeWidth = anim.segment.strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = ui.Path();
      for (var j = 0; j < revealed.length; j++) {
        final pt = camera.latLngToScreenPoint(revealed[j]);
        final offset = Offset(pt.x, pt.y);
        if (j == 0) {
          path.moveTo(offset.dx, offset.dy);
        } else {
          path.lineTo(offset.dx, offset.dy);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  List<LatLng> _extractPath(List<LatLng> points, double progress) {
    if (progress >= 1) return points;
    final total = _polylineLengthM(points);
    final target = total * progress;
    var acc = 0.0;
    final out = <LatLng>[points.first];
    for (var i = 1; i < points.length; i++) {
      final seg = const Distance().distance(points[i - 1], points[i]);
      if (acc + seg >= target) {
        final remain = target - acc;
        final ratio = seg > 0 ? remain / seg : 0.0;
        final lat = points[i - 1].latitude + (points[i].latitude - points[i - 1].latitude) * ratio;
        final lng = points[i - 1].longitude + (points[i].longitude - points[i - 1].longitude) * ratio;
        out.add(LatLng(lat, lng));
        break;
      }
      acc += seg;
      out.add(points[i]);
    }
    return out;
  }

  double _polylineLengthM(List<LatLng> points) {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += const Distance().distance(points[i - 1], points[i]);
    }
    return total;
  }

  @override
  bool shouldRepaint(covariant _StartupRevealPainter oldDelegate) => true;
}
