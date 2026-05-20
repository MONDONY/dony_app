import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/kyc/presentation/widgets/kyc_onboarding_bottom_sheet.dart';
import 'package:dony/features/kyc/presentation/widgets/kyc_status_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class KycRequiredBottomSheet extends StatelessWidget {
  const KycRequiredBottomSheet({super.key, required this.kycStatus});

  final String kycStatus;

  static Future<void> show(BuildContext context, {required String kycStatus}) async {
    bool openKyc = false;

    await DonyBottomSheet.show<void>(
      context,
      stickyBottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DonyButton(
            label: 'Vérifier mon identité',
            onPressed: () {
              openKyc = true;
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

    if (openKyc && context.mounted) {
      if (kycStatus == 'PENDING') {
        await KycStatusBottomSheet.show(context);
      } else {
        await KycOnboardingBottomSheet.show(context);
      }
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
      _ =>
        'Pour envoyer un colis, votre identité doit être vérifiée.',
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
              child: Icon(Icons.shield_outlined, color: cs.primary, size: 48),
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
            icon: Icons.schedule_rounded,
            text: 'Vérification en 2 à 5 minutes',
            cs: cs,
            tt: tt,
          ),
          const SizedBox(height: DonySpacing.sm),
          _InfoRow(
            icon: Icons.verified_user_rounded,
            text: 'Processus Stripe Identity sécurisé',
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
        Icon(icon, size: 16, color: cs.primary),
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
