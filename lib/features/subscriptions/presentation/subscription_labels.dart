import 'package:dony/features/subscriptions/data/subscriptions_repository.dart';
import 'package:dony/l10n/l10n.dart';

/// Nom affiché d'un voyageur suivi.
///
/// Le serveur peut ne pas fournir de nom (`travelerName` vide côté modèle,
/// voir `SubscriptionItem.fromJson`) : l'affichage retombe alors sur
/// [AppLocalizations.tripTravelerFallbackName], comme le reste du domaine
/// trajet, plutôt que sur un « Voyageur » figé en français.
extension SubscriptionItemL10n on SubscriptionItem {
  String displayName(AppLocalizations l) =>
      travelerName.isNotEmpty ? travelerName : l.tripTravelerFallbackName;
}
