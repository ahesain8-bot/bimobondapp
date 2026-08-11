import 'package:bimobondapp/app/video_templates/project/models/user_template_project_draft.dart';
import 'package:bimobondapp/app/video_templates/project/project_media_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

/// Local durable store for editable [UserTemplateProjectDraft] documents.
///
/// Shares DB with [ProjectMediaManager]. Project JSON is written atomically
/// inside a transaction; media binaries stay on disk.
class LocalProjectStore {
  LocalProjectStore({required ProjectMediaManager mediaManager})
      : _mediaManager = mediaManager;

  static const _projectsTable = 'template_projects';

  final ProjectMediaManager _mediaManager;
  bool _schemaReady = false;

  Future<Database> _db() async {
    final db = await _mediaManager.openSharedDatabase();
    if (!_schemaReady) {
      await db.execute('''
CREATE TABLE IF NOT EXISTS $_projectsTable (
  id TEXT PRIMARY KEY NOT NULL,
  backend_project_id TEXT,
  template_id TEXT NOT NULL,
  template_version INTEGER NOT NULL,
  status TEXT NOT NULL,
  json TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)
''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_template_projects_template '
        'ON $_projectsTable(template_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_template_projects_updated '
        'ON $_projectsTable(updated_at DESC)',
      );
      _schemaReady = true;
    }
    return db;
  }

  /// Upsert full project document. Safe to call repeatedly (autosave).
  Future<void> saveDraft(UserTemplateProjectDraft draft) async {
    final db = await _db();
    final updated = draft.copyWith(updatedAt: DateTime.now().toUtc());
    final payload = {
      'id': updated.id,
      'backend_project_id': updated.backendProjectId,
      'template_id': updated.templateId,
      'template_version': updated.templateVersion,
      'status': updated.status,
      'json': updated.encode(),
      'created_at': updated.createdAt.millisecondsSinceEpoch,
      'updated_at': updated.updatedAt.millisecondsSinceEpoch,
    };
    await db.transaction((txn) async {
      await txn.insert(
        _projectsTable,
        payload,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<UserTemplateProjectDraft?> getById(String projectId) async {
    final db = await _db();
    final rows = await db.query(
      _projectsTable,
      where: 'id = ? OR backend_project_id = ?',
      whereArgs: [projectId, projectId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _decodeRow(rows.first);
  }

  Future<List<UserTemplateProjectDraft>> listEditing({int limit = 50}) async {
    final db = await _db();
    final rows = await db.query(
      _projectsTable,
      where: 'status = ?',
      whereArgs: ['EDITING'],
      orderBy: 'updated_at DESC',
      limit: limit,
    );
    final out = <UserTemplateProjectDraft>[];
    for (final row in rows) {
      final draft = _decodeRow(row);
      if (draft != null) out.add(draft);
    }
    return out;
  }

  Future<void> deleteProject(String projectId) async {
    final db = await _db();
    await db.transaction((txn) async {
      await txn.delete(
        _projectsTable,
        where: 'id = ? OR backend_project_id = ?',
        whereArgs: [projectId, projectId],
      );
    });
    await _mediaManager.deleteProjectMedia(projectId);
  }

  UserTemplateProjectDraft? _decodeRow(Map<String, Object?> row) {
    final raw = row['json']?.toString();
    if (raw == null || raw.isEmpty) return null;
    try {
      return UserTemplateProjectDraft.decode(raw);
    } catch (e, st) {
      debugPrint('LocalProjectStore decode failed: $e\n$st');
      return null;
    }
  }
}
