import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Confirmation de « Annuler la demande » sur un colis qui attend son
/// paiement. Rend `true` si l'expéditeur confirme : l'appelant envoie alors
/// `BidCancelBeforePaymentRequested` au BLoC de l'écran, qui porte le
/// chargement et l'erreur (la feuille est déjà refermée).
///
/// Boutons dans `stickyBottom` (règle du projet), feuille sans état : aucun
/// notifier ni contrôleur à disposer.
abstract final class CancelBeforePaymentSheet {
  static Future<bool> show(
    BuildContext context, {
    required BidModel bid,
  }) async {
    final l = context.l10n;
    final confirmed = await DonyBottomSheet.show<bool>(
      context,
      title: l.bidCancelBeforePaymentSheetTitle,
      stickyBottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Builder(
            builder: (ctx) => DonyButton(
              key: const Key('cancel-before-payment-confirm'),
              label: l.bidCancelBeforePaymentConfirm,
              variant: DonyButtonVariant.destructive,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ),
          const SizedBox(height: DonySpacing.sm),
          Builder(
            builder: (ctx) => DonyButton(
              key: const Key('cancel-before-payment-keep'),
              label: l.bidCancelBeforePaymentKeep,
              variant: DonyButtonVariant.ghost,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
          ),
        ],
      ),
      child: _Body(bid: bid),
    );
    return confirmed ?? false;
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.bid});

  final BidModel bid;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final consequence = bid.paymentMethod == BidPaymentMethod.mobileMoney
        ? l.bidCancelBeforePaymentSheetBodyMobileMoney
        : l.bidCancelBeforePaymentSheetBodyCard;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(consequence, style: tt.bodyLarge?.copyWith(color: cs.onSurface)),
        const SizedBox(height: DonySpacing.sm),
        Text(
          l.bidCancelBeforePaymentSheetConversationNote,
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
