import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/price_grid/bloc/price_grid_bloc.dart';
import 'package:dony/features/price_grid/bloc/price_grid_event.dart';
import 'package:dony/features/price_grid/bloc/price_grid_state.dart';
import 'package:dony/features/price_grid/data/models/price_grid_item_model.dart';
import 'package:dony/features/price_grid/presentation/price_grid_item_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PriceGridScreen extends StatelessWidget {
  const PriceGridScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return BlocConsumer<PriceGridBloc, PriceGridState>(
      listener: (context, state) {
        if (state is PriceGridError) {
          DonySnackbar.show(
            context,
            message: state.message,
            type: DonySnackbarType.error,
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          // Fond kraft : la grille est une liasse d'étiquettes posée sur le
          // comptoir, pas une page de réglages.
          backgroundColor: cs.surfaceWarm,
          appBar: AppBar(
            leading: const DonyAppBarBackButton(),
            title: const Text('Ma grille de prix'),
            centerTitle: false,
            backgroundColor: cs.surfaceWarm,
          ),
          body: _buildBody(context, state),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, PriceGridState state) {
    if (state is PriceGridInitial) {
      // Premier rendu : chargement différé pour ne pas émettre pendant le build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<PriceGridBloc>().add(const PriceGridLoadRequested());
      });
      return const Center(child: CircularProgressIndicator());
    }

    if (state is PriceGridLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is PriceGridError) {
      return _ErrorView(
        message: state.message,
        onRetry: () =>
            context.read<PriceGridBloc>().add(const PriceGridLoadRequested()),
      );
    }

    if (state is PriceGridLoaded) {
      return _LoadedView(items: state.items);
    }

    return const SizedBox.shrink();
  }
}

// ── Error view ──────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyIcon('circle-alert', size: 48, color: cs.error),
            const SizedBox(height: DonySpacing.base),
            Text(
              'Une erreur est survenue',
              style: tt.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DonySpacing.xs),
            Text(
              message,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DonySpacing.xl),
            DonyButton(
              label: 'Réessayer',
              onPressed: onRetry,
              variant: DonyButtonVariant.secondary,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Loaded view ─────────────────────────────────────────────────────────────

class _LoadedView extends StatefulWidget {
  const _LoadedView({required this.items});

  final List<PriceGridItemModel> items;

  @override
  State<_LoadedView> createState() => _LoadedViewState();
}

class _LoadedViewState extends State<_LoadedView> {
  /// Mode réorganisation : les poignées remplacent les menus d'options.
  /// `ValueNotifier` et non `setState`, conformément aux règles du projet.
  final _reordering = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _reordering.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final items = widget.items;

    if (items.isEmpty) {
      return _EmptyGrid(onAdd: () => _openAddSheet(context));
    }

    final bottomPadding = MediaQuery.paddingOf(context).bottom + 110;

    return ValueListenableBuilder<bool>(
      valueListenable: _reordering,
      builder: (context, reordering, _) {
        return Column(
          children: [
            // Tampon : la première chose que dit l'écran, c'est la portée du
            // barème. Une grille, tous les trajets.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg,
                DonySpacing.md,
                DonySpacing.lg,
                DonySpacing.sm,
              ),
              child: Row(
                children: [
                  // Flexible et non figé : à grande échelle de texte, le
                  // tampon et le bouton se disputent la ligne.
                  const Flexible(child: _ScopeStamp()),
                  const SizedBox(width: DonySpacing.sm),
                  TextButton(
                    onPressed: () => _reordering.value = !reordering,
                    child: Text(reordering ? 'Terminé' : 'Réordonner'),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ReorderableListView.builder(
                padding: EdgeInsets.fromLTRB(
                  DonySpacing.lg,
                  DonySpacing.xs,
                  DonySpacing.lg,
                  bottomPadding,
                ),
                itemCount: items.length,
                // Poignées explicites, jamais l'appui long : un appui long sur
                // une étiquette entrerait en conflit avec le tap d'édition.
                buildDefaultDragHandles: false,
                proxyDecorator: (child, index, animation) => Material(
                  type: MaterialType.transparency,
                  child: child,
                ),
                // `onReorderItem` et non `onReorder` : il livre un newIndex
                // déjà corrigé du retrait de l'élément déplacé.
                onReorderItem: (oldIndex, newIndex) =>
                    _onReorder(context, oldIndex, newIndex),
                itemBuilder: (context, index) => Padding(
                  key: ValueKey(items[index].id),
                  padding: const EdgeInsets.only(bottom: DonySpacing.sm + 2),
                  child: _PriceGridItemTile(
                    item: items[index],
                    index: index,
                    reordering: reordering,
                  ),
                ),
              ),
            ),

            // L'information de commission vit en pied de liste, là où on la
            // consulte, plutôt qu'en bandeau qui mange le haut de l'écran.
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(top: BorderSide(color: cs.outline)),
              ),
              padding: EdgeInsets.fromLTRB(
                DonySpacing.lg,
                DonySpacing.md,
                DonySpacing.lg,
                MediaQuery.paddingOf(context).bottom + DonySpacing.base,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Yadony ajoute $donyCommissionPercentLabel % au prix que '
                    'vous saisissez. Vous encaissez exactement votre montant.',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: DonySpacing.md),
                  DonyButton(
                    label: 'Nouvelle étiquette',
                    iconAsset: 'plus',
                    onPressed: () => _openAddSheet(context),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _onReorder(BuildContext context, int oldIndex, int newIndex) {
    if (newIndex == oldIndex) return;

    final ordered = List<PriceGridItemModel>.from(widget.items);
    final moved = ordered.removeAt(oldIndex);
    ordered.insert(newIndex, moved);

    context.read<PriceGridBloc>().add(
      PriceGridItemsReorderRequested(ordered.map((e) => e.id).toList()),
    );
  }

  Future<void> _openAddSheet(BuildContext context) async {
    await PriceGridItemFormSheet.show(
      context,
      // Un article déjà tarifé ne se repropose pas : deux étiquettes de même
      // nom rendraient la grille illisible pour l'expéditeur.
      takenLabels: widget.items.map((e) => e.label).toList(),
    );
    // Le BLoC est partagé via `wrapper` : l'écran se reconstruit seul.
  }
}

/// Tampon encré indiquant la portée du barème.
class _ScopeStamp extends StatelessWidget {
  const _ScopeStamp();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Transform.rotate(
      angle: -0.028,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.sm + 2,
          vertical: DonySpacing.xs + 1,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DonyRadius.xs + 1),
          border: Border.all(color: cs.primary, width: 1.5),
        ),
        child: Text(
          'Valable sur tous vos trajets',
          style: tt.labelMedium?.copyWith(
            color: cs.primary,
            letterSpacing: 0.8,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

// ── Empty grid ───────────────────────────────────────────────────────────────

class _EmptyGrid extends StatelessWidget {
  const _EmptyGrid({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: DonyIcon('tag', size: 32, color: cs.primary),
            ),
            const SizedBox(height: DonySpacing.base),
            Text(
              'Aucune étiquette',
              style: tt.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DonySpacing.xs),
            Text(
              'Fixez le prix des articles que vous transportez. Le même '
              'barème servira sur tous vos trajets.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DonySpacing.xl),
            DonyButton(
              label: 'Nouvelle étiquette',
              iconAsset: 'plus',
              onPressed: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Item tile ────────────────────────────────────────────────────────────────

class _PriceGridItemTile extends StatelessWidget {
  const _PriceGridItemTile({
    required this.item,
    required this.index,
    required this.reordering,
  });

  final PriceGridItemModel item;
  final int index;
  final bool reordering;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DonyPriceTag(
      label: item.label,
      emoji: emojiForLabel(item.label),
      price: formatPriceActive(item.unitPriceDisplay),
      caption: 'vous recevez ${formatPriceActive(item.unitPriceNet)}',
      onTap: reordering ? null : () => _openEditSheet(context),
      semanticLabel:
          '${item.label}, l\'expéditeur paie '
          '${formatPriceActive(item.unitPriceDisplay)}, '
          'vous recevez ${formatPriceActive(item.unitPriceNet)}',
      trailing: reordering
          ? ReorderableDragStartListener(
              index: index,
              child: Semantics(
                label: 'Déplacer ${item.label}',
                button: true,
                container: true,
                excludeSemantics: true,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: DonyIcon(
                      'grip-vertical',
                      size: 20,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            )
          : PopupMenuButton<String>(
              icon: DonyIcon('ellipsis-vertical', color: cs.onSurfaceVariant),
              tooltip: 'Options',
              // Le rembourrage par défaut vole une vingtaine de points au
              // libellé, qui se met à s'ellipser sur les écrans étroits. La
              // cible tactile reste à 44 pt par les contraintes.
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 44,
                minHeight: 44,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DonyRadius.md),
              ),
              onSelected: (value) {
                if (value == 'edit') {
                  _openEditSheet(context);
                } else if (value == 'delete') {
                  _confirmDelete(context);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: [
                      DonyIcon('square-pen', size: 20, color: cs.primary),
                      const SizedBox(width: DonySpacing.md),
                      const Text('Modifier'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      DonyIcon('trash-2', size: 20, color: cs.error),
                      const SizedBox(width: DonySpacing.md),
                      Text('Supprimer', style: TextStyle(color: cs.error)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  void _openEditSheet(BuildContext context) {
    PriceGridItemFormSheet.show(context, item: item);
  }

  void _confirmDelete(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer l\'étiquette ?'),
        content: Text(
          'L\'article "${item.label}" sera retiré de votre grille, sur tous '
          'vos trajets.',
          style: tt.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: cs.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true && context.mounted) {
        context.read<PriceGridBloc>().add(
          PriceGridItemDeleteRequested(item.id),
        );
      }
    });
  }
}
