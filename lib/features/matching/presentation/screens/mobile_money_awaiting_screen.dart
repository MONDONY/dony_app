import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/phone/normalize_payer_phone.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/external_url_launcher.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_bloc.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_event.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_state.dart';
import 'package:dony/features/matching/data/models/mobile_money_payment_status.dart';
import 'package:dony/features/matching/data/models/mobile_money_scope.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Écran d'attente du paiement mobile money (Wave / Orange Money via
/// pawaPay) d'un bid, d'un fil de négociation ou du supplément de prix d'un
/// colis, ouvert depuis le détail de l'envoi ou le fil
/// (`context.push<bool>(scope.awaitingRoute)`), une notification
/// `MM_PAYMENT_PENDING` ou le lien profond
/// `yadony://bids/{uuid}/mobile-money/awaiting` (ou
/// `yadony://negotiations/{uuid}/mobile-money/awaiting`, ou
/// `yadony://bids/{uuid}/supplements/{uuid}/mobile-money/awaiting`).
///
/// L'ouverture (`MobileMoneyPaymentOpened`) reprend un dépôt déjà en cours,
/// ou affiche l'étape « Qui paie ? » ; le dépôt part au bouton « Payer ».
/// L'écran sonde ensuite le statut jusqu'au séquestre, puis se referme sur
/// `context.pop(true)` — l'appelant se recharge au retour.
class MobileMoneyAwaitingScreen extends StatefulWidget {
  const MobileMoneyAwaitingScreen({
    super.key,
    required this.scope,
    this.initialPhone,
  });

  /// Bid ou fil de négociation dont ce dépôt paie l'escrow.
  final MobileMoneyScope scope;

  /// Ignoré : le numéro payeur se choisit désormais à l'étape « Qui paie ? ».
  /// Retiré avec ses appelants (feuille d'offre, récapitulatif de
  /// négociation) à la tâche 10 du lot B.
  final String? initialPhone;

  @override
  State<MobileMoneyAwaitingScreen> createState() =>
      _MobileMoneyAwaitingScreenState();
}

class _MobileMoneyAwaitingScreenState extends State<MobileMoneyAwaitingScreen> {
  static const _pollInterval = Duration(seconds: 5);
  static const _countdownInterval = Duration(seconds: 1);

  Timer? _pollingTimer;
  Timer? _countdownTimer;

  /// Jamais mis à jour via `setState` : seul `_CountdownLabel` (via
  /// `ValueListenableBuilder`) se redessine à chaque tick, pas tout l'écran.
  final ValueNotifier<Duration> _remaining = ValueNotifier(Duration.zero);

  /// Numéro payeur, partagé par `_FailedBody`, `_PhoneRequiredBody` et
  /// `_ChoosePayerBody` (I1) : un seul contrôleur pour que le numéro saisi
  /// reste affiché d'un corps à l'autre (refus puis « Réessayer »).
  final TextEditingController _payerPhoneController = TextEditingController();

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
    context.read<MobileMoneyPaymentBloc>().add(
      MobileMoneyPaymentOpened(scope: widget.scope),
    );
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

  /// Vrai quand [error] signale l'absence de numéro côté expéditeur (compte
  /// Firebase sans téléphone) : ce cas bascule sur [_PhoneRequiredBody] au
  /// lieu du `DonyEmptyState` générique.
  static bool _isPhoneRequired(Object error) =>
      error is AppException && error.code == 'mobile-money-phone-required';

  /// Aucun numéro payeur exploitable : aucun numéro, ou un numéro que
  /// pawaPay refuse (souvent le téléphone du compte, étranger, par exemple
  /// +33).
  static bool _needsPayerPhone(Object? error) =>
      error is AppException &&
      (error.code == 'mobile-money-phone-required' ||
          error.code == 'mobile-money-payer-unsupported');

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

  void _retry(String rawPhone) {
    context.read<MobileMoneyPaymentBloc>().add(
      MobileMoneyPaymentInitiateRequested(
        scope: widget.scope,
        phoneNumber: normalizePayerPhone(rawPhone),
      ),
    );
    // DepositFailed a arrêté le sondage : la relance le redémarre aussitôt,
    // sans attendre un futur changement d'état.
    _startPolling();
  }

  /// Depuis un dépôt refusé (`_FailedBody`) : retour à l'étape « Qui
  /// paie ? » (numéro éventuellement changé), jamais une relance aveugle.
  /// Ne redémarre PAS le sondage : aucun dépôt n'est encore relancé, et le
  /// back rapporte le dernier dépôt refusé tant qu'un nouveau n'est pas
  /// initié. Le `listener` reprend le sondage sur `AwaitingConfirmation`.
  void _changePayer() {
    context.read<MobileMoneyPaymentBloc>().add(
      MobileMoneyPaymentChangePayerRequested(scope: widget.scope),
    );
  }

  /// Validation de l'étape « Qui paie ? » (corps transitoire de la tâche 8,
  /// réécrit à la tâche 9) : numéro saisi, sinon celui du compte côté back,
  /// opérateur prédit par le back.
  void _payFromChoice() {
    context.read<MobileMoneyPaymentBloc>().add(
      MobileMoneyPaymentInitiateRequested(
        scope: widget.scope,
        phoneNumber: normalizePayerPhone(_payerPhoneController.text),
      ),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    _remaining.dispose();
    _payerPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        actions: const [DonyFeedbackButton()],
        leading: const DonyAppBarBackButton(),
        title: Text(l.mobileMoneyAwaitingTitle),
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: cs.outline),
        ),
      ),
      // Le bouton collant ne doit pas passer sous la barre de navigation
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
              case MobileMoneyPaymentChoosePayer():
                // Aucun dépôt encore initié : rien à sonder tant que
                // l'expéditeur n'a pas choisi qui paie.
                _pollingTimer?.cancel();
              case MobileMoneyPaymentAwaitingConfirmation() ||
                  MobileMoneyPaymentOverdue():
                // Un dépôt redevient vivant (première ouverture avec un
                // dépôt déjà en cours, ou après « Payer »), ou reste ouvert
                // après l'échéance : le sondage reprend ou continue.
                _startPolling();
              case MobileMoneyPaymentDepositFailed():
                _pollingTimer?.cancel();
              case final MobileMoneyPaymentError e:
                // Numéro refusé : aucun dépôt n'existe, sonder ne fait que
                // tourner à vide jusqu'à la saisie d'un autre numéro (le
                // bouton de [_PhoneRequiredBody] relance le sondage).
                if (_needsPayerPhone(e.error)) _pollingTimer?.cancel();
                unawaited(ErrorPresenter.show(context, e.error));
              case _:
            }
          },
          builder: (context, state) => switch (state) {
            MobileMoneyPaymentInitial() || MobileMoneyPaymentLoading() =>
              Center(child: CircularProgressIndicator(color: cs.primary)),
            // Numéro payeur refusé à l'initiation (aucun numéro, ou numéro
            // que l'opérateur refuse) : saisie obligatoire expliquée plutôt
            // qu'un champ « facultatif » (Sentry FLUTTER-DE).
            final MobileMoneyPaymentChoosePayer s
                when !s.isSubmitting && _needsPayerPhone(s.error) =>
              _PhoneRequiredBody(
                key: const Key('mobile-money-payer-phone-needed'),
                message: _isPhoneRequired(s.error!)
                    ? l.mobileMoneyPhoneRequiredExplanation
                    : l.mobileMoneyPayerUnsupportedExplanation,
                phoneController: _payerPhoneController,
                onRetry: _payFromChoice,
              ),
            final MobileMoneyPaymentChoosePayer s => _ChoosePayerBody(
              state: s,
              remaining: _remaining,
              phoneController: _payerPhoneController,
              onPay: _payFromChoice,
            ),
            final MobileMoneyPaymentAwaitingConfirmation s => _AwaitingBody(
              status: s.status,
              remaining: _remaining,
            ),
            // Transitoire (tâche 8) : la tâche 9 donne à l'échéance passée
            // son propre corps « Pas encore validé ».
            final MobileMoneyPaymentOverdue s => _AwaitingBody(
              status: s.status,
              remaining: _remaining,
            ),
            final MobileMoneyPaymentDepositFailed s => _FailedBody(
              status: s.status,
              remaining: _remaining,
              phoneController: _payerPhoneController,
              onRetry: _changePayer,
            ),
            final MobileMoneyPaymentExpired s => _ExpiredBody(
              scope: widget.scope,
              status: s.status,
              onBack: () => _close(context, paid: false),
            ),
            MobileMoneyPaymentEscrowed() => const _EscrowedBody(),
            // Aucun numéro disponible pour payer (compte Firebase de
            // l'expéditeur sans téléphone), ou numéro que l'opérateur refuse
            // (téléphone du compte étranger, +33) : corps dédié avec saisie
            // obligatoire. Le DonyEmptyState générique montrait une icône
            // wifi barrée et « Réessayer » rejouait le même numéro, donc le
            // même refus (FLUTTER-MQ).
            final MobileMoneyPaymentError e when _needsPayerPhone(e.error) =>
              _PhoneRequiredBody(
                message: _isPhoneRequired(e.error)
                    ? l.mobileMoneyPhoneRequiredExplanation
                    : l.mobileMoneyPayerUnsupportedExplanation,
                phoneController: _payerPhoneController,
                onRetry: () => _retry(_payerPhoneController.text),
              ),
            MobileMoneyPaymentError() => DonyEmptyState(
              type: DonyEmptyStateType.error,
              title: l.commonSomethingWentWrong,
              actionLabel: l.commonRetry,
              onAction: () => context.read<MobileMoneyPaymentBloc>().add(
                MobileMoneyPaymentOpened(scope: widget.scope),
              ),
            ),
          },
        ),
      ),
    );
  }
}

/// Compte à rebours partagé par [_AwaitingBody] et [_FailedBody] : « Temps
/// restant mm:ss », rouge sous 5 minutes. Isolé dans son propre
/// `ValueListenableBuilder` pour ne redessiner que ce texte à chaque tick.
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
            Text(
              l.mobileMoneyTimeLeft(_format(value)),
              style: tt.bodyMedium?.copyWith(
                color: isUrgent ? cs.error : cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                // Chasse fixe : le texte ne doit pas sauter à chaque tick.
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// En-tête commun (montant, opérateur, numéro masqué) affiché en haut de
/// [_AwaitingBody] et [_FailedBody].
class _AmountCard extends StatelessWidget {
  const _AmountCard({required this.status});
  final MobileMoneyPaymentStatus status;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final deposit = status.deposit;

    return DonyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DonyIcon('smartphone', color: cs.primary, size: 28),
              const SizedBox(width: DonySpacing.sm),
              Text(
                formatPriceIn(status.amount ?? 0, status.currency),
                style: tt.headlineLarge,
              ),
            ],
          ),
          if (deposit?.providerLabel != null) ...[
            const SizedBox(height: DonySpacing.xs),
            Text(
              deposit!.providerLabel!,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
          if (deposit?.msisdnMasked != null) ...[
            const SizedBox(height: 2),
            Text(
              deposit!.msisdnMasked!,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

/// Étape « Qui paie ? », corps TRANSITOIRE (lot B, tâche 8) : la tâche 9 le
/// remplace par le bloc « compte qui paie » partagé (pays, opérateur, numéro
/// reconnu). Ici : montant, compte à rebours, numéro payeur facultatif (le
/// back retombe sur celui du compte), bandeau d'un refus d'initiation et
/// bouton collant « Payer `montant` ». L'opérateur reste celui que prédit le
/// back.
class _ChoosePayerBody extends StatelessWidget {
  const _ChoosePayerBody({
    required this.state,
    required this.remaining,
    required this.phoneController,
    required this.onPay,
  });

  final MobileMoneyPaymentChoosePayer state;
  final ValueListenable<Duration> remaining;
  final TextEditingController phoneController;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final status = state.status;
    final error = state.error;
    final amount = formatPriceIn(status.amount ?? 0, status.currency);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.xl,
              DonySpacing.lg,
              DonySpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AmountCard(status: status),
                if (status.deadlineAt != null) ...[
                  const SizedBox(height: DonySpacing.md),
                  _CountdownLabel(remaining: remaining),
                ],
                if (error != null) ...[
                  const SizedBox(height: DonySpacing.base),
                  DonyStatusBanner(
                    type: DonyStatusBannerType.error,
                    message: ErrorPresenter.resolve(error, l10n: l).message,
                  ),
                ],
                const SizedBox(height: DonySpacing.base),
                DonyTextField(
                  key: const Key('mobile-money-payer-phone-field'),
                  controller: phoneController,
                  label: l.mobileMoneyPayWithAnotherNumberOptional,
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DonySpacing.lg,
            DonySpacing.lg,
            DonySpacing.lg,
            DonySpacing.xl,
          ),
          child: DonyButton(
            label: l.mobileMoneyPay(amount),
            iconAsset: 'smartphone',
            isLoading: state.isSubmitting,
            onPressed: state.isSubmitting ? null : onPay,
          ),
        ),
      ],
    );
  }
}

/// Dépôt en cours : PIN opérateur à valider, ou redirection Wave à ouvrir.
class _AwaitingBody extends StatelessWidget {
  const _AwaitingBody({required this.status, required this.remaining});

  final MobileMoneyPaymentStatus status;
  final ValueListenable<Duration> remaining;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final waveUrl = status.deposit?.authorizationUrl;
    final providerLabel = status.deposit?.providerLabel;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(DonySpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AmountCard(status: status),
          if (status.deadlineAt != null) ...[
            const SizedBox(height: DonySpacing.lg),
            _CountdownLabel(remaining: remaining),
          ],
          const SizedBox(height: DonySpacing.xl),
          if (status.isWaveRedirect) ...[
            Text(l.mobileMoneyFinishInWaveApp, style: tt.bodyMedium),
            const SizedBox(height: DonySpacing.base),
            DonyButton(
              label: l.mobileMoneyOpenWave,
              iconAsset: 'external-link',
              onPressed: waveUrl != null
                  ? () => getIt<ExternalUrlLauncher>().open(Uri.parse(waveUrl))
                  : null,
            ),
          ] else
            Text(
              providerLabel != null
                  ? l.mobileMoneyPinSent(providerLabel)
                  : l.mobileMoneyPinSentUnknownProvider,
              style: tt.bodyMedium,
            ),
          const SizedBox(height: DonySpacing.xl),
          Text(
            l.mobileMoneyConfirmationAutomatic,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Dernier dépôt refusé par l'opérateur : possibilité de relancer, avec un
/// numéro payeur différent en option.
class _FailedBody extends StatelessWidget {
  const _FailedBody({
    required this.status,
    required this.remaining,
    required this.phoneController,
    required this.onRetry,
  });

  final MobileMoneyPaymentStatus status;
  final ValueListenable<Duration> remaining;
  final TextEditingController phoneController;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(DonySpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: DonyIcon('circle-alert', color: cs.error, size: 48)),
          const SizedBox(height: DonySpacing.base),
          Text(
            status.deposit?.failureMessage ??
                l.mobileMoneyDepositRefusedFallback,
            textAlign: TextAlign.center,
            style: tt.bodyMedium,
          ),
          if (status.deadlineAt != null) ...[
            const SizedBox(height: DonySpacing.lg),
            Center(child: _CountdownLabel(remaining: remaining)),
          ],
          const SizedBox(height: DonySpacing.xl),
          DonyTextField(
            key: const Key('mobile-money-retry-phone-field'),
            controller: phoneController,
            label: l.mobileMoneyPayWithAnotherNumberOptional,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: DonySpacing.base),
          DonyButton(label: l.commonRetry, onPressed: onRetry),
        ],
      ),
    );
  }
}

/// Aucun numéro disponible pour payer (compte Firebase de l'expéditeur sans
/// téléphone, vérification SMS Twilio pas encore configurée) : contrairement
/// à [_FailedBody], le numéro est ici obligatoire (rien à quoi se replier
/// côté backend), donc la relance reste désactivée tant qu'aucun numéro
/// valide n'est saisi. Pas de `setState` : `ListenableBuilder` s'abonne
/// directement au [TextEditingController], déjà un `Listenable`.
class _PhoneRequiredBody extends StatelessWidget {
  const _PhoneRequiredBody({
    super.key,
    required this.message,
    required this.phoneController,
    required this.onRetry,
  });

  final String message;
  final TextEditingController phoneController;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(DonySpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: DonyIcon('smartphone', color: cs.primary, size: 48)),
          const SizedBox(height: DonySpacing.base),
          Text(message, textAlign: TextAlign.center, style: tt.bodyMedium),
          const SizedBox(height: DonySpacing.xl),
          DonyTextField(
            key: const Key('mobile-money-phone-required-field'),
            controller: phoneController,
            label: l.mobileMoneyPhoneThatWillPayLabel,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: DonySpacing.base),
          ListenableBuilder(
            listenable: phoneController,
            builder: (context, _) => DonyButton(
              label: l.commonRetry,
              onPressed: normalizePayerPhone(phoneController.text) == null
                  ? null
                  : onRetry,
            ),
          ),
        ],
      ),
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
