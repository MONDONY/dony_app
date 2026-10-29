import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/trip_reschedule_info.dart';
import 'package:dony/features/matching/data/models/trip_reschedule_result.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// « Trajet reporté » dans le suivi d'un colis : ancienne et nouvelle date,
/// motif et message du voyageur. Tant que la décision est ouverte, la carte dit
/// jusqu'à quand : l'expéditeur répond depuis la tuile « À traiter » (boutons
/// [TripRescheduleDecisionButtons] dans le pied du sheet), le voyageur voit
/// jusqu'à quand il attend la réponse.
class TripRescheduleCard extends StatelessWidget {
  const TripRescheduleCard({
    super.key,
    required this.bid,
    required this.isSender,
    this.framed = true,
  });

  final BidModel bid;
  final bool isSender;

  /// `false` dans le sheet de la tuile « À traiter » : ni cadre ni titre, le
  /// sheet porte le titre.
  final bool framed;

  /// La carte n'a de sens que si le trajet a été reporté.
  static bool shouldShow(BidModel bid) => bid.reschedule != null;

  /// La décision est encore ouverte : l'expéditeur garde son colis ou se retire
  /// (tuile « À traiter »). Une fois décidé, la carte ne fait que renseigner.
  static bool needsReply(BidModel bid) =>
      bid.reschedule?.decisionPending ?? false;

  static String reasonLabel(BuildContext context, String reason) {
    final l = context.l10n;
    return switch (TripRescheduleReason.fromWire(reason)) {
      TripRescheduleReason.flightCancelled =>
        l.tripRescheduleReasonFlightCancelled,
      TripRescheduleReason.postponed => l.tripRescheduleReasonPostponed,
      _ => l.tripRescheduleReasonOther,
    };
  }

  String _date(BuildContext context, DateTime? date) => date == null
      ? ''
      : DateFormat.MMMEd(context.l10n.localeName).format(date);

  @override
  Widget build(BuildContext context) {
    final TripRescheduleInfo r = bid.reschedule!;
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final pending = r.decisionPending;
    final deadline = r.decisionDeadline == null
        ? ''
        // Envoyée en UTC depuis yadony-back #627 (PROD-1R) : heure de
        // l'appareil, le colis ne porte pas le fuseau du trajet.
        : DateFormat.MMMEd(
            l.localeName,
          ).add_Hm().format(r.decisionDeadline!.toLocal());
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (framed) ...[
          Row(
            children: [
              DonyIcon(
                'calendar-sync',
                size: 20,
                color: pending ? cs.tertiary : cs.primary,
              ),
              const SizedBox(width: DonySpacing.sm),
              Expanded(child: Text(l.bidRescheduleTitle, style: tt.titleSmall)),
            ],
          ),
          const SizedBox(height: DonySpacing.sm),
        ],
        Text(
          l.bidRescheduleBody(
            _date(context, r.previousDepartureDate),
            _date(context, r.newDepartureDate),
            // Libellé de puce (« Vol annulé ») repris en milieu de phrase.
            reasonLabel(context, r.reason).toLowerCase(),
          ),
          style: tt.bodyMedium,
        ),
        if (r.note != null && r.note!.trim().isNotEmpty) ...[
          const SizedBox(height: DonySpacing.xs),
          Text(
            l.bidRescheduleNote(r.note!.trim()),
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        if (pending) ...[
          const SizedBox(height: DonySpacing.sm),
          Text(
            isSender
                ? l.bidRescheduleDecisionHint(deadline)
                : l.bidRescheduleTravelerHint(deadline),
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ],
    );
    if (!framed) return content;
    return DonyCard(key: const Key('trip-reschedule-card'), child: content);
  }
}

/// Réponse de l'expéditeur au report, empilée en pleine largeur (libellés
/// longs) : « Garder mon colis » en haut, « Annuler sans frais » dessous,
/// après une confirmation. Passe par le [CancellationBloc] de l'écran, dont
/// l'écouteur affiche la confirmation et recharge le colis.
class TripRescheduleDecisionButtons extends StatelessWidget {
  const TripRescheduleDecisionButtons({super.key, required this.bid});

  final BidModel bid;

  Future<void> _confirmWithdraw(BuildContext context) async {
    final l = context.l10n;
    final bloc = context.read<CancellationBloc>();
    final confirmed = await DonyDialog.show(
      context,
      title: l.bidRescheduleWithdrawConfirmTitle,
      message: bid.status == 'HANDED_OVER'
          ? l.bidRescheduleWithdrawConfirmReturnMessage
          : l.bidRescheduleWithdrawConfirmMessage,
      confirmLabel: l.bidRescheduleWithdraw,
      cancelLabel: l.commonCancel,
      variant: DonyDialogVariant.destructive,
    );
    // Décision prise ailleurs pendant la confirmation : le pied a retiré les
    // boutons (démontés), rien à envoyer. Le sheet se referme de lui-même en
    // revenant au premier plan.
    if (!context.mounted) return;
    if (confirmed ?? false) {
      bloc.add(RescheduleDecisionRequested(bid.id, keep: false));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return BlocBuilder<CancellationBloc, CancellationState>(
      builder: (context, state) {
        final loading = state is CancellationLoading;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DonyButton(
              key: const Key('reschedule-keep'),
              label: l.bidRescheduleKeep,
              isLoading: loading,
              onPressed: loading
                  ? null
                  : () => context.read<CancellationBloc>().add(
                      RescheduleDecisionRequested(bid.id, keep: true),
                    ),
            ),
            const SizedBox(height: DonySpacing.sm),
            DonyButton(
              key: const Key('reschedule-withdraw'),
              label: l.bidRescheduleWithdraw,
              variant: DonyButtonVariant.secondary,
              onPressed: loading ? null : () => _confirmWithdraw(context),
            ),
          ],
        );
      },
    );
  }
}
