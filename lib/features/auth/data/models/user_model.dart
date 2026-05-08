import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String id;
  final String? phoneNumber;
  final String? email;
  final String? firstName;
  final String? lastName;
  final DateTime? birthDate;
  final String? city;
  final List<String> roles;
  final String kycStatus;
  final String status;
  final int totalTrips;
  final int totalShipments;
  final bool isProAccount;
  final String? companyName;
  final String? siret;
  final String stripeAccountStatus;
  final DateTime? deletionRequestedAt;

  const UserModel({
    required this.id,
    this.phoneNumber,
    this.email,
    this.firstName,
    this.lastName,
    this.birthDate,
    this.city,
    required this.roles,
    required this.kycStatus,
    required this.status,
    this.totalTrips = 0,
    this.totalShipments = 0,
    this.isProAccount = false,
    this.companyName,
    this.siret,
    this.stripeAccountStatus = 'NOT_CREATED',
    this.deletionRequestedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        phoneNumber: json['phoneNumber'] as String?,
        email: json['email'] as String?,
        firstName: json['firstName'] as String?,
        lastName: json['lastName'] as String?,
        birthDate: json['birthDate'] != null
            ? DateTime.tryParse(json['birthDate'] as String)
            : null,
        city: json['city'] as String?,
        roles: List<String>.from(json['roles'] as List? ?? []),
        kycStatus: json['kycStatus'] as String? ?? 'NOT_STARTED',
        status: json['status'] as String? ?? 'ACTIVE',
        totalTrips: (json['totalTrips'] as num?)?.toInt() ?? 0,
        totalShipments: (json['totalShipments'] as num?)?.toInt() ?? 0,
        isProAccount: json['isProAccount'] as bool? ?? false,
        companyName: json['companyName'] as String?,
        siret: json['siret'] as String?,
        stripeAccountStatus:
            json['stripeAccountStatus'] as String? ?? 'NOT_CREATED',
        deletionRequestedAt: json['deletionRequestedAt'] != null
            ? DateTime.tryParse(json['deletionRequestedAt'] as String)
            : null,
      );

  String get displayName {
    final parts = [firstName, lastName]
        .where((p) => p != null && p.isNotEmpty)
        .join(' ');
    if (parts.isNotEmpty) return parts;
    if (phoneNumber != null && phoneNumber!.isNotEmpty) return phoneNumber!;
    if (email != null && email!.isNotEmpty) return email!;
    return 'Utilisateur';
  }

  String get initials {
    if ((firstName?.isNotEmpty ?? false) && (lastName?.isNotEmpty ?? false)) {
      return '${firstName![0]}${lastName![0]}'.toUpperCase();
    }
    if (firstName?.isNotEmpty ?? false) return firstName![0].toUpperCase();
    if (lastName?.isNotEmpty ?? false) return lastName![0].toUpperCase();
    if (email?.isNotEmpty ?? false) return email![0].toUpperCase();
    if (phoneNumber?.isNotEmpty ?? false) {
      final digits = phoneNumber!.replaceAll(RegExp(r'[^\d]'), '');
      if (digits.length >= 2) return digits.substring(digits.length - 2);
      return digits;
    }
    return '?';
  }

  int? get age {
    if (birthDate == null) return null;
    final now = DateTime.now();
    int a = now.year - birthDate!.year;
    if (now.month < birthDate!.month ||
        (now.month == birthDate!.month && now.day < birthDate!.day)) {
      a--;
    }
    return a;
  }

  bool get isProfileComplete {
    final hasName =
        (firstName?.isNotEmpty ?? false) || (lastName?.isNotEmpty ?? false);
    return hasName && birthDate != null && (city?.isNotEmpty ?? false);
  }

  // Number of required profile fields completed (max = profileTotalSteps).
  int get profileCompletionSteps {
    int steps = 0;
    if ((firstName?.isNotEmpty ?? false) || (lastName?.isNotEmpty ?? false)) {
      steps++;
    }
    if (birthDate != null) steps++;
    if (city?.isNotEmpty ?? false) steps++;
    return steps;
  }

  static const int profileTotalSteps = 3;

  bool get isKycVerified => kycStatus == 'VERIFIED';
  bool get isSender => roles.contains('SENDER');
  bool get isTraveler => roles.contains('TRAVELER');
  bool get isPendingDeletion => status == 'PENDING_DELETION';

  @override
  List<Object?> get props => [
        id,
        phoneNumber,
        email,
        firstName,
        lastName,
        birthDate,
        city,
        roles,
        kycStatus,
        status,
        totalTrips,
        totalShipments,
        isProAccount,
        companyName,
        siret,
        stripeAccountStatus,
        deletionRequestedAt,
      ];
}
