// Étape « Conditions » du formulaire « Publier un trajet » : ce que le
// voyageur accepte et refuse, et sa note aux expéditeurs. Le prix et les modes
// de paiement vivent dans `prix_step.dart`.

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/presentation/content_category_selector.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/_shared_widgets.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Corps de la section Conditions du formulaire de création d'annonce.
///
/// Tous les [ValueNotifier] et [TextEditingController] restent la propriété de
/// [_CreateAnnouncementContentState] — ils sont simplement passés en paramètre.
class ConditionsStep extends StatelessWidget {
  final ValueNotifier<Set<String>> selectedContentNotifier;
  final ValueNotifier<Set<String>> customAcceptedNotifier;
  final ValueNotifier<Set<String>> refusedTypesNotifier;

  /// Catalogue de labels de types de contenu — piloté par le repository
  /// (`ContentCategoryRepository`), avec repli embarqué. Remplace l'ancienne
  /// liste figée de types de contenu. Propriété du parent (host
  /// `create_announcement_bottom_sheet.dart` / `create_trip_screen.dart`)
  /// comme les autres notifiers.
  final ValueNotifier<List<String>> catalogLabelsNotifier;
  final TextEditingController descriptionCtrl;
  final TextEditingController customAcceptedCtrl;
  final TextEditingController refusedCtrl;

  /// Trajet en route : exemples de contenus volumineux sous « Ce que
  /// j'accepte » (meubles, électroménager, cartons).
  final bool isRoad;

  const ConditionsStep({
    super.key,
    required this.selectedContentNotifier,
    required this.customAcceptedNotifier,
    required this.refusedTypesNotifier,
    required this.catalogLabelsNotifier,
    required this.descriptionCtrl,
    required this.customAcceptedCtrl,
    required this.refusedCtrl,
    this.isRoad = false,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── CE QUE J'ACCEPTE ──────────────────────────────────────────────────
        CaSectionLabel(
          label: l.tripPublishAcceptedContentSectionLabel,
          iconAsset: 'circle-check',
        ),
        if (isRoad) ...[
          const SizedBox(height: DonySpacing.xs),
          Text(
            l.tripPublishAcceptHintRoad,
            key: const Key('conditions-accept-hint-road'),
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: DonySpacing.sm),
        ListenableBuilder(
          listenable: Listenable.merge([
            selectedContentNotifier,
            customAcceptedNotifier,
            catalogLabelsNotifier,
          ]),
          builder: (context, _) {
            final catalogLabels = catalogLabelsNotifier.value;
            final catalog = catalogLabels
                .map(
                  (label) => ContentCategory(
                    code: label,
                    label: label,
                    emoji: emojiForLabel(label),
                  ),
                )
                .toList();
            final catalogSet = catalogLabels.toSet();
            final combinedSelected = <String>{
              ...selectedContentNotifier.value,
              ...customAcceptedNotifier.value,
            }.toList();

            final otherSelected = combinedSelected.contains(kOtherContentLabel);
            return CaSectionCard(
              child: Padding(
                padding: const EdgeInsets.all(DonySpacing.base),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ContentCategoryComboBox(
                      keyPrefix: 'accepted-content',
                      catalog: catalog,
                      selected: combinedSelected,
                      onChanged: (labels) {
                        final labelSet = labels.toSet();
                        selectedContentNotifier.value = labelSet
                            .where(catalogSet.contains)
                            .toSet();
                        customAcceptedNotifier.value = labelSet
                            .where((l) => !catalogSet.contains(l))
                            .toSet();
                      },
                    ),
                    // « Autre » seul ne dit rien à l'expéditeur : une
                    // précision est obligatoire (FLUTTER-4G).
                    if (otherSelected) ...[
                      const SizedBox(height: DonySpacing.md),
                      DonyTextField(
                        key: const Key('accepted-other-precision'),
                        label: l.tripPublishOtherContentPrecisionLabel,
                        hint: l.tripPublishOtherContentPrecisionHint,
                        controller: customAcceptedCtrl,
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ).animate().fadeIn(delay: 120.ms),
        const SizedBox(height: DonySpacing.xxl),

        // ── CE QUE JE REFUSE ──────────────────────────────────────────────────
        CaSectionLabel(
          label: l.tripPublishRefusedContentSectionLabel,
          iconAsset: 'ban',
        ),
        const SizedBox(height: DonySpacing.sm),
        ListenableBuilder(
          listenable: Listenable.merge([
            refusedTypesNotifier,
            catalogLabelsNotifier,
          ]),
          builder: (context, _) {
            final catalogLabels = catalogLabelsNotifier.value;
            final catalog = catalogLabels
                .map(
                  (label) => ContentCategory(
                    code: label,
                    label: label,
                    emoji: emojiForLabel(label),
                  ),
                )
                .toList();

            return CaSectionCard(
              child: Padding(
                padding: const EdgeInsets.all(DonySpacing.base),
                child: ContentCategoryComboBox(
                  keyPrefix: 'refused-content',
                  catalog: catalog,
                  selected: refusedTypesNotifier.value.toList(),
                  hint: l.tripPublishRefusedContentHint,
                  onChanged: (labels) =>
                      refusedTypesNotifier.value = labels.toSet(),
                ),
              ),
            );
          },
        ).animate().fadeIn(delay: 140.ms),
        const SizedBox(height: DonySpacing.xxl),

        // ── NOTE AUX EXPÉDITEURS ──────────────────────────────────────────────
        CaSectionLabel(
          label: l.tripPublishNoteToSendersSectionLabel,
          iconAsset: 'notebook-pen',
        ),
        const SizedBox(height: DonySpacing.sm),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: descriptionCtrl,
          builder: (context, value, _) {
            return CaSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DonySpacing.base,
                      vertical: DonySpacing.xs,
                    ),
                    child: DonyReplayMask(
                      child: TextField(
                        controller: descriptionCtrl,
                        maxLines: 4,
                        maxLength: 500,
                        scrollPadding: const EdgeInsets.only(bottom: 120),
                        buildCounter:
                            (
                              _, {
                              required currentLength,
                              required isFocused,
                              maxLength,
                            }) => null,
                        style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                        decoration: InputDecoration(
                          hintText: l.tripPublishNoteToSendersHint,
                          hintStyle: tt.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: DonySpacing.md,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      right: DonySpacing.base,
                      bottom: DonySpacing.sm,
                    ),
                    child: Text(
                      '${value.text.length}/500',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            );
          },
        ).animate().fadeIn(delay: 160.ms),
        const SizedBox(height: DonySpacing.xl),
      ],
    );
  }
}

/// Libellé de la catégorie « Autre » du catalogue (valeur de donnée).
const kOtherContentLabel = 'Autre'; // i18n-ignore : valeur ContentCategory

/// Contenus acceptés envoyés au back : « Autre » est remplacé par la
/// précision du voyageur (FLUTTER-4G). `null` quand « Autre » est coché sans
/// précision : l'appelant doit bloquer la publication.
List<String>? acceptedContentWithPrecision({
  required Set<String> selected,
  required Set<String> custom,
  required String otherPrecision,
}) {
  final all = {...selected, ...custom};
  if (!all.contains(kOtherContentLabel)) return all.toList();
  // Le back découpe les contenus sur « , » : pas de virgule dans un libellé.
  final precision = otherPrecision
      .replaceAll(',', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (precision.isEmpty) return null;
  return {...all.where((c) => c != kOtherContentLabel), precision}.toList();
}
