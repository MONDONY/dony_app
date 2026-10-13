import 'package:equatable/equatable.dart';

/// Négociation en cours du voyageur connecté sur une demande d'envoi, servie
/// par la recherche des demandes (`GET /package-requests`, champ
/// `myNegotiation`, yadony-back #513, FLUTTER-NZ).
///
/// Absente quand le lecteur ne négocie pas cette demande, ou sur un back
/// antérieur : la carte n'affiche alors aucune puce.
class MyNegotiationSummary extends Equatable {
  const MyNegotiationSummary({
    required this.threadId,
    required this.status,
    required this.myTurn,
  });

  /// Fil de négociation, ouvert par `/negotiations/{threadId}`.
  final String threadId;

  /// `OPEN`, `AWAITING_TRIP`, `AWAITING_PAYMENT`, `AWAITING_COMMISSION` ou
  /// `AWAITING_DEPOSIT`. Gardé brut : seule [myTurn] pilote l'affichage.
  final String status;

  /// Vrai quand c'est au voyageur de répondre ou d'agir.
  final bool myTurn;

  /// Lit le champ `myNegotiation` ; `null` s'il est absent ou mal formé, pour
  /// qu'un payload inattendu retombe sur la carte sans puce plutôt que de
  /// casser toute la page de résultats.
  static MyNegotiationSummary? tryFromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final threadId = json['threadId'];
    if (threadId is! String || threadId.isEmpty) return null;
    return MyNegotiationSummary(
      threadId: threadId,
      status: json['status'] as String? ?? '',
      myTurn: json['myTurn'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [threadId, status, myTurn];
}
