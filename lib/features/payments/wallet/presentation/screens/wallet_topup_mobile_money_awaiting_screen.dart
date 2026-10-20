import 'dart:async';

import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/phone/phone_last_digits.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/payments/presentation/mobile_money_failure_message.dart';
import 'package:dony/features/payments/presentation/payment_auth.dart';
import 'package:dony/features/payments/presentation/widgets/mobile_money_awaiting_panel.dart';
import 'package:dony/features/payments/presentation/widgets/mobile_money_outcome_body.dart';
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
/// serveur continue de suivre le dépôt et notifie l'issue, et l'on quitte
/// tout le parcours de recharge pour le portefeuille. Rouvrir « Recharger »
/// reprend alors l'attente (`resumePending`). pawaPay ne sait
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

  /// Montant de la recharge, réutilisé par « Renvoyer une demande ».
  /// L'affichage préfère celui de l'état ([WalletTopupMobileMoneyAwaiting.
  /// amount]), seul fiable après une reprise.
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

  /// Retour système ou geste : même sortie que le ✕. Un `pop` explicite
  /// (« Payer avec un autre numéro », déjà réinitialisé) passe tel quel.
  void _onPopped(bool didPop, Object? result) {
    if (didPop) {
      _cubit.detach();
      return;
    }
    _leave();
  }

  /// ✕ : la recharge continue côté serveur, le sondage s'arrête et l'on
  /// quitte tout le parcours pour le portefeuille. Jamais de `reset()` :
  /// l'abandon est réservé à « Payer avec un autre numéro ». Revenir sur
  /// l'écran Recharger laisserait une recharge orpheline (409, ou second
  /// dépôt sans avertissement).
  void _leave() {
    _cubit.detach();
    context.go('/payments/wallet');
  }

  /// Relancer un dépôt est un nouveau paiement : même confirmation que le
  /// premier. Refusé, ou écran quitté pendant la vérification, rien n'est
  /// lancé.
  Future<void> _resend() async {
    final phoneNumber = widget.phoneNumber;
    if (phoneNumber == null) return;
    final authenticated = await requirePaymentAuth(
      context,
      authService: getIt<LocalAuthService>(),
      userPrefs: getIt<HiveService>().userPrefs,
    );
    if (!mounted) return;
    if (!authenticated) {
      DonySnackbar.show(
        context,
        message: context.l10n.paymentNotConfirmedSnackbar,
        type: DonySnackbarType.error,
      );
      return;
    }
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
      canPop: false,
      onPopInvokedWithResult: _onPopped,
      child: Scaffold(
        backgroundColor: cs.surfaceContainerLowest,
        appBar: AppBar(
          actions: const [DonyFeedbackButton()],
          leading: DonyAppBarBackButton(
            leadingIcon: Icons.close_rounded,
            onBack: _leave,
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
        amount: s.amount ?? widget.amount,
      ),
      WalletTopupMobileMoneyOverdue() => MobileMoneyOutcomeBody(
        iconAsset: 'clock',
        warning: true,
        title: l.walletTopupMmOverdueTitle,
        message: l.walletTopupMmOverdueBody,
      ),
      final WalletTopupMobileMoneyFailed f => MobileMoneyOutcomeBody(
        iconAsset: 'circle-alert',
        title: l.walletTopupMmFailedTitle,
        message: walletTopupFailureMessage(l, f),
      ),
      // Erreur technique (réseau coupé pendant « Renvoyer une demande ») :
      // message et boutons de reprise, jamais une roue infinie.
      final WalletTopupMobileMoneyError e => MobileMoneyOutcomeBody(
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
) => mobileMoneyFailureMessage(
  l,
  code: state.failureCode,
  fallback: state.failureReason,
);

/// Récapitulatif de la recharge (montant, compte qui paie, portefeuille
/// crédité) dans le panneau d'attente partagé.
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
    final l = context.l10n;
    final currency = SupportedCurrency.fromCodeOrDefault(topup.currency);

    return MobileMoneyAwaitingPanel(
      expiresAt: expiresAt,
      hint: topup.validationHint,
      msisdnMasked: topup.msisdnMasked,
      authorizationUrl: topup.authorizationUrl,
      providerLabel: topup.providerLabel,
      recap: [
        (
          label: l.walletTopupMmAmountLabel,
          value: CurrencyFormatter.format(amount, currency),
        ),
        (
          label: l.walletTopupMmFromLabel,
          value: l.walletTopupMmFromValue(
            topup.providerLabel,
            phoneLastDigits(topup.msisdnMasked),
          ),
        ),
        (
          label: l.walletTopupMmCreditedToLabel,
          value: l.walletTopupMmCreditedTo(currency.symbol),
        ),
      ],
    );
  }
}
