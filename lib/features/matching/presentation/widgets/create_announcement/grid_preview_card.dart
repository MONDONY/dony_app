import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/pricing_labels.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/matching/bloc/announcement_form_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_form_event.dart';
import 'package:dony/features/matching/data/models/grid_preview_item.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Nombre d'étiquettes montrées dans le formulaire avant repli. Au-delà, la
/// liste complète part dans une feuille : le formulaire de publication est
/// déjà long, un barème de dix articles y noierait les champs suivants.
const int _visibleCount = 3;

/// Étiquette d'un article du barème, montée à l'identique dans l'aperçu replié
/// et dans la feuille complète.
Widget _tag(
  GridPreviewItem item,
  SupportedCurrency? currency, {
  bool compact = false,
}) {
  return DonyPriceTag(
    label: item.label,
    emoji: emojiForLabel(item.label),
    price: CurrencyFormatter.formatOrPlain(item.unitPriceDisplay, currency),
    compact: compact,
  );
}

/// Aperçu de la grille du profil dans l'étape « Prix & conditions ».
///
/// La grille n'appartient pas au trajet : elle est un réglage de profil que
/// tous les trajets consultent. Cette carte est donc en lecture seule, et
/// toute modification passe par l'écran du profil.
class GridPreviewCard extends StatelessWidget {
  const GridPreviewCard({super.key, required this.items, this.currency});

  final List<GridPreviewItem> items;
  final SupportedCurrency? currency;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;

    final visible = items.take(_visibleCount).toList();
    final hidden = items.length - visible.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l.tripPublishGridPreviewLabel,
              style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const Spacer(),
            TextButton(
              key: const Key('grid-preview-edit'),
              onPressed: () => openPriceGridAndRefresh(context),
              child: Text(l.commonEdit),
            ),
          ],
        ),
        const SizedBox(height: DonySpacing.xs),

        if (items.isEmpty)
          _EmptyGridNotice(onAdd: () => openPriceGridAndRefresh(context))
        else ...[
          for (final item in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: DonySpacing.sm),
              child: _tag(item, currency, compact: true),
            ),

          if (hidden > 0)
            TextButton.icon(
              key: const Key('grid-preview-see-all'),
              onPressed: () => _openSheet(context),
              icon: const DonyIcon('tag', size: 16),
              label: Text(l.tripPublishGridPreviewSeeAll(items.length)),
            ),

          const SizedBox(height: DonySpacing.xs),
          Text(
            l.tripPublishGridPreviewNote,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ],
    );
  }

  Future<void> _openSheet(BuildContext context) async {
    final wantsEdit = await GridPreviewSheet.show(
      context,
      items: items,
      currency: currency,
    );
    if (wantsEdit == true && context.mounted) {
      await openPriceGridAndRefresh(context);
    }
  }
}

/// Ouvre l'écran de grille du profil, puis recharge l'aperçu au retour.
///
/// Le `push` est attendu et suivi d'un rechargement explicite : le BLoC du
/// formulaire n'émet [AnnouncementGridPreviewLoadRequested] qu'au moment de la
/// bascule vers le mode grille, jamais au retour d'une navigation. Sans ce
/// rappel, un voyageur déjà en mode grille qui corrige un prix et revient
/// continue de voir l'ancien montant.
Future<void> openPriceGridAndRefresh(BuildContext context) async {
  final bloc = context.read<AnnouncementFormBloc>();
  await context.push('/profile/price-grid');
  if (!context.mounted) return;
  bloc.add(const AnnouncementGridPreviewLoadRequested());
}

/// Feuille listant tout le barème, ouverte depuis « Voir les N articles ».
///
/// Retourne `true` si l'utilisateur demande à modifier sa grille. La
/// navigation est laissée à l'appelant, une fois la feuille refermée, plutôt
/// que d'empiler une route par-dessus la feuille.
abstract final class GridPreviewSheet {
  static Future<bool?> show(
    BuildContext context, {
    required List<GridPreviewItem> items,
    SupportedCurrency? currency,
  }) {
    final l = context.l10n;
    return DonyBottomSheet.show<bool>(
      context,
      title: l.tripPublishGridSheetTitle,
      subtitle: l.tripPublishGridSheetSubtitle,
      stickyBottom: Builder(
        builder: (ctx) => DonyButton(
          key: const Key('grid-sheet-edit'),
          label: l.tripPublishGridSheetEditCta,
          iconAsset: 'square-pen',
          onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(true),
        ),
      ),
      child: _GridPreviewSheetContent(items: items, currency: currency),
    );
  }
}

class _GridPreviewSheetContent extends StatelessWidget {
  const _GridPreviewSheetContent({required this.items, this.currency});

  final List<GridPreviewItem> items;
  final SupportedCurrency? currency;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: DonySpacing.sm + 2),
            child: _tag(item, currency),
          ),
        const SizedBox(height: DonySpacing.xs),
        Text(
          l.tripPublishGridSheetCommissionNote(commissionPercentLabel(l)),
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DonySpacing.base),
      ],
    );
  }
}

/// Affiché quand le voyageur choisit le mode grille sans avoir d'étiquettes.
class _EmptyGridNotice extends StatelessWidget {
  const _EmptyGridNotice({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;

    return DonyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.tripPublishGridEmptyTitle,
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            l.tripPublishGridEmptySubtitle,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: DonySpacing.md),
          DonyButton(
            key: const Key('grid-preview-create'),
            label: l.tripPublishGridComposeCta,
            iconAsset: 'plus',
            variant: DonyButtonVariant.secondary,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}
