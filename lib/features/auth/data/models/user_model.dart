import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String id;

  /// Identifiant public généré par le serveur à la création du compte
  /// (« user » + horodatage). Sert de nom de repli quand [firstName] est vide.
  ///
  /// Nullable uniquement pour tolérer un cache Hive écrit avant son introduction :
  /// le serveur le renvoie toujours.
  final String? username;
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
  final String? bio;
  final String? avatarUrl;
  final List<String> languages;
  final String? transportMode;
  final double? averageRating;

  const UserModel({
    required this.id,
    this.username,
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
    this.bio,
    this.avatarUrl,
    this.languages = const [],
    this.transportMode,
    this.averageRating,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] as String,
    username: json['username'] as String?,
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
    bio: json['bio'] as String?,
    avatarUrl: json['avatarUrl'] as String?,
    languages:
        (json['languages'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        const [],
    transportMode: json['transportMode'] as String?,
    averageRating: (json['averageRating'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'phoneNumber': phoneNumber,
    'email': email,
    'firstName': firstName,
    'lastName': lastName,
    'birthDate': birthDate?.toIso8601String(),
    'city': city,
    'roles': roles,
    'kycStatus': kycStatus,
    'status': status,
    'totalTrips': totalTrips,
    'totalShipments': totalShipments,
    'isProAccount': isProAccount,
    'companyName': companyName,
    'siret': siret,
    'stripeAccountStatus': stripeAccountStatus,
    'deletionRequestedAt': deletionRequestedAt?.toIso8601String(),
    'bio': bio,
    'avatarUrl': avatarUrl,
    'languages': languages,
    'transportMode': transportMode,
    'averageRating': averageRating,
  };

  UserModel copyWith({
    String? id,
    String? username,
    String? phoneNumber,
    String? email,
    String? firstName,
    String? lastName,
    DateTime? birthDate,
    String? city,
    List<String>? roles,
    String? kycStatus,
    String? status,
    int? totalTrips,
    int? totalShipments,
    bool? isProAccount,
    String? companyName,
    String? siret,
    String? stripeAccountStatus,
    DateTime? deletionRequestedAt,
    String? bio,
    String? avatarUrl,
    List<String>? languages,
    String? transportMode,
    double? averageRating,
  }) => UserModel(
    id: id ?? this.id,
    username: username ?? this.username,
    phoneNumber: phoneNumber ?? this.phoneNumber,
    email: email ?? this.email,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    birthDate: birthDate ?? this.birthDate,
    city: city ?? this.city,
    roles: roles ?? this.roles,
    kycStatus: kycStatus ?? this.kycStatus,
    status: status ?? this.status,
    totalTrips: totalTrips ?? this.totalTrips,
    totalShipments: totalShipments ?? this.totalShipments,
    isProAccount: isProAccount ?? this.isProAccount,
    companyName: companyName ?? this.companyName,
    siret: siret ?? this.siret,
    stripeAccountStatus: stripeAccountStatus ?? this.stripeAccountStatus,
    deletionRequestedAt: deletionRequestedAt ?? this.deletionRequestedAt,
    bio: bio ?? this.bio,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    languages: languages ?? this.languages,
    transportMode: transportMode ?? this.transportMode,
    averageRating: averageRating ?? this.averageRating,
  );

  /// Nom affiché : prénom et nom si renseignés, sinon le [username] du compte.
  ///
  /// Ne retombe volontairement ni sur le numéro de téléphone ni sur l'email. C'était le
  /// comportement précédent, et il affichait une coordonnée personnelle comme nom, ce que
  /// le réglage « Masquer mon numéro » est censé interdire. Le serveur garantit un
  /// [username] non vide depuis la migration V183.
  String get displayName {
    final parts = [
      firstName,
      lastName,
    ].where((p) => p != null && p.isNotEmpty).join(' ');
    if (parts.isNotEmpty) return parts;
    if (username != null && username!.isNotEmpty) return username!;
    return 'Utilisateur';
  }

  String get initials {
    if ((firstName?.isNotEmpty ?? false) && (lastName?.isNotEmpty ?? false)) {
      return '${firstName![0]}${lastName![0]}'.toUpperCase();
    }
    if (firstName?.isNotEmpty ?? false) return firstName![0].toUpperCase();
    if (lastName?.isNotEmpty ?? false) return lastName![0].toUpperCase();
    // Les deux derniers chiffres du username : ils distinguent deux comptes sans nom,
    // là où le « U » de « user » les rendrait identiques.
    if (username != null && username!.length >= 2) {
      return username!.substring(username!.length - 2);
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

  // 8 champs d'identité : photo, prénom, nom, email, téléphone, date de
  // naissance, ville, à propos. Reflète tout ce que « Modifier le profil »
  // permet de renseigner (hors langues/mode de transport, des préférences
  // plutôt que de l'identité).
  //
  // [countPhone] : tant que le SMS OTP backend n'est pas confirmé
  // (`smsAuthEnabledListenable`), personne ne peut ajouter/vérifier de
  // numéro — l'appelant doit alors passer `false` pour retomber sur 7
  // champs, sans quoi le profil ne pourrait jamais atteindre 100 %.
  bool isProfileComplete({bool countPhone = true}) =>
      profileCompletionSteps(countPhone: countPhone) >=
      profileTotalSteps(countPhone: countPhone);

  // Nombre de champs d'identité renseignés (max = profileTotalSteps).
  int profileCompletionSteps({bool countPhone = true}) {
    int steps = 0;
    if (avatarUrl?.isNotEmpty ?? false) steps++;
    if (firstName?.isNotEmpty ?? false) steps++;
    if (lastName?.isNotEmpty ?? false) steps++;
    if (email?.isNotEmpty ?? false) steps++;
    if (countPhone && (phoneNumber?.isNotEmpty ?? false)) steps++;
    if (birthDate != null) steps++;
    if (city?.isNotEmpty ?? false) steps++;
    if (bio?.isNotEmpty ?? false) steps++;
    return steps;
  }

  static int profileTotalSteps({bool countPhone = true}) => countPhone ? 8 : 7;

  bool get isKycVerified => kycStatus == 'VERIFIED';
  bool get isSender => roles.contains('SENDER');
  bool get isTraveler => roles.contains('TRAVELER');
  bool get isPendingDeletion => status == 'PENDING_DELETION';

  @override
  List<Object?> get props => [
    id,
    username,
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
    bio,
    avatarUrl,
    languages,
    transportMode,
    averageRating,
  ];
}
