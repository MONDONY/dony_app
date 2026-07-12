import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:dony/core/design/utils/dony_layout.dart';
import 'package:dony/core/design/widgets/dony_app_bar.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/design/widgets/dony_mascotte.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Écran plein affiché après une action majeure réussie (paiement confirmé,
/// trajet publié, livraison confirmée). Pas d'auto-navigation : l'utilisateur
/// quitte l'écran uniquement via [onCta].
class DonySuccessScreen extends StatelessWidget {
  const DonySuccessScreen({
    super.key,
    required this.mascotteType,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.onCta,
    this.ctaVariant = DonyButtonVariant.primary,
  });

  final DonyMascotteType mascotteType;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final VoidCallback onCta;
  final DonyButtonVariant ctaVariant;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const DonyAppBar(
        title: '',
        showBackButton: false,
      ),
      body: Builder(builder: (context) {
        final h = DonyLayout.hPadding(context);
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(h, DonySpacing.xxl, h, DonySpacing.huge),
          child: DonyLayout.constrained(
            context,
            Column(
              children: [
                const SizedBox(height: DonySpacing.xxl),
                DonyMascotteAnimated(
                  type: mascotteType,
                  size: DonyMascotteSize.lg,
                  withGlow: true,
                ),
                const SizedBox(height: DonySpacing.xl),
                Text(
                  title,
                  style: tt.displayLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: DonySpacing.md),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: tt.bodyLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: DonySpacing.xxl),
                DonyButton(
                  label: ctaLabel,
                  variant: ctaVariant,
                  onPressed: onCta,
                ),
              ],
            )
                .animate()
                .fadeIn(duration: 400.ms)
                .scale(begin: const Offset(0.92, 0.92), curve: Curves.easeOutCubic),
          ),
        );
      }),
    );
  }
}
