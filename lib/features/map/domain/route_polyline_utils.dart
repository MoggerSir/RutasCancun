import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:rutas_cancun/features/routes/data/routes_repository.dart';

/// Paridad con `route-segment-geo.util.ts` / Haversine del backend.
class RoutePolylineUtils {
  static const nearbyRadiusKm = 2.5;

  static bool isLikelyNear(RouteBounds? bounds, LatLng user, double radiusKm) {
    if (bounds == null) return true;
    final pad = radiusKm / 111.0;
    return user.latitude >= bounds.minLat - pad &&
        user.latitude <= bounds.maxLat + pad &&
        user.longitude >= bounds.minLng - pad &&
        user.longitude <= bounds.maxLng + pad;
  }

  static double distanceToPolylineKm(LatLng point, List<LatLng> polyline) {
    if (polyline.isEmpty) return double.infinity;
    if (polyline.length == 1) {
      return const Distance().as(LengthUnit.Kilometer, point, polyline.first);
    }

    var minM = double.infinity;
    for (var i = 0; i < polyline.length - 1; i++) {
      final d = _pointToSegmentM(point, polyline[i], polyline[i + 1]);
      if (d < minM) minM = d;
    }
    return minM / 1000;
  }

  static double _pointToSegmentM(LatLng p, LatLng a, LatLng b) {
    final x = p.longitude;
    final y = p.latitude;
    final x1 = a.longitude;
    final y1 = a.latitude;
    final x2 = b.longitude;
    final y2 = b.latitude;
    final dx = x2 - x1;
    final dy = y2 - y1;
    if (dx == 0 && dy == 0) {
      return _haversineM(y, x, y1, x1);
    }
    final t = ((x - x1) * dx + (y - y1) * dy) / (dx * dx + dy * dy);
    final clamped = t.clamp(0.0, 1.0);
    final projLng = x1 + clamped * dx;
    final projLat = y1 + clamped * dy;
    return _haversineM(y, x, projLat, projLng);
  }

  static double _haversineM(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _toRad(double deg) => deg * math.pi / 180;

  static Set<String> filterNearbyRouteCodes({
    required LatLng user,
    required Iterable<RouteDetail> routes,
    double radiusKm = nearbyRadiusKm,
  }) {
    final candidates = routes.where((r) => isLikelyNear(r.bounds, user, radiusKm));
    final near = <String>{};
    for (final route in candidates) {
      for (final seg in _segments(route)) {
        final dist = distanceToPolylineKm(user, seg);
        if (dist <= radiusKm) {
          near.add(route.code);
          break;
        }
      }
    }
    return near;
  }

  static List<List<LatLng>> _segments(RouteDetail detail) {
    final out = <List<LatLng>>[];
    if (detail.polylines != null && detail.polylines!.isNotEmpty) {
      for (final seg in detail.polylines!) {
        out.add(_coordsToLatLng(seg.polyline));
      }
      return out;
    }
    if (detail.polyline != null) {
      out.add(_coordsToLatLng(detail.polyline!));
    }
    return out;
  }

  static List<LatLng> _coordsToLatLng(Map<String, dynamic> poly) {
    return (poly['coordinates'] as List)
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();
  }

  static RouteBounds? boundsFromDetail(RouteDetail detail) {
    final points = _segments(detail).expand((s) => s).toList();
    if (points.isEmpty) return null;
    var minLat = points.first.latitude;
    var maxLat = minLat;
    var minLng = points.first.longitude;
    var maxLng = minLng;
    for (final p in points.skip(1)) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return RouteBounds(
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
    );
  }
}
