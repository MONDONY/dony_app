import 'package:dony/features/ai_form_draft/data/ai_city_resolver.dart';
import 'package:dony/features/ai_form_draft/data/ai_form_draft_models.dart';
import 'package:dony/features/ai_form_draft/data/package_request_ai_draft_resolver.dart';
import 'package:dony/features/city/data/city_model.dart';
import 'package:dony/features/city/data/city_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCityRepository extends Mock implements CityRepository {}

const _lyon = CityModel(
  name: 'Lyon',
  countryCode: 'FR',
  countryName: 'France',
  lat: 45.76,
  lng: 4.83,
);

void main() {
  late _MockCityRepository cities;

  setUp(() {
    cities = _MockCityRepository();
    when(() => cities.searchCities(any())).thenAnswer(
      (inv) async =>
          inv.positionalArguments.first == 'lyon' ? const [_lyon] : const [],
    );
  });

  PackageRequestAiDraftResolver resolver({String? fallbackCurrency = 'EUR'}) =>
      PackageRequestAiDraftResolver(
        cities: AiCityResolver(cities),
        fallbackCurrency: fallbackCurrency,
      );

  test('villes résolues ou vidées', () async {
    final resolved = await resolver().resolve(const {
      'departureCity': 'lyon',
      'arrivalCity': 'Atlantis',
    });
    expect(resolved.draft['departureCity'], 'Lyon');
    expect(resolved.draft['arrivalCity'], isNull);
    expect(resolved.warnings, [AiDraftWarning.arrivalCityUnknown]);
  });

  test('moyens de paiement filtrés par la devise', () async {
    final euro = await resolver().resolve(const {
      'acceptedPaymentMethods': ['STRIPE', 'CASH', 'MOBILE_MONEY'],
    });
    expect(euro.draft['acceptedPaymentMethods'], ['STRIPE', 'CASH']);
    expect(euro.warnings, [AiDraftWarning.mobileMoneyUnavailable]);

    final cfa = await resolver().resolve(const {
      'acceptedPaymentMethods': ['STRIPE', 'MOBILE_MONEY'],
      'currency': 'XOF',
    });
    expect(cfa.draft['acceptedPaymentMethods'], ['MOBILE_MONEY']);
    expect(cfa.warnings, [AiDraftWarning.cardUnavailableInCurrency]);
  });

  test(
    'aucun moyen possible : champ vidé (le formulaire garde le sien)',
    () async {
      final resolved = await resolver().resolve(const {
        'acceptedPaymentMethods': ['MOBILE_MONEY'],
      });
      expect(resolved.draft['acceptedPaymentMethods'], isNull);
    },
  );

  test('budget hors bornes de l’app : retiré, avec avertissement', () async {
    final resolved = await resolver().resolve(const {'totalBudget': 600});
    expect(resolved.draft['totalBudget'], isNull);
    expect(resolved.warnings, [AiDraftWarning.budgetOutOfRange]);
  });

  test('budget valide dans sa devise : gardé', () async {
    final euro = await resolver().resolve(const {'totalBudget': 60});
    expect(euro.draft['totalBudget'], 60);
    final cfa = await resolver().resolve(const {
      'totalBudget': 30000,
      'currency': 'XOF',
    });
    expect(cfa.draft['totalBudget'], 30000);
    expect(cfa.warnings, isEmpty);
  });
}
