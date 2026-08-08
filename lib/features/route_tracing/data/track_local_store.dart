import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:rutas_cancun/features/route_tracing/data/route_tracks_repository.dart';
import 'package:sqflite/sqflite.dart';

final trackLocalStoreProvider = Provider<TrackLocalStore>((ref) {
  return TrackLocalStore.instance;
});

class LocalTracePoint {
  LocalTracePoint({
    required this.localId,
    required this.lat,
    required this.lng,
    required this.recordedAt,
    this.accuracyM,
    this.speedMps,
    required this.synced,
  });

  final int localId;
  final double lat;
  final double lng;
  final String recordedAt;
  final double? accuracyM;
  final double? speedMps;
  final bool synced;

  TrackPointPayload toPayload() => TrackPointPayload(
        lat: lat,
        lng: lng,
        recordedAt: recordedAt,
        accuracyM: accuracyM,
        speedMps: speedMps,
      );
}

class LocalTraceSession {
  LocalTraceSession({
    required this.remoteTrackId,
    required this.routeCode,
    required this.status,
    required this.startedAt,
    required this.pointCount,
    required this.unsyncedCount,
  });

  final String remoteTrackId;
  final String routeCode;
  final String status;
  final String startedAt;
  final int pointCount;
  final int unsyncedCount;
}

class TrackLocalStore {
  TrackLocalStore._();
  static final TrackLocalStore instance = TrackLocalStore._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'trace_points.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE trace_sessions (
            remote_track_id TEXT PRIMARY KEY,
            route_code TEXT NOT NULL,
            status TEXT NOT NULL,
            started_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE trace_points (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            remote_track_id TEXT NOT NULL,
            lat REAL NOT NULL,
            lng REAL NOT NULL,
            recorded_at TEXT NOT NULL,
            accuracy_m REAL,
            speed_mps REAL,
            synced INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (remote_track_id) REFERENCES trace_sessions(remote_track_id)
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_trace_points_sync ON trace_points(remote_track_id, synced)',
        );
      },
    );
    return _db!;
  }

  Future<void> createSession({
    required String remoteTrackId,
    required String routeCode,
  }) async {
    final db = await database;
    await db.insert(
      'trace_sessions',
      {
        'remote_track_id': remoteTrackId,
        'route_code': routeCode,
        'status': 'recording',
        'started_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateSessionStatus(String remoteTrackId, String status) async {
    final db = await database;
    await db.update(
      'trace_sessions',
      {'status': status},
      where: 'remote_track_id = ?',
      whereArgs: [remoteTrackId],
    );
  }

  Future<int> insertPoint(String remoteTrackId, TrackPointPayload point) async {
    final db = await database;
    return db.insert('trace_points', {
      'remote_track_id': remoteTrackId,
      'lat': point.lat,
      'lng': point.lng,
      'recorded_at': point.recordedAt,
      'accuracy_m': point.accuracyM,
      'speed_mps': point.speedMps,
      'synced': 0,
    });
  }

  Future<List<LocalTracePoint>> getUnsyncedPoints(
    String remoteTrackId, {
    int limit = 200,
  }) async {
    final db = await database;
    final rows = await db.query(
      'trace_points',
      where: 'remote_track_id = ? AND synced = 0',
      whereArgs: [remoteTrackId],
      orderBy: 'id ASC',
      limit: limit,
    );
    return rows.map(_rowToPoint).toList();
  }

  Future<void> markSynced(String remoteTrackId, List<int> localIds) async {
    if (localIds.isEmpty) return;
    final db = await database;
    final placeholders = List.filled(localIds.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE trace_points SET synced = 1 WHERE remote_track_id = ? AND id IN ($placeholders)',
      [remoteTrackId, ...localIds],
    );
  }

  Future<int> countUnsynced(String remoteTrackId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM trace_points WHERE remote_track_id = ? AND synced = 0',
      [remoteTrackId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<LocalTracePoint>> getAllPoints(String remoteTrackId) async {
    final db = await database;
    final rows = await db.query(
      'trace_points',
      where: 'remote_track_id = ?',
      whereArgs: [remoteTrackId],
      orderBy: 'id ASC',
    );
    return rows.map(_rowToPoint).toList();
  }

  Future<LocalTraceSession?> findIncompleteSession() async {
    final db = await database;
    final sessions = await db.query(
      'trace_sessions',
      where: "status IN ('recording', 'paused')",
      orderBy: 'started_at DESC',
      limit: 1,
    );
    if (sessions.isEmpty) return null;
    final s = sessions.first;
    final trackId = s['remote_track_id'] as String;
    final counts = await db.rawQuery(
      '''
      SELECT COUNT(*) AS total,
             SUM(CASE WHEN synced = 0 THEN 1 ELSE 0 END) AS unsynced
      FROM trace_points WHERE remote_track_id = ?
      ''',
      [trackId],
    );
    return LocalTraceSession(
      remoteTrackId: trackId,
      routeCode: s['route_code'] as String,
      status: s['status'] as String,
      startedAt: s['started_at'] as String,
      pointCount: (counts.first['total'] as num?)?.toInt() ?? 0,
      unsyncedCount: (counts.first['unsynced'] as num?)?.toInt() ?? 0,
    );
  }

  Future<int> completedSessionCount() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM trace_sessions WHERE status = 'completed_locally'",
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> clearSession(String remoteTrackId) async {
    final db = await database;
    await db.delete('trace_points', where: 'remote_track_id = ?', whereArgs: [remoteTrackId]);
    await db.delete('trace_sessions', where: 'remote_track_id = ?', whereArgs: [remoteTrackId]);
  }

  Future<void> markSessionCompletedLocally(String remoteTrackId) async {
    await updateSessionStatus(remoteTrackId, 'completed_locally');
  }

  LocalTracePoint _rowToPoint(Map<String, Object?> row) => LocalTracePoint(
        localId: row['id'] as int,
        lat: row['lat'] as double,
        lng: row['lng'] as double,
        recordedAt: row['recorded_at'] as String,
        accuracyM: row['accuracy_m'] as double?,
        speedMps: row['speed_mps'] as double?,
        synced: (row['synced'] as int) == 1,
      );
}
