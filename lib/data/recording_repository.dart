import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'recording.dart';

/// Kho luu ban ghi (SQLite). Du lieu ton tai qua cac lan mo app.
class RecordingRepository {
  static Database? _db;

  static Future<Database> _database() async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'vietvoice.db'),
      version: 2,
      onCreate: (db, version) async {
        await _createTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE recordings ADD COLUMN speakers_json TEXT');
          await db.execute('ALTER TABLE recordings ADD COLUMN diarized INTEGER');
        }
      },
    );
    return _db!;
  }

  Future<List<Recording>> all() async {
    final db = await _database();
    final rows = await db.query('recordings', orderBy: 'created_at DESC');
    return rows.map(Recording.fromMap).toList();
  }

  Future<List<Recording>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return all();
    final db = await _database();
    final like = '%$q%';
    final rows = await db.query(
      'recordings',
      where: 'title LIKE ? OR transcript LIKE ?',
      whereArgs: [like, like],
      orderBy: 'created_at DESC',
    );
    return rows.map(Recording.fromMap).toList();
  }

  Future<Recording> insert(Recording r) async {
    final db = await _database();
    final id = await db.insert('recordings', r.toMap());
    return r.copyWith(id: id);
  }

  Future<void> rename(int id, String title) async {
    final db = await _database();
    await db.update(
      'recordings',
      {'title': title},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateAudioPath(int id, String path) async {
    final db = await _database();
    await db.update(
      'recordings',
      {'audio_path': path},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateSummary(int id, Map<String, dynamic> summary) async {
    final db = await _database();
    await db.update(
      'recordings',
      {'summary_json': jsonEncode(summary)},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Luu lai phan chep loi da sua, danh sach nguoi noi va cac doan (UI-05/UI-07).
  Future<void> updateContent(
    int id, {
    String? transcript,
    List<dynamic>? segments,
    Map<String, String>? speakers,
    bool? diarized,
  }) async {
    final db = await _database();
    final values = <String, Object?>{};
    if (transcript != null) values['transcript'] = transcript;
    if (segments != null) values['segments_json'] = jsonEncode(segments);
    if (speakers != null) values['speakers_json'] = jsonEncode(speakers);
    if (diarized != null) values['diarized'] = diarized ? 1 : 0;
    if (values.isNotEmpty) {
      await db.update('recordings', values, where: 'id = ?', whereArgs: [id]);
    }
  }

  static Future<void> _createTable(Database db) async {
    await db.execute('''
      CREATE TABLE recordings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        duration REAL,
        model TEXT,
        language TEXT,
        audio_path TEXT,
        transcript TEXT NOT NULL,
        segments_json TEXT,
        speakers_json TEXT,
        diarized INTEGER,
        summary_json TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_recordings_created ON recordings(created_at DESC)',
    );
  }

  Future<void> delete(int id) async {
    final db = await _database();
    final rows = await db.query(
      'recordings',
      columns: ['audio_path'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    await db.delete('recordings', where: 'id = ?', whereArgs: [id]);
    final path = rows.isEmpty ? null : rows.first['audio_path'] as String?;
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }
}
