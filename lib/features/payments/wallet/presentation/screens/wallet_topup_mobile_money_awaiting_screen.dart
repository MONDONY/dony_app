import 'dart:async';

import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/external_url_launcher.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_topup_mobile_money_cubit.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_topup_mobile_money_state.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_topup_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Écran d'attente d'une recharge de portefeuille par mobile money — sondage
/// déjà démarré par [WalletTopupMobileMoneyCubit.initiate] (poussé depuis
/// l'écran de montant via `pushReplacement` : cet écran remplace celui de
/// montant dans la pile, si bien qu'un `context.pop()` depuis ici revient
/// directement à l'écran de choix de méthode).
///
/// Le cubit est fourni par un ancêtre (`BlocProvider.value` posé par
/// `router.dart` avec l'instance créée par l'écran de choix) : jamais
/// recréé ici, pour ne jamais perdre le sondage en cours.
class WalletTopupMobileMoneyAwaitingScreen extends StatefulWidget {
  const WalletTopupMobileMoneyAwaitingScreen({
    super.key,
    required this.phoneNumber,
    required this.amount,
  });

  /// Numéro payeur, réutilisé par « Réessayer » après un
  /// [WalletTopupMobileMoneyFailed].
  final String phoneNumber;

  /// Montant de la recharge, réutilisé par « Réessayer » — [WalletTopupModel]
  /// ne le porte pas lui-même (seul [WalletTopupStatusModel] l'expose,
  /// après le premier sondage).
  final double amount;

  @override
  State<WalletTopupMobileMoneyAwaitingScreen> createState() =>
      _WalletTopupMobileMoneyAwaitingScreenState();
}

class _WalletTopupMobileMoneyAwaitingScreenState
    extends State<WalletTopupMobileMoneyAwaitingScreen> {
  static const _tick = Duration(seconds: 1);

  Timer? _countdownTimer;

  /// Jamais mis à jour via `setState` : seul `_CountdownValue` (via
  /// `ValueListenableBuilder`) se redessine à chaque tick.
  final ValueNotifier<Duration> _remaining = ValueNotifier(Duration.zero);

  /// Capturé à l'ouverture : `onPopInvokedWithResult` se déclenche alors que
  /// cette route est déjà dépilée, un `context.read` y serait trop tard.
  late final WalletTopupMobileMoneyCubit _cubit = context
      .read<WalletTopupMobileMoneyCubit>();

  @override
  void initState() {
    super.initState();
    _syncCountdown(_cubit.state);
    _countdownTimer = Timer.periodic(_tick, (_) {
      if (!mounted) return;
      _syncCountdown(_cubit.state);
    });
  }

  /// Sortie par le bouton retour de l'AppBar ou par le geste système : même
  /// traitement que « Payer avec un autre numéro ». Sans ce reset, le cubit
  /// (partagé avec l'écran de choix) resterait `Awaiting` et continuerait de
  /// sonder : l'écran de choix n'a pas de bras pour cet état (plus d'
  /// opérateurs, « Suivant » mort, `loadProviders` refusé), et la
  /// confirmation qui finirait par arriver n'aurait plus personne pour
  /// l'annoncer — l'utilisateur croirait à un échec alors que l'argent est
  /// débité, et paierait une seconde fois.
  void _onPopped(bool didPop, Object? result) {
    if (!didPop) return;
    // Rien à abandonner : recharge confirmée (le portefeuille est crédité),
    // ou déjà réinitialisée par « Payer avec un autre numéro ».
    if (_cubit.state is WalletTopupMobileMoneyConfirmed ||
        _cubit.state is WalletTopupMobileMoneyIdle) {
      return;
    }
    _cubit.reset();
  }

  void _syncCountdown(WalletTopupMobileMoneyState state) {
    if (state is! WalletTopupMobileMoneyAwaiting) return;
    final deadline = state.startedAt.add(WalletTopupMobileMoneyCubit.expiry);
    final diff = deadline.difference(DateTime.now());
    _remaining.value = diff.isNegative ? Duration.zero : diff;
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _remaining.dispose();
    super.dispose();
  }

  void _retry(BuildContext context) {
    context.read<WalletTopupMobileMoneyCubit>().initiate(
      amount: widget.amount,
      phoneNumber: widget.phoneNumber,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      onPopInvokedWithResult: _onPopped,
      child: _buildScaffold(context, cs),
    );
  }

  Widget _buildScaffold(BuildContext context, ColorScheme cs) {
    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        actions: const [DonyFeedbackButton()],
        leading: const DonyAppBarBackButton(),
        title: const Text('Recharge mobile money'),
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
                switch (state) {
                  case final WalletTopupMobileMoneyConfirmed s:
                    _countdownTimer?.cancel();
                    context.go(
                      '/payments/wallet',
                      extra: {'topupConfirmed': s.status},
                    );
                  // L'erreur technique n'est plus présentée en surimpression :
                  // le corps de l'écran l'affiche avec son bouton
                  // « Réessayer », un second message dirait la même chose.
                  default:
                }
              },
              builder: (context, state) => Column(
                children: [
                  Expanded(
                    child: switch (state) {
                      final WalletTopupMobileMoneyAwaiting s => _AwaitingBody(
                        topup: s.topup,
                        amount: widget.amount,
                        remaining: _remaining,
                      ),
                      final WalletTopupMobileMoneyFailed f => _FailedBody(
                        message: f.message,
                      ),
                      // Une erreur technique (réseau coupé pendant une
                      // reprise) se traite comme un échec : sans ce bras,
                      // l'écran restait sur une roue infinie et sans bouton,
                      // le retour arrière pour seule issue.
                      final WalletTopupMobileMoneyError e => _FailedBody(
                        message: ErrorPresenter.resolve(e.error).message,
                      ),
                      _ => Center(
                        child: CircularProgressIndicator(color: cs.primary),
                      ),
                    },
                  ),
                  _bottomFor(context, state),
                ],
              ),
            ),
      ),
    );
  }

  Widget _bottomFor(BuildContext context, WalletTopupMobileMoneyState state) {
    if (state is WalletTopupMobileMoneyFailed ||
        state is WalletTopupMobileMoneyError) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          DonySpacing.lg,
          0,
          DonySpacing.lg,
          MediaQuery.paddingOf(context).bottom + DonySpacing.lg,
        ),
        child: DonyButton(
          key: const Key('mobile-money-awaiting-retry'),
          label: 'Réessayer',
          onPressed: () => _retry(context),
        ),
      );
    }
    if (state is WalletTopupMobileMoneyAwaiting) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          DonySpacing.lg,
          0,
          DonySpacing.lg,
          MediaQuery.paddingOf(context).bottom + DonySpacing.lg,
        ),
        child: DonyButton(
          key: const Key('mobile-money-awaiting-other-number'),
          label: 'Payer avec un autre numéro',
          variant: DonyButtonVariant.ghost,
          // L'abandon de la recharge n'est pas écrit ici : il vit dans le
          // [PopScope] de l'écran, seul endroit traversé par TOUTES les
          // sorties (ce bouton, le retour de l'AppBar, le geste système).
          onPressed: () => context.pop(),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

/// Icône pulsée, texte d'attente, carte de détails (montant, crédité sur,
/// expire dans) et, pour Wave, bouton d'ouverture de la page de redirection.
class _AwaitingBody extends StatelessWidget {
  const _AwaitingBody({
    required this.topup,
    required this.amount,
    required this.remaining,
  });

  final WalletTopupModel topup;
  final double amount;
  final ValueListenable<Duration> remaining;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final currency = SupportedCurrency.fromCodeOrDefault(topup.currency);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(DonySpacing.lg),
      child: Column(
        children: [
          const SizedBox(height: DonySpacing.md),
          const _PulsingIcon(),
          const SizedBox(height: DonySpacing.xl),
          Text(
            'Valide le paiement sur ton téléphone',
            textAlign: TextAlign.center,
            style: tt.headlineMedium,
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            'Une demande de paiement a été envoyée à ${topup.msisdnMasked} '
            'via ${topup.providerLabel}.',
            textAlign: TextAlign.center,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: DonySpacing.base),
          Text(
            'La confirmation est automatique, garde cet écran ouvert.',
            textAlign: TextAlign.center,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: DonySpacing.xl),
          DonyCard(
            child: Column(
              children: [
                DonyInfoRow(
                  label: 'Montant',
                  value: CurrencyFormatter.format(amount, currency),
                ),
                const DonyInfoRow.divider(),
                DonyInfoRow(
                  label: 'Crédité sur',
                  value: 'Solde Yadony (${currency.code})',
                ),
                const DonyInfoRow.divider(),
                DonyInfoRow(
                  label: 'Expire dans',
                  value: '',
                  valueWidget: ValueListenableBuilder<Duration>(
                    valueListenable: remaining,
                    builder: (context, value, _) =>
                        Text(_formatCountdown(value)),
                  ),
                ),
              ],
            ),
          ),
          if (topup.authorizationUrl case final String url) ...[
            const SizedBox(height: DonySpacing.xl),
            DonyButton(
              key: const Key('mobile-money-awaiting-open-authorization'),
              label: 'Ouvrir ${topup.providerLabel}',
              iconAsset: 'external-link',
              onPressed: () =>
                  getIt<ExternalUrlLauncher>().open(Uri.parse(url)),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatCountdown(Duration d) {
    final mm = d.inMinutes.toString().padLeft(2, '0');
    final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }
}

/// Dernier dépôt refusé par l'opérateur (ou sondage expiré) : message et
/// bouton « Réessayer » dans le [_bottomFor] sticky du parent.
class _FailedBody extends StatelessWidget {
  const _FailedBody({required this.message});

  final String message;

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
            DonyIcon('circle-alert', color: cs.error, size: 48),
            const SizedBox(height: DonySpacing.base),
            Text(message, textAlign: TextAlign.center, style: tt.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// Icône « smartphone » qui respire en boucle (agrandissement/réduction) :
/// signale une attente active sans texte supplémentaire. `AnimationController`
/// brut (pas `flutter_animate`) — un `Ticker`, jamais un `Timer` `dart:async`,
/// se coupe proprement dans [dispose] sans laisser de minuterie en vol.
class _PulsingIcon extends StatefulWidget {
  const _PulsingIcon();

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<double> _scale = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  ).drive(Tween(begin: 1, end: 1.08));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ScaleTransition(
      scale: _scale,
      child: DonyIcon('smartphone', color: cs.primary, size: 64),
    );
  }
}
