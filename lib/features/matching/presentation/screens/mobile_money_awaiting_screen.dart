import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_bloc.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_event.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

// NOTE : adaptation a minima au bloc réécrit par la tâche 5 du plan pawaPay.
// Cet écran est entièrement redessiné par la tâche 12 ; il ne fait ici que
// suivre le nouveau contrat d'events/states (Opened/InitiateRequested/Polled,
// AwaitingConfirmation/Escrowed/DepositFailed/Expired/Error).
class MobileMoneyAwaitingScreen extends StatefulWidget {
  const MobileMoneyAwaitingScreen({super.key, required this.bidId});
  final String bidId;

  @override
  State<MobileMoneyAwaitingScreen> createState() =>
      _MobileMoneyAwaitingScreenState();
}

class _MobileMoneyAwaitingScreenState extends State<MobileMoneyAwaitingScreen> {
  Timer? _pollingTimer;

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
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _poll();
    });
  }

  void _poll() {
    context.read<MobileMoneyPaymentBloc>().add(
      MobileMoneyStatusPolled(bidId: widget.bidId),
    );
  }

  void _retryInitiate() {
    context.read<MobileMoneyPaymentBloc>().add(
      MobileMoneyPaymentInitiateRequested(bidId: widget.bidId),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        leading: const DonyAppBarBackButton(),
        title: Text('Paiement Mobile Money', style: tt.headlineMedium),
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: cs.outline),
        ),
      ),
      body: BlocConsumer<MobileMoneyPaymentBloc, MobileMoneyPaymentState>(
        listener: (context, state) {
          if (state is MobileMoneyPaymentEscrowed) {
            _pollingTimer?.cancel();
            DonySnackbar.show(
              context,
              message: 'Paiement confirmé',
              type: DonySnackbarType.success,
            );
            context.go('/bids/${widget.bidId}');
          } else if (state is MobileMoneyPaymentExpired ||
              state is MobileMoneyPaymentDepositFailed) {
            _pollingTimer?.cancel();
          } else if (state is MobileMoneyPaymentError) {
            _pollingTimer?.cancel();
            // Jamais state.error brut (String/Object non traduit) : toujours
            // passer par ErrorPresenter, qui résout le code métier via
            // ErrorCatalog et retombe sur un message générique français.
            unawaited(ErrorPresenter.show(context, state.error));
          }
        },
        builder: (context, state) {
          if (state is MobileMoneyPaymentLoading ||
              state is MobileMoneyPaymentInitial) {
            return Center(child: CircularProgressIndicator(color: cs.primary));
          }

          if (state is MobileMoneyPaymentEscrowed) {
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

          if (state is MobileMoneyPaymentExpired) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: DonySpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DonyIcon('timer-off', color: cs.warning, size: 48),
                    const SizedBox(height: DonySpacing.base),
                    Text('Lien expiré', style: tt.headlineLarge),
                    const SizedBox(height: DonySpacing.sm),
                    Text(
                      'Votre lien de paiement a expiré.',
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: DonySpacing.xl),
                    DonyButton(
                      label: 'Régénérer le lien',
                      onPressed: _retryInitiate,
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is MobileMoneyPaymentDepositFailed) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: DonySpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DonyIcon('circle-alert', color: cs.error, size: 48),
                    const SizedBox(height: DonySpacing.base),
                    Text(
                      state.status.deposit?.failureMessage ?? 'Paiement refusé',
                      textAlign: TextAlign.center,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: DonySpacing.xl),
                    DonyButton(label: 'Réessayer', onPressed: _retryInitiate),
                  ],
                ),
              ),
            );
          }

          if (state is MobileMoneyPaymentError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: DonySpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DonyIcon('circle-alert', color: cs.error, size: 48),
                    const SizedBox(height: DonySpacing.base),
                    // Jamais state.error.toString() : message technique
                    // potentiellement non traduit. Le détail exploitable est
                    // déjà montré par ErrorPresenter (listener ci-dessus).
                    Text(
                      'Une erreur est survenue',
                      textAlign: TextAlign.center,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: DonySpacing.base),
                    TextButton(
                      onPressed: () => context
                          .read<MobileMoneyPaymentBloc>()
                          .add(MobileMoneyPaymentOpened(bidId: widget.bidId)),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            );
          }

          // AwaitingConfirmation
          final awaiting = state as MobileMoneyPaymentAwaitingConfirmation;
          final paymentLink = awaiting.status.deposit?.authorizationUrl ?? '';
          final expiresAt = awaiting.status.deadlineAt;
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.xxl,
              DonySpacing.lg,
              DonySpacing.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Contenu scrollable, CTA épinglé en bas (anti-overflow).
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Hero card
                            Container(
                              padding: const EdgeInsets.all(DonySpacing.lg),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    DonyColors.blue700,
                                    DonyColors.blue500,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(
                                  DonyRadius.card,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const DonyIcon(
                                    'smartphone',
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                  const SizedBox(width: DonySpacing.base),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'En attente de paiement',
                                          style: tt.titleLarge?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: DonySpacing.xs),
                                        Text(
                                          'Cliquez sur le bouton pour payer',
                                          style: tt.bodySmall?.copyWith(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: DonySpacing.xl),

                            // Expiry info
                            if (expiresAt != null) ...[
                              Text(
                                'Lien valable jusqu\'à '
                                '${expiresAt.hour.toString().padLeft(2, '0')}:'
                                '${expiresAt.minute.toString().padLeft(2, '0')}',
                                style: tt.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: DonySpacing.xs),
                            ],
                            Text(
                              'Une fois payé, la confirmation est automatique.',
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: DonySpacing.xl),

                // CTA
                DonyButton(
                  label: 'Payer maintenant',
                  iconAsset: 'external-link',
                  onPressed: paymentLink.isNotEmpty
                      ? () => _openLink(paymentLink)
                      : null,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
