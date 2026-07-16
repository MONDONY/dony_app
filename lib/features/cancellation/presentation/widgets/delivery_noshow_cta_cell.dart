import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Cellule discrète (pas d'alarme) proposant de signaler une absence à la
/// remise du destinataire — visible tant qu'aucun signalement n'existe.
/// Une fois signalé, la bannière (hero card) prend le relais (cf. Task B4).
class DeliveryNoShowCtaCell extends StatelessWidget {
  const DeliveryNoShowCtaCell({
    super.key,
    required this.bid,
    required this.isSender,
  });

  final BidModel bid;
  final bool isSender;

  @override
  Widget build(BuildContext context) {
    if (!bid.canReportDeliveryNoShow) {
      return const SizedBox.shrink();
    }
    final title = isSender
        ? 'Le voyageur ne livre pas'
        : "Signaler l'absence du destinataire";
    final subtitle = isSender
        ? 'Injoignable ou refus de remettre le colis'
        : "Si vous êtes sur place et qu'il ne répond pas";

    return DonyCard(
      padding: EdgeInsets.zero,
      child: DonyListTile(
        icon: isSender ? Icons.flight_rounded : Icons.person_off_rounded,
        label: title,
        subtitle: subtitle,
        destructive: true,
        showDivider: false,
        onTap: () => _showSheet(context),
      ),
    );
  }

  Future<void> _showSheet(BuildContext context) async {
    final bloc = context.read<CancellationBloc>();
    final confirmed = await DonyBottomSheet.show<bool>(
      context,
      title: isSender
          ? "Le voyageur ne s'est pas présenté à la remise ?"
          : "Le destinataire ne s'est pas présenté à la remise ?",
      stickyBottom: Builder(
        builder: (ctx) => DonyButton(
          label: 'Confirmer le signalement',
          iconAsset: 'user-x',
          onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(true),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isSender
                  ? 'Le voyageur ne livre pas le colis à votre destinataire.'
                  : "Le destinataire ne s'est pas présenté au point de remise.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: DonySpacing.md),
            Text(
              "L'autre partie aura 24 h pour contester. Le paiement reste "
              'gelé le temps de l\'instruction — aucun versement automatique.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) {
      return;
    }
    if (isSender) {
      bloc.add(TravelerDeliveryNoShowReportRequested(bid.id));
    } else {
      bloc.add(DeliveryNoShowReportRequested(bid.id));
    }
  }
}
