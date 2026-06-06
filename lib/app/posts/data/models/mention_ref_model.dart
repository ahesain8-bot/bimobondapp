import 'package:bimobondapp/app/posts/domain/entities/mention_ref_entity.dart';

class MentionRefModel extends MentionRefEntity {
  const MentionRefModel({
    required super.userId,
    super.username,
  });

  factory MentionRefModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    String? username;
    var userId = json['userId']?.toString() ?? '';
    if (user is Map) {
      final userMap = Map<String, dynamic>.from(user);
      userId = userId.isNotEmpty
          ? userId
          : userMap['id']?.toString() ?? '';
      username = userMap['username']?.toString();
    }
    username ??= json['username']?.toString();
    return MentionRefModel(userId: userId, username: username);
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        if (username != null) 'username': username,
      };

  static List<MentionRefModel> listFromJson(dynamic raw) {
    if (raw is! List) return const [];
    final out = <MentionRefModel>[];
    for (final entry in raw) {
      if (entry is Map<String, dynamic>) {
        final model = MentionRefModel.fromJson(entry);
        if (model.userId.isNotEmpty) out.add(model);
      } else if (entry is Map) {
        final model = MentionRefModel.fromJson(Map<String, dynamic>.from(entry));
        if (model.userId.isNotEmpty) out.add(model);
      } else {
        final userId = entry?.toString() ?? '';
        if (userId.isNotEmpty) {
          out.add(MentionRefModel(userId: userId));
        }
      }
    }
    return out;
  }
}
