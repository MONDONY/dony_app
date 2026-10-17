import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/features/ai_form_draft/data/ai_form_draft_models.dart';
import 'package:dony/features/ai_form_draft/data/ai_text_fold.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/data/package_request_limits.dart';

/// Brouillon de demande d'envoi résolu → [PackageRequestFormState], appliqué
/// par `FormDraftRestored` (qui incrémente `draftRevision` : les étapes
/// relisent l'état du bloc).
///
/// L'IA ne remplit ni les photos ni le code promo (spec §1). Ignorés aussi :
/// `transportMode` (le wizard le fixe à l'avion), les quartiers de remise et de
/// livraison (plus saisis à la publication) et `budgetDeclined` (aucun champ).
abstract final class PackageRequestAiDraftMapper {
  /// Comme l'étape 2 (`_kMaxCategories`).
  static const int maxCategories = 5;

  static PackageRequestFormState toFormState(
    Map<String, Object?> ai, {
    required PackageRequestFormState base,
    required List<String> catalogLabels,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final today = DateTime(clock.year, clock.month, clock.day);
    final date = parseIsoDate(ai['desiredDate']);
    final tolerance = ai['dateToleranceDays'];
    final rawWeight = ai['weightKg'];
    final weight = rawWeight is num ? rawWeight.toDouble() : null;
    final weightKg = PackageRequestLimits.isWeightValid(weight) ? weight : null;
    final categories = _categories(ai['categories'], catalogLabels);
    final rawMethods = ai['acceptedPaymentMethods'];
    final methods = PaymentMethod.setFromJson(
      rawMethods is List ? rawMethods : null,
    );
    final budget = ai['totalBudget'];
    final negotiable = ai['negotiable'];
    return base.copyWith(
      currentStep: 0,
      departureCity: _text(ai['departureCity']),
      arrivalCity: _text(ai['arrivalCity']),
      desiredDate: date != null && !date.isBefore(today) ? date : null,
      dateToleranceDays: tolerance is int && tolerance >= 0 && tolerance <= 7
          ? tolerance
          : null,
      weightKg: weightKg,
      parcelSize: weightKg == null
          ? null
          : _parcelSize(ai['parcelSize']) ?? parcelSizeForWeight(weightKg),
      categories: categories.isEmpty ? null : categories,
      description: _text(ai['description']),
      negotiable: negotiable is bool ? negotiable : null,
      acceptedPaymentMethods: methods.isEmpty ? null : methods,
      totalBudgetEur: budget is num ? budget.toDouble() : null,
      currency: SupportedCurrency.fromCode(_text(ai['currency'])),
    );
  }

  /// Même règle que l'étape 2 (`_sizeFromWeight`).
  static ParcelSize parcelSizeForWeight(double weightKg) {
    if (weightKg <= 3) return ParcelSize.small;
    if (weightKg <= 10) return ParcelSize.medium;
    return ParcelSize.large;
  }

  static List<String> _categories(Object? raw, List<String> catalog) {
    if (raw is! List) return const [];
    final result = <String>[];
    for (final item in raw) {
      if (item is! String || item.trim().isEmpty) continue;
      final label = _catalogLabel(item, catalog) ?? item.trim();
      if (!result.contains(label)) result.add(label);
      if (result.length == maxCategories) break;
    }
    return result;
  }

  /// Libellé du catalogue égal à [said], ou dont une partie (séparée par
  /// « & » ou « / ») lui est égale, au singulier ou au pluriel.
  static String? _catalogLabel(String said, List<String> catalog) {
    final target = foldForMatch(said);
    for (final label in catalog) {
      if (foldForMatch(label) == target) return label;
    }
    for (final label in catalog) {
      for (final part in label.split(RegExp('[&/]'))) {
        final folded = foldForMatch(part);
        if (folded.isNotEmpty && (folded == target || folded == '${target}s')) {
          return label;
        }
      }
    }
    return null;
  }

  static ParcelSize? _parcelSize(Object? raw) {
    for (final size in ParcelSize.values) {
      if (size.wireName == raw) return size;
    }
    return null;
  }

  static String? _text(Object? raw) =>
      raw is String && raw.trim().isNotEmpty ? raw.trim() : null;
}
