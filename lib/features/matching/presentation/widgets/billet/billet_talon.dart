import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/qr_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/retrait_code_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/return_code_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/billet/talon_tracking_strip.dart';
import 'package:flutter/material.dart';

/// Zone action + bande de suivi du talon bas du billet de colis.
///
/// Dispatcher : selon [bid.status] × [isSender], affiche le bon contenu
/// d'action (QR, code retrait, scan, confirmation, placeholder, done…).
/// Si [bid.trackingNumber] est non-null, la [TalonTrackingStrip] est
/// toujours ajoutée en bas, quelle que soit l'action.
///
/// NOTE : les boutons [_QrTalonButton] et [_RetraitTalonButton] ouvrent
/// respectivement la [QrSheet] et la [RetraitCodeSheet] ; les BLoCs ambiants
/// (TrackingBloc / BidBloc) sont fournis par l'écran parent. Ce widget
/// n'injecte aucun [BlocProvider].
class BilletTalon extends StatelessWidget {
  final BidModel bid;
  final bool isSender;

  const BilletTalon({super.key, required this.bid, required this.isSender});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(DonyRadius.card),
          bottomRight: Radius.circular(DonyRadius.card),
        ),
      ),
      padding: const EdgeInsets.all(DonySpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildActionZone(context),
          if (bid.trackingNumber != null) ...[
            const SizedBox(height: DonySpacing.md),
            TalonTrackingStrip(trackingNumber: bid.trackingNumber!),
          ],
        ],
      ),
    );
  }

  Widget _buildActionZone(BuildContext context) {
    final status = bid.status;

    // ── Sender dispatch ───────────────────────────────────────────────────────
    if (isSender) {
      return switch (status) {
        'PENDING' ||
        'AWAITING_PAYMENT' ||
        'PAYMENT_ESCROWED' => const _PendingPlaceholder(),
        'ACCEPTED' => _QrTalonButton(bid: bid),
        // Le code de retrait existe dès la remise (HANDED_OVER). Comme le QR,
        // il s'ouvre dans un bottom sheet : deux boutons côte à côte dans le
        // talon, le QR restant accessible jusqu'au retrait.
        'HANDED_OVER' ||
        'IN_TRANSIT' when bid.confirmationCode != null => Row(
          children: [
            Expanded(child: _QrTalonButton(bid: bid, compact: true)),
            const SizedBox(width: DonySpacing.sm),
            Expanded(child: _RetraitTalonButton(bid: bid)),
          ],
        ),
        // Code pas encore disponible → bouton QR seul, pleine largeur.
        'HANDED_OVER' || 'IN_TRANSIT' => _QrTalonButton(bid: bid, compact: true),
        'COMPLETED' || 'DELIVERED' => const _DoneBlock(),
        'CANCELLED' => _CancelledBlock(bid: bid, isSender: true),
        'REJECTED' => const _TerminalBlock(),
        _ => const SizedBox.shrink(),
      };
    }

    // ── Traveler dispatch (passif — l'action vit dans la barre collante) ────────
    return switch (status) {
      'PENDING' => _TravelerDecisionSummary(bid: bid),
      // ACCEPTED / HANDED_OVER / IN_TRANSIT : plus d'action dans le talon.
      // Seule la bande de suivi (TalonTrackingStrip) subsiste, ajoutée par
      // le parent quand trackingNumber != null.
      'ACCEPTED' || 'HANDED_OVER' || 'IN_TRANSIT' => const SizedBox.shrink(),
      'COMPLETED' || 'DELIVERED' => const _DoneBlock(),
      'CANCELLED' => _CancelledBlock(bid: bid, isSender: false),
      'REJECTED' => const _TerminalBlock(),
      _ => const SizedBox.shrink(),
    };
  }
}

/// any / CANCELLED — selon l'état de la restitution (annulation après remise, D7) :
/// - colis restitué → bloc « Colis restitué » ;
/// - retour en attente → action code de retour (afficher côté expéditeur, saisir
///   côté voyageur) ;
/// - sinon (annulation pré-remise classique) → message terminal neutre.
class _CancelledBlock extends StatelessWidget {
  final BidModel bid;
  final bool isSender;

  const _CancelledBlock({required this.bid, required this.isSender});

  @override
  Widget build(BuildContext context) {
    if (bid.isParcelReturned) {
      return const _ReturnedBlock();
    }
    if (!bid.isAwaitingReturn) {
      return const _TerminalBlock();
    }
    final cs = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: () => isSender
          ? ReturnCodeSheet.show(context, bid: bid)
          : ReturnEntrySheet.show(context, bid: bid),
      icon: Icon(
        isSender ? Icons.vpn_key_rounded : Icons.assignment_turned_in_rounded,
        size: 20,
        color: cs.primary,
      ),
      label: Text(
        isSender ? 'Code de retour' : 'Confirmer le retour',
        textAlign: TextAlign.center,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: cs.primary,
        side: BorderSide(color: cs.primary),
        padding: const EdgeInsets.symmetric(vertical: DonySpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
        ),
      ),
    );
  }
}

/// any / CANCELLED + colis restitué — check vert + « Colis restitué ».
class _ReturnedBlock extends StatelessWidget {
  const _ReturnedBlock();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: DonySpacing.sm),
        Icon(Icons.check_circle_rounded, size: 40, color: cs.success),
        const SizedBox(height: DonySpacing.sm),
        Text(
          'Colis restitué',
          textAlign: TextAlign.center,
          style: tt.bodyMedium?.copyWith(
            color: cs.success,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: DonySpacing.sm),
      ],
    );
  }
}

// ── Inline helper widgets ─────────────────────────────────────────────────────

/// sender / ACCEPTED · HANDED_OVER · IN_TRANSIT — bouton d'ouverture de la
/// [QrSheet] (QR du colis à présenter ou à coller).
///
/// En mode [compact] (côté IN_TRANSIT, à côté du code retrait), le label est
/// raccourci pour tenir dans une largeur contrainte ([Expanded]).
class _QrTalonButton extends StatelessWidget {
  final BidModel bid;
  final bool compact;

  const _QrTalonButton({required this.bid, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: () => QrSheet.show(context, bidId: bid.id, status: bid.status),
      icon: Icon(Icons.qr_code_2_rounded, size: 20, color: cs.primary),
      label: Text(
        compact
            ? 'QR du colis'
            : 'QR du colis — à présenter ou coller sur le colis',
        textAlign: TextAlign.center,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: cs.primary,
        side: BorderSide(color: cs.primary),
        padding: const EdgeInsets.symmetric(vertical: DonySpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
        ),
      ),
    );
  }
}

/// Bouton talon « Code de retrait » — ouvre la [RetraitCodeSheet].
///
/// Même comportement que [_QrTalonButton] : un bottom sheet porte le contenu
/// (digits, copier, régénérer, explication).
class _RetraitTalonButton extends StatelessWidget {
  final BidModel bid;

  const _RetraitTalonButton({required this.bid});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: () => RetraitCodeSheet.show(context, bid: bid),
      icon: Icon(Icons.pin_rounded, size: 20, color: cs.primary),
      label: const Text('Code de retrait', textAlign: TextAlign.center),
      style: OutlinedButton.styleFrom(
        foregroundColor: cs.primary,
        side: BorderSide(color: cs.primary),
        padding: const EdgeInsets.symmetric(vertical: DonySpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
        ),
      ),
    );
  }
}

/// sender / PENDING — Hourglass + "En attente de confirmation du voyageur".
class _PendingPlaceholder extends StatelessWidget {
  const _PendingPlaceholder();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: DonySpacing.sm),
        Icon(Icons.hourglass_top_rounded, size: 32, color: cs.onSurfaceVariant),
        const SizedBox(height: DonySpacing.sm),
        Text(
          'En attente de confirmation du voyageur',
          textAlign: TextAlign.center,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: DonySpacing.sm),
      ],
    );
  }
}

/// any / COMPLETED or DELIVERED — green check + "Colis livré".
class _DoneBlock extends StatelessWidget {
  const _DoneBlock();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: DonySpacing.sm),
        Icon(Icons.check_circle_rounded, size: 40, color: cs.success),
        const SizedBox(height: DonySpacing.sm),
        Text(
          'Colis livré',
          textAlign: TextAlign.center,
          style: tt.bodyMedium?.copyWith(
            color: cs.success,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: DonySpacing.sm),
      ],
    );
  }
}

/// any / REJECTED or CANCELLED — muted terminal message.
class _TerminalBlock extends StatelessWidget {
  const _TerminalBlock();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.sm),
      child: Text(
        'Cette demande est terminée.',
        textAlign: TextAlign.center,
        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
    );
  }
}

/// traveler / PENDING — 3 mini-stats : poids, valeur, catégorie.
class _TravelerDecisionSummary extends StatelessWidget {
  final BidModel bid;
  const _TravelerDecisionSummary({required this.bid});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    final weight = bid.weightKg != null
        ? '${bid.weightKg!.toStringAsFixed(1)} kg'
        : '—';
    final value = bid.declaredValueEur != null
        ? '${bid.declaredValueEur!.toStringAsFixed(0)} €'
        : '—';
    final category = bid.contentCategory ?? '—';

    return Row(
      children: [
        _MiniStat(value: weight, label: 'POIDS', tt: tt),
        _MiniStat(value: value, label: 'VALEUR', tt: tt),
        _MiniStat(value: category, label: 'TYPE', tt: tt),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  final TextTheme tt;

  const _MiniStat({required this.value, required this.label, required this.tt});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            // Une seule ligne : une catégorie multi-valeurs (« Vêtements,
            // Médicaments… ») ne doit pas wrapper sur 2-4 lignes et
            // désaligner les 3 colonnes du talon.
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            label,
            textAlign: TextAlign.center,
            // bodySmall = 12px — plancher HIG ≥ 12px
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
