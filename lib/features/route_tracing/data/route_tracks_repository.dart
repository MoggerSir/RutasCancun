import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rutas_cancun/core/network/dio_provider.dart';

final routeTracksRepositoryProvider = Provider<RouteTracksRepository>((ref) {
  return RouteTracksRepository(ref.watch(dioProvider));
});

class TrackPointPayload {
  TrackPointPayload({
    required this.lat,
    required this.lng,
    required this.recordedAt,
    this.accuracyM,
    this.speedMps,
  });

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        'recordedAt': recordedAt,
        if (accuracyM != null) 'accuracyM': accuracyM,
        if (speedMps != null) 'speedMps': speedMps,
      };

  final double lat;
  final double lng;
  final String recordedAt;
  final double? accuracyM;
  final double? speedMps;
}

class RouteTrackSummary {
  RouteTrackSummary({
    required this.id,
    required this.routeCode,
    required this.status,
    required this.pointCount,
  });

  factory RouteTrackSummary.fromJson(Map<String, dynamic> j) => RouteTrackSummary(
        id: j['id'] as String,
        routeCode: j['routeCode'] as String,
        status: j['status'] as String,
        pointCount: j['pointCount'] as int? ?? 0,
      );

  final String id;
  final String routeCode;
  final String status;
  final int pointCount;
}

class RouteTracksRepository {
  RouteTracksRepository(this._dio);
  final Dio _dio;

  Future<RouteTrackSummary> start(String routeCode) async {
    final res = await _dio.post('/route-tracks', data: {'routeCode': routeCode});
    return RouteTrackSummary.fromJson(res.data as Map<String, dynamic>);
  }

  Future<RouteTrackSummary> appendPoints(
    String trackId,
    List<TrackPointPayload> points,
  ) async {
    final res = await _dio.post(
      '/route-tracks/$trackId/points',
      data: {'points': points.map((p) => p.toJson()).toList()},
    );
    return RouteTrackSummary.fromJson(res.data as Map<String, dynamic>);
  }

  Future<RouteTrackSummary> updateStatus(
    String trackId,
    String status, {
    List<TrackPointPayload>? points,
  }) async {
    final res = await _dio.patch(
      '/route-tracks/$trackId',
      data: {
        'status': status,
        if (points != null && points.isNotEmpty)
          'points': points.map((p) => p.toJson()).toList(),
      },
    );
    return RouteTrackSummary.fromJson(res.data as Map<String, dynamic>);
  }
}
