import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/connect_onboarding/bloc/connect_onboarding_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ConnectOnboardingPendingScreen extends StatefulWidget {
  const ConnectOnboardingPendingScreen({super.key});

  @override
  State<ConnectOnboardingPendingScreen> createState() =>
      _ConnectOnboardingPendingScreenState();
}

class _ConnectOnboardingPendingScreenState
    extends State<ConnectOnboardingPendingScreen> {
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    // Poll immediately, then every 3 seconds
    _dispatchPoll();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _dispatchPoll();
    });
  }

  void _dispatchPoll() {
    if (mounted) {
      context
          .read<ConnectOnboardingBloc>()
          .add(const ConnectOnboardingPollingRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ConnectOnboardingBloc, ConnectOnboardingState>(
      listener: (context, state) {
        if (state is ConnectOnboardingComplete) {
          _pollingTimer?.cancel();
          context.go('/home');
        }
      },
      child: Scaffold(
        appBar: const DonyAppBar(
          title: 'Vérification en cours',
          showBackButton: false,
        ),
        body: Builder(builder: (context) {
          final h = DonyLayout.hPadding(context);
          return SingleChildScrollView(
            padding:
                EdgeInsets.fromLTRB(h, DonySpacing.huge, h, DonySpacing.huge),
            child: DonyLayout.constrained(
              context,
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: DonySpacing.xl),
                  // Animated icon
                  _AnimatedPendingIcon()
                      .animate()
                      .fadeIn(duration: 300.ms)
                      .scale(
                          begin: const Offset(0.85, 0.85),
                          curve: Curves.easeOutBack),
                  const SizedBox(height: DonySpacing.xl),

                  // Title
                  Text(
                    'Vérification en cours...',
                    style: Theme.of(context).textTheme.displayLarge,
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 80.ms),
                  const SizedBox(height: DonySpacing.md),

                  // Subtitle
                  Text(
                    'Stripe vérifie ton compte. Cette opération peut prendre quelques instants. Tu seras redirigé automatiquement une fois la vérification terminée.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                          height: 1.55,
                        ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 120.ms),
                  const SizedBox(height: DonySpacing.xxl),

                  // Polling indicator
                  BlocBuilder<ConnectOnboardingBloc, ConnectOnboardingState>(
                    builder: (context, state) {
                      final isPolling = state is ConnectOnboardingLoading;
                      return _PollingStatusRow(isPolling: isPolling)
                          .animate()
                          .fadeIn(delay: 160.ms);
                    },
                  ),
                  const SizedBox(height: DonySpacing.xxl),

                  // Info
                  const DonyStatusBanner(
                    type: DonyStatusBannerType.info,
                    iconAsset: 'info',
                    message:
                        'Si tu as déjà terminé l\'inscription Stripe, la vérification se fait automatiquement.',
                  ).animate().fadeIn(delay: 200.ms),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _AnimatedPendingIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const DonyMascotteAnimated(
      type: DonyMascotteType.confiant,
      size: DonyMascotteSize.lg,
    );
  }
}

class _PollingStatusRow extends StatelessWidget {
  final bool isPolling;
  const _PollingStatusRow({required this.isPolling});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: isPolling
              ? CircularProgressIndicator(
                  color: cs.primary,
                  strokeWidth: 2,
                )
              : DonyIcon('circle',
                  size: 16, color: cs.onSurfaceVariant),
        ),
        const SizedBox(width: DonySpacing.sm),
        Text(
          isPolling ? 'Vérification...' : 'En attente',
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
