import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/matching/bloc/announcement_form_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_form_event.dart';
import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnnouncementFormBloc', () {
    late AnnouncementFormBloc bloc;

    setUp(() {
      bloc = AnnouncementFormBloc();
    });

    tearDown(() => bloc.close());

    test('état initial: formulaire invalide, prix null, capacité SUITCASE_23KG',
        () {
      expect(bloc.state.isFormValid, isFalse);
      expect(bloc.state.capacityUnit, CapacityUnit.suitcase23kg);
      expect(bloc.state.pricePerKg, isNull);
      expect(bloc.state.priceWarning, isNull);
    });

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
          (s) =>
              s.pricePerKg == 20.0 && s.priceWarning == PriceWarning.tooHigh,
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
            DepartureDateChanged(DateTime.now().add(const Duration(days: 7))));
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
      'sélectionner kgFree met availableKg à null',
      build: () => AnnouncementFormBloc(),
      act: (b) => b.add(const CapacityUnitChanged(CapacityUnit.kgFree)),
      expect: () => [
        isA<AnnouncementFormState>()
            .having((s) => s.capacityUnit, 'unit', CapacityUnit.kgFree)
            .having((s) => s.availableKg, 'kg', null),
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
            .having((s) => s.capacityUnit, 'unit', CapacityUnit.custom),
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
      act: (b) => b.add(const PickupAddressChanged(
        AddressData(label: '12 rue de la Paix, Paris', lat: 48.87, lng: 2.33),
      )),
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
      act: (b) => b.add(const DeliveryAddressChanged(
        AddressData(label: 'Plateau, Abidjan', lat: 5.32, lng: -4.01),
      )),
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
            DepartureDateChanged(DateTime.now().add(const Duration(days: 3))));
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
        b.add(const PickupAddressChanged(
          AddressData(label: 'CDG, Paris', lat: 49.0, lng: 2.55),
        ));
        b.add(const DeliveryAddressChanged(
          AddressData(label: 'Almadies, Dakar', lat: 14.74, lng: -17.49),
        ));
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
  });
}
