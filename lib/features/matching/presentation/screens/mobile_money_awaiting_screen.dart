import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/phone/normalize_payer_phone.dart';
import 'package:dony/core/phone/phone_last_digits.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_bloc.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_event.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_state.dart';
import 'package:dony/features/matching/data/models/mobile_money_payment_status.dart';
import 'package:dony/features/matching/data/models/mobile_money_scope.dart';
import 'package:dony/features/payments/bloc/payer_account_cubit.dart';
import 'package:dony/features/payments/bloc/payer_account_state.dart';
import 'package:dony/features/payments/data/models/mobile_money_countries.dart';
import 'package:dony/features/payments/presentation/mobile_money_failure_message.dart';
import 'package:dony/features/payments/presentation/payment_auth.dart';
import 'package:dony/features/payments/presentation/widgets/mobile_money_awaiting_panel.dart';
import 'package:dony/features/payments/presentation/widgets/mobile_money_outcome_body.dart';
import 'package:dony/features/payments/presentation/widgets/payer_account_section.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Écran « Payer le colis » (ou « Payer le supplément ») en mobile money
/// (Wave / Orange Money via pawaPay) d'un bid, d'un fil de négociation ou du
/// supplément de prix d'un colis, ouvert depuis le détail de l'envoi ou le fil
/// (`context.push<bool>(scope.awaitingRoute)`), une notification
/// `MM_PAYMENT_PENDING` ou le lien profond
/// `yadony://bids/{uuid}/mobile-money/awaiting` (ou
/// `yadony://negotiations/{uuid}/mobile-money/awaiting`, ou
/// `yadony://bids/{uuid}/supplements/{uuid}/mobile-money/awaiting`).
///
/// L'ouverture (`MobileMoneyPaymentOpened`) reprend un dépôt déjà en cours, ou
/// affiche l'étape « Qui paie ? » sur le composant partagé « compte qui paie »
/// (`PayerAccountSection` : pays, opérateur, numéro reconnu par pawaPay) ; le
/// dépôt part au bouton « Payer », après `requirePaymentAuth`. L'écran sonde
/// ensuite le statut jusqu'au séquestre, puis se referme sur
/// `context.pop(true)` : l'appelant se recharge au retour.
///
/// Le `PayerAccountCubit` est fourni par le routeur, sans devise : elle n'est
/// connue qu'avec le statut. L'écran le configure à la **première** étape
/// « Qui paie ? » ; les suivantes (« Payer avec un autre numéro ») ne le
/// rechargent pas, le compte saisi reste affiché.
///
/// Échéance passée avec un dépôt encore ouvert : l'écran dit « Pas encore
/// validé » et continue de sonder, il n'annonce jamais un délai dépassé tant
/// que l'opérateur n'a pas tranché.
class MobileMoneyAwaitingScreen extends StatefulWidget {
  const MobileMoneyAwaitingScreen({super.key, required this.scope});

  /// Bid ou fil de négociation dont ce dépôt paie l'escrow.
  final MobileMoneyScope scope;

  @override
  State<MobileMoneyAwaitingScreen> createState() =>
      _MobileMoneyAwaitingScreenState();
}

class _MobileMoneyAwaitingScreenState extends State<MobileMoneyAwaitingScreen> {
  static const _pollInterval = Duration(seconds: 5);
  static const _countdownInterval = Duration(seconds: 1);

  /// Fenêtre de paiement d'un dépôt dont le back n'a pas rendu l'échéance
  /// (cas qui ne devrait pas se produire) : sert d'échéance à l'anneau.
  static const _fallbackWindow = Duration(minutes: 30);

  Timer? _pollingTimer;
  Timer? _countdownTimer;

  /// Jamais mis à jour via `setState` : seul `_CountdownLabel` (via
  /// `ValueListenableBuilder`) se redessine à chaque tick, pas tout l'écran.
  final ValueNotifier<Duration> _remaining = ValueNotifier(Duration.zero);

  /// Numéro payeur de l'état `legacy` du composant (back sans catalogue des
  /// pays) : le seul cas où l'écran porte lui-même un champ numéro.
  final TextEditingController _legacyPhoneController = TextEditingController();

  /// Le composant « compte qui paie » a déjà reçu sa devise et ses opérateurs
  /// permis : les « Qui paie ? » suivants ne le rechargent pas.
  bool _payerConfigured = false;

  /// Échéance de repli d'un dépôt sans échéance serveur, figée au premier
  /// besoin pour que l'anneau ne reparte pas à chaque reconstruction, et
  /// rattachée à l'identifiant du dépôt : un nouveau dépôt a sa propre fenêtre.
  ({String depositId, DateTime at})? _fallbackDeadline;

  /// Une vérification de paiement (biométrie, PIN) est en cours : « Payer » et
  /// « Renvoyer une demande » sont grisés, un double appui ne lance pas deux
  /// vérifications. Écouté par `ValueListenableBuilder`, jamais par `setState`.
  final ValueNotifier<bool> _verifying = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        getIt<AnalyticsService>().logEvent(
          AnalyticsEvents.mobileMoneyAwaiting,
          properties: {
            'provider': 'mobile_money',
            'scope': widget.scope.analyticsName,
          },
        ),
      );
    });
    final bloc = context.read<MobileMoneyPaymentBloc>();
    if (bloc.state case final MobileMoneyPaymentChoosePayer s) {
      _syncPayerAccount(s);
    }
    bloc.add(MobileMoneyPaymentOpened(scope: widget.scope));
    _startPolling();
    _countdownTimer = Timer.periodic(_countdownInterval, (_) {
      if (!mounted) return;
      _syncCountdown(context.read<MobileMoneyPaymentBloc>().state);
    });
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(_pollInterval, (_) {
      if (!mounted) return;
      context.read<MobileMoneyPaymentBloc>().add(
        MobileMoneyStatusPolled(scope: widget.scope),
      );
    });
  }

  void _cancelAllTimers() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
  }

  /// Extrait l'échéance de paiement d'un état, si ce dernier en porte une.
  /// `null` pour tout autre état : le compte à rebours n'a alors rien à
  /// afficher (Escrowed/Expired ne le montrent plus, Initial/Loading/Error
  /// ne l'ont jamais eu).
  static DateTime? _deadlineAtFor(MobileMoneyPaymentState state) =>
      switch (state) {
        final MobileMoneyPaymentChoosePayer s => s.status.deadlineAt,
        final MobileMoneyPaymentAwaitingConfirmation s => s.status.deadlineAt,
        final MobileMoneyPaymentOverdue s => s.status.deadlineAt,
        final MobileMoneyPaymentDepositFailed s => s.status.deadlineAt,
        _ => null,
      };

  /// Recalcule le temps restant à partir de [state] et le pousse dans le
  /// notifier. Appelé à chaque transition (`listener`) pour ne jamais
  /// afficher une valeur périmée le temps qu'un premier tick de minuterie
  /// arrive, et chaque seconde tant que la minuterie tourne.
  void _syncCountdown(MobileMoneyPaymentState state) {
    final deadline = _deadlineAtFor(state);
    if (deadline == null) return;
    final diff = deadline.difference(DateTime.now().toUtc());
    _remaining.value = diff.isNegative ? Duration.zero : diff;
  }

  /// Donne au composant « compte qui paie » la devise du paiement et les
  /// opérateurs que le voyageur accepte. Première étape « Qui paie ? » :
  /// `configure` (charge le catalogue). Suivantes : seule la restriction est
  /// remise à jour, le compte déjà saisi n'est pas rechargé. Une liste vide
  /// restreint à rien (tous les opérateurs grisés « Non accepté », le back
  /// refuserait de toute façon) ; `null` seulement quand les opérateurs
  /// acceptés sont inconnus (back ancien, lecture en échec) : aucune
  /// restriction.
  void _syncPayerAccount(MobileMoneyPaymentChoosePayer state) {
    final cubit = context.read<PayerAccountCubit>();
    final allowed = state.accepted?.providers;
    if (_payerConfigured) {
      cubit.restrictOperators(allowed);
      return;
    }
    _payerConfigured = true;
    unawaited(
      cubit.configure(
        currency: state.status.currency,
        allowedOperators: allowed,
      ),
    );
  }

  /// Ouvert depuis le détail (`push<bool>`), l'écran rend son résultat au
  /// parent. Ouvert depuis la push « paiement en attente » (lien profond,
  /// seule page de la pile), il n'a rien à dépiler : `pop` levait
  /// « There is nothing to pop » (Sentry FLUTTER-1D, recette du 2026-09-09),
  /// le repli est l'écran de repli de la portée (détail du bid, ou fil de
  /// négociation).
  void _close(BuildContext context, {required bool paid}) {
    if (context.canPop()) {
      context.pop(paid);
    } else {
      context.go(widget.scope.fallbackRoute);
    }
  }

  /// Un dépôt est un paiement : même confirmation (accessibilité, biométrie,
  /// PIN) que tout autre. Refusé, ou écran quitté pendant la vérification,
  /// rien n'est lancé. Pendant une vérification déjà en cours, un second appui
  /// est ignoré.
  Future<bool> _confirmPayment() async {
    if (_verifying.value) return false;
    _verifying.value = true;
    final bool authenticated;
    try {
      authenticated = await requirePaymentAuth(
        context,
        authService: getIt<LocalAuthService>(),
        userPrefs: getIt<HiveService>().userPrefs,
      );
    } finally {
      if (mounted) _verifying.value = false;
    }
    if (!mounted) return false;
    if (!authenticated) {
      DonySnackbar.show(
        context,
        message: context.l10n.paymentNotConfirmedSnackbar,
        type: DonySnackbarType.error,
      );
    }
    return authenticated;
  }

  /// « Payer » : numéro complet et opérateur du composant (ou, sans
  /// catalogue, le numéro saisi et l'opérateur du back).
  Future<void> _pay() async {
    if (!await _confirmPayment() || !mounted) return;
    final payer = context.read<PayerAccountCubit>().state;
    final String? phoneNumber;
    final String? provider;
    if (payer.status == PayerAccountStatus.legacy) {
      // Jamais de dépôt sans numéro saisi : le back paierait avec le numéro
      // du compte, ce que la refonte interdit (« Payer » est grisé tant que
      // le champ n'est pas un numéro valide, ce garde-fou couvre le délai de
      // la vérification locale).
      phoneNumber = normalizePayerPhone(_legacyPhoneController.text);
      if (phoneNumber == null) return;
      provider = null;
    } else {
      // Le numéro a pu changer pendant la vérification : jamais un dépôt sur
      // un numéro qui n'est plus reconnu.
      final operator = payer.operator;
      final e164 = payer.e164;
      if (!payer.canProceed || operator == null || e164 == null) return;
      phoneNumber = e164;
      provider = operator.code;
    }
    context.read<MobileMoneyPaymentBloc>().add(
      MobileMoneyPaymentInitiateRequested(
        scope: widget.scope,
        phoneNumber: phoneNumber,
        provider: provider,
      ),
    );
  }

  /// « Renvoyer une demande » : nouveau dépôt avec le même couple numéro et
  /// opérateur. Le sondage reprend sur `AwaitingConfirmation`.
  Future<void> _resend() async {
    if (!await _confirmPayment() || !mounted) return;
    context.read<MobileMoneyPaymentBloc>().add(
      MobileMoneyPaymentResendRequested(scope: widget.scope),
    );
  }

  /// Depuis un dépôt refusé : retour à l'étape « Qui paie ? » (numéro
  /// éventuellement changé), jamais une relance aveugle.
  void _changePayer() {
    context.read<MobileMoneyPaymentBloc>().add(
      MobileMoneyPaymentChangePayerRequested(scope: widget.scope),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    _remaining.dispose();
    _verifying.dispose();
    _legacyPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        actions: const [DonyFeedbackButton()],
        leading: DonyAppBarBackButton(
          leadingIcon: Icons.close_rounded,
          onBack: () => _close(context, paid: false),
        ),
        title: Text(
          widget.scope is SupplementMobileMoneyScope
              ? l.mobileMoneyPaySupplementTitle
              : l.mobileMoneyPayParcelTitle,
        ),
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: cs.outline),
        ),
      ),
      // Les boutons du bas ne doivent pas passer sous la barre de navigation
      // Android (constaté sur un Redmi à trois boutons) : le haut est déjà
      // couvert par l'AppBar.
      body: SafeArea(
        top: false,
        child: BlocConsumer<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
          listenWhen: (previous, current) =>
              previous.runtimeType != current.runtimeType,
          listener: (context, state) {
            _syncCountdown(state);
            switch (state) {
              case MobileMoneyPaymentEscrowed():
                _cancelAllTimers();
                // Retient pays, opérateur et numéro pour préremplir le
                // prochain paiement.
                unawaited(context.read<PayerAccountCubit>().rememberSuccess());
                DonySnackbar.show(
                  context,
                  message: widget.scope is SupplementMobileMoneyScope
                      ? l.supplementPaidSnackbar
                      : l.mobileMoneyPaymentConfirmedSecured,
                  type: DonySnackbarType.success,
                );
                _close(context, paid: true);
              case MobileMoneyPaymentExpired():
                _cancelAllTimers();
              case final MobileMoneyPaymentChoosePayer s:
                // Aucun dépôt encore initié : rien à sonder tant que
                // l'expéditeur n'a pas choisi qui paie.
                _pollingTimer?.cancel();
                _syncPayerAccount(s);
              case MobileMoneyPaymentAwaitingConfirmation() ||
                  MobileMoneyPaymentOverdue():
                // Un dépôt redevient vivant (première ouverture avec un
                // dépôt déjà en cours, ou après « Payer »), ou reste ouvert
                // après l'échéance : le sondage reprend ou continue.
                _startPolling();
              case MobileMoneyPaymentDepositFailed():
                _pollingTimer?.cancel();
              case final MobileMoneyPaymentError e:
                unawaited(ErrorPresenter.show(context, e.error));
              case _:
            }
          },
          builder: (context, state) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: KeyedSubtree(
                    key: ValueKey(_bodyKey(state)),
                    child: _bodyFor(context, state),
                  ),
                ),
              ),
              _bottomFor(context, state),
            ],
          ),
        ),
      ),
    );
  }

  /// Clé de fondu : `Initial` et `Loading` montrent le même indicateur, les
  /// enchaîner ne doit rien faire clignoter.
  static Object _bodyKey(MobileMoneyPaymentState state) => switch (state) {
    MobileMoneyPaymentInitial() || MobileMoneyPaymentLoading() => 'loading',
    _ => state.runtimeType,
  };

  Widget _bodyFor(BuildContext context, MobileMoneyPaymentState state) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    return switch (state) {
      MobileMoneyPaymentInitial() || MobileMoneyPaymentLoading() => Center(
        child: CircularProgressIndicator(color: cs.primary),
      ),
      final MobileMoneyPaymentChoosePayer s => _ChoosePayerBody(
        state: s,
        remaining: _remaining,
        legacyPhoneController: _legacyPhoneController,
      ),
      final MobileMoneyPaymentAwaitingConfirmation s => _AwaitingBody(
        status: s.status,
        fallbackDeadline: _fallbackDeadlineFor(s.status),
      ),
      MobileMoneyPaymentOverdue() => MobileMoneyOutcomeBody(
        iconAsset: 'clock',
        warning: true,
        title: l.walletTopupMmOverdueTitle,
        message: l.mobileMoneyOverdueBody,
      ),
      final MobileMoneyPaymentDepositFailed s => MobileMoneyOutcomeBody(
        iconAsset: 'circle-alert',
        title: l.mobileMoneyPaymentFailedTitle,
        message: mobileMoneyFailureMessage(
          l,
          code: s.status.deposit?.failureReasonCode,
          fallback: s.status.deposit?.failureMessage,
        ),
      ),
      final MobileMoneyPaymentExpired s => _ExpiredBody(
        scope: widget.scope,
        status: s.status,
        onBack: () => _close(context, paid: false),
      ),
      MobileMoneyPaymentEscrowed() => const _EscrowedBody(),
      MobileMoneyPaymentError() => DonyEmptyState(
        type: DonyEmptyStateType.error,
        title: l.commonSomethingWentWrong,
        actionLabel: l.commonRetry,
        onAction: () => context.read<MobileMoneyPaymentBloc>().add(
          MobileMoneyPaymentOpened(scope: widget.scope),
        ),
      ),
    };
  }

  /// Échéance du dépôt de [status] quand le serveur n'en a pas rendu : une
  /// fenêtre de [_fallbackWindow] à partir de la première fois qu'on le voit.
  DateTime _fallbackDeadlineFor(MobileMoneyPaymentStatus status) {
    final depositId = status.deposit?.id ?? '';
    final known = _fallbackDeadline;
    if (known != null && known.depositId == depositId) return known.at;
    final at = DateTime.now().add(_fallbackWindow);
    _fallbackDeadline = (depositId: depositId, at: at);
    return at;
  }

  /// Boutons du bas : « Payer » à l'étape « Qui paie ? », « Renvoyer une
  /// demande » (seulement avec un numéro complet connu) et « Payer avec un
  /// autre numéro » après un refus. Aucun pendant l'attente : seul le ✕ fait
  /// sortir.
  Widget _bottomFor(BuildContext context, MobileMoneyPaymentState state) =>
      switch (state) {
        final MobileMoneyPaymentChoosePayer s => _PayBar(
          state: s,
          verifying: _verifying,
          legacyPhoneController: _legacyPhoneController,
          onPay: _pay,
        ),
        MobileMoneyPaymentDepositFailed() => _FailedBar(
          canResend: context.read<MobileMoneyPaymentBloc>().canResend,
          verifying: _verifying,
          onResend: _resend,
          onChangePayer: _changePayer,
        ),
        _ => const SizedBox.shrink(),
      };
}

/// Texte du bandeau d'un refus d'initiation. Un numéro absent ou refusé par
/// l'opérateur a ses explications dédiées ; le reste passe par le catalogue
/// d'erreurs.
String _initiationErrorMessage(Object error, AppLocalizations l) {
  if (error is AppException) {
    switch (error.code) {
      case 'mobile-money-phone-required':
        return l.mobileMoneyPhoneRequiredExplanation;
      case 'mobile-money-payer-unsupported':
        return l.mobileMoneyPayerUnsupportedExplanation;
    }
  }
  return ErrorPresenter.resolve(error, l10n: l).message;
}

/// Compte à rebours de l'étape « Qui paie ? » : « Temps restant mm:ss »,
/// rouge sous 5 minutes. Isolé dans son propre `ValueListenableBuilder` pour
/// ne redessiner que ce texte à chaque tick.
class _CountdownLabel extends StatelessWidget {
  const _CountdownLabel({required this.remaining});
  final ValueListenable<Duration> remaining;

  static const _urgentThreshold = Duration(minutes: 5);

  /// `mm:ss` sous une heure (dépôt d'un colis, 30 min) ; `h:mm:ss` au-delà
  /// (échéance de 2 h d'un supplément), jamais « 120:00 ».
  static String _format(Duration d) {
    final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    if (d.inHours >= 1) {
      final mm = (d.inMinutes % 60).toString().padLeft(2, '0');
      return '${d.inHours}:$mm:$ss';
    }
    final mm = d.inMinutes.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return ValueListenableBuilder<Duration>(
      valueListenable: remaining,
      builder: (context, value, _) {
        final isUrgent = value < _urgentThreshold;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyIcon(
              'timer',
              size: 16,
              color: isUrgent ? cs.error : cs.onSurfaceVariant,
            ),
            const SizedBox(width: DonySpacing.xs),
            // Flexible : un grand texte système (accessibilité) passe à la
            // ligne au lieu de déborder de la carte.
            Flexible(
              child: Text(
                l.mobileMoneyTimeLeft(_format(value)),
                style: tt.bodyMedium?.copyWith(
                  color: isUrgent ? cs.error : cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  // Chasse fixe : le texte ne doit pas sauter à chaque tick.
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Montant à payer et temps restant, en tête de l'étape « Qui paie ? ».
class _AmountCard extends StatelessWidget {
  const _AmountCard({required this.status, required this.remaining});

  final MobileMoneyPaymentStatus status;
  final ValueListenable<Duration> remaining;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return DonyCard(
      child: Row(
        children: [
          DonyIcon('smartphone', color: cs.primary, size: 28),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatPriceIn(status.amount ?? 0, status.currency),
                  style: tt.headlineLarge,
                ),
                if (status.deadlineAt != null) ...[
                  const SizedBox(height: DonySpacing.xs),
                  _CountdownLabel(remaining: remaining),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Étape « Qui paie ? » : montant, bandeau d'un refus éventuel, puis le
/// composant partagé « compte qui paie ». Sans catalogue des pays (back
/// ancien, état `legacy` du composant), un simple champ numéro. Le bouton
/// « Payer » est dans [_PayBar], hors de la zone qui défile.
class _ChoosePayerBody extends StatelessWidget {
  const _ChoosePayerBody({
    required this.state,
    required this.remaining,
    required this.legacyPhoneController,
  });

  final MobileMoneyPaymentChoosePayer state;
  final ValueListenable<Duration> remaining;
  final TextEditingController legacyPhoneController;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final error = state.error;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.xl,
        DonySpacing.lg,
        DonySpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AmountCard(status: state.status, remaining: remaining),
          if (error != null) ...[
            const SizedBox(height: DonySpacing.base),
            DonyStatusBanner(
              type: DonyStatusBannerType.error,
              message: _initiationErrorMessage(error, l),
            ),
          ],
          const SizedBox(height: DonySpacing.base),
          BlocBuilder<PayerAccountCubit, PayerAccountState>(
            builder: (context, payer) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PayerAccountSection(numberHelper: l.mobileMoneyPayerHelper),
                if (payer.status == PayerAccountStatus.legacy)
                  DonyTextField(
                    key: const Key('mobile-money-legacy-phone-field'),
                    controller: legacyPhoneController,
                    label: l.mobileMoneyPhoneThatWillPayLabel,
                    keyboardType: TextInputType.phone,
                  ),
                _AcceptsLine(state: state, payer: payer),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// « {Voyageur} accepte {réseaux}, et reçoit sur le réseau que vous
/// choisissez. » Les noms viennent du catalogue du composant (un code
/// pawaPay seul ne se lit pas) ; sans catalogue encore chargé ou sans
/// opérateur connu, la ligne n'est pas montrée.
class _AcceptsLine extends StatelessWidget {
  const _AcceptsLine({required this.state, required this.payer});

  final MobileMoneyPaymentChoosePayer state;
  final PayerAccountState payer;

  @override
  Widget build(BuildContext context) {
    final acceptedOperators = state.accepted;
    if (acceptedOperators == null) return const SizedBox.shrink();
    final labels = <String>[];
    for (final country in payer.countries?.available ?? const []) {
      for (final operator in country.operators) {
        if (acceptedOperators.providers.contains(operator.code) &&
            !labels.contains(operator.label)) {
          labels.add(operator.label);
        }
      }
    }
    if (labels.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final firstName =
        acceptedOperators.travelerFirstName ?? l.mobileMoneyTravelerFallback;
    return Padding(
      padding: const EdgeInsets.only(top: DonySpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DonyIcon('info', size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text(
              l.mobileMoneyAcceptsAndReceives(firstName, joinList(l, labels)),
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton « Payer {montant} » fixé en bas de l'étape « Qui paie ? » : actif
/// quand le numéro est reconnu (ou, sans catalogue, quand le champ numéro
/// contient un numéro valide), grisé pendant l'envoi.
class _PayBar extends StatelessWidget {
  const _PayBar({
    required this.state,
    required this.verifying,
    required this.legacyPhoneController,
    required this.onPay,
  });

  final MobileMoneyPaymentChoosePayer state;
  final ValueListenable<bool> verifying;
  final TextEditingController legacyPhoneController;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final status = state.status;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.sm,
        DonySpacing.lg,
        DonySpacing.lg,
      ),
      child: BlocBuilder<PayerAccountCubit, PayerAccountState>(
        builder: (context, payer) => ValueListenableBuilder<bool>(
          valueListenable: verifying,
          builder: (context, busy, _) => ValueListenableBuilder(
            valueListenable: legacyPhoneController,
            builder: (context, phone, _) {
              // Sans catalogue (état `legacy`), seul un numéro valide dans le
              // champ rend « Payer » actif : un champ vide laisserait le back
              // payer avec le numéro du compte.
              final ready = payer.status == PayerAccountStatus.legacy
                  ? normalizePayerPhone(phone.text) != null
                  : payer.canProceed;
              return DonyButton(
                label: l.mobileMoneyPay(
                  formatPriceIn(status.amount ?? 0, status.currency),
                ),
                iconAsset: 'smartphone',
                isLoading: state.isSubmitting,
                onPressed: state.isSubmitting || busy || !ready ? null : onPay,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Boutons d'un dépôt refusé : « Renvoyer une demande » (avec le même numéro
/// et le même opérateur, seulement s'ils sont connus) et « Payer avec un
/// autre numéro ».
class _FailedBar extends StatelessWidget {
  const _FailedBar({
    required this.canResend,
    required this.verifying,
    required this.onResend,
    required this.onChangePayer,
  });

  final bool canResend;
  final ValueListenable<bool> verifying;
  final VoidCallback onResend;
  final VoidCallback onChangePayer;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg,
        0,
        DonySpacing.lg,
        DonySpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (canResend) ...[
            ValueListenableBuilder<bool>(
              valueListenable: verifying,
              builder: (context, busy, _) => DonyButton(
                key: const Key('mobile-money-awaiting-resend'),
                label: l.walletTopupMmResend,
                onPressed: busy ? null : onResend,
              ),
            ),
            const SizedBox(height: DonySpacing.sm),
          ],
          DonyButton(
            key: const Key('mobile-money-awaiting-other-number'),
            label: l.walletTopupMmPayWithAnotherNumber,
            variant: canResend
                ? DonyButtonVariant.ghost
                : DonyButtonVariant.primary,
            onPressed: onChangePayer,
          ),
        ],
      ),
    );
  }
}

/// Dépôt en cours : anneau calé sur l'échéance du serveur, consigne selon la
/// façon dont l'opérateur fait valider, puis récapitulatif (montant, compte
/// qui paie, versement au voyageur) dans le panneau d'attente partagé.
class _AwaitingBody extends StatelessWidget {
  const _AwaitingBody({required this.status, required this.fallbackDeadline});

  final MobileMoneyPaymentStatus status;
  final DateTime fallbackDeadline;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final deposit = status.deposit;
    final providerLabel = deposit?.providerLabel;
    final msisdnMasked = deposit?.msisdnMasked ?? '';
    final lastDigits = phoneLastDigits(msisdnMasked);
    final authorizationUrl = deposit?.authorizationUrl;

    return MobileMoneyAwaitingPanel(
      expiresAt: status.deadlineAt ?? fallbackDeadline,
      hint: deposit?.validationHint ?? MobileMoneyValidationHint.generic,
      msisdnMasked: msisdnMasked,
      authorizationUrl: authorizationUrl,
      // Le lien d'autorisation n'est propre qu'à Wave : un back ancien qui le
      // rend sans nom d'opérateur garde son bouton.
      providerLabel:
          providerLabel ?? (authorizationUrl == null ? null : 'Wave'),
      recap: [
        (
          label: l.walletTopupMmAmountLabel,
          value: formatPriceIn(status.amount ?? 0, status.currency),
        ),
        if (providerLabel != null)
          (
            label: l.walletTopupMmFromLabel,
            value: lastDigits.isEmpty
                ? providerLabel
                : l.walletTopupMmFromValue(providerLabel, lastDigits),
          ),
        (
          label: l.mobileMoneyPaidToTravelerLabel,
          value: l.mobileMoneyPaidToTravelerValue,
        ),
      ],
    );
  }
}

/// Fenêtre de 30 minutes dépassée (ou sujet annulé) sans séquestre. Le
/// texte dépend de la portée : un bid expiré est annulé côté back (il faut
/// refaire une offre), alors qu'un fil revient simplement à « à payer ».
class _ExpiredBody extends StatelessWidget {
  const _ExpiredBody({
    required this.scope,
    required this.status,
    required this.onBack,
  });
  final MobileMoneyScope scope;
  final MobileMoneyPaymentStatus status;
  final VoidCallback onBack;

  String _message(AppLocalizations l) => switch (scope) {
    BidMobileMoneyScope() => l.mobileMoneyExpiredBid,
    NegotiationMobileMoneyScope() => l.mobileMoneyExpiredNegotiation,
    SupplementMobileMoneyScope() when status.isRefunded =>
      l.supplementSenderRefunded,
    SupplementMobileMoneyScope() when status.isRefundInProgress =>
      l.supplementSenderRefundPending,
    SupplementMobileMoneyScope() => l.mobileMoneyExpiredSupplement,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyIcon('timer-off', color: cs.warning, size: 48),
            const SizedBox(height: DonySpacing.base),
            Text(
              _message(l),
              textAlign: TextAlign.center,
              style: tt.bodyMedium,
            ),
            const SizedBox(height: DonySpacing.xl),
            DonyButton(
              label: l.commonBack,
              variant: DonyButtonVariant.ghost,
              onPressed: onBack,
            ),
          ],
        ),
      ),
    );
  }
}

/// Paiement séquestré : affiché brièvement, le temps que le listener ferme
/// l'écran sur `context.pop(true)`.
class _EscrowedBody extends StatelessWidget {
  const _EscrowedBody();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyIcon('circle-check', color: cs.success, size: 64),
          const SizedBox(height: DonySpacing.base),
          Text(
            context.l10n.mobileMoneyPaymentConfirmedTitle,
            style: tt.headlineLarge,
          ),
        ],
      ),
    );
  }
}
