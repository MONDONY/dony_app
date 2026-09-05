import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_event.dart';
import 'package:dony/features/kyc/bloc/kyc_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class KycOnboardingBottomSheet extends StatelessWidget {
  const KycOnboardingBottomSheet({super.key});

  static Future<void> show(BuildContext context) async {
    final kycBloc = context.read<KycBloc>()..add(const KycReset());

    // Le sheet retourne l'URL Stripe via Navigator.pop(url) quand la session est prête.
    final stripeUrl = await DonyBottomSheet.show<String>(
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
                    : () =>
                          ctx.read<KycBloc>().add(const KycSessionRequested()),
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

    if (stripeUrl != null && context.mounted) {
      GoRouter.of(context).go('/kyc/verify', extra: stripeUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return BlocConsumer<KycBloc, KycState>(
      listener: (context, state) {
        if (state is KycSessionCreated) {
          Navigator.of(context, rootNavigator: true).pop(state.stripeUrl);
        } else if (state is KycError) {
          ErrorPresenter.show(context, state.error);
        }
      },
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DonyIcon('id-card', size: 48, color: cs.primary),
            const SizedBox(height: DonySpacing.base),
            Text(
              'Vérifiez votre identité',
              style: tt.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DonySpacing.xs),
            Text(
              'Requis pour publier des annonces sur Yadony',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DonySpacing.xl),
            _InfoRow(
              iconAsset: 'shield-check',
              text: 'Processus de vérification sécurisé',
              cs: cs,
              tt: tt,
            ),
            const SizedBox(height: DonySpacing.sm),
            _InfoRow(
              iconAsset: 'camera',
              text: "Pièce d'identité + selfie requis",
              cs: cs,
              tt: tt,
            ),
            const SizedBox(height: DonySpacing.sm),
            _InfoRow(
              iconAsset: 'clock',
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
    required this.iconAsset,
    required this.text,
    required this.cs,
    required this.tt,
  });

  final String iconAsset;
  final String text;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DonyIcon(iconAsset, size: 16, color: cs.primary),
        const SizedBox(width: DonySpacing.sm),
        Expanded(
          child: Text(
            text,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
