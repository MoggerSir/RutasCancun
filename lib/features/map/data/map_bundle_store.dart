import 'package:rutas_cancun/features/routes/data/routes_repository.dart';
import 'package:rutas_cancun/core/config/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _legacyBundleKey = 'map_bundle_json';
const _legacyEtagKey = 'map_bundle_etag';
const _bundleSchemaVersion = '2026-07-display-detour-cleanup-v2';
const _sqfliteThresholdBytes = 300 * 1024;

String get _bundleKey => 'map_bundle_json::$_bundleSchemaVersion::${ApiConfig.baseUrl}';
String get _etagKey => 'map_bundle_etag::$_bundleSchemaVersion::${ApiConfig.baseUrl}';

class MapBundleStore {
  MapBundleStore._();
  static final instance = MapBundleStore._();

  Future<({RouteMapBundle? bundle, String? etag})> loadCached() async {
    final prefs = await SharedPreferences.getInstance();
    // Evita pintar durante unos segundos un bundle viejo guardado por una
    // version anterior de la app o por otro backend (Railway/VPS).
    await prefs.remove(_legacyBundleKey);
    await prefs.remove(_legacyEtagKey);

    final json = prefs.getString(_bundleKey);
    final etag = prefs.getString(_etagKey);
    if (json == null || json.isEmpty) return (bundle: null, etag: etag);
    try {
      return (bundle: json.toRouteMapBundle(), etag: etag);
    } catch (_) {
      return (bundle: null, etag: etag);
    }
  }

  Future<void> save(RouteMapBundle bundle) async {
    final json = bundle.toJsonString();
    if (json.length > _sqfliteThresholdBytes) {
      // Umbral documentado: >300 KB migraría a sqflite; por ahora truncamos log.
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bundleKey, json);
    await prefs.setString(_etagKey, bundle.etag);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_bundleKey);
    await prefs.remove(_etagKey);
    await prefs.remove(_legacyBundleKey);
    await prefs.remove(_legacyEtagKey);
  }
}
