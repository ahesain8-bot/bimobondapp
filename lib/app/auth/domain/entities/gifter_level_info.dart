import 'package:equatable/equatable.dart';

class GifterLevelInfo extends Equatable {
  final int level;
  final int currentXp;
  final int nextLevelXp;
  final num progressPercentage;

  const GifterLevelInfo({
    required this.level,
    required this.currentXp,
    required this.nextLevelXp,
    required this.progressPercentage,
  });

  factory GifterLevelInfo.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v, int fallback) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    num parseNum(dynamic v, num fallback) {
      if (v is num) return v;
      if (v is String) return num.tryParse(v) ?? fallback;
      return fallback;
    }

    return GifterLevelInfo(
      level: parseInt(json['level'], 1),
      currentXp: parseInt(json['currentXp'], 0),
      nextLevelXp: parseInt(json['nextLevelXp'], 100),
      progressPercentage: parseNum(json['progressPercentage'], 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'level': level,
      'currentXp': currentXp,
      'nextLevelXp': nextLevelXp,
      'progressPercentage': progressPercentage,
    };
  }

  @override
  List<Object?> get props => [level, currentXp, nextLevelXp, progressPercentage];
}
