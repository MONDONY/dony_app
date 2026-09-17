import 'package:equatable/equatable.dart';

/// Chiffres réservés au propriétaire de la demande (`GET /package-requests/{id}/insights`).
class PackageRequestInsights extends Equatable {
  const PackageRequestInsights({
    required this.viewCount,
    required this.invitedAnnouncementIds,
  });

  factory PackageRequestInsights.fromJson(Map<String, dynamic> json) =>
      PackageRequestInsights(
        viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
        invitedAnnouncementIds: {
          for (final id
              in (json['invitedAnnouncementIds'] as List<dynamic>? ?? const []))
            id as String,
        },
      );

  final int viewCount;
  final Set<String> invitedAnnouncementIds;

  @override
  List<Object?> get props => [viewCount, invitedAnnouncementIds];
}

/// `notFound` couvre deux cas distincts côté 404, que seul l'appelant (qui
/// connaît l'historique de `getInsights`) peut départager : route absente
/// (ancien back, insights jamais répondu) ou trajet disparu entre-temps
/// (back à jour, insights déjà répondu avec succès). Voir
/// `PackageRequestDetailCubit.invite`.
enum InvitationOutcome {
  sent,
  alreadySent,
  notFound,
  notInvitable,
  limitReached,
}
