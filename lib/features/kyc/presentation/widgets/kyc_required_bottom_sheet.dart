import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_event.dart';
import 'package:dony/features/kyc/bloc/kyc_state.dart';
import 'package:dony/features/kyc/presentation/widgets/kyc_status_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class KycRequiredBottomSheet extends StatelessWidget {
  const KycRequiredBottomSheet({super.key, required this.kycStatus});

  final String kycStatus;

  static Future<void> show(
    BuildContext context, {
    required String kycStatus,
  }) async {
    if (kycStatus == 'PENDING') {
      bool openStatus = false;
      await DonyBottomSheet.show<void>(
        context,
        stickyBottom: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DonyButton(
              label: 'Vérifier mon identité',
              onPressed: () {
                openStatus = true;
                Navigator.of(context, rootNavigator: true).pop();
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
        child: KycRequiredBottomSheet(kycStatus: kycStatus),
      );
      if (openStatus && context.mounted) {
        await KycStatusBottomSheet.show(context);
      }
      return;
    }

    // NOT_STARTED / REJECTED : démarre la session KYC directement depuis le portail
    final kycBloc = context.read<KycBloc>()..add(const KycReset());
    final stripeUrl = await DonyBottomSheet.show<String>(
      context,
      wrapper: (child) => BlocProvider.value(value: kycBloc, child: child),
      stickyBottom: BlocBuilder<KycBloc, KycState>(
        builder: (ctx, state) {
          final isLoading = state is KycLoading;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DonyButton(
                label: 'Vérifier mon identité',
                isLoading: isLoading,
                onPressed: isLoading
                    ? null
                    : () =>
                          ctx.read<KycBloc>().add(const KycSessionRequested()),
              ),
              const SizedBox(height: DonySpacing.sm),
              DonyButton(
                label: 'Plus tard',
                variant: DonyButtonVariant.ghost,
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pop(),
              ),
            ],
          );
        },
      ),
      child: BlocListener<KycBloc, KycState>(
        listener: (ctx, state) {
          if (state is KycSessionCreated) {
            Navigator.of(ctx, rootNavigator: true).pop(state.stripeUrl);
          } else if (state is KycError) {
            ErrorPresenter.show(ctx, state.error);
          }
        },
        child: KycRequiredBottomSheet(kycStatus: kycStatus),
      ),
    );

    if (stripeUrl != null && context.mounted) {
      GoRouter.of(context).go('/kyc/verify', extra: stripeUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final message = switch (kycStatus) {
      'REJECTED' =>
        'Votre vérification a échoué. Réessayez pour pouvoir envoyer un colis.',
      'PENDING' =>
        'Votre vérification est en cours. Vous pourrez envoyer une fois votre identité validée.',
      _ => 'Pour envoyer un colis, votre identité doit être vérifiée.',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DonySpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: DonyIcon('shield', color: cs.primary, size: 48),
              ),
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
          ),
          const SizedBox(height: DonySpacing.xxl),
          Text(
            'Vérification requise',
            style: tt.headlineLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DonySpacing.md),
          Text(
            message,
            style: tt.bodyLarge?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DonySpacing.xl),
          _InfoRow(
            iconAsset: 'clock',
            text: 'Vérification en 2 à 5 minutes',
            cs: cs,
            tt: tt,
          ),
          const SizedBox(height: DonySpacing.sm),
          _InfoRow(
            iconAsset: 'shield-check',
            text: 'Processus de vérification sécurisé',
            cs: cs,
            tt: tt,
          ),
          const SizedBox(height: DonySpacing.xxl),
        ],
      ).animate().fadeIn(duration: 300.ms),
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
