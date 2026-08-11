import 'dart:io';

import 'package:flutter/foundation.dart';

/// TikTok-style in-flight post while upload/create runs in the background.
class PendingPostUpload {
  PendingPostUpload({
    required this.id,
    this.coverFile,
    DateTime? createdAt,
    this.progress = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final File? coverFile;
  final DateTime createdAt;

  /// 0.0 – 1.0 from Dio [onSendProgress] (and post-create phase).
  double progress;
}

/// App-wide pending uploads shown on the profile grid first cell(s).
class PendingPostUploads extends ChangeNotifier {
  PendingPostUploads._();

  static final PendingPostUploads instance = PendingPostUploads._();

  final List<PendingPostUpload> _items = [];

  List<PendingPostUpload> get items => List.unmodifiable(_items);

  bool get hasPending => _items.isNotEmpty;

  String start({File? coverFile}) {
    final id = 'pending_${DateTime.now().millisecondsSinceEpoch}';
    _items.insert(
      0,
      PendingPostUpload(id: id, coverFile: coverFile, progress: 0),
    );
    notifyListeners();
    return id;
  }

  /// Updates Dio upload progress for [id] (or the latest pending item).
  /// Only notifies when the displayed percent changes (avoids spam rebuilds).
  void updateProgress(double progress, {String? id}) {
    if (_items.isEmpty) return;
    PendingPostUpload? item;
    if (id == null) {
      item = _items.first;
    } else {
      for (final e in _items) {
        if (e.id == id) {
          item = e;
          break;
        }
      }
    }
    if (item == null) return;

    final next = progress.clamp(0.0, 1.0);
    final oldPct = (item.progress * 100).floor();
    final newPct = (next * 100).floor();
    if (oldPct == newPct && item.progress > 0 && next < 1) return;

    item.progress = next;
    notifyListeners();
  }

  void complete([String? id]) {
    if (_items.isEmpty) return;
    if (id == null) {
      _items.clear();
    } else {
      _items.removeWhere((e) => e.id == id);
    }
    notifyListeners();
  }

  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
  }
}
