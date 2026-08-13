import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/matching/bloc/announcement_form_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_form_event.dart';
import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/grid_preview_item.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/price_grid/data/models/price_grid_item_model.dart';
import 'package:dony/features/price_grid/data/repositories/price_grid_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPriceGridRepository extends Mock implements PriceGridRepository {}

void main() {
  group('AnnouncementFormBloc', () {
    late AnnouncementFormBloc bloc;

    setUp(() {
      bloc = AnnouncementFormBloc();
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
      build: () => AnnouncementFormBloc(),
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
      build: () => AnnouncementFormBloc(),
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
      build: () => AnnouncementFormBloc(),
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
      build: () => AnnouncementFormBloc(),
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
      build: () => AnnouncementFormBloc(),
      act: (b) => b.add(const PriceChanged(15.0)),
      expect: () => [
        predicate<AnnouncementFormState>(
          (s) => s.pricePerKg == 15.0 && s.priceWarning == null,
          'state has pricePerKg=15.0 and no warning',
        ),
      ],
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'DepartureCityChanged met à jour departureCity',
      build: () => AnnouncementFormBloc(),
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
      build: () => AnnouncementFormBloc(),
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
      build: () => AnnouncementFormBloc(),
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
      build: () => AnnouncementFormBloc(),
      act: (b) => b.add(const ArrivalCityChanged('Tokyo', countryCode: 'JP')),
      expect: () => [
        predicate<AnnouncementFormState>(
          (s) => s.arrivalCity == 'Tokyo' && s.arrivalCountryCode == 'JP',
          'arrivalCity=Tokyo, arrivalCountryCode=JP',
        ),
      ],
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'DepartureCityChanged sans countryCode laisse departureCountryCode null',
      build: () => AnnouncementFormBloc(),
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
      build: () => AnnouncementFormBloc(),
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
      build: () => AnnouncementFormBloc(),
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
      build: () => AnnouncementFormBloc(),
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
      build: () => AnnouncementFormBloc(),
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
      build: () => AnnouncementFormBloc(),
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
      build: () => AnnouncementFormBloc(),
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
      expect(CapacityUnit.suitcase23kg.label, '1 valise 23 kg');
      expect(CapacityUnit.suitcase32kg.label, '1 valise 32 kg');
      expect(CapacityUnit.kgFree.label, 'Kg libre');
      expect(CapacityUnit.custom.label, 'Personnalisé');
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
      build: () => AnnouncementFormBloc(),
      act: (b) => b.add(const CapacityUnitChanged(CapacityUnit.suitcase32kg)),
      expect: () => [
        isA<AnnouncementFormState>()
            .having((s) => s.capacityUnit, 'unit', CapacityUnit.suitcase32kg)
            .having((s) => s.availableKg, 'kg', 32.0),
      ],
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'sélectionner kgFree conserve un availableKg ≥ 1 (option b — défaut 1.0)',
      build: () => AnnouncementFormBloc(),
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
      build: () => AnnouncementFormBloc(),
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
      build: () => AnnouncementFormBloc(),
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
      build: () => AnnouncementFormBloc(),
      act: (b) => b.add(const CapacityUnitChanged(CapacityUnit.custom)),
      expect: () => [
        isA<AnnouncementFormState>()
            .having((s) => s.capacityUnit, 'unit', CapacityUnit.custom)
            .having((s) => s.availableKg, 'kg', 1.0),
      ],
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'sélectionner custom puis régler le slider met availableKg',
      build: () => AnnouncementFormBloc(),
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
      build: () => AnnouncementFormBloc(),
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
      build: () => AnnouncementFormBloc(),
      act: (b) {
        b.add(const TransportModeChanged(TransportMode.car));
        b.add(const TransportModeChanged(TransportMode.plane));
      },
      verify: (b) => expect(b.state.transportMode, TransportMode.plane),
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'PickupAddressChanged met à jour pickupAddress',
      build: () => AnnouncementFormBloc(),
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
      build: () => AnnouncementFormBloc(),
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
      build: () => AnnouncementFormBloc(),
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
      build: () => AnnouncementFormBloc(),
      act: (b) => b.add(const CashAcceptedChanged(true)),
      expect: () => [
        predicate<AnnouncementFormState>(
          (s) => s.cashAccepted == true,
          'cashAccepted is true',
        ),
      ],
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'AcceptedTypesChanged met à jour acceptedTypes',
      build: () => AnnouncementFormBloc(),
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
      build: () => AnnouncementFormBloc(),
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
      build: () => AnnouncementFormBloc(),
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
      build: () => AnnouncementFormBloc(),
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
      build: () => AnnouncementFormBloc(),
      act: (b) => b.add(const PriceChanged(8.0)),
      verify: (b) => expect(b.state.isStep3Valid, isTrue),
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'isStep3Valid: faux avec prix = 0',
      build: () => AnnouncementFormBloc(),
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
      build: () => AnnouncementFormBloc(),
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
        return AnnouncementFormBloc(priceGridRepository: mockRepo);
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
      build: () => AnnouncementFormBloc(),
      act: (b) => b.add(const AnnouncementGridPreviewLoadRequested()),
      expect: () => <AnnouncementFormState>[],
    );

    blocTest<AnnouncementFormBloc, AnnouncementFormState>(
      'AnnouncementGridPreviewLoadRequested silencieux si repo throws',
      build: () {
        final mockRepo = MockPriceGridRepository();
        when(() => mockRepo.getItems()).thenThrow(Exception('network error'));
        return AnnouncementFormBloc(priceGridRepository: mockRepo);
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
        return AnnouncementFormBloc(priceGridRepository: mockRepo);
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
        return AnnouncementFormBloc(priceGridRepository: mockRepo);
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
      build: () => AnnouncementFormBloc(),
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
}
