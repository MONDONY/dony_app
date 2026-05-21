import 'package:dony/core/design/design_system.dart';
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
          appBar: AppBar(
            title: const Text('Ma grille de prix'),
            centerTitle: false,
          ),
          body: _buildBody(context, state),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, PriceGridState state) {
    if (state is PriceGridInitial) {
      // Trigger load on first render
      context.read<PriceGridBloc>().add(const PriceGridLoadRequested());
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
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: cs.error,
            ),
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

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.items});

  final List<PriceGridItemModel> items;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 100;

    return Column(
      children: [
        // Info banner
        Container(
          margin: const EdgeInsets.fromLTRB(
            DonySpacing.lg,
            DonySpacing.base,
            DonySpacing.lg,
            0,
          ),
          padding: const EdgeInsets.all(DonySpacing.md),
          decoration: BoxDecoration(
            color: cs.infoLight,
            borderRadius: BorderRadius.circular(DonyRadius.md),
            border: Border.all(
              color: cs.info.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: cs.info,
              ),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: Text(
                  'Dony ajoute 12 % sur chaque prix. '
                  'Vous recevez exactement le montant saisi.',
                  style: tt.bodySmall?.copyWith(color: cs.info),
                ),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: items.isEmpty
              ? _EmptyGrid(onAdd: () => _openAddSheet(context))
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    DonySpacing.lg,
                    DonySpacing.base,
                    DonySpacing.lg,
                    bottomPadding,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: DonySpacing.sm),
                  itemBuilder: (context, index) =>
                      _PriceGridItemTile(item: items[index]),
                ),
        ),

        // Add button
        if (items.isNotEmpty)
          Container(
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
            child: DonyButton(
              label: 'Ajouter un article',
              icon: Icons.add_rounded,
              onPressed: () => _openAddSheet(context),
            ),
          ),
      ],
    );
  }

  Future<void> _openAddSheet(BuildContext context) async {
    await PriceGridItemFormSheet.show(context);
    // The BLoC is shared via wrapper, so the screen rebuilds automatically.
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
              child: Icon(
                Icons.grid_view_rounded,
                size: 32,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: DonySpacing.base),
            Text(
              'Grille vide',
              style: tt.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DonySpacing.xs),
            Text(
              'Ajoutez vos articles pour que les expéditeurs '
              'puissent choisir ce qu\'ils souhaitent envoyer.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DonySpacing.xl),
            DonyButton(
              label: 'Ajouter un article',
              icon: Icons.add_rounded,
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
  const _PriceGridItemTile({required this.item});

  final PriceGridItemModel item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return DonyCard(
      child: Row(
        children: [
          // Position badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(DonyRadius.sm),
            ),
            alignment: Alignment.center,
            child: Text(
              '${item.position}',
              style: tt.labelMedium?.copyWith(color: cs.primary),
            ),
          ),
          const SizedBox(width: DonySpacing.md),

          // Label + prices
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: tt.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: DonySpacing.xxs),
                Row(
                  children: [
                    // Net (traveler receives)
                    Text(
                      '${item.unitPriceNet.toStringAsFixed(2)} €',
                      style: tt.bodySmall?.copyWith(
                        color: cs.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      ' · ',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    // Display (sender sees)
                    Text(
                      '${item.unitPriceDisplay.toStringAsFixed(2)} € expéditeur',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _openEditSheet(context),
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: 'Modifier',
                style: IconButton.styleFrom(
                  foregroundColor: cs.primary,
                ),
              ),
              IconButton(
                onPressed: () => _confirmDelete(context),
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                tooltip: 'Supprimer',
                style: IconButton.styleFrom(
                  foregroundColor: cs.error,
                ),
              ),
            ],
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
        title: const Text('Supprimer l\'article ?'),
        content: Text(
          'L\'article "${item.label}" sera supprimé définitivement.',
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
