import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:rutas_cancun/features/map/data/map_bundle_store.dart';
import 'package:rutas_cancun/features/map/domain/route_polyline_utils.dart';
import 'package:rutas_cancun/features/routes/data/routes_repository.dart';

/// Caché en memoria del map-bundle y resultado de "Cercanas".
class MapRouteCache {
  MapRouteCache._();
  static final instance = MapRouteCache._();

  final _details = <String, RouteDetail>{};
  NearbyCacheEntry? _nearby;
  String? _etag;
  RouteMapBundle? _bundle;
  static const locationThresholdM = 150.0;

  bool hasDetail(String routeId) => _details.containsKey(routeId);

  RouteDetail? detail(String routeId) => _details[routeId];

  RouteDetail? detailByCode(String code) {
    for (final d in _details.values) {
      if (d.code == code) return d;
    }
    return null;
  }

  String? get etag => _etag;
  RouteMapBundle? get bundle => _bundle;

  void seedDetails(Map<String, RouteDetail> details) {
    _details.addAll(details);
  }

  Map<String, RouteDetail> get allDetails => Map.unmodifiable(_details);

  void _applyBundle(RouteMapBundle bundle) {
    _bundle = bundle;
    _etag = bundle.etag;
    for (final route in bundle.routes) {
      final existing = _details[route.id];
      if (existing == null || !existing.fullPrecisionLoaded) {
        _details[route.id] = route;
      } else {
        _details[route.id] = existing.withDisplayGeometryFrom(route);
      }
    }
  }

  /// Stale-while-revalidate: pinta caché primero, revalida en paralelo.
  /// Si `map-bundle` no existe en el servidor, cae a `GET /routes/:id` por ruta.
  Future<void> loadMapBundle(
    RoutesRepository repo, {
    List<RouteSummary>? routesFallback,
    void Function()? onUpdated,
  }) async {
    final cached = await MapBundleStore.instance.loadCached();
    if (cached.bundle != null) {
      _applyBundle(cached.bundle!);
      _etag = cached.etag ?? cached.bundle!.etag;
      onUpdated?.call();
    }

    try {
      final result = await repo.getMapBundle(etag: _etag);
      _applyBundle(result.bundle);
      await MapBundleStore.instance.save(result.bundle);
      onUpdated?.call();
    } on MapBundleNotModifiedException {
      // 304 — datos en memoria/disco siguen válidos.
    } on MapBundleUnavailableException {
      if (cached.bundle != null) return;
      if (routesFallback != null && routesFallback.isNotEmpty) {
        debugPrint('map-bundle no disponible; usando carga legacy por ruta');
        await _preloadLegacy(routesFallback, repo);
        onUpdated?.call();
        return;
      }
      rethrow;
    } catch (e, st) {
      if (cached.bundle != null) {
        debugPrint('Map bundle revalidation failed (using cache): $e');
        return;
      }
      if (routesFallback != null && routesFallback.isNotEmpty) {
        debugPrint('Map bundle failed; usando carga legacy por ruta: $e');
        await _preloadLegacy(routesFallback, repo);
        onUpdated?.call();
        return;
      }
      debugPrint('Map bundle load failed: $e\n$st');
      rethrow;
    }
  }

  Future<void> _preloadLegacy(List<RouteSummary> routes, RoutesRepository repo) async {
    final pending = routes.where((r) => !_details.containsKey(r.id)).toList();
    if (pending.isEmpty) return;
    await Future.wait(
      pending.map((r) async {
        try {
          var detail = await repo.getRoute(r.id);
          final bounds = detail.bounds ?? RoutePolylineUtils.boundsFromDetail(detail);
          if (bounds != null) {
            detail = detail.withComputedBounds(bounds);
          }
          _details[r.id] = detail;
        } catch (e) {
          debugPrint('No se pudo cargar ruta ${r.code}: $e');
        }
      }),
    );
  }

  Future<RouteDetail> ensureFullDetail(String idOrCode, RoutesRepository repo) async {
    final existing = _details.values.where((d) => d.id == idOrCode || d.code == idOrCode).firstOrNull;
    if (existing != null && existing.fullPrecisionLoaded) return existing;

    final full = await repo.getRoute(idOrCode);
    final detail = existing == null ? full : full.withDisplayGeometryFrom(existing);
    _details[detail.id] = detail;
    return detail;
  }

  NearbyCacheEntry? nearbyIfValid(LatLng? currentHint) {
    if (_nearby == null) return null;
    if (currentHint == null) return _nearby;
    final dist = const Distance().distance(_nearby!.position, currentHint);
    if (dist <= locationThresholdM) return _nearby;
    return null;
  }

  void saveNearby({
    required double lat,
    required double lng,
    required String routeCode,
    required double distanceM,
  }) {
    _nearby = NearbyCacheEntry(
      lat: lat,
      lng: lng,
      routeCode: routeCode,
      distanceM: distanceM,
      cachedAt: DateTime.now(),
    );
  }

  void clear() {
    _details.clear();
    _nearby = null;
    _etag = null;
    _bundle = null;
    MapBundleStore.instance.clear();
  }

  void clearNearby() => _nearby = null;
}

class NearbyCacheEntry {
  const NearbyCacheEntry({
    required this.lat,
    required this.lng,
    required this.routeCode,
    required this.distanceM,
    required this.cachedAt,
  });

  final double lat;
  final double lng;
  final String routeCode;
  final double distanceM;
  final DateTime cachedAt;

  LatLng get position => LatLng(lat, lng);
  double get distanceKm => distanceM / 1000;
}
