import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/get_it_safe.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/utils/contact_links.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/profil_card_widgets.dart';
import 'package:dony/features/matching/presentation/widgets/recipient_contact/recipient_contact.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Statuts des colis dont le voyageur prévient le destinataire : remis,
/// en transit ou arrivés.
const notifyRecipientsStatuses = <String>{
  'HANDED_OVER',
  'IN_TRANSIT',
  'ARRIVED',
};

/// Colis du trajet dont le destinataire est à prévenir.
List<BidModel> recipientsToNotify(List<BidModel> bids) => bids
    .where((b) => notifyRecipientsStatuses.contains(b.status))
    .toList(growable: false);

/// Origine de l'ouverture de la feuille, envoyée à l'analytics.
enum NotifyRecipientsSource {
  /// Ouverture automatique après un « Marquer arrivé » réussi.
  afterArrival('after_arrival'),

  /// Bouton « Prévenir les destinataires » de l'écran trajet.
  manual('manual');

  const NotifyRecipientsSource(this.value);
  final String value;
}

/// Feuille « Prévenir les destinataires » de l'écran trajet du voyageur.
///
/// Une ligne par colis remis, en transit ou arrivé : nom et numéro du
/// destinataire, puce « Dans Yadony » quand il suit le colis dans l'app
/// (`recipientAppStatus == 'CONFIRMED'`, seule valeur que le back révèle au
/// voyageur ; un back plus ancien rend `null` et la puce n'apparaît pas), et
/// les boutons WhatsApp / SMS / Appeler avec le message pré-rempli.
///
/// Les boutons de ligne ne sont pas des CTA de soumission : seul « Fermer »
/// est global, et il va dans le `stickyBottom`.
class NotifyRecipientsSheet extends StatelessWidget {
  const NotifyRecipientsSheet({
    super.key,
    required this.bids,
    this.instructions,
    this.launcher,
  });

  /// Colis déjà filtrés par [recipientsToNotify].
  final List<BidModel> bids;

  /// Instructions de retrait à jour du trajet.
  final String? instructions;

  /// Injecté en test ; sinon le lanceur de la plateforme.
  final ContactLinkLauncher? launcher;

  /// Ouvre la feuille sur les colis concernés de [bids] ; ne fait rien s'il
  /// n'y en a aucun.
  static Future<void> show(
    BuildContext context, {
    required List<BidModel> bids,
    required NotifyRecipientsSource source,
    String? instructions,
    ContactLinkLauncher? launcher,
  }) async {
    final concerned = recipientsToNotify(bids);
    if (concerned.isEmpty) {
      return;
    }
    unawaited(
      getItSafe<AnalyticsService>()?.logEvent(
        AnalyticsEvents.recipientsNotifyOpened,
        properties: {'count': concerned.length, 'source': source.value},
      ),
    );
    final l = context.l10n;
    await DonyBottomSheet.show<void>(
      context,
      title: l.notifyRecipientsTitle,
      subtitle: l.notifyRecipientsSubtitle,
      stickyBottom: Builder(
        builder: (ctx) => DonyButton(
          label: l.commonClose,
          variant: DonyButtonVariant.secondary,
          onPressed: () => Navigator.of(ctx).pop(),
        ),
      ),
      child: NotifyRecipientsSheet(
        bids: concerned,
        instructions: instructions,
        launcher: launcher,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < bids.length; i++) ...[
          if (i > 0) const SizedBox(height: DonySpacing.md),
          _RecipientRow(
            bid: bids[i],
            instructions: instructions,
            launcher: launcher,
          ),
        ],
        const SizedBox(height: DonySpacing.lg),
      ],
    );
  }
}

/// Ligne d'un destinataire dans la feuille.
class _RecipientRow extends StatelessWidget {
  const _RecipientRow({
    required this.bid,
    required this.instructions,
    required this.launcher,
  });

  final BidModel bid;
  final String? instructions;
  final ContactLinkLauncher? launcher;

  String _statusLabel(AppLocalizations l) => switch (bid.status) {
    'HANDED_OVER' => l.tripOwnerParcelsStatusHandedOver,
    'IN_TRANSIT' => l.tripOwnerParcelsStatusInTransit,
    _ => l.tripOwnerParcelsStatusArrived,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final rawName = bid.recipientName?.trim();
    final name = (rawName == null || rawName.isEmpty)
        ? l.notifyRecipientsFallbackName
        : rawName;
    final phone = bid.recipientPhone?.trim();
    final hasPhone = phone != null && phone.isNotEmpty;
    final inApp = bid.recipientAppStatus == 'CONFIRMED';

    return Container(
      key: Key('notify-recipient-${bid.id}'),
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: DonySpacing.xs,
            runSpacing: DonySpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                name,
                style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              if (inApp)
                MiniChip(
                  key: Key('notify-recipient-in-app-${bid.id}'),
                  label: l.notifyRecipientsInAppChip,
                  color: cs.primary,
                  bg: cs.primaryContainer,
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            hasPhone
                ? '${_statusLabel(l)} · $phone'
                : '${_statusLabel(l)} · ${l.notifyRecipientsNoPhone}',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          if (inApp && bid.status == 'ARRIVED') ...[
            const SizedBox(height: DonySpacing.xs),
            Row(
              children: [
                DonyIcon('check-check', size: 14, color: cs.success),
                const SizedBox(width: DonySpacing.xs),
                Flexible(
                  child: Text(
                    l.notifyRecipientsNotifiedInApp,
                    style: tt.bodySmall?.copyWith(
                      color: cs.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (hasPhone) ...[
            const SizedBox(height: DonySpacing.md),
            RecipientContactActions(
              bid: bid,
              instructions: instructions,
              launcher: launcher,
            ),
          ],
        ],
      ),
    );
  }
}
