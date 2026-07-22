import 'package:equatable/equatable.dart';

/// Response of GET /auctions/seller-eligibility.
class AuctionSellerEligibilityEntity extends Equatable {
  const AuctionSellerEligibilityEntity({
    required this.canCreateAuction,
    required this.status,
    this.message,
    this.rejectionReason,
    this.submittedAt,
    this.reviewedAt,
  });

  final bool canCreateAuction;

  /// APPROVED | PENDING | REJECTED | NOT_SUBMITTED
  final String status;
  final String? message;
  final String? rejectionReason;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;

  factory AuctionSellerEligibilityEntity.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    return AuctionSellerEligibilityEntity(
      canCreateAuction: data['canCreateAuction'] == true,
      status: data['status']?.toString() ?? 'NOT_SUBMITTED',
      message: data['message']?.toString(),
      rejectionReason: data['rejectionReason']?.toString(),
      submittedAt: DateTime.tryParse(data['submittedAt']?.toString() ?? ''),
      reviewedAt: DateTime.tryParse(data['reviewedAt']?.toString() ?? ''),
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
      ];
}
