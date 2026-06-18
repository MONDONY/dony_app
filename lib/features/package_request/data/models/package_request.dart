import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/data/models/content_category.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:equatable/equatable.dart';

enum PackageRequestStatus {
  open('OPEN'),
  negotiating('NEGOTIATING'),
  accepted('ACCEPTED'),
  expired('EXPIRED'),
  cancelled('CANCELLED'),
  completed('COMPLETED');

  final String wireName;
  const PackageRequestStatus(this.wireName);

  static PackageRequestStatus fromJson(String s) =>
      PackageRequestStatus.values.firstWhere((e) => e.wireName == s);
}

class PackageRequest extends Equatable {
  const PackageRequest({
    required this.id,
    required this.senderId,
    required this.departureCity,
    required this.arrivalCity,
    required this.desiredDate,
    required this.dateToleranceDays,
    required this.weightKg,
    required this.parcelSize,
    required this.transportMode,
    required this.contentCategory,
    this.description,
    this.targetPriceEur,
    this.photoUrl,
    this.photoUrls = const [],
    this.photoKeys = const [],
    this.pickupNeighborhood,
    this.deliveryNeighborhood,
    required this.status,
    required this.createdAt,
    this.negotiable = true,
    this.acceptedPaymentMethods = const {},
    this.viewerThreadId,
    this.viewerThreadStatus,
  });

  final String id;
  final String senderId;
  final String departureCity;
  final String arrivalCity;
  final DateTime desiredDate;
  final int dateToleranceDays;
  final double weightKg;
  final ParcelSize parcelSize;
  final TransportMode transportMode;
  final ContentCategory contentCategory;
  final String? description;
  final double? targetPriceEur;
  final String? photoUrl;

  /// Toutes les photos colis présignées (max 4, ordonnées). Vide si aucune.
  final List<String> photoUrls;

  /// Clés S3 brutes des photos (parallèle à [photoUrls], même ordre). Permet
  /// de pré-charger les photos en mode édition sans les perdre. Vide si aucune.
  final List<String> photoKeys;

  final String? pickupNeighborhood;
  final String? deliveryNeighborhood;
  final PackageRequestStatus status;
  final DateTime createdAt;
  final bool negotiable;
  final Set<PaymentMethod> acceptedPaymentMethods;

  /// Thread de négociation ACTIF du voyageur courant sur cette demande (null sinon).
  /// Permet de basculer le CTA « Proposer mon trajet » → « Voir ma négociation ».
  final String? viewerThreadId;
  final String? viewerThreadStatus;

  factory PackageRequest.fromJson(Map<String, dynamic> json) => PackageRequest(
    id: json['id'] as String,
    senderId: json['senderId'] as String,
    departureCity: json['departureCity'] as String,
    arrivalCity: json['arrivalCity'] as String,
    desiredDate: DateTime.parse(json['desiredDate'] as String),
    dateToleranceDays: json['dateToleranceDays'] as int,
    weightKg: (json['weightKg'] as num).toDouble(),
    parcelSize: ParcelSize.fromJson(json['parcelSize'] as String),
    transportMode:
        transportModeFromWire(json['transportMode'] as String?) ??
        TransportMode.plane,
    contentCategory: ContentCategory.fromWire(
      json['contentCategory'] as String?,
    ),
    description: json['description'] as String?,
    targetPriceEur: (json['targetPriceEur'] as num?)?.toDouble(),
    photoUrl: json['photoUrl'] as String?,
    photoUrls:
        (json['photos'] as List<dynamic>?)
            ?.map((e) => (e as Map<String, dynamic>)['url'] as String)
            .toList() ??
        const [],
    photoKeys:
        (json['photos'] as List<dynamic>?)
            ?.map(
              (e) => (e as Map<String, dynamic>)['objectKey'] as String? ?? '',
            )
            .where((k) => k.isNotEmpty)
            .toList() ??
        const [],
    pickupNeighborhood: json['pickupNeighborhood'] as String?,
    deliveryNeighborhood: json['deliveryNeighborhood'] as String?,
    status: PackageRequestStatus.fromJson(json['status'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
    negotiable: json['negotiable'] as bool? ?? true,
    acceptedPaymentMethods: PaymentMethod.setFromJson(
      json['acceptedPaymentMethods'] as List<dynamic>?,
    ),
    viewerThreadId: json['viewerThreadId'] as String?,
    viewerThreadStatus: json['viewerThreadStatus'] as String?,
  );

  @override
  List<Object?> get props => [
    id,
    senderId,
    departureCity,
    arrivalCity,
    desiredDate,
    dateToleranceDays,
    weightKg,
    parcelSize,
    transportMode,
    contentCategory,
    description,
    targetPriceEur,
    photoUrl,
    photoUrls,
    photoKeys,
    pickupNeighborhood,
    deliveryNeighborhood,
    status,
    createdAt,
    negotiable,
    acceptedPaymentMethods,
    viewerThreadId,
    viewerThreadStatus,
  ];
}
