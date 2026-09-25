import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/l10n/l10n.dart';
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
    final l = context.l10n;
    final title = isSender
        ? l.deliveryNoShowTravelerNotDeliveringTitle
        : l.deliveryNoShowReportAbsentRecipientTitle;
    final subtitle = isSender
        ? l.deliveryNoShowTravelerNotDeliveringSubtitle
        : l.deliveryNoShowReportAbsentRecipientSubtitle;

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
    final l = context.l10n;
    final confirmed = await DonyBottomSheet.show<bool>(
      context,
      title: isSender
          ? l.deliveryNoShowTravelerAbsentSheetTitle
          : l.deliveryNoShowRecipientAbsentSheetTitle,
      stickyBottom: Builder(
        builder: (ctx) => DonyButton(
          label: l.deliveryNoShowConfirmReportAction,
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
                  ? l.deliveryNoShowTravelerNotDeliveringBody
                  : l.deliveryNoShowRecipientAbsentBody,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: DonySpacing.md),
            Text(
              l.deliveryNoShowContestNotice,
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
