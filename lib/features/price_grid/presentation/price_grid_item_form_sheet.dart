import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/core/widgets/dony_keypad.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/price_grid/bloc/price_grid_bloc.dart';
import 'package:dony/features/price_grid/bloc/price_grid_event.dart';
import 'package:dony/features/price_grid/bloc/price_grid_state.dart';
import 'package:dony/features/price_grid/data/models/price_grid_item_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Feuille de création ou de modification d'une étiquette de la grille.
///
/// Deux temps dans une seule feuille : on choisit d'abord l'article dans le
/// catalogue (ou on écrit le sien), puis on fixe son prix au pavé numérique.
/// En modification, l'article est déjà connu : la feuille s'ouvre directement
/// sur le prix.
///
/// Règle CLAUDE.md : le [DonyButton] vit dans [stickyBottom], jamais dans le
/// [child] scrollable.
abstract final class PriceGridItemFormSheet {
  static Future<void> show(
    BuildContext context, {
    PriceGridItemModel? item,
    List<String> takenLabels = const [],
  }) {
    final bloc = context.read<PriceGridBloc>();
    final isEditing = item != null;

    // Article retenu. `null` tant qu'on est dans le catalogue.
    final label = ValueNotifier<String?>(item?.label);
    // Saisie brute du montant, virgule comprise, pour laisser taper « 15, ».
    final raw = ValueNotifier<String>(
      item != null ? _formatInitial(item.unitPriceNet) : '',
    );

    return DonyBottomSheet.show<void>(
      context,
      title: isEditing ? 'Modifier l\'étiquette' : 'Nouvelle étiquette',
      wrapper: (child) => BlocProvider.value(value: bloc, child: child),
      stickyBottom: _SubmitBar(
        label: label,
        raw: raw,
        isEditing: isEditing,
        onSubmit: (ctx, chosenLabel, price) {
          if (isEditing) {
            bloc.add(
              PriceGridItemUpdateRequested(
                itemId: item.id,
                label: chosenLabel,
                unitPriceNet: price,
              ),
            );
          } else {
            bloc.add(
              PriceGridItemAddRequested(
                label: chosenLabel,
                unitPriceNet: price,
              ),
            );
          }
          Navigator.of(ctx, rootNavigator: true).pop();
        },
      ),
      child: _FormContent(
        label: label,
        raw: raw,
        takenLabels: takenLabels,
      ),
    ).whenComplete(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        label.dispose();
        raw.dispose();
      });
    });
  }

  static String _formatInitial(double value) {
    final fixed = value.toStringAsFixed(2);
    // 12.00 se ressaisit plus vite depuis « 12 » que depuis « 12,00 ».
    final trimmed = fixed.endsWith('.00')
        ? fixed.substring(0, fixed.length - 3)
        : fixed;
    return trimmed.replaceAll('.', ',');
  }
}

/// Montant saisi, ou `null` si la saisie n'est pas encore un prix valide.
///
/// Une virgule en fin de saisie est ignorée plutôt que rejetée : « 15, » est
/// un état de frappe normal, et griser le bouton à cet instant donnerait
/// l'impression que le montant est refusé.
double? _parse(String raw) {
  final trimmed = raw.endsWith(',') ? raw.substring(0, raw.length - 1) : raw;
  if (trimmed.isEmpty) return null;
  final parsed = double.tryParse(trimmed.replaceAll(',', '.'));
  if (parsed == null || parsed <= 0 || parsed > maxUnitPriceActive) return null;
  return parsed;
}

// ── Barre de validation ──────────────────────────────────────────────────────

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.label,
    required this.raw,
    required this.isEditing,
    required this.onSubmit,
  });

  final ValueNotifier<String?> label;
  final ValueNotifier<String> raw;
  final bool isEditing;
  final void Function(BuildContext ctx, String label, double price) onSubmit;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: label,
      builder: (context, chosen, _) {
        // Étape catalogue : aucun bouton. Choisir un article fait avancer,
        // un bouton « Suivant » n'ajouterait qu'un geste.
        if (chosen == null) return const SizedBox.shrink();

        return ValueListenableBuilder<String>(
          valueListenable: raw,
          builder: (context, value, _) {
            final price = _parse(value);
            return BlocBuilder<PriceGridBloc, PriceGridState>(
              builder: (context, state) {
                return DonyButton(
                  key: const Key('price-grid-submit'),
                  label: isEditing ? 'Enregistrer' : 'Ajouter à ma grille',
                  isLoading: state is PriceGridLoading,
                  onPressed: price == null
                      ? null
                      : () => onSubmit(context, chosen, price),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ── Contenu ──────────────────────────────────────────────────────────────────

class _FormContent extends StatelessWidget {
  const _FormContent({
    required this.label,
    required this.raw,
    required this.takenLabels,
  });

  final ValueNotifier<String?> label;
  final ValueNotifier<String> raw;
  final List<String> takenLabels;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: label,
      builder: (context, chosen, _) {
        if (chosen == null) {
          return _CatalogStep(
            takenLabels: takenLabels,
            onPicked: (picked) => label.value = picked,
          );
        }
        return _PriceStep(label: label, raw: raw, chosen: chosen);
      },
    );
  }
}

// ── Étape 1 : le catalogue ───────────────────────────────────────────────────

class _CatalogStep extends StatefulWidget {
  const _CatalogStep({required this.takenLabels, required this.onPicked});

  final List<String> takenLabels;
  final ValueChanged<String> onPicked;

  @override
  State<_CatalogStep> createState() => _CatalogStepState();
}

class _CatalogStepState extends State<_CatalogStep> {
  final _controller = TextEditingController();

  /// Catalogue affiché. Démarre sur le repli embarqué pour que la liste soit
  /// utilisable dès l'ouverture, puis se complète avec le catalogue serveur,
  /// qui fait autorité et peut gagner des entrées sans release mobile.
  final _catalog = ValueNotifier<List<ContentCategory>>(fallbackCatalog);

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    // `getCategories` ne lève jamais : en cas d'échec réseau elle rend
    // elle-même le catalogue embarqué.
    final categories = await getIt<IContentCategoryRepository>()
        .getCategories();
    if (mounted) _catalog.value = categories;
  }

  @override
  void dispose() {
    _controller.dispose();
    _catalog.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: Listenable.merge([_controller, _catalog]),
      builder: (context, _) {
        final value = _controller.value;
        final query = value.text.trim();
        final lowered = query.toLowerCase();
        final taken = widget.takenLabels
            .map((e) => e.toLowerCase())
            .toSet();

        final matches = _catalog.value
            .where((c) => !taken.contains(c.label.toLowerCase()))
            .where(
              (c) => lowered.isEmpty || c.label.toLowerCase().contains(lowered),
            )
            .toList();

        // « Ajouter "X" » dès qu'on tape quelque chose qui n'existe pas déjà,
        // à l'identique, dans le catalogue ou dans la grille.
        final exact = query.isNotEmpty &&
            (matches.any((c) => c.label.toLowerCase() == lowered) ||
                taken.contains(lowered));
        final canCreate = query.isNotEmpty && !exact && query.length <= 100;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyTextField(
              key: const Key('price-grid-search'),
              controller: _controller,
              label: 'Article',
              hint: 'Chercher, ou écrire le vôtre',
              prefixWidget: DonyIcon(
                'search',
                size: 20,
                color: cs.onSurfaceVariant,
              ),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: DonySpacing.md),

            if (matches.isEmpty && !canCreate)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: DonySpacing.xl,
                ),
                child: Text(
                  'Tous les articles du catalogue sont déjà dans votre '
                  'grille. Écrivez le vôtre pour en ajouter un autre.',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ),

            for (final category in matches)
              _CatalogRow(
                emoji: category.emoji,
                label: category.label,
                onTap: () => widget.onPicked(category.label),
              ),

            if (canCreate)
              _CatalogRow(
                key: const Key('price-grid-create-custom'),
                emoji: '➕',
                label: 'Ajouter « $query »',
                accent: true,
                onTap: () => widget.onPicked(query),
              ),

            const SizedBox(height: DonySpacing.base),
          ],
        );
      },
    );
  }
}

class _CatalogRow extends StatelessWidget {
  const _CatalogRow({
    super.key,
    required this.emoji,
    required this.label,
    required this.onTap,
    this.accent = false,
  });

  final String emoji;
  final String label;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DonyRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.sm,
          vertical: DonySpacing.md,
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: DonySpacing.md),
            Expanded(
              child: Text(
                label,
                style: tt.bodyLarge?.copyWith(
                  fontWeight: accent ? FontWeight.w700 : FontWeight.w500,
                  color: accent ? cs.primary : cs.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DonyIcon(
              'chevron-right',
              size: 18,
              color: accent ? cs.primary : cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Étape 2 : le prix ────────────────────────────────────────────────────────

class _PriceStep extends StatelessWidget {
  const _PriceStep({
    required this.label,
    required this.raw,
    required this.chosen,
  });

  final ValueNotifier<String?> label;
  final ValueNotifier<String> raw;
  final String chosen;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ValueListenableBuilder<String>(
      valueListenable: raw,
      builder: (context, value, _) {
        final price = _parse(value);
        final tooHigh = value.isNotEmpty &&
            (double.tryParse(value.replaceAll(',', '.')) ?? 0) >
                maxUnitPriceActive;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // En-tête : l'article choisi, avec le retour au catalogue.
            Row(
              children: [
                Text(
                  emojiForLabel(chosen),
                  style: const TextStyle(fontSize: 26),
                ),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Text(
                    chosen,
                    style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  key: const Key('price-grid-change-item'),
                  onPressed: () => label.value = null,
                  child: const Text('Changer'),
                ),
              ],
            ),
            const SizedBox(height: DonySpacing.md),

            Text(
              'Ce que vous encaissez',
              style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DonySpacing.xxs),
            Text(
              value.isEmpty ? '0' : value,
              key: const Key('price-grid-amount'),
              style: tt.displayLarge?.copyWith(
                color: value.isEmpty ? cs.onSurfaceVariant : cs.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DonySpacing.sm),

            _Echo(price: price, tooHigh: tooHigh),
            const SizedBox(height: DonySpacing.md),

            DonyKeypad(
              // Sans cela, la rangée « virgule / 0 / effacer » passe sous la
              // barre de validation et devient inatteignable.
              compact: true,
              onDigit: (d) => raw.value = _append(raw.value, d),
              onDecimal: () => raw.value = _appendDecimal(raw.value),
              onDelete: () => raw.value = raw.value.isEmpty
                  ? ''
                  : raw.value.substring(0, raw.value.length - 1),
            ),
            const SizedBox(height: DonySpacing.base),
          ],
        );
      },
    );
  }

  /// Ajoute un chiffre en refusant ce qui ne peut pas être un montant :
  /// plus de deux décimales, ou un zéro de tête sans virgule derrière.
  static String _append(String current, String digit) {
    final comma = current.indexOf(',');
    if (comma >= 0 && current.length - comma > 2) return current;
    if (current == '0') return digit;
    if (current.replaceAll(',', '').length >= 6) return current;
    return current + digit;
  }

  static String _appendDecimal(String current) {
    if (current.contains(',')) return current;
    if (current.isEmpty) return '0,';
    return '$current,';
  }
}

/// Écho du montant réellement payé par l'expéditeur, recalculé à chaque touche.
class _Echo extends StatelessWidget {
  const _Echo({required this.price, required this.tooHigh});

  final double? price;
  final bool tooHigh;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final Color background;
    final Color ink;
    final String message;

    if (tooHigh) {
      background = cs.errorLight;
      ink = cs.error;
      message =
          'Maximum ${formatPriceActive(maxUnitPriceActive)} par article.';
    } else if (price == null) {
      background = cs.surfaceContainerHighest;
      ink = cs.onSurfaceVariant;
      message = 'Saisissez le montant que vous voulez toucher.';
    } else {
      background = cs.primaryContainer;
      ink = cs.primary;
      message =
          'L\'expéditeur paiera ${formatPriceActive(netToSenderPrice(price!))}, '
          'commission Yadony de $donyCommissionPercentLabel % comprise.';
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: Container(
        key: ValueKey(message),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.md,
          vertical: DonySpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(DonyRadius.md),
        ),
        child: Text(
          message,
          style: tt.bodySmall?.copyWith(color: ink),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
