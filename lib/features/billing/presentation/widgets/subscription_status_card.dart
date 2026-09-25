import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/billing/data/models/pro_subscription_model.dart';
import 'package:dony/features/billing/presentation/widgets/subscription_date_format.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Carte de statut de l'abonnement PRO : état courant, rythme de
/// facturation quand il existe, date de prochain renouvellement ou de fin
/// d'accès, et bouton de gestion optionnel vers le portail web externe.
///
/// Purement présentationnelle : aucun accès BLoC, aucun `getIt`, aucune
/// navigation. Reçoit le modèle déjà résolu et un rappel.
class SubscriptionStatusCard extends StatelessWidget {
  const SubscriptionStatusCard({
    required this.subscription,
    this.onManage,
    super.key,
  });

  final ProSubscriptionModel subscription;
  final VoidCallback? onManage;

  String _statusLabel(AppLocalizations l) => switch (subscription.status) {
    ProSubscriptionStatus.active =>
      subscription.cancelAtPeriodEnd
          ? l.proStatusCancelScheduled
          : l.proStatusActive,
    ProSubscriptionStatus.pastDue => l.proStatusPastDue,
    ProSubscriptionStatus.legacyGrace => l.proStatusLegacyGrace,
    ProSubscriptionStatus.canceled => l.proStatusCanceled,
    ProSubscriptionStatus.expired => l.proStatusExpired,
    ProSubscriptionStatus.none => l.proStatusNone,
    ProSubscriptionStatus.unknown => l.proStatusUnknown,
  };

  /// `null` quand [ProSubscriptionModel.billingCycle] est nul (octroi
  /// administrateur) ou porte une valeur inconnue. Un accès offert n'est
  /// jamais facturé : dans ce cas, aucune mention de rythme ni de prix ne
  /// doit apparaître.
  ///
  /// Le backend ne produit que `MONTHLY` et `YEARLY` (comparés sans tenir
  /// compte de la casse) ; toute autre valeur retombe silencieusement sur
  /// l'absence de libellé plutôt que d'inventer un rythme non prouvé.
  String? _cycleLabel(AppLocalizations l) {
    // Un abonnement dont l'accès n'est plus accordé (résilié, expiré, ou
    // inexistant) ne sera plus prélevé : annoncer « Facturation mensuelle »
    // y décrirait un prélèvement qui n'aura pas lieu.
    if (!subscription.active) {
      return null;
    }
    switch (subscription.billingCycle?.toUpperCase()) {
      case 'MONTHLY':
        return l.proBillingMonthly;
      case 'YEARLY':
        return l.proBillingYearly;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final cycleLabel = _cycleLabel(l);
    final periodEnd = subscription.currentPeriodEnd?.toLocal();
    final isLegacyGrace =
        subscription.status == ProSubscriptionStatus.legacyGrace;
    final isCanceling = subscription.cancelAtPeriodEnd && periodEnd != null;

    return DonyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _statusLabel(l),
            style: tt.titleLarge?.copyWith(color: cs.onSurface),
          ),
          if (cycleLabel != null) ...[
            const SizedBox(height: DonySpacing.xs),
            Text(
              cycleLabel,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
          if (isLegacyGrace) ...[
            const SizedBox(height: DonySpacing.xs),
            Text(
              l.proFreeTemporaryAccess,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
          if (isCanceling) ...[
            const SizedBox(height: DonySpacing.xs),
            Text(
              l.proCancellationScheduledOn(
                formatSubscriptionDate(l, periodEnd),
              ),
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ] else if (periodEnd != null) ...[
            const SizedBox(height: DonySpacing.xs),
            Text(
              l.proNextRenewalOn(formatSubscriptionDate(l, periodEnd)),
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
          if (onManage != null) ...[
            const SizedBox(height: DonySpacing.base),
            DonyButton(
              label: l.proManageSubscriptionButton,
              variant: DonyButtonVariant.secondary,
              fullWidth: false,
              onPressed: onManage,
            ),
          ],
        ],
      ),
    );
  }
}
