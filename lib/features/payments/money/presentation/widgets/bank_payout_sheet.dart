import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/connect_onboarding/bloc/bank_account_link_cubit.dart';
import 'package:dony/features/connect_onboarding/presentation/widgets/change_bank_account_button.dart';
import 'package:dony/features/payments/money/data/models/money_overview_model.dart';
import 'package:dony/features/payments/money/presentation/money_labels.dart';
import 'package:dony/features/payments/money/presentation/screens/money_overview_screen.dart';
import 'package:dony/features/payments/money/presentation/widgets/money_amount_lines.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Tap sur un colis de « Mon argent » ou « Mes trajets » : la feuille du
/// virement bancaire quand le back le suit, sinon le colis (`/bids/:id`).
void openMoneyItem(BuildContext context, MoneyItemModel item) {
  if (item.trackedBankPayout != null) {
    unawaited(BankPayoutSheet.show(context, item));
  } else {
    unawaited(pushAndRefreshMoney(context, '/bids/${item.bidId}'));
  }
}

/// État d'une étape de la frise du virement.
enum BankPayoutStepState { done, current, failed, todo }

/// Une étape de la frise : libellé et état.
typedef BankPayoutStep = ({String label, BankPayoutStepState state});

/// Les quatre étapes de l'argent d'un colis versé : payé sur le compte Stripe,
/// disponible, virement vers la banque, arrivé sur la banque.
List<BankPayoutStep> bankPayoutSteps(MoneyItemModel item, AppLocalizations l) {
  final payout = item.bankPayout;
  final status = payout?.status ?? BankPayoutStatus.unknown;
  String? day(DateTime? d) => d == null ? null : shortDate(d, l);

  final paidOn = day(item.settledAt);
  final availableOn = day(payout?.availableOn);
  final arrival = day(payout?.arrivalDate);
  final arrived = day(payout?.arrivedOn);

  const done = BankPayoutStepState.done;
  const current = BankPayoutStepState.current;
  const todo = BankPayoutStepState.todo;
  final states = switch (status) {
    BankPayoutStatus.pendingAvailability => [done, current, todo, todo],
    BankPayoutStatus.available ||
    BankPayoutStatus.inTransit => [done, done, current, todo],
    BankPayoutStatus.paid => [done, done, done, done],
    BankPayoutStatus.failed => [done, done, BankPayoutStepState.failed, todo],
    BankPayoutStatus.unknown => [done, todo, todo, todo],
  };
  final transfer = switch (status) {
    BankPayoutStatus.failed => l.moneyBankStepFailed,
    BankPayoutStatus.paid => l.moneyBankStepTransferSent,
    _ when arrival != null => l.moneyBankStepInTransit(arrival),
    _ => l.moneyBankStepInTransitNoDate,
  };
  return [
    (
      label: paidOn == null
          ? l.moneyBankStepPaidToStripeNoDate
          : l.moneyBankStepPaidToStripe(paidOn),
      state: states[0],
    ),
    (
      label: availableOn == null
          ? l.moneyBankStepAvailableNoDate
          : l.moneyBankStepAvailable(availableOn),
      state: states[1],
    ),
    (label: transfer, state: states[2]),
    (
      label: status == BankPayoutStatus.paid && arrived != null
          ? l.moneyBankStepArrived(arrived)
          : l.moneyBankStepArrivedNoDate,
      state: states[3],
    ),
  ];
}

/// Feuille « Suivi du virement » d'un colis versé : frise des étapes, délai
/// bancaire, et, pour un virement échoué, le changement de compte bancaire.
abstract final class BankPayoutSheet {
  static Future<void> show(BuildContext context, MoneyItemModel item) {
    final l = context.l10n;
    final failed = item.bankPayout?.status == BankPayoutStatus.failed;
    final amount = item.amount;
    final subtitle = [
      ?item.trackingNumber,
      if (amount != null) formatMoney(amount, item.currency),
    ].join(' · ');
    return DonyBottomSheet.show<void>(
      context,
      title: l.moneyBankSheetTitle,
      subtitle: subtitle.isEmpty ? null : subtitle,
      analyticsName: 'money/bank-payout', // i18n-ignore : nom analytics
      stickyBottom: Builder(
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (failed) ...[
              ChangeBankAccountButton(
                source: BankAccountLinkSource.bankPayoutSheet,
                variant: DonyButtonVariant.primary,
                onOnboardingRequired: () {
                  sheetContext.pop();
                  unawaited(pushAndRefreshMoney(context, kPayoutsRoute));
                },
              ),
              const SizedBox(height: DonySpacing.sm),
            ],
            DonyButton(
              key: const Key('bank-payout-open-parcel'),
              label: l.moneyBankOpenParcel,
              variant: failed
                  ? DonyButtonVariant.ghost
                  : DonyButtonVariant.secondary,
              onPressed: () {
                sheetContext.pop();
                unawaited(pushAndRefreshMoney(context, '/bids/${item.bidId}'));
              },
            ),
          ],
        ),
      ),
      child: BankPayoutTimeline(item: item),
    );
  }
}

/// Frise verticale des étapes, l'étape courante mise en avant, suivie de la
/// phrase d'aide sur le délai bancaire.
class BankPayoutTimeline extends StatelessWidget {
  const BankPayoutTimeline({super.key, required this.item});

  final MoneyItemModel item;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final steps = bankPayoutSteps(item, l);
    final failed = item.bankPayout?.status == BankPayoutStatus.failed;

    return Column(
      key: const Key('bank-payout-timeline'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < steps.length; i++)
          _StepRow(
            step: steps[i],
            isLast: i == steps.length - 1,
            // Ligne vers l'étape suivante : pleine quand celle-ci est atteinte.
            nextReached:
                i < steps.length - 1 &&
                steps[i + 1].state != BankPayoutStepState.todo,
            highlighted:
                steps[i].state == BankPayoutStepState.current ||
                steps[i].state == BankPayoutStepState.failed ||
                (i == steps.length - 1 &&
                    steps[i].state == BankPayoutStepState.done),
          ),
        const SizedBox(height: DonySpacing.base),
        Container(
          padding: const EdgeInsets.all(DonySpacing.md),
          decoration: BoxDecoration(
            color: failed ? cs.warningLight : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(DonyRadius.md),
          ),
          child: Text(
            failed ? l.moneyBankHelpFailed : l.moneyBankHelp,
            key: const Key('bank-payout-help'),
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.isLast,
    required this.nextReached,
    required this.highlighted,
  });

  final BankPayoutStep step;
  final bool isLast;
  final bool nextReached;
  final bool highlighted;

  static const double _marker = 22;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final (Color fill, Color border, IconData? icon) = switch (step.state) {
      BankPayoutStepState.done => (cs.success, cs.success, Icons.check_rounded),
      BankPayoutStepState.current => (cs.surface, cs.primary, null),
      BankPayoutStepState.failed => (cs.error, cs.error, Icons.close_rounded),
      BankPayoutStepState.todo => (cs.surface, cs.outline, null),
    };
    final semantics = switch (step.state) {
      BankPayoutStepState.done => l.moneyBankStepDoneSemantics(step.label),
      BankPayoutStepState.current => l.moneyBankStepCurrentSemantics(
        step.label,
      ),
      BankPayoutStepState.failed => l.moneyBankStepFailedSemantics(step.label),
      BankPayoutStepState.todo => l.moneyBankStepTodoSemantics(step.label),
    };
    final labelColor = switch (step.state) {
      BankPayoutStepState.todo => cs.onSurfaceVariant,
      BankPayoutStepState.failed => cs.error,
      _ => cs.onSurface,
    };

    return Semantics(
      label: semantics,
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: _marker,
              child: Column(
                children: [
                  Container(
                    key: Key('bank-step-${step.state.name}'),
                    width: _marker,
                    height: _marker,
                    decoration: BoxDecoration(
                      color: fill,
                      shape: BoxShape.circle,
                      border: Border.all(color: border, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: icon != null
                        ? Icon(
                            icon,
                            size: 14,
                            color: step.state == BankPayoutStepState.failed
                                ? cs.onError
                                : cs.onPrimary,
                          )
                        : step.state == BankPayoutStepState.current
                        ? Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: cs.primary,
                              shape: BoxShape.circle,
                            ),
                          )
                        : null,
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        color:
                            nextReached &&
                                step.state == BankPayoutStepState.done
                            ? cs.success
                            : cs.outlineVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: DonySpacing.md),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  top: 1,
                  bottom: isLast ? 0 : DonySpacing.base,
                ),
                child: Text(
                  step.label,
                  style: tt.bodyMedium?.copyWith(
                    color: labelColor,
                    fontWeight: highlighted ? FontWeight.w700 : FontWeight.w400,
                    fontFeatures: kTabularFigures,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
