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
/// motif et message du voyageur. Tant que la décision est ouverte,
/// l'expéditeur garde son colis ou se retire sans frais ; le voyageur voit
/// jusqu'à quand il attend la réponse.
class TripRescheduleCard extends StatelessWidget {
  const TripRescheduleCard({
    super.key,
    required this.bid,
    required this.isSender,
  });

  final BidModel bid;
  final bool isSender;

  /// La carte n'a de sens que si le trajet a été reporté.
  static bool shouldShow(BidModel bid) => bid.reschedule != null;

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
    if (confirmed ?? false) {
      bloc.add(RescheduleDecisionRequested(bid.id, keep: false));
    }
  }

  @override
  Widget build(BuildContext context) {
    final TripRescheduleInfo r = bid.reschedule!;
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final pending = r.decisionPending;
    final deadline = r.decisionDeadline == null
        ? ''
        : DateFormat.MMMEd(l.localeName).add_Hm().format(r.decisionDeadline!);
    return DonyCard(
      key: const Key('trip-reschedule-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          if (pending && isSender) ...[
            const SizedBox(height: DonySpacing.md),
            BlocBuilder<CancellationBloc, CancellationState>(
              builder: (context, state) {
                final loading = state is CancellationLoading;
                return Column(
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
                      onPressed: loading
                          ? null
                          : () => _confirmWithdraw(context),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
