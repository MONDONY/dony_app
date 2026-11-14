import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/announcement_form_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_form_event.dart';
import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/boat_price_unit.dart';
import 'package:dony/features/matching/data/models/grid_preview_item.dart';
import 'package:dony/features/matching/data/models/item_size.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/trip_domain_labels.dart';
import 'package:dony/features/price_grid/data/models/price_grid_item_model.dart';
import 'package:dony/features/price_grid/data/repositories/price_grid_repository.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/mock_analytics_backend.dart';

class MockPriceGridRepository extends Mock implements PriceGridRepository {}

/// Fabrique commune : le bloc exige désormais un [AnalyticsService].
/// Par défaut un service sans consentement, qui n'émet rien.
AnnouncementFormBloc _makeBloc({
  PriceGridRepository? priceGridRepository,
  AnalyticsService? analytics,
}) => AnnouncementFormBloc(
  priceGridRepository: priceGridRepository,
  analytics: analytics ?? makeDisabledAnalytics(MockAnalyticsBackend()),
);

void main() {
  group('AnnouncementFormBloc', () {
    late AnnouncementFormBloc bloc;

    setUp(() {
      bloc = _makeBloc();
    });

    tearDown(() => bloc.close());

    test(
      'état initial: formulaire invalide, prix null, capacité SUITCASE_23KG',
      () {
        expect(bloc.state.isFormValid, isFalse);
        expect(bloc.state.capacityUnit, CapacityUnit.suitcase23kg);
        expect(bloc.state.pricePerKg, isNull);
        expect(bloc.state.priceWarning, isNull);
      },
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'PriceChanged avec 3.0 → warning prix trop bas',
      build: () => _makeBloc(),
      act: (b) => b.add(const PriceChanged(3.0)),
      expect: () => [
        predicate<AnnouncementFormState>(
          (s) => s.pricePerKg == 3.0 && s.priceWarning == PriceWarning.tooLow,
          'state has pricePerKg=3.0 and warning=tooLow',
        ),
      ],
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'PriceChanged avec 20.0 → warning prix trop élevé',
      build: () => _makeBloc(),
      act: (b) => b.add(const PriceChanged(20.0)),
      expect: () => [
        predicate<AnnouncementFormState>(
          (s) => s.pricePerKg == 20.0 && s.priceWarning == PriceWarning.tooHigh,
          'state has pricePerKg=20.0 and warning=tooHigh',
        ),
      ],
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'PriceChanged avec 10.0 → pas de warning',
      build: () => _makeBloc(),
      act: (b) => b.add(const PriceChanged(10.0)),
      expect: () => [
        predicate<AnnouncementFormState>(
          (s) => s.pricePerKg == 10.0 && s.priceWarning == null,
          'state has pricePerKg=10.0 and no warning',
        ),
      ],
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'PriceChanged avec 5.0 (limite basse) → pas de warning',
      build: () => _makeBloc(),
      act: (b) => b.add(const PriceChanged(5.0)),
      expect: () => [
        predicate<AnnouncementFormState>(
          (s) => s.pricePerKg == 5.0 && s.priceWarning == null,
          'state has pricePerKg=5.0 and no warning',
        ),
      ],
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'PriceChanged avec 15.0 (limite haute) → pas de warning',
      build: () => _makeBloc(),
      act: (b) => b.add(const PriceChanged(15.0)),
      expect: () => [
        predicate<AnnouncementFormState>(
          (s) => s.pricePerKg == 15.0 && s.priceWarning == null,
          'state has pricePerKg=15.0 and no warning',
        ),
      ],
    );

    // La fourchette suit la devise de l'annonce : figée à 5–15, elle
    // signalait « prix élevé » tout tarif en franc CFA.
    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'PriceChanged 2000 XOF → pas de warning (élevé en euro)',
      build: () => _makeBloc(),
      act: (b) =>
          b.add(const PriceChanged(2000, currency: SupportedCurrency.xof)),
      expect: () => [
        predicate<AnnouncementFormState>(
          (s) => s.pricePerKg == 2000 && s.priceWarning == null,
          'state has pricePerKg=2000 and no warning',
        ),
      ],
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'PriceChanged 500 XOF → warning prix trop bas',
      build: () => _makeBloc(),
      act: (b) =>
          b.add(const PriceChanged(500, currency: SupportedCurrency.xof)),
      expect: () => [
        predicate<AnnouncementFormState>(
          (s) => s.priceWarning == PriceWarning.tooLow,
          'warning=tooLow',
        ),
      ],
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'PriceChanged 6000 XOF → warning prix trop élevé',
      build: () => _makeBloc(),
      act: (b) =>
          b.add(const PriceChanged(6000, currency: SupportedCurrency.xof)),
      expect: () => [
        predicate<AnnouncementFormState>(
          (s) => s.priceWarning == PriceWarning.tooHigh,
          'warning=tooHigh',
        ),
      ],
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'DepartureCityChanged met à jour departureCity',
      build: () => _makeBloc(),
      act: (b) => b.add(const DepartureCityChanged('Paris')),
      expect: () => [
        predicate<AnnouncementFormState>(
          (s) => s.departureCity == 'Paris',
          'departureCity is Paris',
        ),
      ],
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'ArrivalCityChanged met à jour arrivalCity',
      build: () => _makeBloc(),
      act: (b) => b.add(const ArrivalCityChanged('Dakar')),
      expect: () => [
        predicate<AnnouncementFormState>(
          (s) => s.arrivalCity == 'Dakar',
          'arrivalCity is Dakar',
        ),
      ],
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'DepartureCityChanged(countryCode: US) stocke departureCountryCode',
      build: () => _makeBloc(),
      act: (b) =>
          b.add(const DepartureCityChanged('New York', countryCode: 'US')),
      expect: () => [
        predicate<AnnouncementFormState>(
          (s) =>
              s.departureCity == 'New York' && s.departureCountryCode == 'US',
          'departureCity=New York, departureCountryCode=US',
        ),
      ],
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'ArrivalCityChanged(countryCode: JP) stocke arrivalCountryCode',
      build: () => _makeBloc(),
      act: (b) => b.add(const ArrivalCityChanged('Tokyo', countryCode: 'JP')),
      expect: () => [
        predicate<AnnouncementFormState>(
          (s) => s.arrivalCity == 'Tokyo' && s.arrivalCountryCode == 'JP',
          'arrivalCity=Tokyo, arrivalCountryCode=JP',
        ),
      ],
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'FLUTTER-EH — une ville sans code efface le code de la ville précédente',
      build: () => _makeBloc(),
      act: (b) {
        b.add(const DepartureCityChanged('Cotonou', countryCode: 'BJ'));
        b.add(const ArrivalCityChanged('Abidjan', countryCode: 'CI'));
        b.add(const DepartureCityChanged('Atlantide'));
        b.add(const ArrivalCityChanged('Lomé', countryCode: 'TG'));
      },
      skip: 2,
      expect: () => [
        predicate<AnnouncementFormState>(
          (s) =>
              s.departureCity == 'Atlantide' &&
              s.departureCountryCode == null &&
              s.arrivalCountryCode == 'CI',
          'departureCountryCode cleared, arrival kept',
        ),
        predicate<AnnouncementFormState>(
          (s) => s.arrivalCity == 'Lomé' && s.arrivalCountryCode == 'TG',
          'arrivalCountryCode follows the new city',
        ),
      ],
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'DepartureCityChanged sans countryCode laisse departureCountryCode null',
      build: () => _makeBloc(),
      act: (b) => b.add(const DepartureCityChanged('Paris')),
      expect: () => [
        predicate<AnnouncementFormState>(
          (s) => s.departureCity == 'Paris' && s.departureCountryCode == null,
          'departureCountryCode stays null',
        ),
      ],
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'CapacityUnitChanged met à jour capacityUnit',
      build: () => _makeBloc(),
      act: (b) => b.add(const CapacityUnitChanged(CapacityUnit.suitcase32kg)),
      expect: () => [
        predicate<AnnouncementFormState>(
          (s) => s.capacityUnit == CapacityUnit.suitcase32kg,
          'capacityUnit is suitcase32kg',
        ),
      ],
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'CapacityUnitChanged → kgFree',
      build: () => _makeBloc(),
      act: (b) => b.add(const CapacityUnitChanged(CapacityUnit.kgFree)),
      expect: () => [
        predicate<AnnouncementFormState>(
          (s) => s.capacityUnit == CapacityUnit.kgFree,
          'capacityUnit is kgFree',
        ),
      ],
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'AvailableKgChanged met à jour availableKg',
      build: () => _makeBloc(),
      act: (b) => b.add(const AvailableKgChanged(15.0)),
      expect: () => [
        predicate<AnnouncementFormState>(
          (s) => s.availableKg == 15.0,
          'availableKg is 15.0',
        ),
      ],
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'DescriptionChanged met à jour description',
      build: () => _makeBloc(),
      act: (b) => b.add(const DescriptionChanged('Colis bien emballé')),
      expect: () => [
        predicate<AnnouncementFormState>(
          (s) => s.description == 'Colis bien emballé',
          'description is set',
        ),
      ],
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'FormResetRequested remet l\'état initial',
      build: () => _makeBloc(),
      act: (b) {
        b.add(const DepartureCityChanged('Paris'));
        b.add(const PriceChanged(10.0));
        b.add(const FormResetRequested());
      },
      verify: (b) {
        expect(b.state, const AnnouncementFormState());
      },
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'formulaire complet → isFormValid=true',
      build: () => _makeBloc(),
      act: (b) {
        b.add(const DepartureCityChanged('Paris'));
        b.add(const ArrivalCityChanged('Dakar'));
        b.add(
          DepartureDateChanged(DateTime.now().add(const Duration(days: 7))),
        );
        b.add(const PriceChanged(10.0));
        b.add(const AvailableKgChanged(23.0));
      },
      verify: (b) {
        expect(b.state.isFormValid, isTrue);
      },
    );

    test('formulaire incomplet sans ville → isFormValid=false', () {
      expect(bloc.state.isFormValid, isFalse);
    });

    test('CapacityUnit.toWire() retourne les bonnes chaînes', () {
      expect(CapacityUnit.suitcase23kg.toWire(), 'SUITCASE_23KG');
      expect(CapacityUnit.suitcase32kg.toWire(), 'SUITCASE_32KG');
      expect(CapacityUnit.kgFree.toWire(), 'KG_FREE');
      expect(CapacityUnit.custom.toWire(), 'KG_EXACT');
    });

    test('CapacityUnit.label retourne les bons libellés', () {
      final l = lookupAppLocalizations(AppL10n.fr);
      expect(CapacityUnit.suitcase23kg.label(l), '1 valise 23 kg');
      expect(CapacityUnit.suitcase32kg.label(l), '1 valise 32 kg');
      expect(CapacityUnit.kgFree.label(l), 'Kg libre');
      expect(CapacityUnit.custom.label(l), 'Personnalisé');
    });

    test('CapacityUnit.maxKg retourne les bons plafonds', () {
      expect(CapacityUnit.suitcase23kg.maxKg, 23.0);
      expect(CapacityUnit.suitcase32kg.maxKg, 32.0);
      expect(CapacityUnit.kgFree.maxKg, isNull);
      expect(CapacityUnit.custom.maxKg, isNull);
    });

    // ── CapacityUnit.custom (M2) ──────────────────────────────────────────────

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'sélectionner suitcase32kg fixe availableKg à 32',
      build: () => _makeBloc(),
      act: (b) => b.add(const CapacityUnitChanged(CapacityUnit.suitcase32kg)),
      expect: () => [
        isA<AnnouncementFormState>()
            .having((s) => s.capacityUnit, 'unit', CapacityUnit.suitcase32kg)
            .having((s) => s.availableKg, 'kg', 32.0),
      ],
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'sélectionner kgFree conserve un availableKg ≥ 1 (option b — défaut 1.0)',
      build: () => _makeBloc(),
      act: (b) => b.add(const CapacityUnitChanged(CapacityUnit.kgFree)),
      expect: () => [
        isA<AnnouncementFormState>()
            .having((s) => s.capacityUnit, 'unit', CapacityUnit.kgFree)
            .having((s) => s.availableKg, 'kg', 1.0),
      ],
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'kgFree préserve un availableKg déjà saisi (valeur ignorée par le backend, '
      'mais conservée pour ne pas perdre la saisie sur un retour en mode exact)',
      build: () => _makeBloc(),
      seed: () => const AnnouncementFormState(availableKg: 23),
      act: (b) => b.add(const CapacityUnitChanged(CapacityUnit.kgFree)),
      expect: () => [
        isA<AnnouncementFormState>()
            .having((s) => s.capacityUnit, 'unit', CapacityUnit.kgFree)
            .having((s) => s.availableKg, 'kg', 23.0),
      ],
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'kgFree + autres champs requis → isFormValid true SANS AvailableKgChanged',
      build: () => _makeBloc(),
      act: (b) {
        b.add(const DepartureCityChanged('Paris'));
        b.add(const ArrivalCityChanged('Dakar'));
        b.add(
          DepartureDateChanged(DateTime.now().add(const Duration(days: 7))),
        );
        b.add(const PriceChanged(10.0));
        // Sélectionner kgFree → doit fixer availableKg=1.0 automatiquement
        b.add(const CapacityUnitChanged(CapacityUnit.kgFree));
        // Pas de AvailableKgChanged ici — l'utilisateur ne saisit rien
      },
      verify: (b) {
        expect(
          b.state.availableKg,
          1.0,
          reason: 'kgFree must auto-set sentinel 1.0',
        );
        expect(
          b.state.isFormValid,
          isTrue,
          reason: 'form must be valid without manual kg input for kgFree',
        );
      },
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'sélectionner custom sur formulaire vierge → availableKg=1.0',
      build: () => _makeBloc(),
      act: (b) => b.add(const CapacityUnitChanged(CapacityUnit.custom)),
      expect: () => [
        isA<AnnouncementFormState>()
            .having((s) => s.capacityUnit, 'unit', CapacityUnit.custom)
            .having((s) => s.availableKg, 'kg', 1.0),
      ],
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'sélectionner custom puis régler le slider met availableKg',
      build: () => _makeBloc(),
      act: (b) => b
        ..add(const CapacityUnitChanged(CapacityUnit.custom))
        ..add(const AvailableKgChanged(15)),
      expect: () => [
        isA<AnnouncementFormState>()
            .having((s) => s.capacityUnit, 'unit', CapacityUnit.custom)
            .having((s) => s.availableKg, 'kg', 1.0),
        isA<AnnouncementFormState>().having((s) => s.availableKg, 'kg', 15.0),
      ],
    );

    test('custom.toWire vaut KG_EXACT', () {
      expect(CapacityUnit.custom.toWire(), 'KG_EXACT');
    });

    // ── Nouveaux événements ───────────────────────────────────────────────────

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'TransportModeChanged met à jour transportMode',
      build: () => _makeBloc(),
      act: (b) => b.add(const TransportModeChanged(TransportMode.plane)),
      expect: () => [
        predicate<AnnouncementFormState>(
          (s) => s.transportMode == TransportMode.plane,
          'transportMode is plane',
        ),
      ],
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'TransportModeChanged → null efface le mode',
      build: () => _makeBloc(),
      act: (b) {
        b.add(const TransportModeChanged(TransportMode.car));
        b.add(const TransportModeChanged(TransportMode.plane));
      },
      verify: (b) => expect(b.state.transportMode, TransportMode.plane),
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'PickupAddressChanged met à jour pickupAddress',
      build: () => _makeBloc(),
      act: (b) => b.add(
        const PickupAddressChanged(
          AddressData(label: '12 rue de la Paix, Paris', lat: 48.87, lng: 2.33),
        ),
      ),
      expect: () => [
        predicate<AnnouncementFormState>(
          (s) => s.pickupAddress?.label == '12 rue de la Paix, Paris',
          'pickupAddress is set',
        ),
      ],
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'PickupAddressChanged → null efface l\'adresse',
      build: () => _makeBloc(),
      seed: () => const AnnouncementFormState(
        pickupAddress: AddressData(label: 'Quelque part', lat: 0, lng: 0),
      ),
      act: (b) => b.add(const PickupAddressChanged(null)),
      expect: () => [
        predicate<AnnouncementFormState>(
          (s) => s.pickupAddress == null,
          'pickupAddress is null',
        ),
      ],
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'DeliveryAddressChanged met à jour deliveryAddress',
      build: () => _makeBloc(),
      act: (b) => b.add(
        const DeliveryAddressChanged(
          AddressData(label: 'Plateau, Abidjan', lat: 5.32, lng: -4.01),
        ),
      ),
      expect: () => [
        predicate<AnnouncementFormState>(
          (s) => s.deliveryAddress?.label == 'Plateau, Abidjan',
          'deliveryAddress is set',
        ),
      ],
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'CashAcceptedChanged met à jour cashAccepted',
      build: () => _makeBloc(),
      act: (b) => b.add(const CashAcceptedChanged(true)),
      expect: () => [
        predicate<AnnouncementFormState>(
          (s) => s.cashAccepted == true,
          'cashAccepted is true',
        ),
      ],
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'MobileMoneyAcceptedChanged met à jour mobileMoneyAccepted',
      build: () => _makeBloc(),
      act: (b) => b.add(const MobileMoneyAcceptedChanged(true)),
      expect: () => [
        predicate<AnnouncementFormState>(
          (s) => s.mobileMoneyAccepted == true,
          'mobileMoneyAccepted is true',
        ),
      ],
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'AcceptedTypesChanged met à jour acceptedTypes',
      build: () => _makeBloc(),
      act: (b) =>
          b.add(const AcceptedTypesChanged(['Vêtements', 'Médicaments'])),
      expect: () => [
        predicate<AnnouncementFormState>(
          (s) =>
              s.acceptedTypes.length == 2 &&
              s.acceptedTypes.contains('Vêtements'),
          'acceptedTypes has 2 items',
        ),
      ],
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'RejectedTypesChanged met à jour rejectedTypes',
      build: () => _makeBloc(),
      act: (b) => b.add(const RejectedTypesChanged(['Alcool'])),
      expect: () => [
        predicate<AnnouncementFormState>(
          (s) => s.rejectedTypes.contains('Alcool'),
          'rejectedTypes contains Alcool',
        ),
      ],
    );

    // ── Validation par étape ──────────────────────────────────────────────────

    test('isStep1Valid: faux sans données', () {
      expect(bloc.state.isStep1Valid, isFalse);
    });

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'isStep1Valid: vrai avec ville départ + arrivée + date',
      build: () => _makeBloc(),
      act: (b) {
        b.add(const DepartureCityChanged('Paris'));
        b.add(const ArrivalCityChanged('Dakar'));
        b.add(
          DepartureDateChanged(DateTime.now().add(const Duration(days: 3))),
        );
      },
      verify: (b) => expect(b.state.isStep1Valid, isTrue),
    );

    test('isStep2Valid: faux sans adresses', () {
      expect(bloc.state.isStep2Valid, isFalse);
    });

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'isStep2Valid: vrai avec pickup + delivery',
      build: () => _makeBloc(),
      act: (b) {
        b.add(
          const PickupAddressChanged(
            AddressData(label: 'CDG, Paris', lat: 49.0, lng: 2.55),
          ),
        );
        b.add(
          const DeliveryAddressChanged(
            AddressData(label: 'Almadies, Dakar', lat: 14.74, lng: -17.49),
          ),
        );
      },
      verify: (b) => expect(b.state.isStep2Valid, isTrue),
    );

    test('isStep3Valid: faux sans prix', () {
      expect(bloc.state.isStep3Valid, isFalse);
    });

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'isStep3Valid: vrai avec prix > 0',
      build: () => _makeBloc(),
      act: (b) => b.add(const PriceChanged(8.0)),
      verify: (b) => expect(b.state.isStep3Valid, isTrue),
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'isStep3Valid: faux avec prix = 0',
      build: () => _makeBloc(),
      act: (b) => b.add(const PriceChanged(0.0)),
      verify: (b) => expect(b.state.isStep3Valid, isFalse),
    );

    // ── PricingMode ───────────────────────────────────────────────────────────

    test('état initial: pricingMode = kg, gridPreviewItems vide', () {
      expect(bloc.state.pricingMode, PricingMode.kg);
      expect(bloc.state.gridPreviewItems, isEmpty);
    });

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'AnnouncementPricingModeSetRequested.kg → pricingMode = kg',
      build: () => _makeBloc(),
      act: (b) =>
          b.add(const AnnouncementPricingModeSetRequested(PricingMode.kg)),
      expect: () => [
        isA<AnnouncementFormState>().having(
          (s) => s.pricingMode,
          'mode',
          PricingMode.kg,
        ),
      ],
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'AnnouncementPricingModeSetRequested.mixed triggers preview load and emits gridPreviewItems',
      build: () {
        final mockRepo = MockPriceGridRepository();
        when(() => mockRepo.getItems()).thenAnswer(
          (_) async => const [
            PriceGridItemModel(
              id: 'id1',
              label: 'Valise',
              unitPriceNet: 10.0,
              unitPriceDisplay: 11.20,
              position: 0,
            ),
          ],
        );
        return _makeBloc(priceGridRepository: mockRepo);
      },
      act: (b) =>
          b.add(const AnnouncementPricingModeSetRequested(PricingMode.mixed)),
      expect: () => [
        isA<AnnouncementFormState>().having(
          (s) => s.pricingMode,
          'mode',
          PricingMode.mixed,
        ),
        isA<AnnouncementFormState>()
            .having((s) => s.pricingMode, 'mode', PricingMode.mixed)
            .having((s) => s.gridPreviewItems.length, 'items', 1),
      ],
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'AnnouncementGridPreviewLoadRequested silencieux si repository null',
      build: () => _makeBloc(),
      act: (b) => b.add(const AnnouncementGridPreviewLoadRequested()),
      expect: () => <AnnouncementFormState>[],
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'AnnouncementGridPreviewLoadRequested silencieux si repo throws',
      build: () {
        final mockRepo = MockPriceGridRepository();
        when(() => mockRepo.getItems()).thenThrow(Exception('network error'));
        return _makeBloc(priceGridRepository: mockRepo);
      },
      act: (b) => b.add(const AnnouncementGridPreviewLoadRequested()),
      expect: () => <AnnouncementFormState>[],
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'guard double dispatch: passer deux fois mixed ne charge la grille qu\'une seule fois',
      build: () {
        final mockRepo = MockPriceGridRepository();
        when(() => mockRepo.getItems()).thenAnswer(
          (_) async => const [
            PriceGridItemModel(
              id: 'id1',
              label: 'Valise',
              unitPriceNet: 10.0,
              unitPriceDisplay: 11.20,
              position: 0,
            ),
          ],
        );
        return _makeBloc(priceGridRepository: mockRepo);
      },
      act: (b) async {
        b.add(const AnnouncementPricingModeSetRequested(PricingMode.mixed));
        // petit délai pour laisser le premier chargement se terminer
        await Future<void>.delayed(const Duration(milliseconds: 50));
        // deuxième appel en mode mixed → ne doit PAS redéclencher getItems
        b.add(const AnnouncementPricingModeSetRequested(PricingMode.mixed));
      },
      verify: (b) {
        // gridPreviewItems toujours présents (chargés une seule fois)
        expect(b.state.gridPreviewItems.length, 1);
        expect(b.state.gridPreviewItems.first, isA<GridPreviewItem>());
      },
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'gridPreviewItems contient des GridPreviewItem (pas PriceGridItemModel)',
      build: () {
        final mockRepo = MockPriceGridRepository();
        when(() => mockRepo.getItems()).thenAnswer(
          (_) async => const [
            PriceGridItemModel(
              id: 'abc',
              label: 'Petit colis',
              unitPriceNet: 5.0,
              unitPriceDisplay: 5.60,
              position: 0,
            ),
          ],
        );
        return _makeBloc(priceGridRepository: mockRepo);
      },
      act: (b) =>
          b.add(const AnnouncementPricingModeSetRequested(PricingMode.mixed)),
      verify: (b) {
        final items = b.state.gridPreviewItems;
        expect(items.length, 1);
        expect(items.first, isA<GridPreviewItem>());
        expect(items.first.id, 'abc');
        expect(items.first.label, 'Petit colis');
        expect(items.first.unitPriceDisplay, 5.60);
      },
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'AnnouncementPricePerKgClearedRequested → pricePerKg == null',
      build: () => _makeBloc(),
      seed: () => const AnnouncementFormState(pricePerKg: 8.0),
      act: (b) => b.add(const AnnouncementPricePerKgClearedRequested()),
      expect: () => [
        predicate<AnnouncementFormState>(
          (s) => s.pricePerKg == null,
          'state has pricePerKg=null',
        ),
      ],
    );
  });

  group('AnnouncementFormEvent props / equality', () {
    test('base event props (no-override) returns []', () {
      expect(const FormResetRequested().props, isEmpty);
    });

    test('PickupAddressChanged props contains address', () {
      const address = AddressData(label: 'Paris', lat: 48.8566, lng: 2.3522);
      const e1 = PickupAddressChanged(address);
      const e2 = PickupAddressChanged(address);
      expect(e1.props, [address]);
      expect(e1, equals(e2));
    });

    test('PickupAddressChanged null props', () {
      expect(const PickupAddressChanged(null).props, [null]);
    });

    test('DeliveryAddressChanged props contains address', () {
      const address = AddressData(label: 'Lyon', lat: 45.7640, lng: 4.8357);
      const e1 = DeliveryAddressChanged(address);
      const e2 = DeliveryAddressChanged(address);
      expect(e1.props, [address]);
      expect(e1, equals(e2));
    });

    test('DeliveryAddressChanged null props', () {
      expect(const DeliveryAddressChanged(null).props, [null]);
    });
  });

  group('AnnouncementFormBloc — ouverture aux propositions de prix', () {
    late MockAnalyticsBackend backend;
    late AnalyticsService analytics;

    setUp(() {
      backend = MockAnalyticsBackend();
      analytics = makeEnabledAnalytics(backend)..onConfigured();
    });

    AnnouncementFormBloc buildBloc() => _makeBloc(analytics: analytics);

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'negotiable vaut false a l etat initial',
      build: buildBloc,
      verify: (bloc) => expect(bloc.state.negotiable, isFalse),
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'NegotiableChanged met a jour l etat et tire l event analytics',
      build: buildBloc,
      act: (bloc) => bloc.add(const NegotiableChanged(true)),
      expect: () => [predicate<AnnouncementFormState>((s) => s.negotiable)],
      verify: (_) {
        verify(
          () => backend.capture(AnalyticsEvents.tripNegotiableToggled, {
            'enabled': true,
          }),
        ).called(1);
      },
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'NegotiableChanged(false) remet l etat a false',
      build: buildBloc,
      act: (bloc) => bloc
        ..add(const NegotiableChanged(true))
        ..add(const NegotiableChanged(false)),
      expect: () => [
        predicate<AnnouncementFormState>((s) => s.negotiable),
        predicate<AnnouncementFormState>((s) => !s.negotiable),
      ],
    );

    test('NegotiableChanged expose sa valeur dans props', () {
      expect(const NegotiableChanged(true).props, [true]);
      expect(
        const NegotiableChanged(true),
        equals(const NegotiableChanged(true)),
      );
    });
  });

  group('AnnouncementFormBloc — route : valises, taille et poids max (T3)', () {
    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'avion 2 × 23 kg puis route : personnalisé 46 kg',
      build: () => _makeBloc(),
      act: (b) {
        b.add(const TransportModeChanged(TransportMode.plane));
        b.add(const CapacityUnitChanged(CapacityUnit.suitcase23kg));
        b.add(const AvailableKgChanged(46));
        b.add(const TransportModeChanged(TransportMode.car));
      },
      verify: (b) {
        expect(b.state.transportMode, TransportMode.car);
        expect(b.state.capacityUnit, CapacityUnit.custom);
        expect(b.state.availableKg, 46);
      },
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'route puis valise demandée (modèle, brouillon) : personnalisé gardé',
      build: () => _makeBloc(),
      act: (b) {
        b.add(const TransportModeChanged(TransportMode.car));
        b.add(const CapacityUnitChanged(CapacityUnit.suitcase32kg));
        b.add(const AvailableKgChanged(64));
      },
      verify: (b) {
        expect(b.state.capacityUnit, CapacityUnit.custom);
        expect(b.state.availableKg, 64);
      },
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'route L + 20 kg puis avion : taille et poids max effacés',
      build: () => _makeBloc(),
      act: (b) {
        b.add(const TransportModeChanged(TransportMode.car));
        b.add(const MaxItemSizeChanged(ItemSize.l));
        b.add(const MaxParcelWeightChanged(20));
        b.add(const TransportModeChanged(TransportMode.plane));
      },
      verify: (b) {
        expect(b.state.maxItemSize, isNull);
        expect(b.state.maxParcelWeightKg, isNull);
      },
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'route : taille et poids max posés puis désélectionnés',
      build: () => _makeBloc(),
      act: (b) {
        b.add(const TransportModeChanged(TransportMode.car));
        b.add(const MaxItemSizeChanged(ItemSize.xl));
        b.add(const MaxParcelWeightChanged(150));
        b.add(const MaxItemSizeChanged(null));
        b.add(const MaxParcelWeightChanged(null));
      },
      expect: () => [
        isA<AnnouncementFormState>(),
        predicate<AnnouncementFormState>((s) => s.maxItemSize == ItemSize.xl),
        predicate<AnnouncementFormState>((s) => s.maxParcelWeightKg == 150),
        predicate<AnnouncementFormState>((s) => s.maxItemSize == null),
        predicate<AnnouncementFormState>((s) => s.maxParcelWeightKg == null),
      ],
    );

    test('route : 2 500 kg valides, avion : 1 000 kg trop haut', () {
      const road = AnnouncementFormState(
        transportMode: TransportMode.car,
        capacityUnit: CapacityUnit.custom,
        availableKg: 2500,
      );
      expect(road.capacityMaxKg, 999999);
      expect(road.capacityTooHigh, isFalse);
      expect(road.isCapacityStepValid, isTrue);
      const plane = AnnouncementFormState(
        transportMode: TransportMode.plane,
        capacityUnit: CapacityUnit.custom,
        availableKg: 1000,
      );
      expect(plane.capacityMaxKg, 999);
      expect(plane.capacityTooHigh, isTrue);
      expect(plane.isCapacityStepValid, isFalse);
      const planeMax = AnnouncementFormState(
        transportMode: TransportMode.plane,
        capacityUnit: CapacityUnit.custom,
        availableKg: 999,
      );
      expect(planeMax.capacityTooHigh, isFalse);
    });

    test('kilo libre : jamais trop haut (capacité technique)', () {
      const free = AnnouncementFormState(
        transportMode: TransportMode.plane,
        capacityUnit: CapacityUnit.kgFree,
        availableKg: 5000,
      );
      expect(free.capacityTooHigh, isFalse);
    });

    test('poids max par colis en modification : jamais comparé aux kilos '
        'restants, seulement au maximum technique', () {
      AnnouncementFormState s(double w, {bool editing = true}) =>
          AnnouncementFormState(
            transportMode: TransportMode.car,
            capacityUnit: CapacityUnit.custom,
            availableKg: 100,
            maxParcelWeightKg: w,
            isEditingTrip: editing,
          );
      expect(s(200).isMaxParcelWeightValid, isTrue);
      expect(s(200).isCapacityStepValid, isTrue);
      expect(s(0.4).isMaxParcelWeightValid, isFalse);
      expect(s(1000000).isMaxParcelWeightValid, isFalse);
      // En création, comportement inchangé.
      expect(s(200, editing: false).isMaxParcelWeightValid, isFalse);
    });

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'EditingTripStarted pose isEditingTrip',
      build: _makeBloc,
      act: (bloc) => bloc.add(const EditingTripStarted()),
      verify: (bloc) => expect(bloc.state.isEditingTrip, isTrue),
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'EditingTripStarted(fromVolumeSale) pose editedFromVolumeSale',
      build: _makeBloc,
      act: (bloc) => bloc.add(const EditingTripStarted(fromVolumeSale: true)),
      verify: (bloc) {
        expect(bloc.state.isEditingTrip, isTrue);
        expect(bloc.state.editedFromVolumeSale, isTrue);
      },
    );

    test('trajet au m³ passé au kilo ou en avion : kilos exigés (M8)', () {
      const base = AnnouncementFormState(
        transportMode: TransportMode.boat,
        boatPriceUnit: BoatPriceUnit.kg,
        isEditingTrip: true,
        editedFromVolumeSale: true,
        availableKg: 0,
        capacityUnit: CapacityUnit.custom,
      );
      expect(base.kilosMissing, isTrue);
      expect(base.isCapacityStepValid, isFalse);
      expect(
        base.copyWith(availableKgGetter: () => 40).isCapacityStepValid,
        isTrue,
      );
      expect(
        base
            .copyWith(transportModeGetter: () => TransportMode.plane)
            .isCapacityStepValid,
        isFalse,
      );
      // Toujours au m³ : aucun kilo à saisir.
      final m3 = base.copyWith(
        boatPriceUnit: BoatPriceUnit.m3,
        volumeCapacityM3Getter: () => 12,
      );
      expect(m3.kilosMissing, isFalse);
      expect(m3.isCapacityStepValid, isTrue);
      // Un trajet au kilo déjà complet (reste 0) reste modifiable.
      expect(
        base.copyWith(editedFromVolumeSale: false).isCapacityStepValid,
        isTrue,
      );
    });

    test('poids max par colis : vide, 0,5, capacité, au-delà', () {
      AnnouncementFormState s(
        double? w, {
        CapacityUnit u = CapacityUnit.custom,
      }) => AnnouncementFormState(
        transportMode: TransportMode.car,
        capacityUnit: u,
        availableKg: 1200,
        maxParcelWeightKg: w,
      );
      expect(s(null).isMaxParcelWeightValid, isTrue);
      expect(s(0.5).isMaxParcelWeightValid, isTrue);
      expect(s(0.4).isMaxParcelWeightValid, isFalse);
      expect(s(0).isMaxParcelWeightValid, isFalse);
      expect(s(1200).isMaxParcelWeightValid, isTrue);
      expect(s(1201).isMaxParcelWeightValid, isFalse);
      expect(s(1201).isCapacityStepValid, isFalse);
      // Kilo libre : capacité technique, borne haute 999 999 (D19).
      expect(s(5000, u: CapacityUnit.kgFree).isMaxParcelWeightValid, isTrue);
      expect(s(999999, u: CapacityUnit.kgFree).isMaxParcelWeightValid, isTrue);
      expect(
        s(1000000, u: CapacityUnit.kgFree).isMaxParcelWeightValid,
        isFalse,
      );
    });

    test('événements : props', () {
      expect(
        const MaxItemSizeChanged(ItemSize.s),
        equals(const MaxItemSizeChanged(ItemSize.s)),
      );
      expect(
        const MaxParcelWeightChanged(2),
        isNot(equals(const MaxParcelWeightChanged(3))),
      );
    });
  });

  group('AnnouncementFormBloc — bateau : m³ ou kilo (lot 3)', () {
    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'unité, volume et prix au m³ posés puis effacés',
      build: () => _makeBloc(),
      act: (b) {
        b.add(const TransportModeChanged(TransportMode.boat));
        b.add(const BoatPriceUnitChanged(BoatPriceUnit.m3));
        b.add(const VolumeCapacityChanged(12.5));
        b.add(const PricePerM3Changed(150));
        b.add(const VolumeCapacityChanged(null));
        b.add(const PricePerM3Changed(null));
      },
      verify: (b) {
        expect(b.state.boatPriceUnit, BoatPriceUnit.m3);
        expect(b.state.volumeCapacityM3, isNull);
        expect(b.state.pricePerM3, isNull);
      },
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'route 20 kg max par colis puis bateau : poids max gardé, taille '
      'effacée, valises en personnalisé',
      build: () => _makeBloc(),
      act: (b) {
        b.add(const TransportModeChanged(TransportMode.car));
        b.add(const MaxItemSizeChanged(ItemSize.l));
        b.add(const MaxParcelWeightChanged(20));
        b.add(const TransportModeChanged(TransportMode.boat));
        b.add(const CapacityUnitChanged(CapacityUnit.suitcase23kg));
      },
      verify: (b) {
        expect(b.state.maxItemSize, isNull);
        expect(b.state.maxParcelWeightKg, 20);
        expect(b.state.capacityUnit, CapacityUnit.custom);
      },
    );

    test('au m³ : la capacité se juge au volume, jamais aux kilos', () {
      const base = AnnouncementFormState(
        transportMode: TransportMode.boat,
        boatPriceUnit: BoatPriceUnit.m3,
        availableKg: 5000000,
      );
      expect(base.hasBoatPricing, isTrue);
      expect(base.isPricedPerM3, isTrue);
      expect(base.capacityTooHigh, isFalse);
      expect(base.isCapacityStepValid, isFalse);
      expect(
        base.copyWith(volumeCapacityM3Getter: () => 0.05).isCapacityStepValid,
        isFalse,
      );
      expect(
        base.copyWith(volumeCapacityM3Getter: () => 12.5).isCapacityStepValid,
        isTrue,
      );
      expect(
        base.copyWith(volumeCapacityM3Getter: () => 10000).isCapacityStepValid,
        isFalse,
      );
      // Poids max par colis sans capacité en kilos : borne technique.
      expect(
        base
            .copyWith(
              volumeCapacityM3Getter: () => 12.5,
              maxParcelWeightKgGetter: () => 800,
            )
            .isCapacityStepValid,
        isTrue,
      );
    });

    test('prix au m³ : de 0,01 à 99 999 999,99', () {
      const s = AnnouncementFormState(transportMode: TransportMode.boat);
      expect(s.isPricePerM3Valid, isFalse);
      expect(
        s.copyWith(pricePerM3Getter: () => 0.001).isPricePerM3Valid,
        isFalse,
      );
      expect(
        s.copyWith(pricePerM3Getter: () => 0.01).isPricePerM3Valid,
        isTrue,
      );
      expect(
        s.copyWith(pricePerM3Getter: () => 25000000).isPricePerM3Valid,
        isTrue,
      );
      expect(
        s.copyWith(pricePerM3Getter: () => maxPricePerM3).isPricePerM3Valid,
        isTrue,
      );
      final tooHigh = s.copyWith(pricePerM3Getter: () => 100000000);
      expect(tooHigh.isPricePerM3Valid, isFalse);
      expect(tooHigh.isPricePerM3TooHigh, isTrue);
      expect(s.isPricePerM3TooHigh, isFalse);
    });

    test('bateau au kilo, ou sans unité (modèle) : règles du kilo', () {
      const kg = AnnouncementFormState(
        transportMode: TransportMode.boat,
        boatPriceUnit: BoatPriceUnit.kg,
        availableKg: 300,
        capacityUnit: CapacityUnit.custom,
      );
      expect(kg.hasBoatPricing, isTrue);
      expect(kg.isPricedPerM3, isFalse);
      expect(kg.isCapacityStepValid, isTrue);
      const template = AnnouncementFormState(transportMode: TransportMode.boat);
      expect(template.hasBoatPricing, isFalse);
      expect(template.isPricedPerM3, isFalse);
      // Hors bateau, l'unité n'a aucun effet.
      const plane = AnnouncementFormState(
        transportMode: TransportMode.plane,
        boatPriceUnit: BoatPriceUnit.m3,
      );
      expect(plane.isPricedPerM3, isFalse);
      expect(plane.hasBoatPricing, isFalse);
    });

    test('unité de vente : valeur figée du brouillon', () {
      expect(BoatPriceUnit.m3.wire, 'M3');
      expect(BoatPriceUnit.kg.wire, 'KG');
      expect(BoatPriceUnit.fromWire('M3'), BoatPriceUnit.m3);
      expect(BoatPriceUnit.fromWire('KG'), BoatPriceUnit.kg);
      expect(BoatPriceUnit.fromWire('LITRE'), isNull);
      expect(BoatPriceUnit.fromWire(null), isNull);
    });

    test('événements : égalité par valeur', () {
      expect(
        const BoatPriceUnitChanged(BoatPriceUnit.m3),
        const BoatPriceUnitChanged(BoatPriceUnit.m3),
      );
      expect(const VolumeCapacityChanged(2), const VolumeCapacityChanged(2));
      expect(const PricePerM3Changed(9), isNot(const PricePerM3Changed(8)));
    });
  });
}
