import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/connect_onboarding/bloc/connect_onboarding_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ConnectPendingBottomSheet extends StatelessWidget {
  const ConnectPendingBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return DonyBottomSheet.show(
      context,
      isDismissible: false,
      child: BlocProvider.value(
        value: context.read<ConnectOnboardingBloc>(),
        child: const ConnectPendingBottomSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return BlocListener<ConnectOnboardingBloc, ConnectOnboardingState>(
      listener: (context, state) {
        if (state is ConnectOnboardingComplete) {
          Navigator.of(context).pop();
          DonySnackbar.show(
            context,
            message: 'Compte bancaire configuré !',
            type: DonySnackbarType.success,
          );
          context.go('/home');
        } else if (state is ConnectOnboardingError) {
          DonySnackbar.show(
            context,
            message: state.message,
            type: DonySnackbarType.error,
          );
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header icon
          Center(
            child: DonyIconContainer(
              icon: Icons.hourglass_top_rounded,
              size: DonyIconContainerSize.lg,
              borderRadius: DonyRadius.xl,
              backgroundColor: cs.warning.withValues(alpha: 0.1),
              iconColor: cs.warning,
            )
                .animate()
                .fadeIn(duration: 260.ms)
                .scale(
                  begin: const Offset(0.85, 0.85),
                  curve: Curves.easeOutBack,
                ),
          ),
          const SizedBox(height: DonySpacing.xl),

          // Title
          Text(
            'En attente de Stripe',
            style: tt.headlineMedium,
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 60.ms),
          const SizedBox(height: DonySpacing.xs),

          // Description
          Text(
            'Revenez ici après avoir complété le formulaire Stripe dans votre navigateur.',
            style: tt.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: DonySpacing.xl),

          // Check button
          BlocBuilder<ConnectOnboardingBloc, ConnectOnboardingState>(
            builder: (context, state) => DonyButton(
              label: "J'ai complété le formulaire",
              isLoading: state is ConnectOnboardingLoading,
              onPressed: state is ConnectOnboardingLoading
                  ? null
                  : () => context
                      .read<ConnectOnboardingBloc>()
                      .add(const ConnectOnboardingPollingRequested()),
            ),
          ),
          const SizedBox(height: DonySpacing.sm),

          // Back button
          DonyButton(
            label: 'Revenir plus tard',
            variant: DonyButtonVariant.ghost,
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/profile');
            },
          ),
        ],
      ),
    );
  }
}
