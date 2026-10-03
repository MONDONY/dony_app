import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/bid_rejection_reason.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Libellé affiché d'un motif de refus.
String bidRejectionReasonLabel(AppLocalizations l, BidRejectionReason reason) =>
    switch (reason) {
      BidRejectionReason.noCapacity => l.bidRejectionReasonNoCapacity,
      BidRejectionReason.contentNotAccepted =>
        l.bidRejectionReasonContentNotAccepted,
      BidRejectionReason.handoverNotPossible =>
        l.bidRejectionReasonHandoverNotPossible,
      BidRejectionReason.tripChanged => l.bidRejectionReasonTripChanged,
      BidRejectionReason.other => l.bidRejectionReasonOther,
    };

/// Feuille de refus d'une demande : le voyageur choisit un motif, que
/// l'expéditeur verra (FLUTTER-AF). Elle tient lieu de confirmation : rend le
/// motif choisi, ou `null` si la feuille est fermée sans confirmer.
abstract final class RejectReasonSheet {
  static Future<BidRejectionReason?> show(BuildContext context) {
    final l = context.l10n;
    final selected = ValueNotifier<BidRejectionReason?>(null);
    return DonyBottomSheet.show<BidRejectionReason>(
      context,
      title: l.bidDetailDeclineRequestTitle,
      subtitle: l.bidDetailDeclineRequestSubtitle,
      isDanger: true,
      stickyBottom: ValueListenableBuilder<BidRejectionReason?>(
        valueListenable: selected,
        builder: (sheetContext, reason, _) => DonyButton(
          key: const Key('reject-reason-confirm'),
          label: l.bidDetailConfirmDecline,
          variant: DonyButtonVariant.destructive,
          onPressed: reason == null ? null : () => sheetContext.pop(reason),
        ),
      ),
      child: ValueListenableBuilder<BidRejectionReason?>(
        valueListenable: selected,
        builder: (_, reason, _) => DonyRadioGroup<BidRejectionReason>(
          value: reason,
          onChanged: (v) => selected.value = v,
          options: [
            for (final r in BidRejectionReason.values)
              DonyRadioOption(value: r, label: bidRejectionReasonLabel(l, r)),
          ],
        ),
      ),
    ).whenComplete(selected.dispose);
  }
}
