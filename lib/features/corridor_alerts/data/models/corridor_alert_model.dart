import 'package:dony/features/corridor_alerts/data/models/alert_direction.dart';
import 'package:dony/features/corridor_alerts/data/models/alert_notify_mode.dart';
import 'package:equatable/equatable.dart';

/// Alerte corridor du voyageur (saved search). Mappe `CorridorAlertResponse`
/// du backend (`GET /me/corridor-alerts`).
class CorridorAlertModel extends Equatable {
  const CorridorAlertModel({
    required this.id,
    required this.departureCity,
    required this.arrivalCity,
    this.departureCountryCode,
    this.arrivalCountryCode,
    this.dateFrom,
    this.dateTo,
    this.minWeightKg,
    this.contentCategories = const [],
    required this.active,
    this.matchCount = 0,
    this.newMatchCount = 0,
    this.lastSeenAt,
    required this.createdAt,
    this.direction = AlertDirection.travelerWantsPackages,
    this.notifyMode = AlertNotifyMode.instant,
    this.centerLat,
    this.centerLng,
    this.radiusKm,
    this.centerLabel,
  });

  final String id;
  final String departureCity;
  final String arrivalCity;
  final String? departureCountryCode;
  final String? arrivalCountryCode;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final double? minWeightKg;
  final List<String> contentCategories;
  final bool active;

  /// Tout ce qui matche aujourd'hui.
  final int matchCount;

  /// Ce qui est apparu depuis la dernière ouverture des correspondances
  /// (tout, si elles n'ont jamais été ouvertes). C'est le seul chiffre que
  /// l'interface met en avant : [matchCount] ne dit rien de ce qui a changé.
  final int newMatchCount;

  /// Dernière ouverture des correspondances ; `null` = jamais ouvertes.
  final DateTime? lastSeenAt;
  final DateTime createdAt;
  final AlertDirection direction;
  final AlertNotifyMode notifyMode;

  // ── Zone de remise optionnelle (alertes trajet) ──────────────────────────
  final double? centerLat;
  final double? centerLng;
  final int? radiusKm;
  final String? centerLabel;

  /// Brouillon reprenant tous les réglages : base d'un « Dupliquer ».
  CorridorAlertDraft toDraft() => CorridorAlertDraft(
    departureCity: departureCity,
    arrivalCity: arrivalCity,
    departureCountryCode: departureCountryCode,
    arrivalCountryCode: arrivalCountryCode,
    dateFrom: dateFrom,
    dateTo: dateTo,
    minWeightKg: minWeightKg,
    contentCategories: contentCategories,
    direction: direction,
    notifyMode: notifyMode,
    centerLat: centerLat,
    centerLng: centerLng,
    radiusKm: radiusKm,
    centerLabel: centerLabel,
  );

  /// True si l'alerte porte une zone de remise (centre + rayon).
  bool get hasPickupZone =>
      centerLat != null && centerLng != null && radiusKm != null;

  String get corridorLabel => '$departureCity → $arrivalCity';

  bool get hasNews => newMatchCount > 0;

  /// Fenêtre de dates dépassée : l'alerte ne peut plus rien trouver de neuf.
  /// Sans `dateTo`, une alerte est permanente.
  bool isExpiredAt(DateTime now) {
    final end = dateTo;
    if (end == null) return false;
    final today = DateTime(now.year, now.month, now.day);
    return DateTime(end.year, end.month, end.day).isBefore(today);
  }

  bool get isExpired => isExpiredAt(DateTime.now());

  factory CorridorAlertModel.fromJson(Map<String, dynamic> json) =>
      CorridorAlertModel(
        id: json['id'] as String,
        departureCity: json['departureCity'] as String,
        arrivalCity: json['arrivalCity'] as String,
        departureCountryCode: json['departureCountryCode'] as String?,
        arrivalCountryCode: json['arrivalCountryCode'] as String?,
        dateFrom: json['dateFrom'] != null
            ? DateTime.parse(json['dateFrom'] as String)
            : null,
        dateTo: json['dateTo'] != null
            ? DateTime.parse(json['dateTo'] as String)
            : null,
        minWeightKg: (json['minWeightKg'] as num?)?.toDouble(),
        contentCategories:
            (json['contentCategories'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        active: json['active'] as bool,
        matchCount: (json['matchCount'] as num?)?.toInt() ?? 0,
        newMatchCount: (json['newMatchCount'] as num?)?.toInt() ?? 0,
        lastSeenAt: json['lastSeenAt'] != null
            ? DateTime.parse(json['lastSeenAt'] as String)
            : null,
        createdAt: DateTime.parse(json['createdAt'] as String),
        direction: AlertDirection.fromWire(json['direction'] as String?),
        notifyMode: AlertNotifyMode.fromWire(json['notifyMode'] as String?),
        centerLat: (json['centerLat'] as num?)?.toDouble(),
        centerLng: (json['centerLng'] as num?)?.toDouble(),
        radiusKm: (json['radiusKm'] as num?)?.toInt(),
        centerLabel: json['centerLabel'] as String?,
      );

  CorridorAlertModel copyWith({
    bool? active,
    int? matchCount,
    int? newMatchCount,
    AlertDirection? direction,
  }) => CorridorAlertModel(
    id: id,
    departureCity: departureCity,
    arrivalCity: arrivalCity,
    departureCountryCode: departureCountryCode,
    arrivalCountryCode: arrivalCountryCode,
    dateFrom: dateFrom,
    dateTo: dateTo,
    minWeightKg: minWeightKg,
    contentCategories: contentCategories,
    active: active ?? this.active,
    matchCount: matchCount ?? this.matchCount,
    newMatchCount: newMatchCount ?? this.newMatchCount,
    lastSeenAt: lastSeenAt,
    createdAt: createdAt,
    direction: direction ?? this.direction,
    notifyMode: notifyMode,
    centerLat: centerLat,
    centerLng: centerLng,
    radiusKm: radiusKm,
    centerLabel: centerLabel,
  );

  @override
  List<Object?> get props => [
    id,
    departureCity,
    arrivalCity,
    departureCountryCode,
    arrivalCountryCode,
    dateFrom,
    dateTo,
    minWeightKg,
    contentCategories,
    active,
    matchCount,
    newMatchCount,
    lastSeenAt,
    createdAt,
    direction,
    notifyMode,
    centerLat,
    centerLng,
    radiusKm,
    centerLabel,
  ];
}

/// Payload de création/édition d'alerte (POST / PUT). Découple le bloc/sheet
/// du format wire ; les optionnels nuls sont omis du body.
/// [direction] est obligatoire (§4.6) et toujours inclus dans le body.
class CorridorAlertDraft {
  const CorridorAlertDraft({
    required this.departureCity,
    required this.arrivalCity,
    this.departureCountryCode,
    this.arrivalCountryCode,
    this.dateFrom,
    this.dateTo,
    this.minWeightKg,
    this.contentCategories = const [],
    this.direction = AlertDirection.travelerWantsPackages,
    this.notifyMode = AlertNotifyMode.instant,
    this.centerLat,
    this.centerLng,
    this.radiusKm,
    this.centerLabel,
  });

  final String departureCity;
  final String arrivalCity;
  final String? departureCountryCode;
  final String? arrivalCountryCode;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final double? minWeightKg;
  final List<String> contentCategories;
  final AlertDirection direction;
  final AlertNotifyMode notifyMode;

  // ── Zone de remise optionnelle (alertes trajet) ──────────────────────────
  final double? centerLat;
  final double? centerLng;
  final int? radiusKm;
  final String? centerLabel;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'departureCity': departureCity,
    'arrivalCity': arrivalCity,
    'direction': direction.wire,
    'notifyMode': notifyMode.wire,
    if (departureCountryCode != null)
      'departureCountryCode': departureCountryCode,
    if (arrivalCountryCode != null) 'arrivalCountryCode': arrivalCountryCode,
    if (dateFrom != null) 'dateFrom': _date(dateFrom!),
    if (dateTo != null) 'dateTo': _date(dateTo!),
    if (minWeightKg != null) 'minWeightKg': minWeightKg,
    if (contentCategories.isNotEmpty) 'contentCategories': contentCategories,
    if (centerLat != null) 'centerLat': centerLat,
    if (centerLng != null) 'centerLng': centerLng,
    if (radiusKm != null) 'radiusKm': radiusKm,
    if (centerLabel != null) 'centerLabel': centerLabel,
  };

  static String _date(DateTime d) => d.toIso8601String().substring(0, 10);
}
