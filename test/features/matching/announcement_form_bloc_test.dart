import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/matching/bloc/announcement_form_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_form_event.dart';
import 'package:dony/features/matching/bloc/announcement_form_state.dart';
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
    });

    test('CapacityUnit.label retourne les bons libellés', () {
      expect(CapacityUnit.suitcase23kg.label, '1 valise 23 kg');
      expect(CapacityUnit.suitcase32kg.label, '1 valise 32 kg');
      expect(CapacityUnit.kgFree.label, 'Kg libre');
    });
  });
}
