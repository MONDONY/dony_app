import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_sticky_bar.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Pourquoi ni le footer ni le talon ne proposent le QR de remise : la
/// déclaration d'absence de l'expéditeur est contestée ou confirmée, l'équipe
/// Yadony tranche avant toute remise. Même composant que les cartes
/// d'information de la vue voyageur ([DonyStatusBanner]).
class SenderHandoverBlockedCard extends StatelessWidget {
  const SenderHandoverBlockedCard({super.key});

  static bool shouldShow(BidModel bid) =>
      SenderStickyBar.handoverBlockedByNoShow(bid);

  @override
  Widget build(BuildContext context) => DonyStatusBanner(
    key: const Key('sender-handover-blocked-card'),
    type: DonyStatusBannerType.info,
    iconAsset: 'gavel',
    message: context.l10n.bidDetailSenderHandoverBlockedByNoShow,
  );
}
