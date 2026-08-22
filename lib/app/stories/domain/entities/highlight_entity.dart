import 'package:bimobondapp/app/stories/domain/entities/story_entities.dart';
import 'package:equatable/equatable.dart';

class HighlightEntity extends Equatable {
  const HighlightEntity({
    required this.id,
    required this.title,
    this.coverUrl,
    this.sortOrder = 0,
    this.stories = const [],
    this.createdAt,
  });

  final String id;
  final String title;
  final String? coverUrl;
  final int sortOrder;
  final List<StoryEntity> stories;
  final DateTime? createdAt;

  factory HighlightEntity.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['_id'];
    final rawTitle = json['title'] ?? json['name'] ?? 'Highlight';
    final rawCover = json['coverUrl'] ?? json['cover_url'] ?? json['cover'] ?? json['thumbnailUrl'];

    List<StoryEntity> items = [];
    final storiesRaw = json['stories'] ?? json['items'] ?? json['data'];
    if (storiesRaw is List) {
      items = storiesRaw
          .whereType<Map>()
          .map((m) {
            final storyMap = Map<String, dynamic>.from(m['story'] ?? m);
            return StoryEntity.fromJson(storyMap);
          })
          .toList();
    }

    return HighlightEntity(
      id: rawId?.toString() ?? '',
      title: rawTitle?.toString() ?? 'Highlight',
      coverUrl: rawCover?.toString(),
      sortOrder: json['sortOrder'] is int ? json['sortOrder'] as int : 0,
      stories: items,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }

  @override
  List<Object?> get props => [id, title, coverUrl, sortOrder, stories, createdAt];
}
