import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
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
import 'package:dony/features/matching/presentation/widgets/create_bid/payer_phone.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Écran d'attente du paiement mobile money (Wave / Orange Money via
/// pawaPay) d'un bid, ouvert depuis le détail de l'envoi
/// (`context.push<bool>('/bids/{id}/mobile-money/awaiting')`), une
/// notification `MM_PAYMENT_PENDING` ou le lien profond
/// `yadony://bids/{uuid}/mobile-money/awaiting`.
///
/// L'ouverture déclenche le dépôt (push PIN chez l'opérateur, ou redirection
/// Wave via `authorizationUrl`) : le bloc s'en charge lui-même dès
/// `MobileMoneyPaymentOpened`. L'écran sonde ensuite le statut jusqu'au
/// séquestre, puis se referme sur `context.pop(true)` — le détail de
/// l'envoi se recharge au retour.
class MobileMoneyAwaitingScreen extends StatefulWidget {
  const MobileMoneyAwaitingScreen({super.key, required this.bidId});
  final String bidId;

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        getIt<AnalyticsService>().logEvent(
          AnalyticsEvents.mobileMoneyAwaiting,
          properties: {'provider': 'mobile_money'},
        ),
      );
    });
    context.read<MobileMoneyPaymentBloc>().add(
      MobileMoneyPaymentOpened(bidId: widget.bidId),
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
        MobileMoneyStatusPolled(bidId: widget.bidId),
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

  void _retry(String rawPhone) {
    context.read<MobileMoneyPaymentBloc>().add(
      MobileMoneyPaymentInitiateRequested(
        bidId: widget.bidId,
        phoneNumber: normalizePayerPhone(rawPhone),
      ),
    );
    // DepositFailed a arrêté le sondage : la relance le redémarre aussitôt,
    // sans attendre un futur changement d'état.
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    _remaining.dispose();
    _retryPhoneController.dispose();
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
                context.pop(true);
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
            final MobileMoneyPaymentAwaitingConfirmation s => _AwaitingBody(
              status: s.status,
              remaining: _remaining,
            ),
            final MobileMoneyPaymentDepositFailed s => _FailedBody(
              status: s.status,
              remaining: _remaining,
              phoneController: _retryPhoneController,
              onRetry: () => _retry(_retryPhoneController.text),
            ),
            MobileMoneyPaymentExpired() => _ExpiredBody(
              onBack: () => context.pop(false),
            ),
            MobileMoneyPaymentEscrowed() => const _EscrowedBody(),
            MobileMoneyPaymentError() => DonyEmptyState(
              type: DonyEmptyStateType.error,
              title: 'Une erreur est survenue',
              actionLabel: 'Réessayer',
              onAction: () => context.read<MobileMoneyPaymentBloc>().add(
                MobileMoneyPaymentOpened(bidId: widget.bidId),
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

/// Fenêtre de 30 minutes dépassée (ou bid annulé) sans séquestre.
class _ExpiredBody extends StatelessWidget {
  const _ExpiredBody({required this.onBack});
  final VoidCallback onBack;

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
            Text(
              'Délai dépassé. La demande a été annulée, refais une offre au '
              'voyageur.',
              textAlign: TextAlign.center,
              style: tt.bodyMedium,
            ),
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
