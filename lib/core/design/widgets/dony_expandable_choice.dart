import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Un choix de [DonyExpandableChoice] : une carte avec icône, titre, résumé,
/// et un contenu révélé quand le choix est retenu.
class DonyChoice<T> {
  const DonyChoice({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.iconAsset,
    required this.expanded,
    this.key,
  });

  final T value;
  final String title;

  /// Une ligne, toujours visible : ce qui permet de comparer sans ouvrir.
  final String subtitle;

  /// Nom d'icône [DonyIcon].
  final String iconAsset;

  /// Contenu de la carte ouverte. Construit **seulement** pour le choix
  /// retenu : un champ ou une clé qui y vit n'existe pas ailleurs.
  final WidgetBuilder expanded;

  /// Clé posée sur l'en-tête tappable (tests, accessibilité).
  final Key? key;
}

/// Choix **exclusif** entre des cartes empilées, dont celle qu'on touche
/// s'ouvre sur sa conséquence : montant, explication, champs propres à ce
/// choix. Les autres restent repliées sur une ligne de résumé, donc toujours
/// comparables sans rien ouvrir. Chaque carte a toute la largeur pour son
/// nom : rien ne se tasse, à aucune taille de texte.
///
/// Un seul choix possible : la carte est ouverte d'office, sans bouton radio,
/// et son en-tête garde sa clé.
///
/// Aucun `setState` : l'état vit chez l'appelant, via [value] et [onChanged].
class DonyExpandableChoice<T> extends StatelessWidget {
  const DonyExpandableChoice({
    super.key,
    required this.choices,
    required this.value,
    required this.onChanged,
    this.enableHaptic = true,
  }) : assert(choices.length >= 1, 'Au moins un choix');

  final List<DonyChoice<T>> choices;
  final T value;
  final ValueChanged<T> onChanged;
  final bool enableHaptic;

  static const Duration _open = Duration(milliseconds: 250);
  static const Duration _decor = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final single = choices.length == 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < choices.length; i++) ...[
          if (i > 0) const SizedBox(height: DonySpacing.sm + 2),
          _ChoiceCard<T>(
            choice: choices[i],
            selected: single || choices[i].value == value,
            showRadio: !single,
            openDuration: _open,
            decorDuration: _decor,
            onTap: () {
              if (single || choices[i].value == value) return;
              if (enableHaptic) HapticFeedback.selectionClick();
              onChanged(choices[i].value);
            },
          ),
        ],
      ],
    );
  }
}

class _ChoiceCard<T> extends StatelessWidget {
  const _ChoiceCard({
    required this.choice,
    required this.selected,
    required this.showRadio,
    required this.onTap,
    required this.openDuration,
    required this.decorDuration,
  });

  final DonyChoice<T> choice;
  final bool selected;
  final bool showRadio;
  final VoidCallback onTap;
  final Duration openDuration;
  final Duration decorDuration;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(DonyRadius.xl);

    return AnimatedContainer(
      duration: decorDuration,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: radius,
        border: Border.all(
          color: selected ? cs.primary : cs.outlineVariant,
          width: selected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: selected
                ? cs.primary.withValues(alpha: 0.18)
                : cs.shadow.withValues(alpha: 0.04),
            blurRadius: selected ? 20 : 4,
            offset: Offset(0, selected ? 8 : 1),
          ),
        ],
      ),
      // Le bord change d'épaisseur (1 → 2) : on compense pour que le contenu
      // ne bouge pas d'un pixel à la sélection.
      padding: EdgeInsets.all(selected ? 0 : 1),
      child: ClipRRect(
        borderRadius: radius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              selected: selected,
              child: InkWell(
                key: choice.key,
                onTap: onTap,
                splashColor: cs.primary.withValues(alpha: 0.08),
                highlightColor: cs.primary.withValues(alpha: 0.04),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DonySpacing.base,
                    DonySpacing.md + 2,
                    DonySpacing.base,
                    DonySpacing.md + 2,
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: decorDuration,
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: selected
                              ? cs.primaryContainer
                              : cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(DonyRadius.md),
                        ),
                        alignment: Alignment.center,
                        child: DonyIcon(
                          choice.iconAsset,
                          size: 20,
                          color: selected ? cs.primary : cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: DonySpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              choice.title,
                              style: tt.labelLarge?.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              choice.subtitle,
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (showRadio) ...[
                        const SizedBox(width: DonySpacing.sm),
                        _Radio(selected: selected, duration: decorDuration),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // Contenu ouvert : construit seulement pour le choix retenu.
            AnimatedSize(
              duration: openDuration,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: selected
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(
                        DonySpacing.base,
                        0,
                        DonySpacing.base,
                        DonySpacing.base,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Divider(height: 1, color: cs.outlineVariant),
                          const SizedBox(height: DonySpacing.md + 2),
                          choice.expanded(context),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected, required this.duration});

  final bool selected;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: duration,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? cs.primary : Colors.transparent,
        border: Border.all(color: selected ? cs.primary : cs.outline, width: 2),
      ),
      alignment: Alignment.center,
      child: AnimatedScale(
        duration: duration,
        curve: Curves.easeOutCubic,
        scale: selected ? 1 : 0.25,
        child: AnimatedOpacity(
          duration: duration,
          opacity: selected ? 1 : 0,
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
