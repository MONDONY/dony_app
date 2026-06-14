import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/action_bars/bid_detail_action_bars.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum _TravelerAction { decide, confirmPresence, scan, deliver, delete }

/// Barre collante contextuelle voyageur — route vers le bon scanner/étape
/// selon le statut de l'offre.
class TravelerStickyBar extends StatelessWidget {
  final BidModel bid;
  final bool isLoading;

  const TravelerStickyBar({
    super.key,
    required this.bid,
    required this.isLoading,
  });

  // ── Static helper ────────────────────────────────────────────────────────────

  /// Returns true if this bar should be shown for the given [bid] status.
  static bool hasAction(BidModel bid) => _resolve(bid) != null;

  static _TravelerAction? _resolve(BidModel bid) {
    final now = DateTime.now();
    switch (bid.status) {
      case 'PENDING':
        return _TravelerAction.decide;
      case 'REJECTED':
        return _TravelerAction.delete;
      case 'ACCEPTED':
        if (bid.voyageurConfirmed) {
          return _TravelerAction.scan;
        }
        final end = bid.handoverWindowEnd;
        // Window has expired and traveler hasn't confirmed → hero handles it
        if (end != null && now.isAfter(end)) {
          return null;
        }
        return _TravelerAction.confirmPresence;
      case 'HANDED_OVER':
      case 'IN_TRANSIT':
        return _TravelerAction.deliver;
      default:
        return null;
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    switch (_resolve(bid)) {
      case null:
        return const SizedBox.shrink();
      case _TravelerAction.decide:
        return TravelerPendingBar(bid: bid, isLoading: isLoading);
      case _TravelerAction.confirmPresence:
        return ConfirmPresenceBar(bid: bid, isLoading: isLoading);
      case _TravelerAction.delete:
        return TravelerRejectedBar(bid: bid, isLoading: isLoading);
      case _TravelerAction.scan:
        return const _ScanBar();
      case _TravelerAction.deliver:
        return const _DeliverBar();
    }
  }
}

// ── Scan bar ──────────────────────────────────────────────────────────────────

class _ScanBar extends StatelessWidget {
  const _ScanBar();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final h = DonyLayout.hPadding(context);
    return Container(
      color: cs.surface,
      padding: EdgeInsets.fromLTRB(
        h,
        DonySpacing.base,
        h,
        MediaQuery.of(context).padding.bottom + DonySpacing.base,
      ),
      // Redirige vers l'étape Départ du hub de scan (identify → photo →
      // confirm), cohérent avec le flux d'étapes du Suivi.
      child: DonyButton(
        label: 'Scanner le colis',
        icon: Icons.qr_code_scanner_rounded,
        onPressed: () => context.push(
          '/tracking/scan/identify',
          extra: <String, dynamic>{'etape': 'DEPART', 'focusNumber': false},
        ),
      ),
    );
  }
}

// ── Deliver bar ───────────────────────────────────────────────────────────────

class _DeliverBar extends StatelessWidget {
  const _DeliverBar();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final h = DonyLayout.hPadding(context);
    return Container(
      color: cs.surface,
      padding: EdgeInsets.fromLTRB(
        h,
        DonySpacing.base,
        h,
        MediaQuery.of(context).padding.bottom + DonySpacing.base,
      ),
      // Redirige vers l'étape Arrivée du hub de scan (identify → confirm), qui
      // dispatche ConfirmDeliveryRequested et libère le paiement — au lieu de
      // l'écran de réception autonome (/tracking/confirm).
      child: DonyButton(
        label: 'Valider la remise',
        icon: Icons.verified_rounded,
        variant: DonyButtonVariant.success,
        onPressed: () => context.push(
          '/tracking/scan/identify',
          extra: <String, dynamic>{'etape': 'ARRIVEE', 'focusNumber': false},
        ),
      ),
    );
  }
}
