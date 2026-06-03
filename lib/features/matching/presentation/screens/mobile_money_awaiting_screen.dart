import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_bloc.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_event.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_state.dart';

class MobileMoneyAwaitingScreen extends StatefulWidget {
  const MobileMoneyAwaitingScreen({super.key, required this.bidId});
  final String bidId;

  @override
  State<MobileMoneyAwaitingScreen> createState() =>
      _MobileMoneyAwaitingScreenState();
}

class _MobileMoneyAwaitingScreenState
    extends State<MobileMoneyAwaitingScreen> {
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(getIt<AnalyticsService>().logEvent(
        AnalyticsEvents.mobileMoneyAwaiting,
        properties: {'provider': 'mobile_money'},
      ));
    });
    _poll();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _poll();
    });
  }

  void _poll() {
    context
        .read<MobileMoneyPaymentBloc>()
        .add(MobileMoneyStatusPolled(bidId: widget.bidId));
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
        title: Text(
          'Paiement Mobile Money',
          style: tt.headlineMedium,
        ),
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
          if (state is MobileMoneyPaymentConfirmed) {
            _pollingTimer?.cancel();
            DonySnackbar.show(
              context,
              message: 'Paiement confirmé',
              type: DonySnackbarType.success,
            );
            context.go('/bids/${widget.bidId}');
          } else if (state is MobileMoneyPaymentExpired ||
              state is MobileMoneyPaymentError) {
            _pollingTimer?.cancel();
          }
        },
        builder: (context, state) {
          if (state is MobileMoneyPaymentLoading ||
              state is MobileMoneyPaymentInitial) {
            return Center(
              child: CircularProgressIndicator(color: cs.primary),
            );
          }

          if (state is MobileMoneyPaymentConfirmed) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: cs.success,
                    size: 64,
                  ),
                  const SizedBox(height: DonySpacing.base),
                  Text(
                    'Paiement confirmé',
                    style: tt.headlineLarge,
                  ),
                ],
              ),
            );
          }

          if (state is MobileMoneyPaymentExpired) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DonySpacing.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_off_outlined,
                      color: cs.warning,
                      size: 48,
                    ),
                    const SizedBox(height: DonySpacing.base),
                    Text(
                      'Lien expiré',
                      style: tt.headlineLarge,
                    ),
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
                      onPressed: () => context
                          .read<MobileMoneyPaymentBloc>()
                          .add(MobileMoneyLinkRegenRequested(
                            bidId: widget.bidId,
                          )),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is MobileMoneyPaymentError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DonySpacing.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: cs.error,
                      size: 48,
                    ),
                    const SizedBox(height: DonySpacing.base),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: DonySpacing.base),
                    TextButton(
                      onPressed: () => context
                          .read<MobileMoneyPaymentBloc>()
                          .add(MobileMoneyStatusPolled(bidId: widget.bidId)),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            );
          }

          // PENDING
          final pending = state as MobileMoneyPaymentPending;
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
                // Hero card
                Container(
                  padding: const EdgeInsets.all(DonySpacing.lg),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [DonyColors.blue700, DonyColors.blue500],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius:
                        BorderRadius.circular(DonyRadius.card),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.phone_android_outlined,
                        color: Colors.white,
                        size: 32,
                      ),
                      const SizedBox(width: DonySpacing.base),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                if (pending.expiresAt != null) ...[
                  Text(
                    'Lien valable jusqu\'à '
                    '${pending.expiresAt!.hour.toString().padLeft(2, '0')}:'
                    '${pending.expiresAt!.minute.toString().padLeft(2, '0')}',
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

                const Spacer(),

                // CTA
                DonyButton(
                  label: 'Payer maintenant',
                  icon: Icons.open_in_new,
                  onPressed: pending.paymentLink.isNotEmpty
                      ? () => _openLink(pending.paymentLink)
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
