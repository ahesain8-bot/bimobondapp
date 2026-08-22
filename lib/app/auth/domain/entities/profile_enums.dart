import 'package:equatable/equatable.dart';

enum AccountType {
  personal,
  creator,
  business;

  static AccountType fromString(String? value) {
    if (value == null) return AccountType.personal;
    switch (value.toUpperCase()) {
      case 'CREATOR':
        return AccountType.creator;
      case 'BUSINESS':
        return AccountType.business;
      default:
        return AccountType.personal;
    }
  }

  String toUppercaseString() => name.toUpperCase();
}

enum VerificationBadge {
  none,
  email,
  creator,
  official;

  static VerificationBadge fromString(String? value) {
    if (value == null) return VerificationBadge.none;
    switch (value.toUpperCase()) {
      case 'EMAIL':
        return VerificationBadge.email;
      case 'CREATOR':
        return VerificationBadge.creator;
      case 'OFFICIAL':
        return VerificationBadge.official;
      default:
        return VerificationBadge.none;
    }
  }

  String toUppercaseString() => name.toUpperCase();
}

class ProfileLinkEntity extends Equatable {
  final String? label;
  final String url;
  final int sortOrder;

  const ProfileLinkEntity({
    this.label,
    required this.url,
    this.sortOrder = 0,
  });

  factory ProfileLinkEntity.fromJson(Map<String, dynamic> json) {
    return ProfileLinkEntity(
      label: json['label']?.toString(),
      url: json['url']?.toString() ?? '',
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (label != null) 'label': label,
      'url': url,
      'sortOrder': sortOrder,
    };
  }

  @override
  List<Object?> get props => [label, url, sortOrder];
}
