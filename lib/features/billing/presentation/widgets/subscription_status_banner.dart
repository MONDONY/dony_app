import 'package:dony/core/design/widgets/dony_status_banner.dart';
import 'package:dony/features/billing/data/models/pro_subscription_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Nombre de jours pleins restants avant [instant], arrondi vers le haut.
///
/// [instant] arrive systématiquement en UTC (dates serveur). [now] est
/// injectable pour les tests ; en production c'est `DateTime.now()`
/// (horloge locale de l'appareil). Les deux instants sont normalisés en UTC
/// avant la soustraction : peu importe que l'un soit UTC et l'autre local,
/// on compare toujours la même durée réelle écoulée, jamais des champs
/// calendaires (année/mois/jour) qui, eux, dépendent du fuseau horaire.
///
/// Rend `null` si [instant] est nul. Arrondit vers le haut (6 jours et 12
/// heures rendent 7, pas 6) et borne le résultat à 0 : une échéance déjà
/// passée ne rend jamais un nombre négatif.
int? daysUntil(DateTime? instant, {DateTime? now}) {
  if (instant == null) {
    return null;
  }
  final reference = now ?? DateTime.now();
  final diffMinutes = instant
      .toUtc()
      .difference(reference.toUtc())
      .inMinutes;
  final days = (diffMinutes / 1440).ceil();
  return days < 0 ? 0 : days;
}

/// Formate une date locale en français, ex. « 24 décembre 2026 ».
///
/// `intl` est déjà une dépendance directe du projet (voir
/// `lib/features/matching/presentation/widgets/trip_card.dart`) et déjà
/// initialisée en `fr` au démarrage (`main.dart`) : on réutilise ce même
/// utilitaire plutôt que d'ajouter une troisième liste de noms de mois
/// écrite à la main dans le dépôt.
String _formatLocalDate(DateTime local) => DateFormat('d MMMM yyyy', 'fr').format(local);

/// Bandeau d'alerte pour l'abonnement PRO : impayé, fin de gratuité proche,
/// ou résiliation programmée.
///
/// Purement présentationnel : aucun accès BLoC, aucun `getIt`, aucune
/// navigation. Rend `SizedBox.shrink()` quand rien n'est à signaler, pour
/// que l'appelant puisse toujours le monter sans condition.
class SubscriptionStatusBanner extends StatelessWidget {
  const SubscriptionStatusBanner({
    required this.subscription,
    this.onAction,
    super.key,
  });

  final ProSubscriptionModel subscription;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return switch (subscription.status) {
      ProSubscriptionStatus.pastDue => DonyStatusBanner(
        type: DonyStatusBannerType.error,
        message:
            "Votre dernier paiement n'a pas abouti. Sans régularisation, "
            'votre accès PRO sera suspendu.',
        action: _actionButton(context, 'Régler'),
      ),
      ProSubscriptionStatus.legacyGrace => DonyStatusBanner(
        type: DonyStatusBannerType.warning,
        message: _legacyGraceMessage(),
        action: _actionButton(context, "S'abonner"),
      ),
      ProSubscriptionStatus.active => _activeBanner(context),
      ProSubscriptionStatus.none ||
      ProSubscriptionStatus.canceled ||
      ProSubscriptionStatus.expired ||
      ProSubscriptionStatus.unknown => const SizedBox.shrink(),
    };
  }

  String _legacyGraceMessage() {
    final days = daysUntil(subscription.graceExpiresAt);
    if (days == null) {
      return 'Votre accès PRO gratuit prendra bientôt fin.';
    }
    final plural = days > 1 ? 's' : '';
    return 'Votre accès PRO gratuit prend fin dans $days jour$plural.';
  }

  Widget _activeBanner(BuildContext context) {
    final periodEnd = subscription.currentPeriodEnd;
    if (!subscription.cancelAtPeriodEnd || periodEnd == null) {
      return const SizedBox.shrink();
    }
    final dateStr = _formatLocalDate(periodEnd.toLocal());
    return DonyStatusBanner(
      type: DonyStatusBannerType.info,
      message: 'Votre abonnement PRO prend fin le $dateStr.',
      action: _actionButton(context, 'Gérer'),
    );
  }

  Widget? _actionButton(BuildContext context, String label) {
    if (onAction == null) {
      return null;
    }
    return TextButton(
      onPressed: onAction,
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: Text(label),
    );
  }
}
