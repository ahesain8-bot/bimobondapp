import 'dart:io';
import 'dart:math';

import 'package:bimobondapp/core/utils/video_thumbnail_utils.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Durable media owned by a template project (paths, not picker temps).
class ProjectMediaRecord extends Equatable {
  const ProjectMediaRecord({
    required this.mediaId,
    required this.projectId,
    required this.mediaType,
    required this.fileName,
    required this.createdAt,
    this.originalPath,
  });

  final String mediaId;
  final String projectId;
  /// `IMAGE` | `VIDEO` | `AUDIO`
  final String mediaType;
  final String fileName;
  final String? originalPath;
  final DateTime createdAt;

  @override
  List<Object?> get props =>
      [mediaId, projectId, mediaType, fileName, originalPath, createdAt];
}

/// Copies user media into app-managed storage and tracks refs by [mediaId].
///
/// Never stores binary blobs in SQLite — only paths and metadata.
class ProjectMediaManager {
  ProjectMediaManager({Database? database}) : _dbOverride = database;

  static const _dbName = 'template_projects.db';
  static const _mediaTable = 'project_media';

  final Database? _dbOverride;
  Database? _db;
  Directory? _root;

  Future<Database> _database() async {
    if (_dbOverride != null) return _dbOverride;
    if (_db != null) return _db!;
    final docs = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docs.path, 'video_templates', _dbName);
    await Directory(p.dirname(dbPath)).create(recursive: true);
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE IF NOT EXISTS $_mediaTable (
  media_id TEXT PRIMARY KEY NOT NULL,
  project_id TEXT NOT NULL,
  media_type TEXT NOT NULL,
  file_name TEXT NOT NULL,
  original_path TEXT,
  created_at INTEGER NOT NULL
)
''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_project_media_project '
          'ON $_mediaTable(project_id)',
        );
      },
    );
    return _db!;
  }

  Future<Directory> _projectMediaDir(String projectId) async {
    _root ??= Directory(
      p.join(
        (await getApplicationDocumentsDirectory()).path,
        'video_templates',
        'media',
      ),
    );
    final dir = Directory(p.join(_root!.path, projectId));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _newMediaId() {
    final ms = DateTime.now().millisecondsSinceEpoch;
    final r = Random().nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return 'm_${ms}_$r';
  }

  String _detectType(File file, {String? hint}) {
    // File extension / content wins over recipe slot type (IMAGE slots often
    // receive video clips for photo-dump templates).
    if (VideoThumbnailUtils.isVideoFile(file)) return 'VIDEO';
    final h = hint?.trim().toUpperCase();
    if (h == 'VIDEO') return 'VIDEO';
    if (h == 'AUDIO') return 'AUDIO';
    final path = file.path.toLowerCase();
    if (path.endsWith('.mp3') ||
        path.endsWith('.m4a') ||
        path.endsWith('.aac') ||
        path.endsWith('.wav')) {
      return 'AUDIO';
    }
    if (h == 'IMAGE' || h == 'PHOTO') return 'IMAGE';
    return 'IMAGE';
  }

  /// Import [source] into project storage. Returns a durable [ProjectMediaRecord].
  Future<ProjectMediaRecord> importFile({
    required String projectId,
    required File source,
    String? mediaType,
  }) async {
    if (!await source.exists()) {
      throw StateError('Source media missing: ${source.path}');
    }
    final type = _detectType(source, hint: mediaType);
    final mediaId = _newMediaId();
    final ext = p.extension(source.path);
    final safeExt = ext.isEmpty
        ? (type == 'VIDEO'
            ? '.mp4'
            : type == 'AUDIO'
                ? '.m4a'
                : '.jpg')
        : ext;
    final fileName = '$mediaId$safeExt';
    final dir = await _projectMediaDir(projectId);
    final dest = File(p.join(dir.path, fileName));
    await source.copy(dest.path);

    final record = ProjectMediaRecord(
      mediaId: mediaId,
      projectId: projectId,
      mediaType: type,
      fileName: fileName,
      originalPath: source.path,
      createdAt: DateTime.now().toUtc(),
    );
    final db = await _database();
    await db.insert(
      _mediaTable,
      {
        'media_id': record.mediaId,
        'project_id': record.projectId,
        'media_type': record.mediaType,
        'file_name': record.fileName,
        'original_path': record.originalPath,
        'created_at': record.createdAt.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return record;
  }

  Future<File?> resolveFile(String mediaId) async {
    final record = await getRecord(mediaId);
    if (record == null) return null;
    final dir = await _projectMediaDir(record.projectId);
    final file = File(p.join(dir.path, record.fileName));
    if (await file.exists()) return file;
    // Recover: if original picker path still exists, re-copy.
    final original = record.originalPath;
    if (original != null && original.isNotEmpty) {
      final src = File(original);
      if (await src.exists()) {
        try {
          await src.copy(file.path);
          if (await file.exists()) return file;
        } catch (e, st) {
          debugPrint('ProjectMediaManager recover: $e\n$st');
        }
      }
    }
    return null;
  }

  Future<ProjectMediaRecord?> getRecord(String mediaId) async {
    final db = await _database();
    final rows = await db.query(
      _mediaTable,
      where: 'media_id = ?',
      whereArgs: [mediaId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _rowToRecord(rows.first);
  }

  Future<List<ProjectMediaRecord>> listForProject(String projectId) async {
    final db = await _database();
    final rows = await db.query(
      _mediaTable,
      where: 'project_id = ?',
      whereArgs: [projectId],
    );
    return rows.map(_rowToRecord).toList(growable: false);
  }

  Future<bool> exists(String mediaId) async {
    final file = await resolveFile(mediaId);
    return file != null;
  }

  /// Delete media that is not referenced by any [referencedMediaIds] for project.
  Future<void> deleteUnused({
    required String projectId,
    required Set<String> referencedMediaIds,
  }) async {
    final all = await listForProject(projectId);
    final db = await _database();
    for (final record in all) {
      if (referencedMediaIds.contains(record.mediaId)) continue;
      // Shared across projects? Skip if another project owns same media_id
      // (media_id is unique globally, so safe to delete).
      final dir = await _projectMediaDir(record.projectId);
      final file = File(p.join(dir.path, record.fileName));
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
      await db.delete(
        _mediaTable,
        where: 'media_id = ?',
        whereArgs: [record.mediaId],
      );
    }
  }

  /// Remove all media for a project (call when project is discarded).
  Future<void> deleteProjectMedia(String projectId) async {
    final all = await listForProject(projectId);
    final db = await _database();
    for (final record in all) {
      final dir = await _projectMediaDir(record.projectId);
      final file = File(p.join(dir.path, record.fileName));
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    await db.delete(
      _mediaTable,
      where: 'project_id = ?',
      whereArgs: [projectId],
    );
    try {
      final dir = await _projectMediaDir(projectId);
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  ProjectMediaRecord _rowToRecord(Map<String, Object?> row) {
    return ProjectMediaRecord(
      mediaId: row['media_id']?.toString() ?? '',
      projectId: row['project_id']?.toString() ?? '',
      mediaType: row['media_type']?.toString() ?? 'IMAGE',
      fileName: row['file_name']?.toString() ?? '',
      originalPath: row['original_path']?.toString(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (row['created_at'] as int?) ?? 0,
        isUtc: true,
      ),
    );
  }

  /// Shared DB handle for [LocalProjectStore] (same file).
  Future<Database> openSharedDatabase() => _database();
}
