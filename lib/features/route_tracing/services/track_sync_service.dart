import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rutas_cancun/features/route_tracing/data/route_tracks_repository.dart';
import 'package:rutas_cancun/features/route_tracing/data/track_local_store.dart';

final trackSyncServiceProvider = Provider<TrackSyncService>((ref) {
  return TrackSyncService(
    ref.watch(trackLocalStoreProvider),
    ref.watch(routeTracksRepositoryProvider),
  );
});

class TrackSyncResult {
  TrackSyncResult({
    required this.uploaded,
    required this.remainingUnsynced,
    required this.serverPointCount,
  });

  final int uploaded;
  final int remainingUnsynced;
  final int? serverPointCount;
}

class TrackSyncService {
  TrackSyncService(this._store, this._repo);

  final TrackLocalStore _store;
  final RouteTracksRepository _repo;

  Future<TrackSyncResult> syncPending(String remoteTrackId) async {
    var totalUploaded = 0;
    int? serverCount;

    while (true) {
      final batch = await _store.getUnsyncedPoints(remoteTrackId, limit: 200);
      if (batch.isEmpty) break;

      try {
        final summary = await _repo.appendPoints(
          remoteTrackId,
          batch.map((p) => p.toPayload()).toList(),
        );
        await _store.markSynced(remoteTrackId, batch.map((p) => p.localId).toList());
        totalUploaded += batch.length;
        serverCount = summary.pointCount;
      } catch (_) {
        break;
      }
    }

    final remaining = await _store.countUnsynced(remoteTrackId);
    return TrackSyncResult(
      uploaded: totalUploaded,
      remainingUnsynced: remaining,
      serverPointCount: serverCount,
    );
  }
}
