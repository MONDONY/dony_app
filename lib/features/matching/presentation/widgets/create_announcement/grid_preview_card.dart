import 'package:dony/core/currency/currency_conversion.dart';
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

/// Devise d'affichage des prix de l'aperçu et conversion à appliquer.
///
/// La grille est exprimée dans la devise ACTIVE du voyageur ; à la publication,
/// le backend la convertit dans la devise du trajet (`ExchangeRateService`).
/// L'aperçu doit donc montrer ce montant converti, jamais le prix brut sous le
/// symbole du trajet (« 10 F CFA » pour 10 €, FLUTTER-ER).
@visibleForTesting
class GridPriceDisplay {
  const GridPriceDisplay._({required this.currency, this.convertedFrom});

  /// Devise du symbole affiché. `null` : devise de la grille inconnue, le
  /// montant est montré sans symbole plutôt qu'avec une devise inventée.
  final SupportedCurrency? currency;

  /// Devise de la grille quand les prix sont convertis, sinon `null`.
  final SupportedCurrency? convertedFrom;

  bool get isConverted => convertedFrom != null;

  /// Résout l'affichage à partir de la devise de la grille et de celle du
  /// trajet. Sans taux serveur, les prix restent dans la devise de la grille,
  /// avec leur propre symbole.
  static GridPriceDisplay resolve({
    required SupportedCurrency? gridCurrency,
    required SupportedCurrency? tripCurrency,
  }) {
    if (gridCurrency == null) return const GridPriceDisplay._(currency: null);
    if (tripCurrency == null || tripCurrency == gridCurrency) {
      return GridPriceDisplay._(currency: gridCurrency);
    }
    final ratesReady =
        convertWithServerRates(1, from: gridCurrency, to: tripCurrency) != null;
    if (!ratesReady) return GridPriceDisplay._(currency: gridCurrency);
    return GridPriceDisplay._(
      currency: tripCurrency,
      convertedFrom: gridCurrency,
    );
  }

  /// Prix [amount] (dans la devise de la grille) tel qu'il doit s'afficher.
  String format(double amount, {bool compact = false}) {
    final from = convertedFrom;
    final value = from == null
        ? amount
        : convertWithServerRates(amount, from: from, to: currency!) ?? amount;
    return CurrencyFormatter.formatOrPlain(value, currency, compact: compact);
  }
}

/// Étiquette d'un article du barème, montée à l'identique dans l'aperçu replié
/// et dans la feuille complète.
Widget _tag(
  GridPreviewItem item,
  GridPriceDisplay display, {
  bool compact = false,
}) {
  return DonyPriceTag(
    label: item.label,
    emoji: emojiForLabel(item.label),
    price: display.format(item.unitPriceDisplay),
    compact: compact,
  );
}

/// Mention affichée sous les prix uniquement quand ils sont convertis.
Widget _convertedNote(BuildContext context, GridPriceDisplay display) {
  final from = display.convertedFrom;
  if (from == null) return const SizedBox.shrink();
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;
  return Padding(
    padding: const EdgeInsets.only(bottom: DonySpacing.xs),
    child: Text(
      context.l10n.tripPublishGridPreviewConvertedNote(from.code),
      key: const Key('grid-preview-converted-note'),
      style: tt.bodySmall?.copyWith(
        color: cs.onSurfaceVariant,
        fontStyle: FontStyle.italic,
      ),
    ),
  );
}

/// Aperçu de la grille du profil dans l'étape « Prix & conditions ».
///
/// La grille n'appartient pas au trajet : elle est un réglage de profil que
/// tous les trajets consultent. Cette carte est donc en lecture seule, et
/// toute modification passe par l'écran du profil.
class GridPreviewCard extends StatelessWidget {
  const GridPreviewCard({
    super.key,
    required this.items,
    this.currency,
    this.gridCurrency,
  });

  final List<GridPreviewItem> items;

  /// Devise du trajet, celle dans laquelle le backend publiera la grille.
  final SupportedCurrency? currency;

  /// Devise de la grille (devise active du voyageur), `null` si inconnue.
  final SupportedCurrency? gridCurrency;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final display = GridPriceDisplay.resolve(
      gridCurrency: gridCurrency,
      tripCurrency: currency,
    );

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
              child: _tag(item, display, compact: true),
            ),

          _convertedNote(context, display),

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
      gridCurrency: gridCurrency,
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
    SupportedCurrency? gridCurrency,
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
      child: _GridPreviewSheetContent(
        display: GridPriceDisplay.resolve(
          gridCurrency: gridCurrency,
          tripCurrency: currency,
        ),
        items: items,
      ),
    );
  }
}

class _GridPreviewSheetContent extends StatelessWidget {
  const _GridPreviewSheetContent({required this.items, required this.display});

  final List<GridPreviewItem> items;
  final GridPriceDisplay display;

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
            child: _tag(item, display),
          ),
        _convertedNote(context, display),
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
