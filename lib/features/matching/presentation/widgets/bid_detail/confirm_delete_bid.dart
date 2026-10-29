import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Confirmation « Supprimer cette demande ? » d'un envoi clos (retrait de la
/// liste, jamais de suppression physique côté serveur), puis [BidDeleteRequested].
///
/// Appelée par l'entrée « Supprimer cette demande » du menu ⋮ expéditeur
/// (`showSenderOptionsSheet`). [context] doit voir le [BidBloc] de l'écran de
/// détail : le bloc est lu avant d'ouvrir la boîte, dont la route se pose
/// au-dessus du provider.
void confirmDeleteBid(BuildContext context, BidModel bid) {
  final l = context.l10n;
  final tt = Theme.of(context).textTheme;
  final cs = Theme.of(context).colorScheme;
  final bloc = context.read<BidBloc>();
  showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DonyRadius.sheet),
      ),
      title: Text(
        l.bidDetailDeleteRequestQuestionTitle,
        style: tt.headlineMedium,
      ),
      content: Text(
        l.bidDetailDeleteRequestDefaultBody,
        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(
            l.commonCancel,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: cs.error,
            foregroundColor: DonyColors.white,
            elevation: 0,
          ),
          child: Text(l.commonDelete, style: tt.labelLarge),
        ),
      ],
    ),
  ).then((confirmed) {
    if (confirmed ?? false) {
      bloc.add(BidDeleteRequested(bid.id));
    }
  });
}

/// Confirmation « Supprimer cette demande » côté voyageur (demande refusée ou
/// annulée), puis [BidTravelerDismissRequested] : la demande quitte sa liste,
/// jamais de suppression physique côté serveur.
///
/// Appelée par l'entrée « Supprimer cette demande » du menu ⋮ voyageur
/// (`showTravelerOptionsSheet`). Même lecture du [BidBloc] avant d'ouvrir la
/// boîte que [confirmDeleteBid]. Le corps parle d'une « demande refusée » pour
/// REJECTED seulement ; une demande annulée reçoit le corps générique.
void confirmTravelerDismissBid(BuildContext context, BidModel bid) {
  final l = context.l10n;
  final tt = Theme.of(context).textTheme;
  final cs = Theme.of(context).colorScheme;
  final bloc = context.read<BidBloc>();
  showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DonyRadius.sheet),
      ),
      title: Text(l.bidDetailDeleteRequest, style: tt.headlineMedium),
      content: Text(
        bid.status == 'REJECTED'
            ? l.bidDetailDeleteRejectedBody
            : l.bidDetailDeleteRequestDefaultBody,
        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(
            l.commonCancel,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: cs.error,
            foregroundColor: DonyColors.white,
            elevation: 0,
          ),
          child: Text(l.commonDelete, style: tt.labelLarge),
        ),
      ],
    ),
  ).then((confirmed) {
    if (confirmed ?? false) {
      bloc.add(BidTravelerDismissRequested(bid.id));
    }
  });
}
