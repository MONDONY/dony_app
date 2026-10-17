import 'package:dony/features/ai_form_draft/data/trip_ai_draft_mapper.dart';
import 'package:dony/features/matching/data/models/trip_form_draft.dart';
import 'package:dony/features/matching/data/models/trip_stops.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 17, 9);

  TripFormDraft map(
    Map<String, Object?> ai, {
    TripFormDraft base = const TripFormDraft(currency: 'EUR'),
  }) => TripAiDraftMapper.toFormDraft(ai, base: base, now: now);

  test('chaque champ du schéma trajet', () {
    final d = map(const {
      'departureCity': 'Paris',
      'departureCountryCode': 'FR',
      'arrivalCity': 'Abidjan',
      'arrivalCountryCode': 'CI',
      'departureDate': '2026-11-15',
      'departureTime': '15:00',
      'transportMode': 'PLANE',
      'direct': true,
      'availableKg': 23,
      'capacityUnit': 'SUITCASE_23KG',
      'pricingMode': 'MIXED',
      'pricePerKg': 10,
      'currency': 'EUR',
      'cardEnabled': true,
      'cashEnabled': true,
      'mobileMoneyEnabled': false,
      'negotiable': true,
      'description': 'Pas de liquides',
    });
    expect(d.step, 0);
    expect(d.departureCity, 'Paris');
    expect(d.departureCountryCode, 'FR');
    expect(d.arrivalCity, 'Abidjan');
    expect(d.arrivalCountryCode, 'CI');
    expect(d.departureDate, DateTime(2026, 11, 15));
    expect(d.departureTime, '15:00');
    expect(d.transportMode, 'PLANE');
    expect(d.stops, TripStops.direct);
    expect(d.availableKg, 23);
    expect(d.capacityUnit, 'SUITCASE_23KG');
    expect(d.pricingMode, 'MIXED');
    expect(d.kgPriceEnabled, isTrue);
    // Puces EUR : 7, 8, 9, 10 → 10 € est la quatrième.
    expect(d.priceOption, 3);
    expect(d.currency, 'EUR');
    expect(d.cardEnabled, isTrue);
    expect(d.cashEnabled, isTrue);
    expect(d.mobileMoneyEnabled, isFalse);
    expect(d.negotiable, isTrue);
    expect(d.description, 'Pas de liquides');
  });

  test('prix hors puces : Autre prix avec le champ rempli', () {
    final d = map(const {'pricePerKg': 12});
    expect(d.priceOption, 4);
    expect(d.customPrice, 12);
    expect(d.customPriceText, '12');
    expect(d.kgPriceEnabled, isTrue);
  });

  test('puce trouvée dans la devise dite (franc CFA)', () {
    final d = map(const {'pricePerKg': 2000, 'currency': 'XOF'});
    // Puces CFA : 1000, 1500, 2000, 3000.
    expect(d.priceOption, 2);
    expect(d.currency, 'XOF');
  });

  test('grille sans prix au kilo : tarif au kilo désactivé', () {
    final d = map(const {'pricingMode': 'MIXED'});
    expect(d.kgPriceEnabled, isFalse);
    expect(d.priceOption, -1);
  });

  test('devise changée sans prix : la puce de l’autre devise est oubliée', () {
    final d = map(const {
      'currency': 'XOF',
    }, base: const TripFormDraft(currency: 'EUR', priceOption: 2));
    expect(d.priceOption, -1);
  });

  test('valeurs nulles : la saisie courante est gardée', () {
    const base = TripFormDraft(
      step: 2,
      currency: 'EUR',
      departureCity: 'Lyon',
      departureCountryCode: 'FR',
      description: 'déjà saisi',
      cashEnabled: true,
      cardEnabled: false,
      stops: TripStops.one,
      priceOption: 1,
    );
    final d = map(const {
      'departureCity': null,
      'description': null,
      'cashEnabled': null,
      'direct': false,
    }, base: base);
    expect(d.step, 0);
    expect(d.departureCity, 'Lyon');
    expect(d.departureCountryCode, 'FR');
    expect(d.description, 'déjà saisi');
    expect(d.cashEnabled, isTrue);
    expect(d.cardEnabled, isFalse);
    expect(d.stops, TripStops.one);
    expect(d.priceOption, 1);
  });

  test('date passée ignorée ; date changée : date limite retirée', () {
    final base = TripFormDraft(
      currency: 'EUR',
      departureDate: DateTime(2026, 11, 20),
      handoverDeadline: DateTime(2026, 11, 19, 18),
    );
    final past = map(const {'departureDate': '2026-10-01'}, base: base);
    expect(past.departureDate, DateTime(2026, 11, 20));
    expect(past.handoverDeadline, DateTime(2026, 11, 19, 18));

    final changed = map(const {'departureDate': '2026-11-15'}, base: base);
    expect(changed.departureDate, DateTime(2026, 11, 15));
    expect(changed.handoverDeadline, isNull);

    final same = map(const {'departureDate': '2026-11-20'}, base: base);
    expect(same.handoverDeadline, DateTime(2026, 11, 19, 18));
  });

  test('kilos libres : arrondis à l’entier', () {
    final d = map(const {'availableKg': 15.6, 'capacityUnit': 'KG_EXACT'});
    expect(d.availableKg, 16);
  });

  test('heure illisible ignorée', () {
    final d = map(const {'departureTime': '15h'});
    expect(d.departureTime, isNull);
  });
}
