import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/features/ai_form_draft/data/ai_city_resolver.dart';
import 'package:dony/features/ai_form_draft/data/ai_form_draft_models.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/data/package_request_limits.dart';

/// Contrôles du brouillon de demande d'envoi que seule l'app sait faire.
class PackageRequestAiDraftResolver implements AiDraftResolver {
  PackageRequestAiDraftResolver({
    required AiCityResolver cities,
    required String? fallbackCurrency,
  }) : _cities = cities,
       _fallbackCurrency = fallbackCurrency;

  final AiCityResolver _cities;
  final String? _fallbackCurrency;

  @override
  Future<AiResolvedDraft> resolve(Map<String, Object?> draft) async {
    final out = Map<String, Object?>.of(draft);
    final warnings = <AiDraftWarning>[];
    if (!await _cities.resolveInto(out, cityKey: 'departureCity')) {
      warnings.add(AiDraftWarning.departureCityUnknown);
    }
    if (!await _cities.resolveInto(out, cityKey: 'arrivalCity')) {
      warnings.add(AiDraftWarning.arrivalCityUnknown);
    }
    final rawCurrency = out['currency'];
    final currency =
        SupportedCurrency.fromCode(
          rawCurrency is String ? rawCurrency : null,
        ) ??
        SupportedCurrency.fromCode(_fallbackCurrency) ??
        SupportedCurrency.eur;

    final rawMethods = out['acceptedPaymentMethods'];
    if (rawMethods is List) {
      final asked = [
        for (final m in rawMethods)
          if (m is String) m,
      ];
      final selectable = {
        for (final m in PaymentMethod.selectableIn(currency)) m.wireName,
      };
      final kept = [
        for (final m in asked)
          if (selectable.contains(m)) m,
      ];
      if (asked.contains(PaymentMethod.stripe.wireName) &&
          !selectable.contains(PaymentMethod.stripe.wireName)) {
        warnings.add(AiDraftWarning.cardUnavailableInCurrency);
      }
      if (asked.contains(PaymentMethod.mobileMoney.wireName) &&
          !selectable.contains(PaymentMethod.mobileMoney.wireName)) {
        warnings.add(AiDraftWarning.mobileMoneyUnavailable);
      }
      out['acceptedPaymentMethods'] = kept.isEmpty ? null : kept;
    }

    // Le serveur accepte jusqu'à 1 000 000 ; le formulaire, lui, borne le
    // budget à 1–560 € mis à l'échelle de la devise de la demande.
    final budget = out['totalBudget'];
    if (budget is num &&
        !PackageRequestLimits.isBudgetValid(budget.toDouble(), currency)) {
      out['totalBudget'] = null;
      warnings.add(AiDraftWarning.budgetOutOfRange);
    }
    return AiResolvedDraft(
      draft: Map<String, Object?>.unmodifiable(out),
      warnings: List<AiDraftWarning>.unmodifiable(warnings),
    );
  }
}
