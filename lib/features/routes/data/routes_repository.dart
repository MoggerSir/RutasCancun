import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rutas_cancun/core/config/api_config.dart';
import 'package:rutas_cancun/core/network/dio_provider.dart';

final routesRepositoryProvider = Provider<RoutesRepository>((ref) {
  return RoutesRepository(ref.watch(dioProvider));
});

class RouteSummary {
  RouteSummary({
    required this.id,
    required this.code,
    required this.name,
    required this.operator,
    this.photoUrl,
    this.coverage,
  });

  factory RouteSummary.fromJson(Map<String, dynamic> j) => RouteSummary(
        id: j['id'] as String,
        code: j['code'] as String,
        name: j['name'] as String,
        operator: j['operator'] as String? ?? '',
        photoUrl: j['photoUrl'] as String?,
        coverage: j['coverage'] as String?,
      );

  final String id;
  final String code;
  final String name;
  final String operator;
  final String? photoUrl;
  final String? coverage;
}

class RouteDirectionInfo {
  RouteDirectionInfo({
    required this.direction,
    required this.distanceKm,
    required this.estDurationMin,
  });

  factory RouteDirectionInfo.fromJson(Map<String, dynamic> j) =>
      RouteDirectionInfo(
        direction: j['direction'] as String? ?? 'ida',
        distanceKm: (j['distanceKm'] as num).toDouble(),
        estDurationMin: (j['estDurationMin'] as num).round(),
      );

  final String direction;
  final double distanceKm;
  final int estDurationMin;
}

class RouteBounds {
  RouteBounds({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  factory RouteBounds.fromJson(Map<String, dynamic> j) => RouteBounds(
        minLat: (j['minLat'] as num).toDouble(),
        maxLat: (j['maxLat'] as num).toDouble(),
        minLng: (j['minLng'] as num).toDouble(),
        maxLng: (j['maxLng'] as num).toDouble(),
      );

  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;
}

class RouteDetail {
  RouteDetail({
    required this.id,
    required this.code,
    required this.name,
    required this.stops,
    required this.polyline,
    required this.metadata,
    this.polylines,
    this.photoUrl,
    this.description,
    this.descriptionUpdatedAt,
    this.coverage,
    this.directions,
    this.bounds,
    this.operatorName,
    this.operatorSlug,
    this.fullPrecisionLoaded = true,
  });

  factory RouteDetail.fromJson(Map<String, dynamic> j) => RouteDetail(
        id: j['id'] as String,
        code: j['code'] as String,
        name: j['name'] as String,
        stops: (j['stops'] as List)
            .map((s) => RouteStop.fromJson(s as Map<String, dynamic>))
            .toList(),
        polyline: j['polyline'] as Map<String, dynamic>?,
        metadata: j['metadata'] as Map<String, dynamic>?,
        polylines: (j['polylines'] as List?)
            ?.map((p) => RoutePolyline.fromJson(p as Map<String, dynamic>))
            .toList(),
        photoUrl: j['photoUrl'] as String?,
        description: j['description'] as String?,
        descriptionUpdatedAt: j['descriptionUpdatedAt'] as String?,
        coverage: j['coverage'] as String?,
        directions: (j['directions'] as List?)
            ?.map((d) => RouteDirectionInfo.fromJson(d as Map<String, dynamic>))
            .toList(),
        operatorName:
            (j['operator'] as Map<String, dynamic>?)?['name'] as String?,
        operatorSlug:
            (j['operator'] as Map<String, dynamic>?)?['slug'] as String?,
        fullPrecisionLoaded: true,
      );

  factory RouteDetail.fromMapBundleItem(Map<String, dynamic> j) {
    final polylinesSimplified = (j['polylinesSimplified'] as List?)
            ?.map((p) => RoutePolyline.fromJson(p as Map<String, dynamic>))
            .toList() ??
        [];
    final primary = j['polylineSimplified'] as Map<String, dynamic>?;
    return RouteDetail(
      id: j['id'] as String,
      code: j['code'] as String,
      name: j['name'] as String,
      stops: (j['stops'] as List)
          .map((s) => RouteStop.fromJson(s as Map<String, dynamic>))
          .toList(),
      polyline: primary,
      polylines: polylinesSimplified,
      metadata: _metadataFromDirections(j['directions'] as List?),
      photoUrl: j['photoUrl'] as String?,
      description: null,
      coverage: j['coverage'] as String?,
      directions: (j['directions'] as List?)
          ?.map((d) => RouteDirectionInfo.fromJson(d as Map<String, dynamic>))
          .toList(),
      bounds: j['bounds'] != null
          ? RouteBounds.fromJson(j['bounds'] as Map<String, dynamic>)
          : null,
      operatorName:
          (j['operator'] as Map<String, dynamic>?)?['name'] as String?,
      operatorSlug:
          (j['operator'] as Map<String, dynamic>?)?['slug'] as String?,
      fullPrecisionLoaded: false,
    );
  }

  static Map<String, dynamic>? _metadataFromDirections(List? directions) {
    if (directions == null || directions.isEmpty) return null;
    final ida = directions.cast<Map<String, dynamic>>().firstWhere(
          (d) => d['direction'] == 'ida',
          orElse: () => directions.first as Map<String, dynamic>,
        );
    return {
      'distanceKm': ida['distanceKm'],
      'estDurationMin': ida['estDurationMin'],
    };
  }

  final String id;
  final String code;
  final String name;
  final List<RouteStop> stops;
  final Map<String, dynamic>? polyline;
  final Map<String, dynamic>? metadata;
  final List<RoutePolyline>? polylines;
  final String? photoUrl;
  final String? description;
  final String? descriptionUpdatedAt;
  final String? coverage;
  final List<RouteDirectionInfo>? directions;
  final RouteBounds? bounds;
  final String? operatorName;
  final String? operatorSlug;
  final bool fullPrecisionLoaded;

  int? get durationIda {
    final dir = directions?.where((d) => d.direction == 'ida').firstOrNull;
    return dir?.estDurationMin ?? metadata?['estDurationMin'] as int?;
  }

  int? get durationVuelta {
    return directions
        ?.where((d) => d.direction == 'vuelta')
        .firstOrNull
        ?.estDurationMin;
  }

  bool get hasVuelta =>
      coverage == 'ida_vuelta' ||
      coverage == 'vuelta' ||
      (directions?.any((d) => d.direction == 'vuelta') ?? false);

  bool get hasIdaOnly =>
      coverage == 'ida' ||
      (directions != null &&
          directions!.length == 1 &&
          directions!.first.direction == 'ida');

  String? resolvedPhotoUrl() {
    final url = photoUrl;
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return url;
    final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/api$'), '');
    return '$base$url';
  }

  RouteDetail withComputedBounds(RouteBounds bounds) => RouteDetail(
        id: id,
        code: code,
        name: name,
        stops: stops,
        polyline: polyline,
        metadata: metadata,
        polylines: polylines,
        photoUrl: photoUrl,
        description: description,
        descriptionUpdatedAt: descriptionUpdatedAt,
        coverage: coverage,
        directions: directions,
        bounds: bounds,
        operatorName: operatorName,
        operatorSlug: operatorSlug,
        fullPrecisionLoaded: fullPrecisionLoaded,
      );

  RouteDetail withDisplayGeometryFrom(RouteDetail display) => RouteDetail(
        id: id,
        code: code,
        name: name,
        stops: stops,
        polyline: display.polyline ?? polyline,
        metadata: metadata,
        polylines: display.polylines?.isNotEmpty == true
            ? display.polylines
            : polylines,
        photoUrl: photoUrl,
        description: description,
        descriptionUpdatedAt: descriptionUpdatedAt,
        coverage: coverage,
        directions: directions,
        bounds: display.bounds ?? bounds,
        operatorName: operatorName,
        operatorSlug: operatorSlug,
        fullPrecisionLoaded: true,
      );
}

class RoutePolyline {
  RoutePolyline({
    required this.direction,
    required this.polyline,
    this.snapped,
  });

  factory RoutePolyline.fromJson(Map<String, dynamic> j) => RoutePolyline(
        direction: j['direction'] as String? ?? 'ida',
        polyline: (j['polyline'] as Map<String, dynamic>?) ?? {},
        snapped: j['snapped'] as bool?,
      );

  final String direction;
  final Map<String, dynamic> polyline;
  final bool? snapped;
}

class RouteStop {
  RouteStop({
    required this.sequence,
    required this.name,
    required this.lat,
    required this.lng,
  });

  factory RouteStop.fromJson(Map<String, dynamic> j) => RouteStop(
        sequence: j['sequence'] as int,
        name: j['name'] as String,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
      );

  final int sequence;
  final String name;
  final double lat;
  final double lng;
}

class RouteMapBundle {
  RouteMapBundle({
    required this.generatedAt,
    required this.etag,
    required this.routes,
  });

  factory RouteMapBundle.fromJson(Map<String, dynamic> j) => RouteMapBundle(
        generatedAt: j['generatedAt'] as String,
        etag: j['etag'] as String,
        routes: (j['routes'] as List)
            .map(
                (r) => RouteDetail.fromMapBundleItem(r as Map<String, dynamic>))
            .toList(),
      );

  final String generatedAt;
  final String etag;
  final List<RouteDetail> routes;

  Map<String, dynamic> toJson() => {
        'generatedAt': generatedAt,
        'etag': etag,
        'routes': routes.map(_routeToJson).toList(),
      };

  static Map<String, dynamic> _routeToJson(RouteDetail r) => {
        'id': r.id,
        'code': r.code,
        'name': r.name,
        'operator': {'name': r.operatorName, 'slug': r.operatorSlug},
        'coverage': r.coverage,
        'photoUrl': r.photoUrl,
        'bounds': r.bounds == null
            ? null
            : {
                'minLat': r.bounds!.minLat,
                'maxLat': r.bounds!.maxLat,
                'minLng': r.bounds!.minLng,
                'maxLng': r.bounds!.maxLng,
              },
        'polylineSimplified': r.polyline,
        'polylinesSimplified': r.polylines
            ?.map((p) => {'direction': p.direction, 'polyline': p.polyline})
            .toList(),
        'stops': r.stops
            .map((s) => {
                  'sequence': s.sequence,
                  'name': s.name,
                  'lat': s.lat,
                  'lng': s.lng,
                })
            .toList(),
        'directions': r.directions
            ?.map((d) => {
                  'direction': d.direction,
                  'distanceKm': d.distanceKm,
                  'estDurationMin': d.estDurationMin,
                })
            .toList(),
      };
}

class MapBundleFetchResult {
  MapBundleFetchResult(
      {required this.bundle,
      required this.fromCache,
      this.notModified = false});

  final RouteMapBundle bundle;
  final bool fromCache;
  final bool notModified;
}

class SearchResult {
  SearchResult({
    required this.results,
    required this.journeys,
    required this.incidentsAvailable,
    required this.disclaimer,
  });

  factory SearchResult.fromJson(Map<String, dynamic> j) => SearchResult(
        results: (j['results'] as List)
            .map((r) => RankedRoute.fromJson(r as Map<String, dynamic>))
            .toList(),
        journeys: (j['journeys'] as List? ?? const [])
            .map((item) => JourneyOption.fromJson(item as Map<String, dynamic>))
            .toList(),
        incidentsAvailable: j['incidentsAvailable'] as bool? ?? false,
        disclaimer: j['disclaimer'] as String? ?? '',
      );

  final List<RankedRoute> results;
  final List<JourneyOption> journeys;
  final bool incidentsAvailable;
  final String disclaimer;
}

class JourneyLeg {
  JourneyLeg({
    required this.routeId,
    required this.routeCode,
    required this.routeName,
    required this.boardStop,
    required this.alightStop,
    required this.distanceKm,
  });

  factory JourneyLeg.fromJson(Map<String, dynamic> json) => JourneyLeg(
        routeId: json['routeId'] as String,
        routeCode: json['routeCode'] as String,
        routeName: json['routeName'] as String,
        boardStop: json['boardStop'] as String,
        alightStop: json['alightStop'] as String,
        distanceKm: (json['distanceKm'] as num).toDouble(),
      );

  final String routeId;
  final String routeCode;
  final String routeName;
  final String boardStop;
  final String alightStop;
  final double distanceKm;
}

class JourneyOption {
  JourneyOption({
    required this.id,
    required this.legs,
    required this.transfers,
    required this.accessWalkKm,
    required this.transferWalkKm,
    required this.egressWalkKm,
    required this.transitDistanceKm,
    required this.estimatedDurationMin,
    required this.generalizedCost,
    required this.recentIncidentClusters,
  });

  factory JourneyOption.fromJson(Map<String, dynamic> json) => JourneyOption(
        id: json['id'] as String,
        legs: (json['legs'] as List)
            .map((item) => JourneyLeg.fromJson(item as Map<String, dynamic>))
            .toList(),
        transfers: json['transfers'] as int,
        accessWalkKm: (json['accessWalkKm'] as num).toDouble(),
        transferWalkKm: (json['transferWalkKm'] as num).toDouble(),
        egressWalkKm: (json['egressWalkKm'] as num).toDouble(),
        transitDistanceKm: (json['transitDistanceKm'] as num).toDouble(),
        estimatedDurationMin: json['estimatedDurationMin'] as int,
        generalizedCost: (json['generalizedCost'] as num).toDouble(),
        recentIncidentClusters: json['recentIncidentClusters'] as int? ?? 0,
      );

  final String id;
  final List<JourneyLeg> legs;
  final int transfers;
  final double accessWalkKm;
  final double transferWalkKm;
  final double egressWalkKm;
  final double transitDistanceKm;
  final int estimatedDurationMin;
  final double generalizedCost;
  final int recentIncidentClusters;

  double get totalWalkKm => accessWalkKm + transferWalkKm + egressWalkKm;
}

class RankedRoute {
  RankedRoute({
    required this.routeId,
    required this.routeCode,
    required this.routeName,
    required this.rankByCoverage,
    required this.rankByDistance,
    required this.rankByIncidents,
    required this.distanceKm,
    required this.estDurationMin,
    required this.durationConfidence,
    required this.durationLabel,
    required this.recentIncidentClusters,
  });

  factory RankedRoute.fromJson(Map<String, dynamic> j) => RankedRoute(
        routeId: j['routeId'] as String,
        routeCode: j['routeCode'] as String,
        routeName: j['routeName'] as String,
        rankByCoverage: j['rankByCoverage'] as int,
        rankByDistance: j['rankByDistance'] as int,
        rankByIncidents: j['rankByIncidents'] as int?,
        distanceKm: (j['distanceKm'] as num).toDouble(),
        estDurationMin: j['estDurationMin'] as int?,
        durationConfidence: j['durationConfidence'] as String?,
        durationLabel: j['durationLabel'] as String? ?? '',
        recentIncidentClusters: j['recentIncidentClusters'] as int? ?? 0,
      );

  final String routeId;
  final String routeCode;
  final String routeName;
  final int rankByCoverage;
  final int rankByDistance;
  final int? rankByIncidents;
  final double distanceKm;
  final int? estDurationMin;
  final String? durationConfidence;
  final String durationLabel;
  final int recentIncidentClusters;

  String durationText() {
    if (estDurationMin == null || durationLabel == 'oculto_baja_confianza') {
      return '';
    }
    if (durationConfidence == 'medium') {
      return '~$estDurationMin min (aprox., sin tráfico en vivo)';
    }
    return '~$estDurationMin min estimados (sin tráfico en vivo)';
  }
}

class RoutesRepository {
  RoutesRepository(this._dio);
  final Dio _dio;

  Future<List<RouteSummary>> listRoutes() async {
    final res = await _dio.get('/routes');
    return (res.data as List)
        .map((j) => RouteSummary.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<RouteDetail> getRoute(String idOrCode) async {
    final res = await _dio.get('/routes/$idOrCode');
    return RouteDetail.fromJson(res.data as Map<String, dynamic>);
  }

  Future<MapBundleFetchResult> getMapBundle({String? etag}) async {
    final headers = <String, dynamic>{};
    if (etag != null && etag.isNotEmpty) {
      headers['If-None-Match'] = etag;
    }

    final res = await _dio.get<Map<String, dynamic>>(
      '/routes/map-bundle',
      options: Options(
        headers: headers,
        validateStatus: (status) =>
            status != null && (status < 300 || status == 304 || status == 404),
      ),
    );

    if (res.statusCode == 304) {
      throw const MapBundleNotModifiedException();
    }
    if (res.statusCode == 404) {
      throw const MapBundleUnavailableException();
    }

    final data = res.data!;
    final responseEtag = res.headers.value('etag') ?? data['etag'] as String;
    return MapBundleFetchResult(
      bundle: RouteMapBundle.fromJson({...data, 'etag': responseEtag}),
      fromCache: false,
    );
  }

  Future<SearchResult> search({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String? originLabel,
    String? destLabel,
  }) async {
    final res = await _dio.post('/routes/search', data: {
      'origin': {
        'lat': originLat,
        'lng': originLng,
        if (originLabel != null) 'label': originLabel
      },
      'destination': {
        'lat': destLat,
        'lng': destLng,
        if (destLabel != null) 'label': destLabel
      },
    });
    return SearchResult.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> submitReport({
    required String routeId,
    required String reportType,
    required double lat,
    required double lng,
  }) async {
    await _dio.post('/reports', data: {
      'routeId': routeId,
      'reportType': reportType,
      'lat': lat,
      'lng': lng,
    });
  }
}

class MapBundleNotModifiedException implements Exception {
  const MapBundleNotModifiedException();
}

/// API aún no expone `/routes/map-bundle` (p. ej. despliegue pendiente).
class MapBundleUnavailableException implements Exception {
  const MapBundleUnavailableException();
}

extension RouteDetailJson on RouteMapBundle {
  String toJsonString() => jsonEncode(toJson());
}

extension RouteMapBundleDecode on String {
  RouteMapBundle toRouteMapBundle() =>
      RouteMapBundle.fromJson(jsonDecode(this) as Map<String, dynamic>);
}
