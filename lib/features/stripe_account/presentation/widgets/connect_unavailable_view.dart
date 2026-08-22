import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Écran plein pour un pays que Stripe ne couvre pas.
///
/// yadony dessert plus de pays que Stripe n'en couvre : les zones XOF et XAF,
/// les États-Unis et le Canada n'ont pas droit à un compte connecté. Ces
/// voyageurs encaissent en espèces, et **rien dans l'application ne peut
/// débloquer la carte pour eux** — ce n'est pas un onboarding à terminer.
///
/// Partagé par les deux parcours d'onboarding Connect
/// (`ConnectOnboardingIntroScreen` et `PayoutOnboardingScreen`) : la même
/// impasse doit donner le même écran, quel que soit le chemin emprunté.
class ConnectUnavailableView extends StatelessWidget {
  const ConnectUnavailableView({super.key, required this.title});

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
      padding: EdgeInsets.fromLTRB(h, DonySpacing.xxl, h, DonySpacing.xxl),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DonyMascotteAnimated(
            type: DonyMascotteType.securise,
            size: DonyMascotteSize.lg,
          ),
          const SizedBox(height: DonySpacing.xl),
          Text(
            'Pas encore disponible\ndans votre pays',
            style: tt.headlineSmall,
          ),
          const SizedBox(height: DonySpacing.md),
          Text(
            'Stripe ne permet pas encore d\'ouvrir un compte de paiement '
            'depuis votre pays. Vous pouvez continuer à transporter des '
            'colis et à être payé en espèces, à la remise.',
            style: tt.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
