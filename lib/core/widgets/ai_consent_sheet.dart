import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/ai_consent_service.dart';
import 'package:dony/core/services/external_url_launcher.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Demande l'accord de l'utilisateur avant le premier envoi à un fournisseur
/// d'IA tiers : assistant et formulaires « Créer avec l'IA ».
abstract final class AiConsentSheet {
  /// Page déclarée à Apple comme politique de confidentialité ; elle décrit
  /// l'assistant et tient à jour la liste des fournisseurs.
  static const privacyUrl = 'https://yadony.com/confidentialite';

  /// Rend `true` si l'accord est déjà donné ou vient de l'être. Fermer la
  /// feuille par geste vaut refus.
  static Future<bool> ensure(
    BuildContext context, {
    required AiConsentEntry entry,
  }) async {
    final service = getIt<AiConsentService>();
    if (service.granted) return true;
    service.markShown(entry);
    final l = context.l10n;
    final accepted = await DonyBottomSheet.show<bool>(
      context,
      title: l.aiConsentTitle,
      stickyBottom: Builder(
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyButton(
              key: const Key('ai-consent-accept'),
              label: l.aiConsentAccept,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: DonySpacing.sm),
            DonyButton(
              key: const Key('ai-consent-decline'),
              label: l.aiConsentDecline,
              variant: DonyButtonVariant.secondary,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
          ],
        ),
      ),
      child: const _AiConsentBody(),
    );
    final granted = accepted ?? false;
    await service.answer(granted: granted, entry: entry);
    return granted;
  }
}

class _AiConsentBody extends StatelessWidget {
  const _AiConsentBody();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final body = tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant);
    final points = [
      l.aiConsentPointSent,
      l.aiConsentPointParcel,
      l.aiConsentPointNotSent,
      l.aiConsentPointProvider,
      l.aiConsentPointStorage,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.aiConsentIntro, style: tt.bodyMedium),
          const SizedBox(height: DonySpacing.md),
          for (final point in points)
            Padding(
              padding: const EdgeInsets.only(bottom: DonySpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: body),
                  Expanded(child: Text(point, style: body)),
                ],
              ),
            ),
          const SizedBox(height: DonySpacing.sm),
          Text(l.aiConsentRefuseNote, style: body),
          const SizedBox(height: DonySpacing.sm),
          DonyButton(
            key: const Key('ai-consent-privacy'),
            label: l.aiConsentPrivacyLink,
            variant: DonyButtonVariant.ghost,
            onPressed: () => getIt<ExternalUrlLauncher>().open(
              Uri.parse(AiConsentSheet.privacyUrl),
            ),
          ),
        ],
      ),
    );
  }
}
