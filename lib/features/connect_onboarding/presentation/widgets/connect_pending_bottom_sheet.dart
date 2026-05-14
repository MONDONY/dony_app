import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/connect_onboarding/bloc/connect_onboarding_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ConnectPendingBottomSheet extends StatelessWidget {
  const ConnectPendingBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    final connectBloc = context.read<ConnectOnboardingBloc>();
    return DonyBottomSheet.show(
      context,
      isDismissible: false,
      wrapper: (child) => BlocProvider.value(value: connectBloc, child: child),
      stickyBottom: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          BlocBuilder<ConnectOnboardingBloc, ConnectOnboardingState>(
            builder: (ctx, state) => DonyButton(
              label: "J'ai complété le formulaire",
              isLoading: state is ConnectOnboardingLoading,
              onPressed: state is ConnectOnboardingLoading
                  ? null
                  : () => ctx
                      .read<ConnectOnboardingBloc>()
                      .add(const ConnectOnboardingPollingRequested()),
            ),
          ),
          const SizedBox(height: DonySpacing.sm),
          DonyButton(
            label: 'Revenir plus tard',
            variant: DonyButtonVariant.ghost,
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              context.go('/profile');
            },
          ),
        ],
      ),
      child: const ConnectPendingBottomSheet(),
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
          ErrorPresenter.show(context, state.error);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header mascotte
          const Center(
            child: DonyMascotteAnimated(
              type: DonyMascotteType.confiant,
              size: DonyMascotteSize.md,
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
        ],
      ),
    );
  }
}
