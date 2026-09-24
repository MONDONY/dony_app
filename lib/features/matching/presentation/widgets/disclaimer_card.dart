import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/detail_card.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Carte affichant le statut du disclaimer de responsabilité légale.
///
/// Correspond à l'ancienne classe privée `_DisclaimerCard` de
/// `bid_detail_screen.dart`.
class DisclaimerCard extends StatelessWidget {
  final BidModel bid;

  const DisclaimerCard({super.key, required this.bid});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final signedAt = bid.disclaimerSignedAt?.toLocal();
    return DetailCard(
      title: l.bidCreateLegalResponsibilityTitle,
      child: Row(
        children: [
          DonyIcon('badge-check', color: cs.success, size: 20),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text(
              signedAt != null
                  ? l.bidCreateDisclaimerSigned(
                      l.commonDateAtTime(
                        DateFormat.yMd(l.localeName).format(signedAt),
                        DateFormat.jm(l.localeName).format(signedAt),
                      ),
                    )
                  : l.bidCreateDisclaimerSignedLabel,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
