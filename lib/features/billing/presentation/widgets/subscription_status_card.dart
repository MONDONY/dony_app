import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/billing/data/models/pro_subscription_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String _formatLocalDate(DateTime local) =>
    DateFormat('d MMMM yyyy', 'fr').format(local);

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

  String get _statusLabel => switch (subscription.status) {
    ProSubscriptionStatus.active => subscription.cancelAtPeriodEnd
        ? 'Résiliation programmée'
        : 'Actif',
    ProSubscriptionStatus.pastDue => 'Paiement en attente',
    ProSubscriptionStatus.legacyGrace => 'Accès gratuit temporaire',
    ProSubscriptionStatus.canceled => 'Résilié',
    ProSubscriptionStatus.expired => 'Expiré',
    ProSubscriptionStatus.none => 'Aucun abonnement',
    ProSubscriptionStatus.unknown => 'Statut inconnu',
  };

  /// `null` quand [ProSubscriptionModel.billingCycle] est nul (octroi
  /// administrateur) ou porte une valeur inconnue. Un accès offert n'est
  /// jamais facturé : dans ce cas, aucune mention de rythme ni de prix ne
  /// doit apparaître.
  String? get _cycleLabel {
    switch (subscription.billingCycle?.toUpperCase()) {
      case 'MONTHLY':
        return 'Facturation mensuelle';
      case 'YEARLY':
      case 'ANNUAL':
        return 'Facturation annuelle';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final cycleLabel = _cycleLabel;
    final periodEnd = subscription.currentPeriodEnd?.toLocal();
    final isLegacyGrace = subscription.status == ProSubscriptionStatus.legacyGrace;
    final isCanceling = subscription.cancelAtPeriodEnd && periodEnd != null;

    return DonyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _statusLabel,
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
              'Votre accès PRO est gratuit et temporaire.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
          if (isCanceling) ...[
            const SizedBox(height: DonySpacing.xs),
            Text(
              'Résiliation programmée pour le '
              '${_formatLocalDate(periodEnd)}.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ] else if (periodEnd != null) ...[
            const SizedBox(height: DonySpacing.xs),
            Text(
              'Prochain renouvellement le ${_formatLocalDate(periodEnd)}.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
          if (onManage != null) ...[
            const SizedBox(height: DonySpacing.base),
            DonyButton(
              label: 'Gérer mon abonnement',
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
