import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:equatable/equatable.dart';
import 'parcel_size.dart';
import 'payment_method.dart';

/// Lightweight item returned by the search endpoint (`GET /package-requests`).
/// Includes city-level coords (departure/arrival) for map markers and a public
/// sender profile (no PII).
class PackageRequestSearchItem extends Equatable {
  const PackageRequestSearchItem({
    required this.id,
    required this.departureCity,
    required this.arrivalCity,
    this.departureLat,
    this.departureLng,
    this.arrivalLat,
    this.arrivalLng,
    required this.desiredDate,
    required this.dateToleranceDays,
    required this.weightKg,
    required this.parcelSize,
    this.categories = const [],
    this.targetPriceEur,
    this.photoUrl,
    this.photoUrls = const [],
    this.pickupNeighborhood,
    this.deliveryNeighborhood,
    this.negotiable = true,
    this.acceptedPaymentMethods = const {},
    required this.sender,
    this.isFavorite = false,
  });

  final String id;
  final String departureCity;
  final String arrivalCity;
  final double? departureLat;
  final double? departureLng;
  final double? arrivalLat;
  final double? arrivalLng;
  final DateTime desiredDate;
  final int dateToleranceDays;
  final double weightKg;
  final ParcelSize parcelSize;
  final List<String> categories;

  /// 1ère catégorie pour les affichages compacts (titre, emoji). Null si vide.
  String? get primaryCategory => categories.isEmpty ? null : categories.first;
  final double? targetPriceEur;

  /// URL présignée de la 1ère photo (rétro-compat). Préférer [photoUrls].
  final String? photoUrl;

  /// Toutes les photos colis présignées (max 4, ordonnées). Vide si aucune.
  final List<String> photoUrls;

  final String? pickupNeighborhood;
  final String? deliveryNeighborhood;
  final bool negotiable;
  final Set<PaymentMethod> acceptedPaymentMethods;
  final SenderPublicProfile sender;

  /// Indique si cette demande est dans les favoris de l'utilisateur courant.
  /// Fourni par le backend sur les endpoints de feed ; `false` par défaut.
  final bool isFavorite;

  factory PackageRequestSearchItem.fromJson(Map<String, dynamic> json) =>
      PackageRequestSearchItem(
        id: json['id'] as String,
        departureCity: json['departureCity'] as String,
        arrivalCity: json['arrivalCity'] as String,
        departureLat: (json['departureLat'] as num?)?.toDouble(),
        departureLng: (json['departureLng'] as num?)?.toDouble(),
        arrivalLat: (json['arrivalLat'] as num?)?.toDouble(),
        arrivalLng: (json['arrivalLng'] as num?)?.toDouble(),
        desiredDate: DateTime.parse(json['desiredDate'] as String),
        dateToleranceDays: json['dateToleranceDays'] as int,
        weightKg: (json['weightKg'] as num).toDouble(),
        parcelSize: ParcelSize.fromJson(json['parcelSize'] as String),
        categories: splitContentCategoryLabels(
          json['contentCategory'] as String?,
        ),
        targetPriceEur: (json['targetPriceEur'] as num?)?.toDouble(),
        photoUrl: json['photoUrl'] as String?,
        photoUrls:
            (json['photos'] as List<dynamic>?)
                ?.map((e) => (e as Map<String, dynamic>)['url'] as String)
                .toList() ??
            const [],
        pickupNeighborhood: json['pickupNeighborhood'] as String?,
        deliveryNeighborhood: json['deliveryNeighborhood'] as String?,
        negotiable: json['negotiable'] as bool? ?? true,
        acceptedPaymentMethods: PaymentMethod.setFromJson(
          json['acceptedPaymentMethods'] as List<dynamic>?,
        ),
        sender: SenderPublicProfile.fromJson(
          json['sender'] as Map<String, dynamic>,
        ),
        isFavorite: json['isFavorite'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [
    id,
    departureCity,
    arrivalCity,
    departureLat,
    departureLng,
    arrivalLat,
    arrivalLng,
    desiredDate,
    dateToleranceDays,
    weightKg,
    parcelSize,
    categories,
    targetPriceEur,
    photoUrl,
    photoUrls,
    pickupNeighborhood,
    deliveryNeighborhood,
    negotiable,
    acceptedPaymentMethods,
    sender,
    isFavorite,
  ];
}

class SenderPublicProfile extends Equatable {
  const SenderPublicProfile({
    required this.id,
    required this.displayName,
    required this.averageRating,
    required this.totalRatings,
    required this.kycVerified,
    this.avatarUrl,
  });

  final String id;
  final String displayName;
  final double averageRating;
  final int totalRatings;
  final bool kycVerified;

  /// URL de l'avatar de l'expéditeur (nullable, fourni par le backend).
  final String? avatarUrl;

  factory SenderPublicProfile.fromJson(Map<String, dynamic> json) =>
      SenderPublicProfile(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        averageRating: (json['averageRating'] as num).toDouble(),
        totalRatings: json['totalRatings'] as int,
        kycVerified: json['kycVerified'] as bool,
        avatarUrl: json['avatarUrl'] as String?,
      );

  @override
  List<Object?> get props => [
    id,
    displayName,
    averageRating,
    totalRatings,
    kycVerified,
    avatarUrl,
  ];
}
