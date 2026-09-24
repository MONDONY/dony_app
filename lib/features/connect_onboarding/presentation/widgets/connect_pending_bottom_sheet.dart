import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/connect_onboarding/bloc/connect_onboarding_bloc.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ConnectPendingBottomSheet extends StatelessWidget {
  const ConnectPendingBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    final connectBloc = context.read<ConnectOnboardingBloc>();
    final l = context.l10n;
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
              label: l.connectPendingCompleteCta,
              isLoading: state is ConnectOnboardingLoading,
              onPressed: state is ConnectOnboardingLoading
                  ? null
                  : () => ctx.read<ConnectOnboardingBloc>().add(
                      const ConnectOnboardingPollingRequested(),
                    ),
            ),
          ),
          const SizedBox(height: DonySpacing.sm),
          DonyButton(
            label: l.connectPendingLaterCta,
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
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return BlocListener<ConnectOnboardingBloc, ConnectOnboardingState>(
      listener: (context, state) {
        if (state is ConnectOnboardingComplete) {
          getIt<StripeAccountBloc>().add(const StripeAccountStatusRefreshed());
          Navigator.of(context, rootNavigator: true).pop();
          DonySnackbar.show(
            context,
            message: context.l10n.connectPendingConfigured,
            type: DonySnackbarType.success,
          );
          context.go('/home');
        } else if (state is ConnectOnboardingPending) {
          // L'utilisateur a affirmé avoir terminé, Stripe dit le contraire :
          // sans ce retour, le bouton semblait ne rien faire.
          DonySnackbar.show(
            context,
            message: context.l10n.connectPendingNotReceived,
          );
        } else if (state is ConnectOnboardingError) {
          ErrorPresenter.show(context, state.error);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header mascotte
          const Center(
            child: DonyMascotteAnimated(type: DonyMascotteType.attente),
          ),
          const SizedBox(height: DonySpacing.xl),

          // Title
          Text(
            l.connectPendingTitle,
            style: tt.headlineMedium,
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 60.ms),
          const SizedBox(height: DonySpacing.xs),

          // Description
          Text(
            l.connectPendingSubtitle,
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
