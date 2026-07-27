import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:flutter/material.dart';

/// Bottom sheet de consentement analytics (RGPD — opt-in strict).
///
/// Retourne `true` si l'utilisateur accepte le tracking, `false` sinon.
/// Enregistre systématiquement la réponse via [AnalyticsService.setConsent].
abstract final class AnalyticsConsentSheet {
  static Future<bool> show(BuildContext context) async {
    final accepted = await DonyBottomSheet.show<bool>(
      context,
      isDismissible: false,
      title: 'Aide-nous à améliorer Yadony',
      subtitle:
          "Avec ton accord, on mesure de façon anonyme comment l'app est "
          "utilisée, pour corriger les bugs et simplifier ton expérience.",
      stickyBottom: Builder(
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyButton(
              label: 'Accepter',
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: DonySpacing.sm),
            DonyButton(
              label: 'Non merci',
              variant: DonyButtonVariant.ghost,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
          ],
        ),
      ),
      child: const _ConsentBody(),
    );
    final granted = accepted ?? false;
    await getIt<AnalyticsService>().setConsent(granted: granted);
    return granted;
  }
}

class _ConsentBody extends StatelessWidget {
  const _ConsentBody();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ConsentLine(
          emoji: '📊',
          text: 'Les écrans visités et les fonctionnalités utilisées',
        ),
        SizedBox(height: DonySpacing.md),
        _ConsentLine(
          emoji: '👆',
          text: 'Les gestes (taps, défilements) pour repérer ce qui bloque',
        ),
        SizedBox(height: DonySpacing.md),
        _ConsentLine(
          emoji: '🔒',
          text: 'Jamais tes paiements, ton identité ni ton numéro',
        ),
        SizedBox(height: DonySpacing.md),
        _ConsentLine(
          emoji: '↩️',
          text: 'Modifiable à tout moment dans Réglages › Confidentialité',
        ),
      ],
    );
  }
}

class _ConsentLine extends StatelessWidget {
  const _ConsentLine({required this.emoji, required this.text});

  final String emoji;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: DonySpacing.md),
        Expanded(
          child: Text(
            text,
            style: tt.bodyMedium?.copyWith(color: cs.onSurface, height: 1.35),
          ),
        ),
      ],
    );
  }
}
