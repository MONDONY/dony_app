import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/billing/data/models/pro_subscription_model.dart';
import 'package:dony/features/billing/presentation/widgets/subscription_date_format.dart';
import 'package:flutter/material.dart';

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
  final diffMinutes = instant.toUtc().difference(reference.toUtc()).inMinutes;
  final days = (diffMinutes / 1440).ceil();
  return days < 0 ? 0 : days;
}

/// Vrai quand [SubscriptionStatusBanner] rend autre chose qu'un
/// `SizedBox.shrink()`.
///
/// Source UNIQUE de cette décision : `build` commence par une garde sur ce
/// prédicat avant de choisir quoi rendre, il n'y a donc plus rien à
/// maintenir en miroir. Vit ici, collé à ce qu'il gouverne, parce que
/// plusieurs écrans montent le bandeau (Profil, compte PRO) et qu'un bandeau
/// muet doit aussi faire disparaître l'espacement qui le suit. Sans ce
/// prédicat partagé, chaque appelant en réécrirait sa propre copie.
bool subscriptionHasVisibleAlert(ProSubscriptionModel subscription) =>
    switch (subscription.status) {
      ProSubscriptionStatus.pastDue ||
      ProSubscriptionStatus.legacyGrace => true,
      ProSubscriptionStatus.active =>
        subscription.cancelAtPeriodEnd && subscription.currentPeriodEnd != null,
      ProSubscriptionStatus.none ||
      ProSubscriptionStatus.canceled ||
      ProSubscriptionStatus.expired ||
      ProSubscriptionStatus.unknown => false,
    };

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
    // Garde unique : au-delà, `subscription.status` ne peut plus valoir
    // `none`/`canceled`/`expired`/`unknown`, ni `active` sans résiliation
    // programmée avec date connue. `_activeBanner` n'a donc plus besoin de
    // revérifier cette dernière condition.
    if (!subscriptionHasVisibleAlert(subscription)) {
      return const SizedBox.shrink();
    }
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
      // Seule valeur qui reste possible ici : la garde ci-dessus a déjà
      // écarté `none`/`canceled`/`expired`/`unknown`, qui ne portent jamais
      // d'alerte. Un joker plutôt qu'un `ProSubscriptionStatus.active =>`
      // explicite suivi des quatre autres valeurs : ces dernières
      // redeviendraient du code mort, jamais atteignable, donc jamais
      // couvrable par un test — exactement la duplication que la garde
      // existe pour supprimer.
      _ => _activeBanner(context),
    };
  }

  String _legacyGraceMessage() {
    final expiry = subscription.graceExpiresAt;
    if (expiry == null) {
      return 'Votre accès PRO gratuit prendra bientôt fin.';
    }
    // Le cron de bascule des grâces historiques est désactivé par défaut : un
    // statut `legacyGrace` survit donc à sa propre échéance. Sans ce garde,
    // `daysUntil` bornant à 0, l'écran afficherait « prend fin dans 0 jour »
    // indéfiniment APRÈS la date, ce qui est faux au présent comme au futur.
    if (!expiry.toUtc().isAfter(DateTime.now().toUtc())) {
      return 'Votre accès PRO gratuit a pris fin.';
    }
    // L'échéance est strictement dans le futur et `daysUntil` arrondit vers le
    // haut : le compte vaut donc toujours 1 au minimum, et « 0 jour » est
    // désormais inatteignable.
    final days = daysUntil(expiry) ?? 1;
    final plural = days > 1 ? 's' : '';
    return 'Votre accès PRO gratuit prend fin dans $days jour$plural.';
  }

  Widget _activeBanner(BuildContext context) {
    // La garde de `build` a déjà établi `cancelAtPeriodEnd` vrai et
    // `currentPeriodEnd` non nul pour atteindre ce point : la retester ici
    // recréerait la copie que `subscriptionHasVisibleAlert` existe pour
    // supprimer.
    final dateStr = formatSubscriptionDate(
      subscription.currentPeriodEnd!.toLocal(),
    );
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
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.md),
      ),
      child: Text(label),
    );
  }
}
