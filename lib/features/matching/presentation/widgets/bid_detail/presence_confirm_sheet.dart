import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Confirmation de « Confirmer ma présence » côté voyageur. Rend `true` si le
/// voyageur confirme : l'appelant envoie alors `BidConfirmPresenceRequested`
/// au BLoC de l'écran, qui porte le chargement et l'erreur.
///
/// Textes neutres quel que soit le mode de transport : on récupère « le
/// colis », jamais à l'aéroport ou au port.
///
/// Boutons dans `stickyBottom` (règle du projet), feuille sans état.
abstract final class PresenceConfirmSheet {
  static Future<bool> show(
    BuildContext context, {
    required BidModel bid,
  }) async {
    final l = context.l10n;
    final confirmed = await DonyBottomSheet.show<bool>(
      context,
      title: l.bidPresenceSheetTitle,
      stickyBottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Builder(
            builder: (ctx) => DonyButton(
              key: const Key('presence-confirm-yes'),
              label: l.bidDetailConfirmPresence,
              iconAsset: 'map-pin',
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ),
          const SizedBox(height: DonySpacing.sm),
          Builder(
            builder: (ctx) => DonyButton(
              key: const Key('presence-confirm-no'),
              label: l.commonCancel,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _commitment(l),
          style: tt.bodyLarge?.copyWith(color: cs.onSurface),
        ),
        const SizedBox(height: DonySpacing.sm),
        Text(
          l.bidPresenceSheetFinalNote,
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  String _commitment(AppLocalizations l) {
    final deadline = bid.handoverDeadline?.toLocal();
    if (deadline == null) return l.bidPresenceSheetBody;
    final locale = l.localeName;
    try {
      return l.bidPresenceSheetBodyUntil(
        DateFormat.MMMEd(locale).format(deadline),
        DateFormat.jm(locale).format(deadline),
      );
    } catch (_) {
      // Repli sans date quand les données de locale manquent.
      return l.bidPresenceSheetBody;
    }
  }
}
