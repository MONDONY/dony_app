import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Écran affiché quand le compte de paiement du voyageur ne peut pas encore
/// encaisser.
///
/// Il ne se voit qu'au moment où il gêne (gating de `/trips/create`), plus via
/// un bandeau permanent en haut de l'application : cet état se règle en
/// terminant l'onboarding, ce n'est pas une panne à signaler en continu.
class AccountDisabledScreen extends StatelessWidget {
  const AccountDisabledScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        actions: const [DonyFeedbackButton()],
        leading: const DonyAppBarBackButton(leadingIconAsset: 'x'),
        title: Text(l.stripeAccountDisabledTitle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Texte scrollable, boutons épinglés en bas (anti-overflow petit
            // écran / gros text scale).
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const DonyIcon(
                          'triangle-alert',
                          size: 48,
                          color: Color(0xFFF59E0B),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l.stripeAccountDisabledHeading,
                          style: tt.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        Text(l.stripeAccountDisabledBody),
                        const SizedBox(height: 20),
                        Text(
                          l.stripeAccountDisabledRequirementsHeading,
                          style: tt.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        _Requirement(
                          l.stripeAccountDisabledRequirementIdentity,
                        ),
                        _Requirement(l.stripeAccountDisabledRequirementPayout),
                        _Requirement(l.stripeAccountDisabledRequirementTerms),
                        const SizedBox(height: 16),
                        Text(
                          l.stripeAccountDisabledEta,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.go('/connect/onboarding/intro'),
                child: Text(l.stripeAccountDisabledCta),
              ),
            ),
            const SizedBox(height: 8),
            // Toujours visible : le bouton principal quitte l'écran, un
            // recours révélé « après plusieurs essais » ne serait jamais
            // atteignable.
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () async {
                  final uri = Uri.parse('mailto:support@yadony.com');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
                child: Text(l.stripeAccountContactSupport),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ligne « ✓ intitulé » de la liste des pièces à fournir.
class _Requirement extends StatelessWidget {
  const _Requirement(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: DonyIcon('check', size: 16, color: cs.primary),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
