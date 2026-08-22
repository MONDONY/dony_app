import 'package:dony/core/urgency/dony_urgency.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:json_annotation/json_annotation.dart';

part 'announcement_model.g.dart';

/// Représente un article d'une grille de prix (mode MIXED).
/// Ne fait pas partie du modèle généré — pas de @JsonSerializable car la
/// classe est simple et n'est pas un `part` du fichier d'annotation.
class AnnouncementGridItemModel {
  final String id;
  final String label;

  /// Net voyageur de cet article de grille. `null` pour une session
  /// anonyme : masqué exactement comme `AnnouncementModel.pricePerKg`
  /// (`GuestSession.travelerNetOrNull` appelé depuis `PriceGridService`
  /// côté backend). `unitPriceDisplay` reste toujours servi.
  final double? unitPriceNet;
  final double unitPriceDisplay;

  const AnnouncementGridItemModel({
    required this.id,
    required this.label,
    this.unitPriceNet,
    required this.unitPriceDisplay,
  });

  factory AnnouncementGridItemModel.fromJson(Map<String, dynamic> json) =>
      AnnouncementGridItemModel(
        id: json['id'] as String,
        label: json['label'] as String,
        unitPriceNet: (json['unitPriceNet'] as num?)?.toDouble(),
        unitPriceDisplay: (json['unitPriceDisplay'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'unitPriceNet': unitPriceNet,
    'unitPriceDisplay': unitPriceDisplay,
  };
}

@JsonSerializable()
class TravelerProfile {
  final String id;
  final String? displayName;
  final String? phoneNumber;
  final double? averageRating;
  final int? totalTrips;
  final bool kiloPro;
  final bool isProAccount;
  final bool kycVerified;

  /// URL de l'avatar du voyageur (nullable, fourni par le backend).
  final String? avatarUrl;

  /// Ce voyageur accepte les demandes d'expéditeurs non vérifiés (il a désactivé
  /// « profils vérifiés uniquement »). Par défaut false, ce qui correspond au
  /// réglage par défaut des comptes et au cas d'un backend plus ancien.
  final bool acceptsUnverified;

  const TravelerProfile({
    required this.id,
    this.displayName,
    this.phoneNumber,
    this.averageRating,
    this.totalTrips,
    this.kiloPro = false,
    this.isProAccount = false,
    this.kycVerified = false,
    this.avatarUrl,
    this.acceptsUnverified = false,
  });

  factory TravelerProfile.fromJson(Map<String, dynamic> json) =>
      _$TravelerProfileFromJson(json);

  Map<String, dynamic> toJson() => _$TravelerProfileToJson(this);

  /// Nom à afficher.
  ///
  /// Le serveur renvoie désormais toujours un [displayName] non vide : « Prénom N. » ou, à
  /// défaut de prénom, le username du compte. Le repli sur 'Voyageur' ne couvre plus qu'une
  /// réponse tronquée ou un cache antérieur.
  ///
  /// Le numéro de téléphone n'est plus un repli : il n'a jamais figuré dans
  /// TravelerProfileDto côté serveur, et l'afficher comme nom contredisait le réglage
  /// « Masquer mon numéro ».
  String get resolvedName {
    if (displayName != null && displayName!.isNotEmpty) return displayName!;
    return 'Voyageur';
  }

  /// Initiales, dérivées du seul nom affiché.
  String get resolvedInitials {
    if (displayName != null && displayName!.isNotEmpty) {
      final parts = displayName!.trim().split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return displayName![0].toUpperCase();
    }
    return '?';
  }
}

@JsonSerializable()
class AnnouncementModel {
  final String id;
  final String travelerId;
  final String departureCity;
  final String arrivalCity;

  /// Code pays ISO-2 (ex: "US") du départ / arrivée. Fourni par le backend.
  final String? departureCountryCode;
  final String? arrivalCountryCode;

  /// Drapeau emoji (ex: "🇺🇸") résolu par le backend depuis le code pays.
  final String? departureFlag;
  final String? arrivalFlag;
  final DateTime departureDate;
  // "HH:mm" format, null if not set
  final String? departureTime;
  final String? arrivalTime;
  final AddressData? pickupAddress;
  final AddressData? deliveryAddress;
  final double availableKg;
  final double totalKg;

  /// Net voyageur. `null` pour une session anonyme : le backend masque le
  /// net aux invités (il révélerait le taux de commission, parfois négocié
  /// par voyageur). Utiliser [pricePerKgDisplay] pour l'affichage côté
  /// expéditeur, qui reste fourni.
  final double? pricePerKg;

  /// Prix au kilo affiché à l'EXPÉDITEUR = `pricePerKg` (net voyageur) + commission Yadony.
  /// Fourni par le backend (symétrique de `unitPriceDisplay` du mode MIXED) ; null si
  /// absent (anciens payloads / mode MIXED). Utiliser l'extension `senderPricePerKg`
  /// qui retombe sur un calcul net×multiplicateur le cas échéant.
  final double? pricePerKgDisplay;
  @JsonKey(fromJson: transportModeFromWire, toJson: _transportModeToWireOrNull)
  final TransportMode? transportMode;
  final String status;
  final int? bidsCount;

  /// Nombre de demandes (bids) en attente d'acceptation pour ce trajet.
  /// Exposé par `GET /announcements/my`. `0` si absent (ex: endpoint search).
  @JsonKey(defaultValue: 0)
  final int pendingBidCount;

  /// Nombre de demandes (bids) acceptées / colis confirmés pour ce trajet.
  /// Exposé par `GET /announcements/my`. `0` si absent.
  @JsonKey(defaultValue: 0)
  final int confirmedParcelCount;
  final TravelerProfile? traveler;
  final String? description;

  /// Instructions d'arrivée laissées par le voyageur pour l'expéditeur (ex :
  /// point de rendez-vous précis, consignes de retrait). Facultatif.
  final String? arrivalInstructions;
  final List<String>? acceptedContentTypes;
  final List<String>? refusedTypes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Set<BidPaymentMethod> acceptedPaymentMethods;
  final String? capacityUnit;
  final String pricingMode;

  /// Articles disponibles dans la grille de prix (mode MIXED uniquement).
  /// Vide pour le mode KG.
  @JsonKey(fromJson: _gridItemsFromJson, toJson: _gridItemsToJson)
  final List<AnnouncementGridItemModel> priceGridItems;

  /// Capacité réservée à la négociation (trajet dédié). `0` pour un trajet
  /// public classique. `> 0` ⇒ trajet dédié (cf. [isDedicated]).
  final double reservedKg;

  /// La négociation liée a été payée → le voyageur peut ouvrir le surplus.
  final bool surplusEligible;

  /// Le surplus a déjà été ouvert au public (action définitive, non répétable).
  final bool surplusPublished;

  /// Date limite de dépôt : jusqu'à quand les expéditeurs peuvent remettre
  /// leurs colis au voyageur. Définie à la création ; null pour les anciennes
  /// annonces.
  final DateTime? handoverDeadline;

  /// Indique si ce trajet est dans les favoris de l'utilisateur courant.
  /// Fourni par le backend sur les endpoints de feed ; `false` par défaut.
  @JsonKey(defaultValue: false)
  final bool isFavorite;

  /// Urgence calculée côté backend (`dony.urgency.threshold-days`). Source de
  /// vérité quand présente ; `null` pour les anciens payloads (repli local
  /// via [isUrgent]).
  final bool? urgent;

  /// Devise du trajet, figée à la création. `EUR` par défaut pour les
  /// anciens payloads sans ce champ.
  @JsonKey(defaultValue: 'EUR')
  final String currency;

  /// Le voyageur accepte les propositions de prix de l'expéditeur.
  /// `false` par défaut pour les anciens payloads : un trajet publié avant
  /// cette fonctionnalité reste à prix ferme.
  @JsonKey(defaultValue: false)
  final bool negotiable;

  /// Équivalent de [pricePerKg] converti par le SERVEUR dans la devise du
  /// lecteur courant (`ExchangeRateService.convert`). `null` quand le
  /// backend n'a rien à convertir (lecteur anonyme, devise déjà identique,
  /// ancien payload). Jamais recalculé côté client : le taux vit en base.
  final double? convertedPricePerKg;

  /// Devise cible de [convertedPricePerKg], celle du lecteur. `null` en
  /// même temps que [convertedPricePerKg].
  final String? convertedCurrency;

  /// Prix au kilo **affiché à l'expéditeur** ([pricePerKgDisplay], le BRUT),
  /// converti par le SERVEUR dans la devise du lecteur courant. Ajouté (PR
  /// #219) pour compenser le masquage de [pricePerKg] (le net) aux lecteurs
  /// anonymes : sans lui, un invité perdait toute conversion de devise sur le
  /// prix au kilo. Servi à tous les lecteurs, jamais retiré à un inscrit.
  /// `null` quand le backend n'a rien à convertir (devise déjà identique,
  /// ancien payload, ou trajet sans tarif au kilo exploitable).
  final double? pricePerKgDisplayConverted;

  const AnnouncementModel({
    required this.id,
    required this.travelerId,
    required this.departureCity,
    required this.arrivalCity,
    this.departureCountryCode,
    this.arrivalCountryCode,
    this.departureFlag,
    this.arrivalFlag,
    required this.departureDate,
    this.departureTime,
    this.arrivalTime,
    this.pickupAddress,
    this.deliveryAddress,
    required this.availableKg,
    required this.totalKg,
    this.pricePerKg,
    this.pricePerKgDisplay,
    this.transportMode,
    required this.status,
    this.bidsCount,
    this.pendingBidCount = 0,
    this.confirmedParcelCount = 0,
    this.traveler,
    this.description,
    this.arrivalInstructions,
    this.acceptedContentTypes,
    this.refusedTypes,
    required this.createdAt,
    required this.updatedAt,
    this.acceptedPaymentMethods = const {BidPaymentMethod.stripe},
    this.capacityUnit,
    this.pricingMode = 'KG',
    this.priceGridItems = const [],
    this.reservedKg = 0,
    this.surplusEligible = false,
    this.surplusPublished = false,
    this.handoverDeadline,
    this.isFavorite = false,
    this.urgent,
    this.currency = 'EUR',
    this.negotiable = false,
    this.convertedPricePerKg,
    this.convertedCurrency,
    this.pricePerKgDisplayConverted,
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) =>
      _$AnnouncementModelFromJson(json);

  Map<String, dynamic> toJson() => _$AnnouncementModelToJson(this);

  /// Trajet dédié : une part de la capacité est réservée à une négociation.
  bool get isDedicated => reservedKg > 0;

  /// Le voyageur peut ouvrir le surplus : la négo est payée mais le surplus
  /// n'a pas encore été publié.
  bool get canOpenSurplus => surplusEligible && !surplusPublished;

  /// Trajet vendu au kilo sans capacité fixe totale (mode "kilo libre").
  /// Toujours vrai quand `capacityUnit == 'KG_FREE'`.
  bool get isKgFree => capacityUnit == 'KG_FREE';

  /// Urgence effective : la valeur backend prime ; repli sur le calcul local
  /// depuis [departureDate] uniquement si absente (ancien backend).
  bool get isUrgent => urgent ?? isUrgentDate(departureDate);
}

String? _transportModeToWireOrNull(TransportMode? mode) =>
    mode == null ? null : transportModeToWire(mode);

List<AnnouncementGridItemModel> _gridItemsFromJson(List<dynamic>? json) =>
    (json ?? [])
        .map(
          (e) => AnnouncementGridItemModel.fromJson(e as Map<String, dynamic>),
        )
        .toList();

List<Map<String, dynamic>> _gridItemsToJson(
  List<AnnouncementGridItemModel> items,
) => items.map((e) => e.toJson()).toList();
