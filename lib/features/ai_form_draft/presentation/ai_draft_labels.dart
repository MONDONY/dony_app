import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/utils/format_weight.dart';
import 'package:dony/features/ai_form_draft/data/ai_form_draft_models.dart';
import 'package:dony/features/content_categories/presentation/content_category_labels.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/trip_domain_labels.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/presentation/package_request_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:intl/intl.dart';

/// Textes affichés à partir d'un brouillon (puces, résumé). Fonctions pures :
/// la valeur vient du brouillon, le libellé de l'ARB.

String? aiRouteLabel(Map<String, Object?> draft) {
  final from = _text(draft['departureCity']);
  final to = _text(draft['arrivalCity']);
  if (from == null || to == null) return from ?? to;
  return '$from → $to';
}

String? aiPaymentLabel(
  AppLocalizations l,
  AiFormKind kind,
  Map<String, Object?> draft,
) {
  final labels = switch (kind) {
    AiFormKind.trip => [
      if (draft['cardEnabled'] == true) l.paymentMethodCard,
      if (draft['cashEnabled'] == true) l.paymentMethodCash,
      if (draft['mobileMoneyEnabled'] == true) l.paymentMethodMobileMoney,
    ],
    AiFormKind.packageRequest => [
      for (final wire in _strings(draft['acceptedPaymentMethods']))
        if (PaymentMethod.tryFromWire(wire) case final method?) method.label(l),
    ],
  };
  return labels.isEmpty ? null : joinList(l, labels);
}

/// Valeur d'une puce « Déjà compris » ([key] : libellé `understood` du
/// serveur, spec §3.5 et §3.6). `null` : rien à montrer.
String? aiUnderstoodChipLabel(
  AppLocalizations l,
  AiFormKind kind,
  String key,
  Map<String, Object?> draft, {
  String? fallbackCurrency,
}) {
  switch (key) {
    case 'route':
      return aiRouteLabel(draft);
    case 'date':
      return _date(
        l,
        draft[kind == AiFormKind.trip ? 'departureDate' : 'desiredDate'],
      );
    case 'time':
      return _text(draft['departureTime']);
    case 'transport':
      return transportModeFromWire(_text(draft['transportMode']))?.label(l);
    case 'capacity':
      return _weight(l, draft['availableKg']);
    case 'weight':
      return _weight(l, draft['weightKg']);
    case 'price':
      return _price(l, draft, fallbackCurrency);
    case 'grid':
      return l.aiFormDraftChipGrid;
    case 'direct':
      return l.aiFormDraftChipDirect;
    case 'flexibility':
      final days = draft['dateToleranceDays'];
      return days is int ? l.aiFormDraftChipTolerance(days) : null;
    case 'content':
      return _categories(l, draft);
    case 'budget':
      return _budget(draft, fallbackCurrency);
    case 'payment':
      return aiPaymentLabel(l, kind, draft);
  }
  return null;
}

/// Puces « ? » des champs requis manquants (une par information).
List<String> aiMissingChipLabels(AppLocalizations l, List<String> missing) {
  final labels = <String>[];
  void add(String label) {
    if (!labels.contains(label)) labels.add(label);
  }

  for (final field in missing) {
    switch (field) {
      case 'departureCity' || 'arrivalCity':
        add(l.aiFormDraftMissingRoute);
      case 'departureDate' || 'desiredDate':
        add(l.aiFormDraftMissingDate);
      case 'departureTime':
        add(l.aiFormDraftMissingTime);
      case 'transportMode':
        add(l.aiFormDraftMissingTransport);
      case 'availableKg':
        add(l.aiFormDraftMissingCapacity);
      case 'price' || 'pricePerKg':
        add(l.aiFormDraftMissingPrice);
      case 'paymentMethod' || 'acceptedPaymentMethods':
        add(l.aiFormDraftMissingPayment);
      case 'weightKg':
        add(l.aiFormDraftMissingWeight);
      case 'categories':
        add(l.aiFormDraftMissingContent);
      case 'budget' || 'totalBudget':
        add(l.aiFormDraftMissingBudget);
    }
  }
  return labels;
}

String aiWarningText(
  AppLocalizations l,
  AiDraftWarning warning,
) => switch (warning) {
  AiDraftWarning.departureCityUnknown => l.aiFormDraftWarningDepartureUnknown,
  AiDraftWarning.arrivalCityUnknown => l.aiFormDraftWarningArrivalUnknown,
  AiDraftWarning.noPriceGrid => l.aiFormDraftWarningNoGrid,
  AiDraftWarning.cardNotConfigured => l.aiFormDraftWarningCardNotConfigured,
  AiDraftWarning.cardUnavailableInCurrency => l.aiFormDraftWarningCardCurrency,
  AiDraftWarning.mobileMoneyUnavailable => l.aiFormDraftWarningMobileMoney,
  AiDraftWarning.planeOnly => l.aiFormDraftWarningPlaneOnly,
  AiDraftWarning.budgetOutOfRange => l.aiFormDraftWarningBudget,
};

/// Lignes (libellé, valeur) du résumé « C'est tout bon ».
///
/// [fallbackCurrency] : devise du formulaire, quand l'IA n'en a pas dit
/// (sinon un prix en francs CFA s'afficherait en euros).
List<(String, String)> aiSummaryLines(
  AppLocalizations l,
  AiFormKind kind,
  Map<String, Object?> draft, {
  String? fallbackCurrency,
}) {
  final lines = <(String, String)>[];
  void add(String label, String? value) {
    if (value != null && value.isNotEmpty) lines.add((label, value));
  }

  switch (kind) {
    case AiFormKind.trip:
      add(
        l.aiFormDraftSummaryDeparture,
        _join([
          _date(l, draft['departureDate'], long: true),
          _text(draft['departureTime']),
          transportModeFromWire(_text(draft['transportMode']))?.label(l),
          if (draft['direct'] == true) l.aiFormDraftChipDirect,
        ]),
      );
      add(l.aiFormDraftSummaryCapacity, _weight(l, draft['availableKg']));
      add(l.aiFormDraftSummaryPrice, _price(l, draft, fallbackCurrency));
      if (draft['pricingMode'] == 'MIXED') {
        add(l.aiFormDraftSummaryGrid, l.aiFormDraftSummaryGridValue);
      }
    case AiFormKind.packageRequest:
      final date = _date(l, draft['desiredDate'], long: true);
      final days = draft['dateToleranceDays'];
      add(
        l.aiFormDraftSummaryDesiredDate,
        _join([
          if (date != null) l.aiFormDraftSummaryAround(date),
          if (days is int) l.aiFormDraftSummaryTolerance(days),
        ]),
      );
      add(
        l.aiFormDraftSummaryParcel,
        _join([_weight(l, draft['weightKg']), _parcelSize(l, draft)]),
      );
      add(l.aiFormDraftSummaryContent, _categories(l, draft));
      add(l.aiFormDraftSummaryBudget, _budget(draft, fallbackCurrency));
  }
  add(l.aiFormDraftSummaryPayment, aiPaymentLabel(l, kind, draft));
  return lines;
}

String? _join(List<String?> parts) {
  final kept = parts.nonNulls.where((p) => p.isNotEmpty).toList();
  return kept.isEmpty ? null : kept.join(' · ');
}

String? _text(Object? raw) =>
    raw is String && raw.trim().isNotEmpty ? raw.trim() : null;

List<String> _strings(Object? raw) => [
  if (raw is List)
    for (final item in raw)
      if (item is String) item,
];

String? _date(AppLocalizations l, Object? raw, {bool long = false}) {
  final date = parseIsoDate(raw);
  if (date == null) return null;
  final format = long
      ? DateFormat.MMMMEEEEd(l.localeName)
      : DateFormat.MMMd(l.localeName);
  return format.format(date);
}

String? _weight(AppLocalizations l, Object? raw) =>
    raw is num ? formatWeightKg(l, raw.toDouble()) : null;

SupportedCurrency _currency(Map<String, Object?> draft, String? fallback) =>
    SupportedCurrency.fromCode(_text(draft['currency'])) ??
    SupportedCurrency.fromCode(fallback) ??
    SupportedCurrency.eur;

String? _price(
  AppLocalizations l,
  Map<String, Object?> draft,
  String? fallback,
) {
  final price = draft['pricePerKg'];
  if (price is! num || price <= 0) return null;
  return l.tripPosterPricePerKg(
    CurrencyFormatter.format(price, _currency(draft, fallback), compact: true),
  );
}

String? _budget(Map<String, Object?> draft, String? fallback) {
  final budget = draft['totalBudget'];
  if (budget is! num) return null;
  return CurrencyFormatter.format(
    budget,
    _currency(draft, fallback),
    compact: true,
  );
}

String? _categories(AppLocalizations l, Map<String, Object?> draft) {
  final labels = [
    for (final c in _strings(draft['categories']))
      contentCategoryDisplayName(l, c),
  ];
  return labels.isEmpty ? null : joinList(l, labels);
}

String? _parcelSize(AppLocalizations l, Map<String, Object?> draft) {
  final wire = _text(draft['parcelSize']);
  for (final size in ParcelSize.values) {
    if (size.wireName == wire) return size.label(l);
  }
  return null;
}
