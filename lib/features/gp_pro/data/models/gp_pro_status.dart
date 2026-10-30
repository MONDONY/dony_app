import 'package:equatable/equatable.dart';

/// État de la demande GP Pro, miroir de `state` côté back (yadony-back #560).
enum GpProState {
  none('NONE'),
  awaitingKyc('AWAITING_KYC'),
  pending('PENDING'),
  active('ACTIVE'),
  rejected('REJECTED'),
  revoked('REVOKED');

  const GpProState(this.wire);

  final String wire;

  /// Valeur inconnue ou absente (back plus récent) : `none`, jamais d'échec.
  static GpProState fromWire(String? value) => GpProState.values.firstWhere(
    (s) => s.wire == value,
    orElse: () => GpProState.none,
  );
}

/// Fréquence de voyage déclarée dans la demande.
enum GpProFrequency {
  weekly('WEEKLY'),
  twiceAMonth('TWICE_A_MONTH'),
  monthly('MONTHLY'),
  lessOften('LESS_OFTEN');

  const GpProFrequency(this.wire);

  final String wire;

  static GpProFrequency? fromWire(String? value) {
    for (final f in GpProFrequency.values) {
      if (f.wire == value) return f;
    }
    return null;
  }
}

/// Nature d'un justificatif joint à la demande.
enum GpProDocType {
  businessRegistration('BUSINESS_REGISTRATION'),
  travelProof('TRAVEL_PROOF'),
  socialProfile('SOCIAL_PROFILE'),
  other('OTHER');

  const GpProDocType(this.wire);

  final String wire;

  /// Type inconnu : `other`, le justificatif reste affichable.
  static GpProDocType fromWire(String? value) => GpProDocType.values.firstWhere(
    (t) => t.wire == value,
    orElse: () => GpProDocType.other,
  );
}

/// Origine de la demande : le profil (l'inscription ne la propose plus).
enum GpProSource {
  profile('PROFILE');

  const GpProSource(this.wire);

  final String wire;
}

/// Justificatif joint (image) : seul l'identifiant et le type sont exposés.
class GpProDocument extends Equatable {
  const GpProDocument({required this.id, required this.type});

  /// `documentId` à l'upload (`POST /gp-pro/documents`), `id` dans `documents`
  /// de `GET /gp-pro/me` : les deux clés sont lues.
  factory GpProDocument.fromJson(Map<String, dynamic> json) => GpProDocument(
    id: (json['id'] ?? json['documentId']) as String,
    type: GpProDocType.fromWire(json['type'] as String?),
  );

  final String id;
  final GpProDocType type;

  @override
  List<Object?> get props => [id, type];
}

/// Statut GP Pro de l'utilisateur (`GET /gp-pro/me`).
class GpProStatus extends Equatable {
  const GpProStatus({
    required this.state,
    this.travelFrequency,
    this.commercialName,
    this.documentCount = 0,
    this.documents,
    this.reason,
    this.decidedAt,
  });

  factory GpProStatus.fromJson(Map<String, dynamic> json) {
    final rawDocs = json['documents'];
    final decided = json['decidedAt'] as String?;
    return GpProStatus(
      state: GpProState.fromWire(json['state'] as String?),
      travelFrequency: GpProFrequency.fromWire(
        json['travelFrequency'] as String?,
      ),
      commercialName: json['commercialName'] as String?,
      documentCount: (json['documentCount'] as num?)?.toInt() ?? 0,
      // `null` tant que le back n'expose pas la liste (contrat actuel).
      documents: rawDocs is List
          ? rawDocs
                .whereType<Map<String, dynamic>>()
                .map(GpProDocument.fromJson)
                .toList()
          : null,
      reason: json['reason'] as String?,
      decidedAt: decided == null ? null : DateTime.parse(decided).toLocal(),
    );
  }

  final GpProState state;
  final GpProFrequency? travelFrequency;
  final String? commercialName;
  final int documentCount;
  final List<GpProDocument>? documents;
  final String? reason;
  final DateTime? decidedAt;

  GpProStatus copyWith({int? documentCount, List<GpProDocument>? documents}) =>
      GpProStatus(
        state: state,
        travelFrequency: travelFrequency,
        commercialName: commercialName,
        documentCount: documentCount ?? this.documentCount,
        documents: documents ?? this.documents,
        reason: reason,
        decidedAt: decidedAt,
      );

  /// Demande en cours : on peut la compléter ou l'annuler, pas en ouvrir une
  /// seconde.
  bool get isOpen =>
      state == GpProState.awaitingKyc || state == GpProState.pending;

  @override
  List<Object?> get props => [
    state,
    travelFrequency,
    commercialName,
    documentCount,
    documents,
    reason,
    decidedAt,
  ];
}
