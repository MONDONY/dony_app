import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String id;
  final String? phoneNumber;
  final String? email;
  final List<String> roles;
  final String kycStatus;
  final String status;

  const UserModel({
    required this.id,
    this.phoneNumber,
    this.email,
    required this.roles,
    required this.kycStatus,
    required this.status,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        phoneNumber: json['phoneNumber'] as String?,
        email: json['email'] as String?,
        roles: List<String>.from(json['roles'] as List? ?? []),
        kycStatus: json['kycStatus'] as String? ?? 'PENDING',
        status: json['status'] as String? ?? 'ACTIVE',
      );

  bool get isKycVerified => kycStatus == 'VERIFIED';
  bool get isSender => roles.contains('SENDER');
  bool get isTraveler => roles.contains('TRAVELER');

  @override
  List<Object?> get props => [id, phoneNumber, email, roles, kycStatus, status];
}
