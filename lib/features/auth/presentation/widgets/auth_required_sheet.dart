import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum AuthRequiredReason { explore, offer, report }

abstract final class AuthRequiredSheet {
  static Future<void> show(
    BuildContext context, {
    AuthRequiredReason reason = AuthRequiredReason.explore,
  }) {
    final copy = _copyFor(reason);
    return DonyBottomSheet.show<void>(
      context,
      title: 'Connexion requise',
      subtitle: copy.subtitle,
      stickyBottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyButton(
            label: 'Se connecter',
            iconAsset: 'key-round',
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              context.go('/auth/method');
            },
          ),
          const SizedBox(height: DonySpacing.sm),
          DonyButton(
            label: 'Continuer à explorer',
            variant: DonyButtonVariant.ghost,
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ReassuranceRow(
            iconAsset: 'search',
            title: 'Recherche libre',
            subtitle: 'Tu peux consulter les demandes et comparer les trajets.',
          ),
          const SizedBox(height: DonySpacing.md),
          _ReassuranceRow(
            iconAsset: 'shield-check',
            title: 'Actions protégées',
            subtitle: copy.body,
          ),
        ],
      ),
    );
  }

  static _AuthRequiredCopy _copyFor(AuthRequiredReason reason) {
    return switch (reason) {
      AuthRequiredReason.offer => const _AuthRequiredCopy(
        subtitle: 'Connecte-toi pour proposer ton trajet en toute sécurité.',
        body:
            'La connexion protège les échanges, les propositions et le suivi du colis.',
      ),
      AuthRequiredReason.report => const _AuthRequiredCopy(
        subtitle: 'Connecte-toi pour signaler une annonce.',
        body:
            'Les signalements sont reliés à un compte pour éviter les abus et mieux protéger la communauté.',
      ),
      AuthRequiredReason.explore => const _AuthRequiredCopy(
        subtitle: 'Connecte-toi pour utiliser cette action.',
        body:
            'Publier, contacter, réserver ou payer nécessite un compte Yadony.',
      ),
    };
  }
}

class _AuthRequiredCopy {
  const _AuthRequiredCopy({required this.subtitle, required this.body});

  final String subtitle;
  final String body;
}

class _ReassuranceRow extends StatelessWidget {
  const _ReassuranceRow({
    required this.iconAsset,
    required this.title,
    required this.subtitle,
  });

  final String iconAsset;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(DonyRadius.md),
          ),
          child: Center(
            child: DonyIcon(iconAsset, size: 20, color: cs.primary),
          ),
        ),
        const SizedBox(width: DonySpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: DonySpacing.xxs),
              Text(
                subtitle,
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
