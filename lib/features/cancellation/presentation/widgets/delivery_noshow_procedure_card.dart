import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/cancellation/bloc/delivery_noshow_procedure/delivery_noshow_procedure_cubit.dart';
import 'package:dony/features/cancellation/data/models/delivery_noshow_procedure_model.dart';
import 'package:dony/features/cancellation/presentation/widgets/delivery_noshow_cta_cell.dart';
import 'package:dony/features/cancellation/presentation/widgets/retry_appointment_sheet.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/recipient_change_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Procédure « destinataire absent » (FLUTTER-E2) sur la fiche colis.
///
/// - Voyageur, colis arrivé : étapes avant de pouvoir signaler (arrivée
///   déclarée, compteur d'attente, preuve de contact), puis garde du colis et
///   colis « non réclamé ».
/// - Expéditeur, après le signalement du voyageur : nouveau rendez-vous ou
///   changement de destinataire, fin de garde, colis « non réclamé ».
///
/// Back antérieur à la procédure (404) : le voyageur retrouve l'ancien
/// signalement ([DeliveryNoShowCtaCell]), l'expéditeur ne voit rien de plus.
class DeliveryNoShowProcedureCard extends StatelessWidget {
  const DeliveryNoShowProcedureCard({
    super.key,
    required this.bid,
    required this.isSender,
  });

  final BidModel bid;
  final bool isSender;

  /// La carte n'a de sens qu'à l'arrivée (voyageur) ou après un signalement
  /// « destinataire absent » (les deux parties).
  static bool shouldShow(BidModel bid, {required bool isSender}) {
    final reportedByTraveler = bid.deliveryNoShowReportedByTraveler == true;
    if (isSender) return reportedByTraveler;
    return bid.status == 'ARRIVED' || reportedByTraveler;
  }

  @override
  Widget build(BuildContext context) {
    if (!shouldShow(bid, isSender: isSender)) {
      return isSender
          ? const SizedBox.shrink()
          : DeliveryNoShowCtaCell(bid: bid, isSender: false);
    }
    return BlocProvider<DeliveryNoShowProcedureCubit>(
      key: ValueKey('dnp-${bid.id}-${bid.status}-${bid.deliveryNoShowStatus}'),
      create: (_) => getIt<DeliveryNoShowProcedureCubit>()..load(bid.id),
      child: _ProcedureView(bid: bid, isSender: isSender),
    );
  }
}

class _ProcedureView extends StatelessWidget {
  const _ProcedureView({required this.bid, required this.isSender});

  final BidModel bid;
  final bool isSender;

  @override
  Widget build(BuildContext context) {
    return BlocListener<CancellationBloc, CancellationState>(
      listener: (ctx, state) {
        if (state is DeliveryNoShowReported) {
          ctx.read<DeliveryNoShowProcedureCubit>().refresh();
        }
      },
      child:
          BlocBuilder<
            DeliveryNoShowProcedureCubit,
            DeliveryNoShowProcedureState
          >(
            builder: (ctx, state) => switch (state) {
              DeliveryNoShowProcedureLoading() => const SizedBox.shrink(),
              DeliveryNoShowProcedureUnavailable() =>
                isSender
                    ? const SizedBox.shrink()
                    : DeliveryNoShowCtaCell(bid: bid, isSender: false),
              DeliveryNoShowProcedureError() => DonyStatusBanner(
                type: DonyStatusBannerType.warning,
                message: ctx.l10n.dnpLoadError,
                action: TextButton(
                  onPressed: () =>
                      ctx.read<DeliveryNoShowProcedureCubit>().refresh(),
                  child: Text(ctx.l10n.commonRetry),
                ),
              ),
              DeliveryNoShowProcedureLoaded() => _content(ctx, state),
            },
          ),
    );
  }

  Widget _content(BuildContext context, DeliveryNoShowProcedureLoaded state) {
    final p = state.procedure;
    if (p.isUnclaimed) {
      return _UnclaimedCard(bid: bid, isSender: isSender);
    }
    if (isSender) {
      return p.isHolding
          ? _SenderHoldCard(bid: bid, procedure: p)
          : const SizedBox.shrink();
    }
    if (p.reported) {
      return p.isHolding
          ? _TravelerHoldCard(procedure: p)
          : const SizedBox.shrink();
    }
    return _TravelerChecklist(bid: bid, state: state);
  }
}

String formatProcedureDate(BuildContext context, DateTime date) {
  final locale = context.l10n.localeName;
  return DateFormat.MMMEd(locale).add_Hm().format(date.toLocal());
}

class _Step extends StatelessWidget {
  const _Step({required this.done, required this.label, required this.keyName});

  final bool done;
  final String label;
  final String keyName;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      key: Key(keyName),
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 20,
            color: done ? cs.primary : cs.onSurfaceVariant,
          ),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _TravelerChecklist extends StatelessWidget {
  const _TravelerChecklist({required this.bid, required this.state});

  final BidModel bid;
  final DeliveryNoShowProcedureLoaded state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = state.procedure;
    final arrived = p.bidStatus == 'ARRIVED';
    final waitDone = p.waitElapsed;
    final availableAt = p.reportAvailableAt;
    return DonyCard(
      key: const Key('dnp-traveler-checklist'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.dnpTravelerTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: DonySpacing.sm),
          _Step(
            keyName: 'dnp-step-arrival',
            done: arrived,
            label: arrived ? l.dnpStepArrivalDone : l.dnpStepArrivalTodo,
          ),
          _Step(
            keyName: 'dnp-step-wait',
            done: waitDone,
            label: waitDone || availableAt == null
                ? l.dnpStepWaitDone
                : l.dnpStepWaitPending(
                    '${state.remainingWaitMinutes}',
                    DateFormat.Hm(l.localeName).format(availableAt.toLocal()),
                  ),
          ),
          _Step(
            keyName: 'dnp-step-contact',
            done: p.hasContactProof,
            label: p.hasContactProof
                ? l.dnpStepContactDone
                : l.dnpStepContactTodo,
          ),
          const SizedBox(height: DonySpacing.md),
          DonyButton(
            key: const Key('dnp-report'),
            label: l.dnpReportAction,
            variant: DonyButtonVariant.destructive,
            onPressed: p.canReport ? () => _openReportSheet(context, p) : null,
          ),
        ],
      ),
    );
  }

  Future<void> _openReportSheet(
    BuildContext context,
    DeliveryNoShowProcedureModel procedure,
  ) async {
    final bloc = context.read<CancellationBloc>();
    final l = context.l10n;
    // Seul le tap sur la case y écrit : la disposition au pop est sûre.
    final confirmed = ValueNotifier<bool>(false);
    final send = await DonyBottomSheet.show<bool>(
      context,
      title: l.deliveryNoShowRecipientAbsentSheetTitle,
      stickyBottom: ValueListenableBuilder<bool>(
        valueListenable: confirmed,
        builder: (ctx, checked, _) => DonyButton(
          key: const Key('dnp-report-confirm'),
          label: l.deliveryNoShowConfirmReportAction,
          iconAsset: 'user-x',
          onPressed: checked
              ? () => Navigator.of(ctx, rootNavigator: true).pop(true)
              : null,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.dnpSheetBody('${procedure.holdDays}'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: DonySpacing.md),
            ValueListenableBuilder<bool>(
              valueListenable: confirmed,
              builder: (_, checked, _) => DonyCheckbox(
                key: const Key('dnp-confirm-checkbox'),
                label: l.dnpConfirmCheckbox,
                value: checked,
                onChanged: (v) => confirmed.value = v ?? false,
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(confirmed.dispose);
    if (send == true) {
      bloc.add(DeliveryNoShowReportRequested(bid.id, contactConfirmed: true));
    }
  }
}

class _TravelerHoldCard extends StatelessWidget {
  const _TravelerHoldCard({required this.procedure});

  final DeliveryNoShowProcedureModel procedure;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final appointment = procedure.retryAppointmentAt;
    return DonyStatusBanner(
      key: const Key('dnp-traveler-hold'),
      type: DonyStatusBannerType.info,
      title: l.dnpHoldTravelerTitle,
      message: [
        l.dnpHoldTraveler(formatProcedureDate(context, procedure.holdUntil!)),
        if (appointment != null)
          l.dnpRetryAppointment(formatProcedureDate(context, appointment)),
        if (appointment != null &&
            (procedure.retryAppointmentNote ?? '').isNotEmpty)
          procedure.retryAppointmentNote!,
      ].join('\n'),
    );
  }
}

class _SenderHoldCard extends StatelessWidget {
  const _SenderHoldCard({required this.bid, required this.procedure});

  final BidModel bid;
  final DeliveryNoShowProcedureModel procedure;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final appointment = procedure.retryAppointmentAt;
    return DonyCard(
      key: const Key('dnp-sender-hold'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.dnpSenderTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            l.dnpSenderHold(formatProcedureDate(context, procedure.holdUntil!)),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (appointment != null) ...[
            const SizedBox(height: DonySpacing.sm),
            Text(
              l.dnpRetryAppointment(formatProcedureDate(context, appointment)),
              key: const Key('dnp-sender-appointment'),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
          if (procedure.canSetRetryAppointment) ...[
            const SizedBox(height: DonySpacing.md),
            DonyButton(
              key: const Key('dnp-set-appointment'),
              label: l.dnpSetAppointmentAction,
              onPressed: () => RetryAppointmentSheet.show(
                context,
                cubit: context.read<DeliveryNoShowProcedureCubit>(),
                holdUntil: procedure.holdUntil!,
              ),
            ),
            if (bid.canChangeRecipient) ...[
              const SizedBox(height: DonySpacing.sm),
              DonyButton(
                key: const Key('dnp-change-recipient'),
                label: l.dnpChangeRecipientAction,
                variant: DonyButtonVariant.secondary,
                onPressed: () => openRecipientChangeSheet(context, bid),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _UnclaimedCard extends StatelessWidget {
  const _UnclaimedCard({required this.bid, required this.isSender});

  final BidModel bid;
  final bool isSender;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return DonyStatusBanner(
      key: const Key('dnp-unclaimed'),
      type: DonyStatusBannerType.warning,
      title: l.dnpUnclaimedTitle,
      message: isSender ? l.dnpUnclaimedSender : l.dnpUnclaimedTraveler,
      // Retrait par une personne mandatée : l'expéditeur la désigne comme
      // destinataire (nouveau code de retrait).
      action: isSender && bid.canChangeRecipient
          ? TextButton(
              key: const Key('dnp-unclaimed-change-recipient'),
              onPressed: () => openRecipientChangeSheet(context, bid),
              child: Text(l.dnpChangeRecipientAction),
            )
          : null,
    );
  }
}
