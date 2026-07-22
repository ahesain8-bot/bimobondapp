import 'package:equatable/equatable.dart';

class SellerVerificationRecordEntity extends Equatable {
  const SellerVerificationRecordEntity({
    required this.id,
    required this.status,
    this.nationalIdNumber,
    this.passportFrontUrl,
    this.rejectionReason,
    this.submittedAt,
    this.reviewedAt,
  });

  final String id;
  final String status;
  final String? nationalIdNumber;
  final String? passportFrontUrl;
  final String? rejectionReason;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;

  factory SellerVerificationRecordEntity.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) => DateTime.tryParse(v?.toString() ?? '');
    return SellerVerificationRecordEntity(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      nationalIdNumber: json['nationalIdNumber']?.toString(),
      passportFrontUrl: json['passportFrontUrl']?.toString(),
      rejectionReason: json['rejectionReason']?.toString(),
      submittedAt: parseDate(json['submittedAt']),
      reviewedAt: parseDate(json['reviewedAt']),
    );
  }

  @override
  List<Object?> get props => [
    id,
    status,
    nationalIdNumber,
    passportFrontUrl,
    rejectionReason,
    submittedAt,
    reviewedAt,
  ];
}

class SellerVerificationStatusEntity extends Equatable {
  const SellerVerificationStatusEntity({
    required this.canCreateAuction,
    required this.status,
    this.message,
    this.rejectionReason,
    this.submittedAt,
    this.reviewedAt,
    this.verification,
  });

  final bool canCreateAuction;
  final String status;
  final String? message;
  final String? rejectionReason;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final SellerVerificationRecordEntity? verification;

  bool get isNotSubmitted => status.toUpperCase() == 'NOT_SUBMITTED';
  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isRejected => status.toUpperCase() == 'REJECTED';
  bool get isApproved => status.toUpperCase() == 'APPROVED';
  bool get canSubmitForm => isNotSubmitted || isRejected;

  factory SellerVerificationStatusEntity.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    final verificationRaw = data['verification'];
    return SellerVerificationStatusEntity(
      canCreateAuction: data['canCreateAuction'] == true,
      status: data['status']?.toString() ?? 'NOT_SUBMITTED',
      message: data['message']?.toString(),
      rejectionReason: data['rejectionReason']?.toString(),
      submittedAt: DateTime.tryParse(data['submittedAt']?.toString() ?? ''),
      reviewedAt: DateTime.tryParse(data['reviewedAt']?.toString() ?? ''),
      verification: verificationRaw is Map
          ? SellerVerificationRecordEntity.fromJson(
              Map<String, dynamic>.from(verificationRaw),
            )
          : null,
    );
  }

  @override
  List<Object?> get props => [
    canCreateAuction,
    status,
    message,
    rejectionReason,
    submittedAt,
    reviewedAt,
    verification,
  ];
}

/// Minimal submit: national ID number + passport photo only.
class SubmitSellerVerificationInput extends Equatable {
  const SubmitSellerVerificationInput({
    required this.nationalIdNumber,
    required this.passportFrontUrl,
  });

  final String nationalIdNumber;
  final String passportFrontUrl;

  Map<String, dynamic> toJson() => {
    'nationalIdNumber': nationalIdNumber,
    'passportFrontUrl': passportFrontUrl,
  };

  @override
  List<Object?> get props => [nationalIdNumber, passportFrontUrl];
}
