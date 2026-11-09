import 'package:dony/core/design/design_system.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Choix de l'utilisateur sur le modal de mise à jour recommandée. Fermer le
/// modal sans choisir (tap à côté, geste retour, glissement) rend `null`,
/// traité comme [later].
enum AppUpdatePromptChoice { update, later }

/// Modal de mise à jour recommandée : une feuille du design system, avec les
/// deux boutons empilés en pleine largeur dans le pied collant.
abstract final class AppUpdatePromptSheet {
  static Future<AppUpdatePromptChoice?> show(BuildContext context) {
    final l = context.l10n;
    return DonyBottomSheet.show<AppUpdatePromptChoice>(
      context,
      analyticsName: 'app_update_prompt',
      stickyBottom: Builder(
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DonyButton(
              key: const Key('app-update-prompt-update'),
              label: l.appUpdatePromptUpdate,
              onPressed: () =>
                  Navigator.of(sheetContext).pop(AppUpdatePromptChoice.update),
            ),
            const SizedBox(height: DonySpacing.sm),
            DonyButton(
              key: const Key('app-update-prompt-later'),
              label: l.appUpdatePromptLater,
              variant: DonyButtonVariant.secondary,
              onPressed: () =>
                  Navigator.of(sheetContext).pop(AppUpdatePromptChoice.later),
            ),
          ],
        ),
      ),
      child: const _Content(),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: DonyMascotteAnimated(
            type: DonyMascotteType.joyeux,
            size: DonyMascotteSize.lg,
          ),
        ),
        const SizedBox(height: DonySpacing.base),
        Text(
          l.appUpdatePromptTitle,
          style: tt.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DonySpacing.sm),
        Text(
          l.appUpdatePromptMessage,
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
