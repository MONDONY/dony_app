// dony_app/lib/features/settings/presentation/widgets/delete_account_bottom_sheet.dart
import 'dart:async';

import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/settings/bloc/account_deletion_bloc.dart';
import 'package:dony/features/settings/bloc/deletion_eligibility_cubit.dart';
import 'package:dony/features/settings/data/account_deletion_repository.dart';
import 'package:dony/features/settings/presentation/deletion_labels.dart';
import 'package:dony/features/settings/presentation/widgets/delete_confirmation_sheet.dart';
import 'package:dony/features/settings/presentation/widgets/escrow_block_dialog.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DeleteAccountBottomSheet extends StatefulWidget {
  final ValueNotifier<DeleteMode?> modeNotifier;
  final void Function(VoidCallback)? onSubmitReady;

  const DeleteAccountBottomSheet({
    super.key,
    required this.modeNotifier,
    this.onSubmitReady,
  });

  static Future<void> show(
    BuildContext context, {
    DeletionEligibilityCubit? eligibilityCubit,
  }) {
    final deletionBloc = context.read<AccountDeletionBloc>();
    final cubit =
        eligibilityCubit ??
        DeletionEligibilityCubit(
          getIt<AccountDeletionRepository>(),
          getIt<AnalyticsService>(),
        );
    cubit.check();
    final modeNotifier = ValueNotifier<DeleteMode?>(null);
    VoidCallback? submit;

    return DonyBottomSheet.show(
      context,
      title: context.l10n.deletionSheetTitle,
      wrapper: (child) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: deletionBloc),
          BlocProvider.value(value: cubit),
        ],
        child: child,
      ),
      stickyBottom: _DeleteActions(
        modeNotifier: modeNotifier,
        onSubmit: () => submit?.call(),
      ),
      child: DeleteAccountBottomSheet(
        modeNotifier: modeNotifier,
        onSubmitReady: (fn) => submit = fn,
      ),
    ).whenComplete(() {
      modeNotifier.dispose();
      // Ne ferme que le cubit créé ici — un cubit injecté (tests) reste géré
      // par son propriétaire.
      if (eligibilityCubit == null) {
        cubit.close();
      }
    });
  }

  @override
  State<DeleteAccountBottomSheet> createState() =>
      _DeleteAccountBottomSheetState();
}

class _DeleteAccountBottomSheetState extends State<DeleteAccountBottomSheet> {
  String? _reason;

  @override
  void initState() {
    super.initState();
    widget.onSubmitReady?.call(_confirm);
  }

  void _confirm() {
    final bloc = context.read<AccountDeletionBloc>();
    final mode = widget.modeNotifier.value;

    if (mode == DeleteMode.soft) {
      final l = context.l10n;
      // Dialog shown while sheet is still mounted so context stays valid.
      // BlocListener catches AccountDeletionRequested (below) to close the sheet
      // and show the snackbar while still in the tree.
      DonyDialog.show(
        context,
        title: l.deletionSoftConfirmLabel,
        message: l.deletionSoftConfirmDialogMessage,
        iconAsset: 'hourglass',
      ).then((confirmed) {
        if (confirmed == true && mounted) bloc.add(const RequestDeletion());
      });
    } else if (mode == DeleteMode.hard) {
      final hardBloc = bloc;
      Navigator.of(context, rootNavigator: true).pop();
      DeleteConfirmationSheet.show(context, hardBloc);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final walletSettlement = context
        .watch<DeletionEligibilityCubit>()
        .state
        .walletSettlement;

    return BlocListener<AccountDeletionBloc, AccountDeletionState>(
      listener: (context, state) {
        if (state is AccountDeletionRequested) {
          Navigator.of(context, rootNavigator: true).pop();
          DonySnackbar.show(
            context,
            message: context.l10n.deletionRequestedSnackbar,
          );
        } else if (state is AccountDeletionError && state.isEscrowBlocked) {
          EscrowBlockDialog.show(context);
        } else if (state is AccountDeletionError) {
          ErrorPresenter.show(context, state.error);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (walletSettlement != null && walletSettlement.isNotEmpty) ...[
            _WalletSettlementSummary(walletSettlement),
            const SizedBox(height: DonySpacing.lg),
          ],
          _ModeCard(
            mode: DeleteMode.soft,
            modeNotifier: widget.modeNotifier,
            iconAsset: 'hourglass',
            title: l.deletionModeSoftTitle,
            badge: l.deletionModeSoftBadge,
            isDestructive: false,
            description: l.deletionModeSoftDescription,
          ),
          const SizedBox(height: DonySpacing.md),
          _ModeCard(
            mode: DeleteMode.hard,
            modeNotifier: widget.modeNotifier,
            iconAsset: 'trash',
            title: l.deletionModeHardTitle,
            badge: l.deletionModeHardBadge,
            isDestructive: true,
            description: l.deletionModeHardDescription,
          ),
          const SizedBox(height: DonySpacing.lg),
          Text(l.deletionReasonSectionTitle, style: tt.titleSmall),
          const SizedBox(height: DonySpacing.sm),
          DonyRadioGroup<String>(
            value: _reason,
            onChanged: (v) => setState(() => _reason = v),
            options: [
              DonyRadioOption(
                value:
                    "Je n'utilise plus le service", // i18n-ignore: motif envoyé au serveur (valeur de donnée)
                label: l.deletionReasonNotUsing,
              ),
              DonyRadioOption(
                value:
                    'Problème de confidentialité', // i18n-ignore: motif envoyé au serveur (valeur de donnée)
                label: l.deletionReasonPrivacy,
              ),
              DonyRadioOption(
                value:
                    'Trop de notifications', // i18n-ignore: motif envoyé au serveur (valeur de donnée)
                label: l.deletionReasonTooManyNotifications,
              ),
              DonyRadioOption(
                value:
                    'Autre raison', // i18n-ignore: motif envoyé au serveur (valeur de donnée)
                label: l.deletionReasonOther,
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.xl),
        ],
      ),
    );
  }
}

/// Barre d'actions collée en bas de la sheet : motif de blocage éventuel +
/// boutons Annuler / valider.
class _DeleteActions extends StatelessWidget {
  final ValueNotifier<DeleteMode?> modeNotifier;
  final VoidCallback onSubmit;

  const _DeleteActions({required this.modeNotifier, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final eligibility = context.watch<DeletionEligibilityCubit>().state;
    final isSubmitting =
        context.watch<AccountDeletionBloc>().state is AccountDeletionLoading;
    final blockedReason = eligibility.canDelete
        ? null
        : deletionBlockedMessage(l, eligibility.blockedReasonCode);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Bloqué par le backend (escrow actif, solde wallet...) : on l'explique
        // ICI, à côté du bouton, plutôt que de laisser l'utilisateur tenter
        // puis échouer.
        if (blockedReason != null) ...[
          DonyStatusBanner(
            type: DonyStatusBannerType.error,
            iconAsset: 'lock',
            message: blockedReason,
          ),
          const SizedBox(height: DonySpacing.sm),
        ],
        if (eligibility.hasWalletBalance &&
            eligibility.walletSettlement == null) ...[
          _WalletRefundRequestCta(),
          const SizedBox(height: DonySpacing.sm),
        ],
        ValueListenableBuilder<DeleteMode?>(
          valueListenable: modeNotifier,
          builder: (context, mode, _) {
            final isHard = mode == DeleteMode.hard;
            return Row(
              children: [
                Expanded(
                  child: DonyButton(
                    label: l.commonCancel,
                    variant: DonyButtonVariant.ghost,
                    onPressed: () =>
                        Navigator.of(context, rootNavigator: true).pop(),
                  ),
                ),
                const SizedBox(width: DonySpacing.sm),
                Expanded(
                  flex: 2,
                  child: DonyButton(
                    label: isHard
                        ? l.deletionContinueArrow
                        : l.deletionSoftConfirmLabel,
                    variant: isHard
                        ? DonyButtonVariant.destructive
                        : DonyButtonVariant.primary,
                    isLoading: isSubmitting,
                    onPressed:
                        mode == null ||
                            isSubmitting ||
                            eligibility.isLoading ||
                            !eligibility.canDelete
                        ? null
                        : onSubmit,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// CTA "Demander le remboursement de mon solde" — apparaît quand l'utilisateur
/// a un solde wallet positif. Purement optionnel : la suppression de compte
/// fonctionne dans tous les cas (Apple 5.1.1(v)) et ouvre déjà ce même ticket
/// automatiquement si l'utilisateur ne le fait pas ici. Bascule en bannière
/// de confirmation une fois le ticket ouvert ; un admin rembourse hors-app
/// puis résout le ticket.
class _WalletRefundRequestCta extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DeletionEligibilityCubit, DeletionEligibilityState>(
      listenWhen: (previous, current) =>
          current.walletRefundError != null &&
          current.walletRefundError != previous.walletRefundError,
      listener: (context, state) {
        if (state.walletRefundError != null) {
          unawaited(ErrorPresenter.show(context, state.walletRefundError));
        }
      },
      builder: (context, state) {
        final l = context.l10n;
        if (state.walletRefundRequested) {
          final amounts = state.walletRefundRequests
              .map(
                (r) => CurrencyFormatter.format(
                  r.amount,
                  SupportedCurrency.fromCodeOrDefault(r.currency),
                ),
              )
              .join(', ');
          return DonyStatusBanner(
            type: DonyStatusBannerType.success,
            iconAsset: 'circle-check',
            message: l.deletionWalletRefundRequestedMessage(amounts),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DonyStatusBanner(
              type: DonyStatusBannerType.info,
              iconAsset: 'wallet',
              message: l.deletionWalletBalanceInfo,
            ),
            const SizedBox(height: DonySpacing.sm),
            DonyButton(
              label: l.deletionRequestRefundNowButton,
              variant: DonyButtonVariant.secondary,
              isLoading: state.isRequestingWalletRefund,
              onPressed: state.isRequestingWalletRefund
                  ? null
                  : () => context
                        .read<DeletionEligibilityCubit>()
                        .requestWalletRefund(),
            ),
          ],
        );
      },
    );
  }
}

/// Récapitulatif par devise de ce que la suppression fera du solde wallet :
/// remboursé sur la carte (rail STRIPE) ou par mobile money (rail PAWAPAY),
/// repris par un membre de l'équipe (rail MANUAL), et bonus perdu à la
/// finalisation. Purement informatif, la suppression déclenche tout côté
/// serveur.
///
/// Deux affichages coexistent par devise, choisis par [WalletSettlement.
/// hasFeeInfo] : tant que le back n'expose pas les frais de remboursement
/// (lot 2 — ancien contrat, ou prod backend gelée), l'écran reste
/// RIGOUREUSEMENT identique à avant (aucun `!`, aucun `?? 0`). Dès que
/// [WalletSettlement.feeAmount] est présent, la devise passe au nouvel
/// affichage (étiquette de rail, montant net, détail des frais ou
/// destination). Le rail MANUAL garde son message inchangé dans tous les cas
/// — même quand le back y attache des frais nuls (devise alimentée à la fois
/// par carte et mobile money, ticket support ouvert côté back).
class _WalletSettlementSummary extends StatelessWidget {
  const _WalletSettlementSummary(this.settlement);

  final List<WalletSettlement> settlement;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // Alimente le bandeau récapitulatif du bas : seules les devises au
    // nouveau contrat et automatiquement remboursées (jamais MANUAL, qui
    // dépend d'un ticket support) y entrent.
    final banner = settlement
        .where((s) => !s.isManual && s.hasFeeInfo)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in settlement) ...[
          if (s.isManual)
            DonyStatusBanner(
              type: DonyStatusBannerType.info,
              iconAsset: 'wallet',
              message: l.deletionManualRailMessage(
                _fmt(s.refundableAmount, s.currency),
              ),
            )
          else if (!s.hasFeeInfo) ...[
            if (s.refundableAmount > 0)
              DonyStatusBanner(
                type: DonyStatusBannerType.info,
                iconAsset: 'wallet',
                message: l.deletionRefundableOnCardMessage(
                  _fmt(s.refundableAmount, s.currency),
                ),
              ),
          ] else
            _RailAmountBlock(s),
          if (s.inFlightAmount > 0) ...[
            const SizedBox(height: DonySpacing.xs),
            DonyStatusBanner(
              type: DonyStatusBannerType.info,
              iconAsset: 'history',
              message: l.deletionInFlightMessage(
                _fmt(s.inFlightAmount, s.currency),
              ),
            ),
          ],
          if (s.forfeitedAmount > 0) ...[
            const SizedBox(height: DonySpacing.xs),
            if (!s.isManual && s.hasFeeInfo)
              Text(
                l.deletionBonusLostLabel(_fmt(s.forfeitedAmount, s.currency)),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              DonyStatusBanner(
                type: DonyStatusBannerType.warning,
                iconAsset: 'circle-alert',
                message: l.deletionBonusForfeitedMessage(
                  _fmt(s.forfeitedAmount, s.currency),
                ),
              ),
          ],
          const SizedBox(height: DonySpacing.xs),
        ],
        if (banner.isNotEmpty) _SettlementBanner(banner),
      ],
    );
  }

  static String _fmt(double amount, String currency) =>
      CurrencyFormatter.format(
        amount,
        SupportedCurrency.fromCodeOrDefault(currency),
      );
}

/// Bloc « nouveau contrat » d'une devise : étiquette de rail, montant net en
/// valeur principale, puis le détail des frais (mobile money) ou la
/// destination masquée quand le versement est sans frais.
class _RailAmountBlock extends StatelessWidget {
  const _RailAmountBlock(this.settlement);

  final WalletSettlement settlement;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final net = settlement.netAmount ?? settlement.refundableAmount;
    if (net <= 0) {
      // Un solde entièrement absorbé par les frais ne disparaît pas du
      // récapitulatif : il s'affichait avant les frais, il doit continuer à
      // se voir — avec sa raison, plutôt qu'un vide inexplicable.
      if (settlement.refundableAmount <= 0) return const SizedBox.shrink();
      return DonyStatusBanner(
        type: DonyStatusBannerType.warning,
        iconAsset: 'circle-alert',
        message: l.deletionBalanceAbsorbedByFeesMessage(
          _WalletSettlementSummary._fmt(
            settlement.refundableAmount,
            settlement.currency,
          ),
        ),
      );
    }

    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final fee = settlement.feeAmount ?? 0;

    final (railLabel, railColor) = switch (settlement.rail) {
      'PAWAPAY' => (l.paymentMethodMobileMoney, cs.secondary),
      'STRIPE' => (l.paymentMethodCard, cs.primary),
      _ => (null, null),
    };

    String? detail;
    if (fee > 0) {
      detail = l.deletionRefundableWithFeeMessage(
        _WalletSettlementSummary._fmt(
          settlement.refundableAmount,
          settlement.currency,
        ),
        _WalletSettlementSummary._fmt(fee, settlement.currency),
      );
    } else if (settlement.rail == 'PAWAPAY' &&
        settlement.destinationMasked != null) {
      detail = l.deletionFeelessDestinationMessage(
        settlement.destinationMasked!,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (railLabel != null && railColor != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DonySpacing.sm,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: railColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(DonyRadius.full),
              ),
              child: Text(
                railLabel,
                style: tt.labelSmall?.copyWith(
                  color: railColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: DonySpacing.xs),
          ],
          Text(
            _WalletSettlementSummary._fmt(net, settlement.currency),
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (detail != null) ...[
            const SizedBox(height: 2),
            Text(
              detail,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bandeau récapitulatif combinant toutes les devises au nouveau contrat
/// (hors MANUAL) : les montants nets joints par « et », puis le bonus perdu
/// le cas échéant. Absent tant qu'aucune devise n'expose les frais (ancien
/// contrat).
class _SettlementBanner extends StatelessWidget {
  const _SettlementBanner(this.items);

  final List<WalletSettlement> items;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final netTexts = items
        .map((s) => s.netAmount ?? s.refundableAmount)
        .toList();
    final nonZeroNets = <String>[
      for (var i = 0; i < items.length; i++)
        if (netTexts[i] > 0)
          _WalletSettlementSummary._fmt(netTexts[i], items[i].currency),
    ];
    if (nonZeroNets.isEmpty) return const SizedBox.shrink();

    final forfeitedTexts = [
      for (final s in items)
        if (s.forfeitedAmount > 0)
          _WalletSettlementSummary._fmt(s.forfeitedAmount, s.currency),
    ];

    final message = StringBuffer(
      l.deletionSettlementRefundedOnRequest(joinList(l, nonZeroNets)),
    );
    if (forfeitedTexts.isNotEmpty) {
      message.write(
        ' ${l.deletionSettlementBonusLost(joinList(l, forfeitedTexts))}',
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: DonySpacing.xs),
      child: DonyStatusBanner(
        type: DonyStatusBannerType.info,
        iconAsset: 'wallet',
        message: message.toString(),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final DeleteMode mode;
  final ValueNotifier<DeleteMode?> modeNotifier;
  final String iconAsset;
  final String title;
  final String badge;
  final bool isDestructive;
  final String description;

  const _ModeCard({
    required this.mode,
    required this.modeNotifier,
    required this.iconAsset,
    required this.title,
    required this.badge,
    required this.isDestructive,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final badgeColor = isDestructive ? cs.error : cs.success;

    return ValueListenableBuilder<DeleteMode?>(
      valueListenable: modeNotifier,
      builder: (_, selected, _) {
        final isSelected = selected == mode;
        final borderColor = isSelected ? badgeColor : cs.outline;
        final bgColor = isSelected
            ? badgeColor.withValues(alpha: 0.06)
            : Colors.transparent;

        return GestureDetector(
          onTap: () => modeNotifier.value = mode,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(DonySpacing.base),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(DonyRadius.card),
              border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    DonyIcon(iconAsset, size: 20, color: badgeColor),
                    const SizedBox(width: DonySpacing.sm),
                    Expanded(
                      child: Text(
                        title,
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DonySpacing.sm,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(DonyRadius.xl),
                      ),
                      child: Text(
                        badge,
                        style: tt.labelSmall?.copyWith(
                          color: badgeColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DonySpacing.sm),
                Text(
                  description,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
