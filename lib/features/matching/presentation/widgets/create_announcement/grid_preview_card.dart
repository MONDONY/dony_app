import 'package:dony/core/currency/currency_conversion.dart';
import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/commission_pricing.dart';
import 'package:dony/features/matching/bloc/announcement_form_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_form_event.dart';
import 'package:dony/features/matching/data/models/grid_preview_item.dart';
import 'package:dony/features/price_grid/data/models/price_grid_suggestion.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Devise d'affichage des prix de l'aperçu et conversion à appliquer.
///
/// La grille est exprimée dans la devise ACTIVE du voyageur ; à la publication,
/// le backend la convertit dans la devise du trajet (`ExchangeRateService`).
/// L'aperçu doit donc montrer ce montant converti, jamais le prix brut sous le
/// symbole du trajet (« 10 F CFA » pour 10 €, FLUTTER-ER).
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

  /// Frais de service minimum de la grille de commission en vigueur dans la
  /// devise affichée, `null` sans grille : les prix sont alors ceux que
  /// l'expéditeur paie, commission comprise.
  double? get feeMinimum => commissionMinimumFor(currency?.code);

  /// Prix d'un article tel qu'il doit s'afficher. Sous grille de commission,
  /// le net du voyageur (les frais de service s'ajoutent au total) ; sinon le
  /// prix servi, commission comprise.
  String formatItem(GridPreviewItem item, {bool compact = false}) {
    final net = item.unitPriceNet;
    final amount = feeMinimum != null && net != null
        ? net
        : item.unitPriceDisplay;
    return format(amount, compact: compact);
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

/// Mention affichée sous les prix uniquement quand ils sont convertis.
class GridConvertedNote extends StatelessWidget {
  const GridConvertedNote({super.key, required this.display});

  final GridPriceDisplay display;

  @override
  Widget build(BuildContext context) {
    final from = display.convertedFrom;
    if (from == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: DonySpacing.xs),
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
}

/// Ouvre l'écran de grille du profil, puis recharge les prix par article
/// du formulaire au retour.
///
/// Le `push` est attendu et suivi d'un rechargement explicite : sans ce
/// rappel, un voyageur qui corrige un prix et revient continue de voir
/// l'ancien montant, et le mode de tarification (déduit de la grille) reste
/// celui d'avant. [suggestions] préremplit une grille vide avec les prix
/// pratiqués sur la route.
Future<void> openPriceGridAndRefresh(
  BuildContext context, {
  List<PriceGridSuggestion> suggestions = const [],
}) async {
  final bloc = context.read<AnnouncementFormBloc>();
  await context.push(
    '/profile/price-grid',
    extra: suggestions.isEmpty ? null : suggestions,
  );
  if (!context.mounted) return;
  bloc.add(const AnnouncementGridPreviewLoadRequested());
}
