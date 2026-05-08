import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_event.dart';
import 'package:dony/features/kyc/bloc/kyc_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class KycOnboardingBottomSheet extends StatelessWidget {
  const KycOnboardingBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    final kycBloc = context.read<KycBloc>();
    return DonyBottomSheet.show(
      context,
      wrapper: (child) => BlocProvider.value(value: kycBloc, child: child),
      stickyBottom: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          BlocBuilder<KycBloc, KycState>(
            builder: (ctx, state) {
              final isLoading = state is KycLoading;
              return DonyButton(
                label: 'Démarrer la vérification',
                isLoading: isLoading,
                onPressed: isLoading
                    ? null
                    : () => ctx.read<KycBloc>().add(const KycSessionRequested()),
              );
            },
          ),
          const SizedBox(height: DonySpacing.sm),
          DonyButton(
            label: 'Plus tard',
            variant: DonyButtonVariant.ghost,
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          ),
        ],
      ),
      child: const KycOnboardingBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return BlocConsumer<KycBloc, KycState>(
      listener: (context, state) {
        if (state is KycSessionCreated) {
          Navigator.of(context).pop();
        } else if (state is KycError) {
          DonySnackbar.show(
            context,
            message: state.message,
            type: DonySnackbarType.error,
          );
        }
      },
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.badge_rounded,
              size: 48,
              color: DonyColors.primary,
            ),
            const SizedBox(height: DonySpacing.base),
            Text(
              'Vérifiez votre identité',
              style: tt.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DonySpacing.xs),
            Text(
              'Requis pour publier des annonces sur dony',
              style: tt.bodyMedium?.copyWith(
                color: DonyColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DonySpacing.xl),
            _InfoRow(
              icon: Icons.verified_user_rounded,
              text: 'Processus Stripe Identity sécurisé',
              cs: cs,
              tt: tt,
            ),
            const SizedBox(height: DonySpacing.sm),
            _InfoRow(
              icon: Icons.photo_camera_rounded,
              text: "Pièce d'identité + selfie requis",
              cs: cs,
              tt: tt,
            ),
            const SizedBox(height: DonySpacing.sm),
            _InfoRow(
              icon: Icons.schedule_rounded,
              text: 'Vérification en 2 à 5 minutes',
              cs: cs,
              tt: tt,
            ),
            const SizedBox(height: DonySpacing.xl),
          ],
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
    required this.cs,
    required this.tt,
  });

  final IconData icon;
  final String text;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: DonyColors.primary,
        ),
        const SizedBox(width: DonySpacing.sm),
        Expanded(
          child: Text(
            text,
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
