import 'package:equatable/equatable.dart';

/// Result of POST /posts/:id/share.
class PostShareResult extends Equatable {
  const PostShareResult({
    required this.postId,
    required this.channel,
    this.title,
    this.description,
    this.thumbnailUrl,
    this.shareUrl,
    this.deepLink,
    this.shareCount,
  });

  final String postId;
  final String channel;
  final String? title;
  final String? description;
  final String? thumbnailUrl;
  final String? shareUrl;
  final String? deepLink;
  final int? shareCount;

  factory PostShareResult.fromJson(Map<String, dynamic> json) {
    return PostShareResult(
      postId: json['postId']?.toString() ?? '',
      channel: json['channel']?.toString() ?? 'EXTERNAL',
      title: json['title']?.toString(),
      description: json['description']?.toString(),
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      shareUrl: json['shareUrl']?.toString(),
      deepLink: json['deepLink']?.toString(),
      shareCount: json['shareCount'] is num
          ? (json['shareCount'] as num).toInt()
          : null,
    );
  }

  @override
  List<Object?> get props => [
    postId,
    channel,
    title,
    description,
    thumbnailUrl,
    shareUrl,
    deepLink,
    shareCount,
  ];
}
