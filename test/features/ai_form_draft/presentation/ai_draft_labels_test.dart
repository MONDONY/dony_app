import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/features/ai_form_draft/data/ai_form_draft_models.dart';
import 'package:dony/features/ai_form_draft/presentation/ai_draft_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  late AppLocalizations fr;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    fr = lookupAppLocalizations(AppL10n.fr);
  });

  const trip = {
    'departureCity': 'Paris',
    'arrivalCity': 'Abidjan',
    'departureDate': '2026-11-15',
    'departureTime': '15:00',
    'transportMode': 'PLANE',
    'direct': true,
    'availableKg': 23,
    'pricingMode': 'MIXED',
    'pricePerKg': 10,
    'currency': 'EUR',
    'cardEnabled': true,
    'cashEnabled': true,
    'mobileMoneyEnabled': false,
  };

  const parcel = {
    'departureCity': 'Lyon',
    'arrivalCity': 'Dakar',
    'desiredDate': '2026-11-20',
    'dateToleranceDays': 3,
    'weightKg': 5,
    'parcelSize': 'MEDIUM',
    'categories': ['Vêtements & tissus', 'jouets en bois'],
    'acceptedPaymentMethods': ['STRIPE'],
    'totalBudget': 60,
    'currency': 'EUR',
  };

  test('trajet et moyens de paiement', () {
    expect(aiRouteLabel(trip), 'Paris → Abidjan');
    expect(aiRouteLabel(const {'arrivalCity': 'Dakar'}), 'Dakar');
    expect(aiRouteLabel(const {}), isNull);
    expect(aiPaymentLabel(fr, AiFormKind.trip, trip), 'Carte et Espèces');
    expect(aiPaymentLabel(fr, AiFormKind.packageRequest, parcel), 'Carte');
    expect(aiPaymentLabel(fr, AiFormKind.trip, const {}), isNull);
  });

  test('puces « Déjà compris » du trajet', () {
    String? chip(String key) =>
        aiUnderstoodChipLabel(fr, AiFormKind.trip, key, trip);
    expect(chip('route'), 'Paris → Abidjan');
    expect(chip('date'), '15 nov.');
    expect(chip('time'), '15:00');
    expect(chip('transport'), fr.tripTransportPlane);
    expect(chip('capacity'), '23 kg');
    expect(
      chip('price'),
      fr.tripPosterPricePerKg(
        CurrencyFormatter.format(10, SupportedCurrency.eur, compact: true),
      ),
    );
    expect(chip('grid'), fr.aiFormDraftChipGrid);
    expect(chip('direct'), fr.aiFormDraftChipDirect);
    expect(chip('payment'), 'Carte et Espèces');
    expect(chip('inconnu'), isNull);
  });

  test('puces « Déjà compris » de la demande d’envoi', () {
    String? chip(String key) =>
        aiUnderstoodChipLabel(fr, AiFormKind.packageRequest, key, parcel);
    expect(chip('date'), '20 nov.');
    expect(chip('flexibility'), fr.aiFormDraftChipTolerance(3));
    expect(chip('weight'), '5 kg');
    expect(chip('content'), startsWith(fr.contentCategoryClothing));
    expect(chip('content'), endsWith('jouets en bois'));
    expect(
      chip('budget'),
      CurrencyFormatter.format(60, SupportedCurrency.eur, compact: true),
    );
  });

  test('puces manquantes : une par information, sans doublon', () {
    expect(
      aiMissingChipLabels(fr, const [
        'departureCity',
        'arrivalCity',
        'departureDate',
        'departureTime',
        'transportMode',
        'availableKg',
        'price',
        'paymentMethod',
        'weightKg',
        'categories',
        'champInconnu',
      ]),
      [
        fr.aiFormDraftMissingRoute,
        fr.aiFormDraftMissingDate,
        fr.aiFormDraftMissingTime,
        fr.aiFormDraftMissingTransport,
        fr.aiFormDraftMissingCapacity,
        fr.aiFormDraftMissingPrice,
        fr.aiFormDraftMissingPayment,
        fr.aiFormDraftMissingWeight,
        fr.aiFormDraftMissingContent,
      ],
    );
  });

  test('chaque avertissement a son texte', () {
    for (final warning in AiDraftWarning.values) {
      expect(aiWarningText(fr, warning), isNotEmpty, reason: warning.name);
    }
    expect(
      aiWarningText(fr, AiDraftWarning.noPriceGrid),
      fr.aiFormDraftWarningNoGrid,
    );
  });

  test('lignes du résumé trajet', () {
    final lines = aiSummaryLines(fr, AiFormKind.trip, trip);
    expect(lines.map((l) => l.$1), [
      fr.aiFormDraftSummaryDeparture,
      fr.aiFormDraftSummaryCapacity,
      fr.aiFormDraftSummaryPrice,
      fr.aiFormDraftSummaryGrid,
      fr.aiFormDraftSummaryPayment,
    ]);
    expect(lines.first.$2, contains('15:00'));
    expect(lines.first.$2, contains(fr.aiFormDraftChipDirect));
    expect(lines[3].$2, fr.aiFormDraftSummaryGridValue);
  });

  test('lignes du résumé demande d’envoi', () {
    final lines = aiSummaryLines(fr, AiFormKind.packageRequest, parcel);
    expect(lines.map((l) => l.$1), [
      fr.aiFormDraftSummaryDesiredDate,
      fr.aiFormDraftSummaryParcel,
      fr.aiFormDraftSummaryContent,
      fr.aiFormDraftSummaryBudget,
      fr.aiFormDraftSummaryPayment,
    ]);
    expect(lines.first.$2, contains(fr.aiFormDraftSummaryTolerance(3)));
    expect(lines[1].$2, '5 kg · ${fr.parcelSizeMedium}');
  });

  test('résumé sans données : aucune ligne', () {
    expect(aiSummaryLines(fr, AiFormKind.trip, const {}), isEmpty);
    expect(aiSummaryLines(fr, AiFormKind.packageRequest, const {}), isEmpty);
  });
}
