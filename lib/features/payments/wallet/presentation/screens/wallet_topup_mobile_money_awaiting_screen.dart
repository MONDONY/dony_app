import 'dart:async';

import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/phone/phone_last_digits.dart';
import 'package:dony/core/services/external_url_launcher.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/payments/data/models/mobile_money_countries.dart';
import 'package:dony/features/payments/presentation/widgets/mobile_money_awaiting_ring.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_topup_mobile_money_cubit.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_topup_mobile_money_state.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_topup_model.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Écran d'attente d'une recharge de portefeuille par mobile money : anneau
/// et chrono calés sur l'échéance du serveur, consigne selon la façon dont
/// l'opérateur fait valider (lien par SMS, code secret, ou neutre), puis
/// récapitulatif (montant, compte qui paie, portefeuille crédité).
///
/// Poussé depuis l'écran de montant (`pushReplacement` : un `pop` revient
/// à l'écran Recharger) ou depuis l'écran Recharger quand une recharge en
/// cours est reprise. Le cubit est fourni par un ancêtre
/// (`BlocProvider.value` posé par `router.dart`), jamais recréé ici.
///
/// Quitter l'écran (✕, retour système) ne perd pas la recharge : le cubit
/// arrête seulement de sonder ([WalletTopupMobileMoneyCubit.detach]), le
/// serveur continue de suivre le dépôt et notifie l'issue. pawaPay ne sait
/// pas annuler un dépôt : « Payer avec un autre numéro » n'apparaît qu'une
/// fois l'échéance passée ou après un échec final.
class WalletTopupMobileMoneyAwaitingScreen extends StatefulWidget {
  const WalletTopupMobileMoneyAwaitingScreen({
    super.key,
    required this.phoneNumber,
    required this.amount,
  });

  /// Numéro payeur complet, réutilisé par « Renvoyer une demande ». `null`
  /// pour une recharge reprise : le serveur ne renvoie que le numéro
  /// masqué, la relance n'est alors pas proposée.
  final String? phoneNumber;

  /// Montant de la recharge, affiché et réutilisé par « Renvoyer une
  /// demande » ([WalletTopupModel] ne le porte pas).
  final double amount;

  @override
  State<WalletTopupMobileMoneyAwaitingScreen> createState() =>
      _WalletTopupMobileMoneyAwaitingScreenState();
}

class _WalletTopupMobileMoneyAwaitingScreenState
    extends State<WalletTopupMobileMoneyAwaitingScreen> {
  /// Capturé à l'ouverture : `onPopInvokedWithResult` se déclenche alors que
  /// cette route est déjà dépilée, un `context.read` y serait trop tard.
  late final WalletTopupMobileMoneyCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<WalletTopupMobileMoneyCubit>();
  }

  /// Toute sortie (✕, retour système, geste) passe par ici : la recharge
  /// continue côté serveur, le sondage s'arrête. Jamais de `reset()` :
  /// l'abandon est réservé à « Payer avec un autre numéro ».
  void _onPopped(bool didPop, Object? result) {
    if (didPop) _cubit.detach();
  }

  void _close() {
    _cubit.detach();
    context.pop();
  }

  void _resend() {
    final phoneNumber = widget.phoneNumber;
    if (phoneNumber == null) return;
    unawaited(_cubit.initiate(amount: widget.amount, phoneNumber: phoneNumber));
  }

  /// Abandon de la recharge puis retour à l'écran Recharger.
  void _payWithAnotherNumber() {
    _cubit.reset();
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return PopScope(
      onPopInvokedWithResult: _onPopped,
      child: Scaffold(
        backgroundColor: cs.surfaceContainerLowest,
        appBar: AppBar(
          actions: const [DonyFeedbackButton()],
          leading: DonyAppBarBackButton(
            leadingIcon: Icons.close_rounded,
            onBack: _close,
          ),
          title: Text(context.l10n.walletTopupMmAwaitingTitle),
          backgroundColor: cs.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: cs.outline),
          ),
        ),
        body: SafeArea(
          top: false,
          child:
              BlocConsumer<
                WalletTopupMobileMoneyCubit,
                WalletTopupMobileMoneyState
              >(
                listenWhen: (previous, current) =>
                    previous.runtimeType != current.runtimeType,
                listener: (context, state) {
                  if (state is WalletTopupMobileMoneyConfirmed) {
                    context.go(
                      '/payments/wallet',
                      extra: {'topupConfirmed': state.status},
                    );
                  }
                },
                builder: (context, state) => Column(
                  children: [
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 250),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: KeyedSubtree(
                          key: ValueKey(state.runtimeType),
                          child: _bodyFor(context, state),
                        ),
                      ),
                    ),
                    _bottomFor(context, state),
                  ],
                ),
              ),
        ),
      ),
    );
  }

  Widget _bodyFor(BuildContext context, WalletTopupMobileMoneyState state) {
    final l = context.l10n;
    return switch (state) {
      final WalletTopupMobileMoneyAwaiting s => _AwaitingBody(
        topup: s.topup,
        expiresAt: s.expiresAt,
        amount: widget.amount,
      ),
      WalletTopupMobileMoneyOverdue() => _OutcomeBody(
        iconAsset: 'clock',
        warning: true,
        title: l.walletTopupMmOverdueTitle,
        message: l.walletTopupMmOverdueBody,
      ),
      final WalletTopupMobileMoneyFailed f => _OutcomeBody(
        iconAsset: 'circle-alert',
        title: l.walletTopupMmFailedTitle,
        message: walletTopupFailureMessage(l, f),
      ),
      // Erreur technique (réseau coupé pendant « Renvoyer une demande ») :
      // message et boutons de reprise, jamais une roue infinie.
      final WalletTopupMobileMoneyError e => _OutcomeBody(
        iconAsset: 'circle-alert',
        message: ErrorPresenter.resolve(e.error, l10n: l).message,
      ),
      _ => Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    };
  }

  /// Boutons du bas : aucun pendant l'attente (seul le ✕ fait sortir),
  /// « Renvoyer une demande » (ou « Réessayer » après une erreur technique)
  /// et « Payer avec un autre numéro » une fois l'échéance passée ou après
  /// un échec.
  Widget _bottomFor(BuildContext context, WalletTopupMobileMoneyState state) {
    final l = context.l10n;
    final String? primaryLabel;
    switch (state) {
      case WalletTopupMobileMoneyOverdue() || WalletTopupMobileMoneyFailed():
        primaryLabel = l.walletTopupMmResend;
      case WalletTopupMobileMoneyError():
        primaryLabel = l.commonRetry;
      default:
        return const SizedBox.shrink();
    }
    final canResend = widget.phoneNumber != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        DonySpacing.lg,
        0,
        DonySpacing.lg,
        MediaQuery.paddingOf(context).bottom + DonySpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (canResend) ...[
            DonyButton(
              key: const Key('mobile-money-awaiting-resend'),
              label: primaryLabel,
              onPressed: _resend,
            ),
            const SizedBox(height: DonySpacing.sm),
          ],
          DonyButton(
            key: const Key('mobile-money-awaiting-other-number'),
            label: l.walletTopupMmPayWithAnotherNumber,
            variant: canResend
                ? DonyButtonVariant.ghost
                : DonyButtonVariant.primary,
            onPressed: _payWithAnotherNumber,
          ),
        ],
      ),
    );
  }
}

/// Texte d'un échec final : celui du code Yadony dans la langue de l'app,
/// sinon le motif déjà traduit par le back (code inconnu de cette version),
/// sinon un message générique.
@visibleForTesting
String walletTopupFailureMessage(
  AppLocalizations l,
  WalletTopupMobileMoneyFailed state,
) {
  // Codes Yadony du back (liste fermée), jamais affichés.
  final byCode = switch (state.failureCode) {
    'insufficient-balance' =>
      l.walletTopupFailureInsufficientBalance, // i18n-ignore
    'not-approved' => l.walletTopupFailureNotApproved, // i18n-ignore
    'payer-limit-reached' => l.walletTopupFailurePayerLimit, // i18n-ignore
    'invalid-number' => l.walletTopupFailureInvalidNumber, // i18n-ignore
    'provider-unavailable' =>
      l.walletTopupFailureProviderUnavailable, // i18n-ignore
    'expired' => l.walletTopupFailureExpired, // i18n-ignore
    'other' => l.walletTopupFailureOther, // i18n-ignore
    _ => null,
  };
  return byCode ?? state.failureReason ?? l.walletTopupFailureOther;
}

/// Anneau, consigne de validation et récapitulatif de la recharge.
class _AwaitingBody extends StatelessWidget {
  const _AwaitingBody({
    required this.topup,
    required this.expiresAt,
    required this.amount,
  });

  final WalletTopupModel topup;
  final DateTime expiresAt;
  final double amount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final currency = SupportedCurrency.fromCodeOrDefault(topup.currency);
    final (title, body) = switch (topup.validationHint) {
      MobileMoneyValidationHint.smsLink => (
        l.walletTopupMmSmsSentTitle(topup.msisdnMasked),
        l.walletTopupMmSmsSentBody,
      ),
      MobileMoneyValidationHint.pinPrompt => (
        l.walletTopupMmPromptTitle(topup.msisdnMasked),
        l.walletTopupMmPromptBody,
      ),
      MobileMoneyValidationHint.generic => (
        l.walletTopupMmPromptTitle(topup.msisdnMasked),
        l.walletTopupMmGenericBody,
      ),
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(DonySpacing.lg),
      child: Column(
        children: [
          const SizedBox(height: DonySpacing.md),
          MobileMoneyAwaitingRing(expiresAt: expiresAt, now: DateTime.now),
          const SizedBox(height: DonySpacing.xl),
          Text(
            title,
            textAlign: TextAlign.center,
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            body,
            textAlign: TextAlign.center,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: DonySpacing.xl),
          DonyCard(
            child: Column(
              children: [
                DonyInfoRow(
                  label: l.walletTopupMmAmountLabel,
                  value: CurrencyFormatter.format(amount, currency),
                ),
                const DonyInfoRow.divider(),
                DonyInfoRow(
                  label: l.walletTopupMmFromLabel,
                  value: l.walletTopupMmFromValue(
                    topup.providerLabel,
                    phoneLastDigits(topup.msisdnMasked),
                  ),
                ),
                const DonyInfoRow.divider(),
                DonyInfoRow(
                  label: l.walletTopupMmCreditedToLabel,
                  value: l.walletTopupMmCreditedTo(currency.code),
                ),
              ],
            ),
          ),
          if (topup.authorizationUrl case final String url) ...[
            const SizedBox(height: DonySpacing.xl),
            DonyButton(
              key: const Key('mobile-money-awaiting-open-authorization'),
              label: l.walletTopupMmOpenProvider(topup.providerLabel),
              iconAsset: 'external-link',
              onPressed: () =>
                  getIt<ExternalUrlLauncher>().open(Uri.parse(url)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Issue sans attente : « Pas encore validé » (échéance passée), échec
/// final ou erreur technique. Icône dans une pastille, titre, texte.
class _OutcomeBody extends StatelessWidget {
  const _OutcomeBody({
    required this.iconAsset,
    required this.message,
    this.title,
    this.warning = false,
  });

  final String iconAsset;
  final String? title;
  final String message;

  /// Pastille ambre (rien n'est perdu) plutôt que rouge (échec).
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final tone = warning ? DonyColors.warning : cs.error;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(child: DonyIcon(iconAsset, color: tone, size: 26)),
            ),
            const SizedBox(height: DonySpacing.base),
            if (title case final String t) ...[
              Text(
                t,
                textAlign: TextAlign.center,
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: DonySpacing.sm),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
