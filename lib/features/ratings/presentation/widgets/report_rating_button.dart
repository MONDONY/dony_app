import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/incident_report/data/repositories/incident_report_repository.dart';
import 'package:dony/features/ratings/data/models/rating_summary.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Drapeau « Signaler cet avis », posé sur chaque avis affiché.
///
/// Tout contenu publié par un utilisateur doit pouvoir être signalé depuis
/// l'app (guideline Apple 1.2). Ouvre l'écran de signalement commun avec la
/// cible `RATING`. Rien ne s'affiche quand l'avis n'a pas de commentaire
/// (des étoiles seules ne publient aucun contenu) ou quand le back ne renvoie
/// pas encore son identifiant.
class ReportRatingButton extends StatelessWidget {
  const ReportRatingButton({super.key, required this.item});

  final RatingItem item;

  static bool canReport(RatingItem item) =>
      item.id != null && (item.comment?.trim().isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    if (!canReport(item)) return const SizedBox.shrink();
    return IconButton(
      tooltip: context.l10n.ratingReportTooltip,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      padding: EdgeInsets.zero,
      icon: DonyIcon(
        'flag',
        size: 16,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onPressed: () => context.push(
        '/settings/report-incident',
        extra: {'targetType': IncidentTargetType.rating, 'targetId': item.id},
      ),
    );
  }
}
