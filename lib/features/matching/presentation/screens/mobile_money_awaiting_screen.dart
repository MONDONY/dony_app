import 'dart:async';

import 'package:dony/core/currency/country_catalog.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/error/error_presenter.dart';
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
import 'package:dony/features/matching/presentation/widgets/create_bid/payer_phone.dart';
import 'package:dony/features/payments/presentation/widgets/mobile_money_networks_checklist.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Écran d'attente du paiement mobile money (Wave / Orange Money via
/// pawaPay) d'un bid ou d'un fil de négociation, ouvert depuis le détail de
/// l'envoi ou le fil (`context.push<bool>(scope.awaitingRoute)`), une
/// notification `MM_PAYMENT_PENDING` ou le lien profond
/// `yadony://bids/{uuid}/mobile-money/awaiting` (ou
/// `yadony://negotiations/{uuid}/mobile-money/awaiting`).
///
/// L'ouverture déclenche le dépôt (push PIN chez l'opérateur, ou redirection
/// Wave via `authorizationUrl`) : le bloc s'en charge lui-même dès
/// `MobileMoneyPaymentOpened`. [initialPhone] porte le numéro payeur déjà
/// saisi (feuille de récapitulatif), absent depuis un lien profond ou une
/// notification. L'écran sonde ensuite le statut jusqu'au séquestre, puis se
/// referme sur `context.pop(true)` — l'appelant se recharge au retour.
class MobileMoneyAwaitingScreen extends StatefulWidget {
  const MobileMoneyAwaitingScreen({
    super.key,
    required this.scope,
    this.initialPhone,
  });

  /// Bid ou fil de négociation dont ce dépôt paie l'escrow.
  final MobileMoneyScope scope;

  /// Numéro payeur déjà connu, envoyé avec `MobileMoneyPaymentOpened` à
  /// l'ouverture.
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
  final TextEditingController _retryPhoneController = TextEditingController();
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
      MobileMoneyPaymentOpened(
        scope: widget.scope,
        phoneNumber: widget.initialPhone,
      ),
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
        final MobileMoneyPaymentChooseOperator s => s.status.deadlineAt,
        final MobileMoneyPaymentAwaitingConfirmation s => s.status.deadlineAt,
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

  /// Depuis un dépôt refusé (`_FailedBody`) : retour à l'étape de choix de
  /// l'opérateur (numéro éventuellement changé), jamais une relance aveugle
  /// avec l'opérateur prédit. Distinct de [_retry], que garde
  /// [_PhoneRequiredBody] : sans aucun numéro connu, il n'y a encore rien à
  /// choisir, seulement un numéro à fournir avant la toute première
  /// initiation.
  void _retryToChooseOperator(String rawPhone) {
    context.read<MobileMoneyPaymentBloc>().add(
      MobileMoneyPaymentProvidersRequested(
        scope: widget.scope,
        phoneNumber: normalizePayerPhone(rawPhone),
      ),
    );
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    _remaining.dispose();
    _retryPhoneController.dispose();
    _payerPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        leading: const DonyAppBarBackButton(),
        title: const Text('Paiement mobile money'),
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
                  message: 'Paiement confirmé, ton envoi est sécurisé',
                  type: DonySnackbarType.success,
                );
                _close(context, paid: true);
              case MobileMoneyPaymentExpired():
                _cancelAllTimers();
              case MobileMoneyPaymentDepositFailed():
                _pollingTimer?.cancel();
              case final MobileMoneyPaymentError e:
                unawaited(ErrorPresenter.show(context, e.error));
              case _:
            }
          },
          builder: (context, state) => switch (state) {
            MobileMoneyPaymentInitial() || MobileMoneyPaymentLoading() =>
              Center(child: CircularProgressIndicator(color: cs.primary)),
            final MobileMoneyPaymentChooseOperator s => _ChooseOperatorBody(
              state: s,
              remaining: _remaining,
              phoneController: _payerPhoneController,
              onPhoneConfirmed: (phone) =>
                  context.read<MobileMoneyPaymentBloc>().add(
                    MobileMoneyPaymentProvidersRequested(
                      scope: widget.scope,
                      phoneNumber: phone,
                    ),
                  ),
              onPay: (provider) => context.read<MobileMoneyPaymentBloc>().add(
                MobileMoneyPaymentInitiateRequested(
                  scope: widget.scope,
                  phoneNumber: normalizePayerPhone(_payerPhoneController.text),
                  provider: provider,
                ),
              ),
            ),
            final MobileMoneyPaymentAwaitingConfirmation s => _AwaitingBody(
              status: s.status,
              remaining: _remaining,
            ),
            final MobileMoneyPaymentDepositFailed s => _FailedBody(
              status: s.status,
              remaining: _remaining,
              phoneController: _retryPhoneController,
              onRetry: () => _retryToChooseOperator(_retryPhoneController.text),
            ),
            MobileMoneyPaymentExpired() => _ExpiredBody(
              scope: widget.scope,
              onBack: () => _close(context, paid: false),
            ),
            MobileMoneyPaymentEscrowed() => const _EscrowedBody(),
            // Aucun numéro disponible pour payer (compte Firebase de
            // l'expéditeur sans téléphone) : corps dédié avec saisie
            // obligatoire, plutôt que le DonyEmptyState générique.
            final MobileMoneyPaymentError e when _isPhoneRequired(e.error) =>
              _PhoneRequiredBody(
                phoneController: _retryPhoneController,
                onRetry: () => _retry(_retryPhoneController.text),
              ),
            MobileMoneyPaymentError() => DonyEmptyState(
              type: DonyEmptyStateType.error,
              title: 'Une erreur est survenue',
              actionLabel: 'Réessayer',
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

  static String _format(Duration d) {
    final mm = d.inMinutes.toString().padLeft(2, '0');
    final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
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
              'Temps restant ${_format(value)}',
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

/// Étape « Avec quel opérateur ? » : montant et compte à rebours, numéro
/// payeur (masqué, modifiable), réseaux acceptés par le voyageur pour ce
/// numéro, bouton collant « Payer `montant` ». Sélection dans un
/// [ValueNotifier] (détecté pré-sélectionné), saisie d'un autre numéro
/// suivie d'un rechargement du catalogue après 400 ms. Aucun `setState`.
class _ChooseOperatorBody extends StatefulWidget {
  const _ChooseOperatorBody({
    required this.state,
    required this.remaining,
    required this.phoneController,
    required this.onPhoneConfirmed,
    required this.onPay,
  });

  final MobileMoneyPaymentChooseOperator state;
  final ValueListenable<Duration> remaining;
  final TextEditingController phoneController;

  /// Recharge le catalogue pour [phone] (`null` = numéro du bid). Appelé
  /// après le délai de 400 ms sur une saisie, et immédiatement par le
  /// bouton « Réessayer » du bandeau d'erreur (même numéro que la tentative
  /// qui a échoué).
  final ValueChanged<String?> onPhoneConfirmed;
  final ValueChanged<String> onPay;

  @override
  State<_ChooseOperatorBody> createState() => _ChooseOperatorBodyState();
}

class _ChooseOperatorBodyState extends State<_ChooseOperatorBody> {
  static const _debounce = Duration(milliseconds: 400);
  final ValueNotifier<String?> _selected = ValueNotifier(null);
  Timer? _timer;
  String? _requestedPhone;

  @override
  void initState() {
    super.initState();
    _selected.value =
        widget.state.catalog?.detectedOption?.code ?? _firstCode();
    _requestedPhone = widget.state.payerPhone;
    widget.phoneController.addListener(_onPhoneChanged);
  }

  @override
  void didUpdateWidget(covariant _ChooseOperatorBody old) {
    super.didUpdateWidget(old);
    final catalog = widget.state.catalog;
    if (catalog != old.state.catalog) {
      final codes = catalog?.providers.map((p) => p.code).toSet() ?? {};
      final keep = _selected.value != null && codes.contains(_selected.value);
      _selected.value = keep
          ? _selected.value
          : (catalog?.detectedOption?.code ?? _firstCode());
    }
  }

  String? _firstCode() {
    final providers = widget.state.catalog?.providers;
    return providers == null || providers.isEmpty ? null : providers.first.code;
  }

  void _onPhoneChanged() {
    _timer?.cancel();
    final phone = normalizePayerPhone(widget.phoneController.text);
    if (phone == _requestedPhone) return;
    _timer = Timer(_debounce, () {
      if (!mounted) return;
      _requestedPhone = phone;
      if (phone != null) widget.onPhoneConfirmed(phone);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.phoneController.removeListener(_onPhoneChanged);
    _selected.dispose();
    super.dispose();
  }

  String _country(String? code) =>
      CountryCatalog.byCode(code)?.name ?? code ?? '';

  String _joinLabels(List<String> labels) => switch (labels.length) {
    0 => '',
    1 => labels.first,
    _ => '${labels.sublist(0, labels.length - 1).join(', ')} et ${labels.last}',
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final status = widget.state.status;
    final catalog = widget.state.catalog;
    final firstName = catalog?.travelerFirstName ?? 'Le voyageur';
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
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AmountCard(status: status),
                if (status.deadlineAt != null) ...[
                  const SizedBox(height: DonySpacing.md),
                  _CountdownLabel(remaining: widget.remaining),
                ],
                const SizedBox(height: DonySpacing.base),
                DonyCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DonyInfoRow(
                        label: 'Numéro qui paie',
                        value: catalog?.msisdnMasked ?? '…',
                      ),
                      const SizedBox(height: DonySpacing.sm),
                      DonyTextField(
                        key: const Key('mobile-money-payer-phone-field'),
                        controller: widget.phoneController,
                        label: 'Payer avec un autre numéro (facultatif)',
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DonySpacing.base),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        'Avec quel opérateur ?',
                        style: tt.titleLarge,
                      ),
                    ),
                    if (catalog?.country != null)
                      Text(
                        _country(catalog!.country),
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: DonySpacing.md),
                if (widget.state.isLoadingCatalog && catalog == null)
                  const MobileMoneyNetworksSkeleton()
                else if (widget.state.error != null)
                  DonyStatusBanner(
                    type: DonyStatusBannerType.error,
                    message: ErrorPresenter.resolve(widget.state.error).message,
                    action: TextButton(
                      onPressed: () =>
                          widget.onPhoneConfirmed(widget.state.payerPhone),
                      child: const Text('Réessayer'),
                    ),
                  )
                else if (catalog == null || catalog.isEmpty)
                  DonyStatusBanner(
                    type: DonyStatusBannerType.warning,
                    message:
                        '$firstName accepte ${_joinLabels(catalog?.travelerAccepts ?? const [])}, '
                        "qui n'existent pas pour ton numéro (${_country(catalog?.country)}). "
                        'Change de numéro payeur ou écris-lui depuis la conversation.',
                  )
                else ...[
                  ValueListenableBuilder<String?>(
                    valueListenable: _selected,
                    builder: (context, selected, _) => DonyCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DonySpacing.base,
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < catalog.providers.length; i++)
                            DonyOperatorTile(
                              key: Key('operator-${catalog.providers[i].code}'),
                              brand: catalog.providers[i].brand,
                              title: catalog.providers[i].label,
                              subtitle: catalog.providers[i].detected
                                  ? 'Détecté pour ce numéro'
                                  : catalog.providers[i].brand == 'WAVE'
                                  ? "Tu confirmes dans l'application Wave"
                                  : null,
                              control: DonyOperatorControl.radio,
                              selected: selected == catalog.providers[i].code,
                              showDivider: i < catalog.providers.length - 1,
                              onChanged: (_) =>
                                  _selected.value = catalog.providers[i].code,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: DonySpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DonyIcon('info', size: 16, color: cs.onSurfaceVariant),
                      const SizedBox(width: DonySpacing.sm),
                      Expanded(
                        child: Text(
                          '$firstName accepte ${_joinLabels(catalog.travelerAccepts)}, '
                          'et reçoit sur le réseau que tu choisis.',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: DonySpacing.xl),
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
          child: ValueListenableBuilder<String?>(
            valueListenable: _selected,
            builder: (context, selected, _) => DonyButton(
              label: 'Payer $amount',
              iconAsset: 'smartphone',
              isLoading: widget.state.isLoadingCatalog && catalog != null,
              onPressed: selected == null || catalog == null || catalog.isEmpty
                  ? null
                  : () => widget.onPay(selected),
            ),
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
            Text(
              "Termine le paiement dans l'application Wave",
              style: tt.bodyMedium,
            ),
            const SizedBox(height: DonySpacing.base),
            DonyButton(
              label: 'Ouvrir Wave',
              iconAsset: 'external-link',
              onPressed: waveUrl != null
                  ? () => getIt<ExternalUrlLauncher>().open(Uri.parse(waveUrl))
                  : null,
            ),
          ] else
            Text(
              'Valide le paiement sur ton téléphone : une demande de code '
              "PIN vient de t'être envoyée par "
              "${providerLabel ?? 'ton opérateur'}.",
              style: tt.bodyMedium,
            ),
          const SizedBox(height: DonySpacing.xl),
          Text(
            'La confirmation est automatique, garde cet écran ouvert.',
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(DonySpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: DonyIcon('circle-alert', color: cs.error, size: 48)),
          const SizedBox(height: DonySpacing.base),
          Text(
            status.deposit?.failureMessage ??
                "Le paiement a été refusé par l'opérateur",
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
            label: 'Payer avec un autre numéro (facultatif)',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: DonySpacing.base),
          DonyButton(label: 'Réessayer', onPressed: onRetry),
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
    required this.phoneController,
    required this.onRetry,
  });

  final TextEditingController phoneController;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(DonySpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: DonyIcon('smartphone', color: cs.primary, size: 48)),
          const SizedBox(height: DonySpacing.base),
          Text(
            "Ton compte Yadony n'a pas de numéro de téléphone : indique le "
            'numéro mobile money qui paiera.',
            textAlign: TextAlign.center,
            style: tt.bodyMedium,
          ),
          const SizedBox(height: DonySpacing.xl),
          DonyTextField(
            key: const Key('mobile-money-phone-required-field'),
            controller: phoneController,
            label: 'Numéro qui paiera',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: DonySpacing.base),
          ListenableBuilder(
            listenable: phoneController,
            builder: (context, _) => DonyButton(
              label: 'Réessayer',
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
  const _ExpiredBody({required this.scope, required this.onBack});
  final MobileMoneyScope scope;
  final VoidCallback onBack;

  String get _message => switch (scope) {
    BidMobileMoneyScope() =>
      'Délai dépassé. La demande a été annulée, refais une offre au '
          'voyageur.',
    NegotiationMobileMoneyScope() =>
      'Délai dépassé. Le fil est revenu à « à payer » : tu peux relancer le '
          'paiement ou changer de moyen de paiement depuis le fil.',
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyIcon('timer-off', color: cs.warning, size: 48),
            const SizedBox(height: DonySpacing.base),
            Text(_message, textAlign: TextAlign.center, style: tt.bodyMedium),
            const SizedBox(height: DonySpacing.xl),
            DonyButton(
              label: 'Retour',
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
          Text('Paiement confirmé', style: tt.headlineLarge),
        ],
      ),
    );
  }
}
