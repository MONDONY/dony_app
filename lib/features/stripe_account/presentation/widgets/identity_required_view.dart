import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/presentation/onboarding_step.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Écran plein quand l'onboarding Stripe Connect est atteint sans identité
/// vérifiée.
///
/// Le serveur refuse déjà ce cas (422 `kyc-required` sur la création de compte
/// comme sur le lien d'onboarding) : sans cet écran, l'utilisateur ne récolte
/// qu'un message d'erreur brut, sans savoir quoi faire. Contrairement à
/// [ConnectUnavailableView], ce n'est pas une impasse — il manque une étape,
/// et l'écran mène droit dessus.
///
/// Partagé par les deux parcours Connect (`ConnectOnboardingIntroScreen` et
/// `PayoutOnboardingScreen`) : les sept points d'entrée de l'application y
/// convergent, un seul garde-fou les couvre donc tous.
class IdentityRequiredView extends StatelessWidget {
  const IdentityRequiredView({super.key, required this.title});

  /// Titre de l'app bar, repris de l'écran remplacé pour que la barre ne
  /// change pas de libellé sous les pieds de l'utilisateur.
  final String title;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final h = DonyLayout.hPadding(context);

    return DonyPageScaffold(
      title: title,
      padding: EdgeInsets.fromLTRB(h, DonySpacing.xxl, h, DonySpacing.base),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DonyIconContainer(
            iconAsset: 'shield-check',
            size: DonyIconContainerSize.xl,
            borderRadius: DonyRadius.xl,
            backgroundColor: cs.primaryContainer,
            iconColor: cs.primary,
          ),
          const SizedBox(height: DonySpacing.lg),
          Text('Vérifiez votre identité\nd\'abord', style: tt.headlineSmall),
          const SizedBox(height: DonySpacing.md),
          Text(
            'Pour recevoir de l\'argent, Stripe doit pouvoir rattacher votre '
            'compte de paiement à une identité vérifiée. C\'est une pièce '
            'd\'identité à photographier, rien de plus.',
            style: tt.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          // Pas de `Spacer` : le corps de `DonyPageScaffold` défile, sa
          // hauteur est donc non bornée et un enfant `Expanded` y lève une
          // assertion de layout. Un écart fixe suffit, et l'écran tient de
          // toute façon sans défilement.
          const SizedBox(height: DonySpacing.xxl),
          DonyButton(
            label: 'Vérifier mon identité',
            iconAsset: 'shield-check',
            onPressed: () => context.push(OnboardingStep.identity.route),
          ),
        ],
      ),
    );
  }
}
