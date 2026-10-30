import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/consent_prompt.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Feuille facultative de consentement à la mesure d'usage, ouverte sur
/// l'accueil. Fermer par geste ne répond pas : rien n'est enregistré et la
/// demande revient au prochain lancement.
abstract final class AnalyticsConsentSheet {
  static Future<void> show(BuildContext context) {
    final l = context.l10n;
    return DonyBottomSheet.show<void>(
      context,
      title: l.consentSheetTitle,
      analyticsName: 'consent/analytics',
      stickyBottom: Builder(
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyButton(
              key: const Key('consent-sheet-accept'),
              label: l.authConsentAccept,
              onPressed: () => _respond(ctx, granted: true),
            ),
            const SizedBox(height: DonySpacing.sm),
            DonyButton(
              key: const Key('consent-sheet-decline'),
              label: l.consentSheetDecline,
              variant: DonyButtonVariant.secondary,
              onPressed: () => _respond(ctx, granted: false),
            ),
          ],
        ),
      ),
      child: const _ConsentSheetBody(),
    );
  }

  static Future<void> _respond(
    BuildContext context, {
    required bool granted,
  }) async {
    final navigator = Navigator.of(context);
    final analytics = getIt<AnalyticsService>();
    await analytics.setConsent(granted: granted);
    unawaited(
      analytics.logEvent(
        AnalyticsEvents.analyticsConsentAnswered,
        properties: {'granted': granted},
      ),
    );
    getIt<ConsentPrompt>().clear();
    navigator.pop();
  }
}

class _ConsentSheetBody extends StatelessWidget {
  const _ConsentSheetBody();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.base),
      child: Text(
        context.l10n.consentSheetBody,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
      ),
    );
  }
}
