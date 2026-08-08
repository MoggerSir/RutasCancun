import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:rutas_cancun/features/route_tracing/data/route_tracks_repository.dart';

class LocationTracker {
  StreamSubscription<Position>? _subscription;
  final _buffer = <TrackPointPayload>[];

  List<TrackPointPayload> get pendingPoints => List.unmodifiable(_buffer);

  int get pendingCount => _buffer.length;

  Future<bool> ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    if (permission == LocationPermission.denied) {
      return false;
    }
    final enabled = await Geolocator.isLocationServiceEnabled();
    return enabled;
  }

  void start(void Function(TrackPointPayload point) onPoint) {
    _subscription?.cancel();
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 8,
    );
    _subscription = Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) {
        final point = TrackPointPayload(
          lat: pos.latitude,
          lng: pos.longitude,
          recordedAt: pos.timestamp.toUtc().toIso8601String(),
          accuracyM: pos.accuracy,
          speedMps: pos.speed >= 0 ? pos.speed : null,
        );
        _buffer.add(point);
        onPoint(point);
      },
    );
  }

  void pause() {
    _subscription?.cancel();
    _subscription = null;
  }

  List<TrackPointPayload> drainPending() {
    final copy = List<TrackPointPayload>.from(_buffer);
    _buffer.clear();
    return copy;
  }

  void dispose() {
    _subscription?.cancel();
    _buffer.clear();
  }
}
