import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/ai_form_draft/data/ai_form_draft_models.dart';
import 'package:dony/features/matching/data/models/trip_form_draft.dart';
import 'package:dony/features/matching/data/models/trip_stops.dart';

/// Brouillon trajet résolu → [TripFormDraft], appliqué par le chemin existant
/// de reprise de brouillon (`_restoreDraft` de `create_trip_screen.dart`).
///
/// Posé sur la saisie courante ([base]) : une clé nulle ne remplace rien, et
/// « Reparler » complète au lieu d'effacer. L'IA ne remplit jamais les
/// adresses, la date limite de remise ni les étapes (spec §1).
abstract final class TripAiDraftMapper {
  static TripFormDraft toFormDraft(
    Map<String, Object?> ai, {
    required TripFormDraft base,
    DateTime? now,
  }) {
    final today = _dateOnly(now ?? DateTime.now());
    final currency =
        SupportedCurrency.fromCode(_text(ai['currency'])) ??
        SupportedCurrency.fromCode(base.currency) ??
        SupportedCurrency.eur;
    final presets = KgPriceReference.forCurrency(currency).presets;
    final currencyChanged = currency.code != base.currency;

    var priceOption = currencyChanged ? -1 : base.priceOption;
    var customPrice = base.customPrice;
    var customPriceText = base.customPriceText;
    final price = _number(ai['pricePerKg']);
    if (price != null && price > 0) {
      final index = presets.indexOf(price);
      if (index != -1) {
        priceOption = index;
      } else {
        priceOption = presets.length;
        customPrice = price;
        customPriceText = formatKgPrice(price);
      }
    }
    final pricingMode = _text(ai['pricingMode']) ?? base.pricingMode;

    final aiDate = parseIsoDate(ai['departureDate']);
    final date = aiDate != null && !aiDate.isBefore(today)
        ? aiDate
        : base.departureDate;
    final dateChanged = date != base.departureDate;

    final capacityUnit = _text(ai['capacityUnit']) ?? base.capacityUnit;
    var kg = _number(ai['availableKg']) ?? base.availableKg;
    if (kg != null && capacityUnit == 'KG_EXACT') kg = kg.roundToDouble();

    final departureCity = _text(ai['departureCity']);
    final arrivalCity = _text(ai['arrivalCity']);

    return TripFormDraft(
      currency: currency.code,
      departureCity: departureCity ?? base.departureCity,
      departureCountryCode: departureCity != null
          ? _text(ai['departureCountryCode'])
          : base.departureCountryCode,
      arrivalCity: arrivalCity ?? base.arrivalCity,
      arrivalCountryCode: arrivalCity != null
          ? _text(ai['arrivalCountryCode'])
          : base.arrivalCountryCode,
      departureDate: date,
      departureTime: _hhmm(ai['departureTime']) ?? base.departureTime,
      arrivalTime: base.arrivalTime,
      arrivalDayOffset: base.arrivalDayOffset,
      handoverDeadline: dateChanged ? null : base.handoverDeadline,
      handoverLeadDays: dateChanged ? null : base.handoverLeadDays,
      transportMode: _text(ai['transportMode']) ?? base.transportMode,
      stops: ai['direct'] == true ? TripStops.direct : base.stops,
      pickupAddress: base.pickupAddress,
      deliveryAddress: base.deliveryAddress,
      availableKg: kg,
      capacityUnit: capacityUnit,
      pricingMode: pricingMode,
      kgPriceEnabled: pricingMode != 'MIXED' || priceOption >= 0,
      priceOption: priceOption,
      customPrice: customPrice,
      customPriceText: customPriceText,
      acceptedContent: base.acceptedContent,
      customAccepted: base.customAccepted,
      refusedTypes: base.refusedTypes,
      description: _text(ai['description']) ?? base.description,
      cashEnabled: _bool(ai['cashEnabled']) ?? base.cashEnabled,
      cardEnabled: _bool(ai['cardEnabled']) ?? base.cardEnabled,
      mobileMoneyEnabled:
          _bool(ai['mobileMoneyEnabled']) ?? base.mobileMoneyEnabled,
      negotiable: _bool(ai['negotiable']) ?? base.negotiable,
      legs: dateChanged ? const [] : base.legs,
    );
  }

  static String? _text(Object? raw) =>
      raw is String && raw.trim().isNotEmpty ? raw.trim() : null;

  static double? _number(Object? raw) => raw is num ? raw.toDouble() : null;

  static bool? _bool(Object? raw) => raw is bool ? raw : null;

  static String? _hhmm(Object? raw) =>
      raw is String && RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(raw)
      ? raw
      : null;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
