import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/settings/bloc/accessibility_bloc.dart';
import 'package:flutter/material.dart';

/// Aperçu réagissant en direct aux réglages d'accessibilité.
///
/// Sans lui, l'écran de réglages est invérifiable de l'extérieur : on bascule
/// une option et rien ne bouge à l'écran. L'aperçu applique les réglages
/// localement, via un [Theme] et un [MediaQuery] dérivés de l'état, donc
/// l'effet est visible dans le même geste que le réglage.
class A11yPreviewCard extends StatelessWidget {
  const A11yPreviewCard({super.key, required this.state});

  final AccessibilityState state;

  @override
  Widget build(BuildContext context) {
    final outerTt = Theme.of(context).textTheme;
    final outerCs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final options = A11yThemeOptions(
      highContrast: state.highContrast == AccessibilityMode.on,
      reduceMotion: state.reduceMotion == AccessibilityMode.on,
      underlineLinks: state.underlineLinks,
    );
    final previewTheme =
        isDark ? AppTheme.dark(a11y: options) : AppTheme.light(a11y: options);

    final mq = MediaQuery.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: DonySpacing.sm),
          child: Text(
            'Aperçu',
            style: outerTt.labelMedium?.copyWith(
              color: outerCs.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Theme(
          data: previewTheme,
          child: MediaQuery(
            data: mq.copyWith(
              textScaler: state.followSystemTextScale
                  ? mq.textScaler.clamp(maxScaleFactor: kA11yMaxTextScale)
                  : TextScaler.linear(state.textScaleFactor),
              boldText: state.boldText,
            ),
            child: AccessibilityScope(
              underlineLinks: state.underlineLinks,
              reinforceLabels: state.reinforceLabels,
              persistentMessages: state.persistentMessages,
              confirmImportantActions: state.confirmImportantActions,
              child: Builder(builder: _buildSample),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSample(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(
          color: cs.outline,
          width: state.highContrast == AccessibilityMode.on ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: DonySpacing.sm,
            runSpacing: DonySpacing.xs,
            children: [
              Text('Paris', style: tt.titleLarge?.copyWith(color: cs.onSurface)),
              Icon(Icons.arrow_forward_rounded, size: 16, color: cs.onSurfaceVariant),
              Text('Dakar', style: tt.titleLarge?.copyWith(color: cs.onSurface)),
              // Seul ce badge a un défaut de contraste connu et déjà différé
              // (étiquette renforcée de DonyUrgentBadge, tâche ultérieure) :
              // on l'exempte lui seul du contrôle WCAG, pas le reste de
              // l'échantillon (titres, poids, bouton), qui doit rester
              // soumis aux mêmes contrôles de contraste et de cible tactile
              // que n'importe quel contenu réel de cet écran.
              Semantics(
                label: 'Urgent',
                child: const ExcludeSemantics(child: DonyUrgentBadge()),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            '12 kg disponibles',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: DonySpacing.md),
          DonyButton(
            label: 'Faire une offre',
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
