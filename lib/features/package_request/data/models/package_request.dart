import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:equatable/equatable.dart';

enum PackageRequestStatus {
  draft('DRAFT'),
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
    this.categories = const [],
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
    this.promoCode,
    this.currency = 'EUR',
    this.grossPriceEur,
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

  /// Catégories de colis (libellés libres, comme une annonce). Vide si aucune.
  final List<String> categories;

  /// 1ère catégorie pour les affichages compacts (titre, emoji). Null si vide.
  String? get primaryCategory => categories.isEmpty ? null : categories.first;
  final String? description;
  final double? targetPriceEur;

  /// Prix brut de la demande (ce que l'expéditeur paierait réellement),
  /// ajouté (PR #219) en compensation : [targetPriceEur] seul est un NET,
  /// un tarif que personne ne paie. Ne jamais afficher les deux côte à côte
  /// (révélerait le taux de commission par soustraction) : à l'affichage,
  /// préférer ce champ à [targetPriceEur] avec repli sur ce dernier si le
  /// serveur ne le sert pas encore (ancien payload/cache).
  final double? grossPriceEur;
  final String? photoUrl;

  /// Toutes les photos colis présignées (max 4, ordonnées). Vide si aucune.
  final List<String> photoUrls;

  /// Clés S3 brutes des photos (parallèle à [photoUrls], même ordre). Permet
  /// de pré-charger les photos en mode édition sans les perdre. Vide si aucune.
  final List<String> photoKeys;

  /// Photos appariées (clé S3 + URL présignée) — encapsule l'alignement par
  /// index de [photoKeys]/[photoUrls] pour la pré-charge en édition.
  List<({String key, String url})> get photos {
    final n = photoUrls.length < photoKeys.length
        ? photoUrls.length
        : photoKeys.length;
    return [for (var i = 0; i < n; i++) (key: photoKeys[i], url: photoUrls[i])];
  }

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

  /// Code promo saisi à la publication (brut, null si aucun) — pré-remplit l'édition.
  final String? promoCode;

  /// Devise de la demande, figée à la création. `EUR` par défaut pour les
  /// anciens payloads sans ce champ.
  final String currency;

  /// Parse le tableau `photos` du wire en deux listes alignées (URLs
  /// présignées + clés S3) en un seul passage.
  static (List<String>, List<String>) _photosFromJson(List<dynamic>? raw) {
    final urls = <String>[];
    final keys = <String>[];
    for (final e in raw ?? const []) {
      final m = e as Map<String, dynamic>;
      urls.add(m['url'] as String);
      keys.add(m['objectKey'] as String? ?? '');
    }
    return (urls, keys);
  }

  factory PackageRequest.fromJson(Map<String, dynamic> json) {
    final (urls, keys) = _photosFromJson(json['photos'] as List<dynamic>?);
    return PackageRequest(
      id: json['id'] as String,
      senderId: json['senderId'] as String? ?? '',
      departureCity: json['departureCity'] as String,
      arrivalCity: json['arrivalCity'] as String,
      desiredDate: DateTime.parse(json['desiredDate'] as String),
      dateToleranceDays: json['dateToleranceDays'] as int,
      weightKg: (json['weightKg'] as num).toDouble(),
      parcelSize: ParcelSize.fromJson(json['parcelSize'] as String),
      transportMode:
          transportModeFromWire(json['transportMode'] as String?) ??
          TransportMode.plane,
      categories: splitContentCategoryLabels(
        json['contentCategory'] as String?,
      ),
      description: json['description'] as String?,
      targetPriceEur: (json['targetPriceEur'] as num?)?.toDouble(),
      photoUrl: json['photoUrl'] as String?,
      photoUrls: urls,
      photoKeys: keys,
      pickupNeighborhood: json['pickupNeighborhood'] as String?,
      deliveryNeighborhood: json['deliveryNeighborhood'] as String?,
      status: PackageRequestStatus.fromJson(
        json['status'] as String? ?? 'OPEN',
      ),
      createdAt: switch (json['createdAt']) {
        final String value => DateTime.parse(value),
        _ => DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      },
      negotiable: json['negotiable'] as bool? ?? true,
      acceptedPaymentMethods: PaymentMethod.setFromJson(
        json['acceptedPaymentMethods'] as List<dynamic>?,
      ),
      viewerThreadId: json['viewerThreadId'] as String?,
      viewerThreadStatus: json['viewerThreadStatus'] as String?,
      promoCode: json['promoCode'] as String?,
      currency: json['currency'] as String? ?? 'EUR',
      grossPriceEur: (json['grossPriceEur'] as num?)?.toDouble(),
    );
  }

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
    categories,
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
    promoCode,
    currency,
    grossPriceEur,
  ];
}
