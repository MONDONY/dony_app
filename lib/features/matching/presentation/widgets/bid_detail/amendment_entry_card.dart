import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/amendment_request_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/detail_card.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Encart d'entrée de la modification d'un colis accepté, dans le détail
/// d'envoi de l'expéditeur : ouvre la feuille « Modifier mon colis ».
class AmendmentEntryCard extends StatelessWidget {
  const AmendmentEntryCard({super.key, required this.bid});

  final BidModel bid;

  /// Le serveur décide (éligibilité, drapeau, fenêtre) : l'app ne recalcule rien.
  static bool shouldShow(BidModel bid) => bid.amendmentAllowed;

  /// Ouvre la feuille puis relit le colis (`BidBloc` de l'écran, s'il est là)
  /// quand une demande a été envoyée ou n'est plus possible. Aussi appelée par
  /// l'entrée du menu d'options.
  static Future<void> openSheet(BuildContext context, BidModel bid) async {
    BidBloc? bidBloc;
    try {
      bidBloc = context.read<BidBloc>();
    } on ProviderNotFoundException {
      bidBloc = null;
    }
    final changed = await AmendmentRequestSheet.show(context, bid: bid);
    if (changed) bidBloc?.add(BidDetailRequested(bid.id));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return DetailCard(
      title: l.amendmentEntryTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.amendmentEntryBodyShort(
              bid.travelerName ?? l.bidDetailSenderTravelerFallback,
            ),
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: DonySpacing.md),
          DonyButton(
            label: l.amendmentEntryButton,
            iconAsset: 'plus',
            variant: DonyButtonVariant.secondary,
            onPressed: () => openSheet(context, bid),
          ),
        ],
      ),
    );
  }
}
