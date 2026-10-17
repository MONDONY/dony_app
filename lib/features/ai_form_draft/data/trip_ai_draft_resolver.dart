import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/features/ai_form_draft/data/ai_city_resolver.dart';
import 'package:dony/features/ai_form_draft/data/ai_form_draft_models.dart';
import 'package:dony/features/price_grid/data/repositories/price_grid_repository.dart';

/// Contrôles du brouillon trajet que seule l'app sait faire (spec §4.3).
class TripAiDraftResolver implements AiDraftResolver {
  TripAiDraftResolver({
    required AiCityResolver cities,
    required PriceGridRepository priceGrid,
    required bool Function() isCardReady,
    required String? fallbackCurrency,
  }) : _cities = cities,
       _priceGrid = priceGrid,
       _isCardReady = isCardReady,
       _fallbackCurrency = fallbackCurrency;

  final AiCityResolver _cities;
  final PriceGridRepository _priceGrid;
  final bool Function() _isCardReady;
  final String? _fallbackCurrency;

  @override
  Future<AiResolvedDraft> resolve(Map<String, Object?> draft) async {
    final out = Map<String, Object?>.of(draft);
    final warnings = <AiDraftWarning>[];
    if (!await _cities.resolveInto(
      out,
      cityKey: 'departureCity',
      countryKey: 'departureCountryCode',
    )) {
      warnings.add(AiDraftWarning.departureCityUnknown);
    }
    if (!await _cities.resolveInto(
      out,
      cityKey: 'arrivalCity',
      countryKey: 'arrivalCountryCode',
    )) {
      warnings.add(AiDraftWarning.arrivalCityUnknown);
    }
    // Le formulaire ne propose que l'avion (sélecteur retiré) : un autre
    // mode partirait au serveur sans que l'utilisateur le voie.
    final mode = out['transportMode'];
    if (mode is String && mode != 'PLANE') {
      out['transportMode'] = 'PLANE';
      warnings.add(AiDraftWarning.planeOnly);
    }
    if (out['pricingMode'] == 'MIXED' && !await _hasGrid()) {
      out['pricingMode'] = 'KG';
      warnings.add(AiDraftWarning.noPriceGrid);
    }
    final rawCurrency = out['currency'];
    final currency =
        SupportedCurrency.fromCode(
          rawCurrency is String ? rawCurrency : null,
        ) ??
        SupportedCurrency.fromCode(_fallbackCurrency) ??
        SupportedCurrency.eur;
    if (out['cardEnabled'] == true) {
      if (!currency.isStripeEligible) {
        warnings.add(AiDraftWarning.cardUnavailableInCurrency);
      } else if (!_isCardReady()) {
        // Gardée : le formulaire montre déjà le bandeau « Activer les
        // paiements par carte » à l'étape Prix.
        warnings.add(AiDraftWarning.cardNotConfigured);
      }
    }
    if (out['mobileMoneyEnabled'] == true && !currency.isMobileMoneyEligible) {
      out['mobileMoneyEnabled'] = false;
      warnings.add(AiDraftWarning.mobileMoneyUnavailable);
    }
    return AiResolvedDraft(
      draft: Map<String, Object?>.unmodifiable(out),
      warnings: List<AiDraftWarning>.unmodifiable(warnings),
    );
  }

  /// Hors ligne ou en erreur : on ne rétrograde pas, le formulaire chargera
  /// la grille lui-même.
  Future<bool> _hasGrid() async {
    try {
      return (await _priceGrid.getItems()).isNotEmpty;
    } on Object {
      return true;
    }
  }
}
