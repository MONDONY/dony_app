import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/pickup_addresses/bloc/pickup_address_bloc.dart';
import 'package:dony/features/pickup_addresses/data/models/pickup_address.dart';
import 'package:dony/features/pickup_addresses/data/repositories/pickup_address_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPickupAddressRepository extends Mock
    implements PickupAddressRepository {}

const _addr1 = PickupAddress(
  id: 'addr-1',
  label: 'Maison',
  street: '12 rue de la Paix',
  postalCode: '75001',
  city: 'Paris',
  country: 'France',
  isDefault: true,
);

const _addr2 = PickupAddress(
  id: 'addr-2',
  label: 'Bureau',
  street: '5 avenue Montaigne',
  postalCode: '75008',
  city: 'Paris',
  country: 'France',
  isDefault: false,
);

void main() {
  late MockPickupAddressRepository repository;

  setUp(() {
    repository = MockPickupAddressRepository();
  });

  group('PickupAddressBloc', () {
    test('initial state is correct', () {
      final bloc = PickupAddressBloc(repository);
      expect(bloc.state.status, PickupAddressStatus.initial);
      expect(bloc.state.addresses, isEmpty);
      expect(bloc.state.error, isNull);
      bloc.close();
    });

    blocTest<PickupAddressBloc, PickupAddressState>(
      'PickupAddressLoaded → success + list',
      build: () {
        when(() => repository.getAll()).thenAnswer((_) async => [_addr1, _addr2]);
        return PickupAddressBloc(repository);
      },
      act: (bloc) => bloc.add(const PickupAddressLoaded()),
      expect: () => [
        isA<PickupAddressState>()
            .having((s) => s.status, 'status', PickupAddressStatus.loading),
        isA<PickupAddressState>()
            .having((s) => s.status, 'status', PickupAddressStatus.success)
            .having((s) => s.addresses, 'addresses', [_addr1, _addr2]),
      ],
    );

    blocTest<PickupAddressBloc, PickupAddressState>(
      'PickupAddressLoaded → error state when repository throws',
      build: () {
        when(() => repository.getAll()).thenThrow(Exception('Network error'));
        return PickupAddressBloc(repository);
      },
      act: (bloc) => bloc.add(const PickupAddressLoaded()),
      expect: () => [
        isA<PickupAddressState>()
            .having((s) => s.status, 'status', PickupAddressStatus.loading),
        isA<PickupAddressState>()
            .having((s) => s.status, 'status', PickupAddressStatus.error)
            .having((s) => s.error, 'error', isNotNull),
      ],
    );

    blocTest<PickupAddressBloc, PickupAddressState>(
      'PickupAddressCreated → adds to the list',
      build: () {
        const created = PickupAddress(
          id: 'addr-3',
          label: 'Chez un ami',
          street: '1 rue Test',
          postalCode: '75002',
          city: 'Paris',
          country: 'France',
          isDefault: false,
        );
        when(() => repository.create(any())).thenAnswer((_) async => created);
        return PickupAddressBloc(repository)
          ..emit(const PickupAddressState(
            status: PickupAddressStatus.success,
            addresses: [_addr1, _addr2],
          ));
      },
      act: (bloc) => bloc.add(const PickupAddressCreated(
        label: 'Chez un ami',
        street: '1 rue Test',
        postalCode: '75002',
        city: 'Paris',
        country: 'France',
      )),
      expect: () => [
        isA<PickupAddressState>()
            .having((s) => s.status, 'status', PickupAddressStatus.loading),
        isA<PickupAddressState>()
            .having((s) => s.status, 'status', PickupAddressStatus.success)
            .having((s) => s.addresses.length, 'length', 3),
      ],
    );

    blocTest<PickupAddressBloc, PickupAddressState>(
      'PickupAddressDeleted → removes from the list',
      build: () {
        when(() => repository.delete('addr-1')).thenAnswer((_) async {});
        return PickupAddressBloc(repository)
          ..emit(const PickupAddressState(
            status: PickupAddressStatus.success,
            addresses: [_addr1, _addr2],
          ));
      },
      act: (bloc) => bloc.add(const PickupAddressDeleted('addr-1')),
      expect: () => [
        isA<PickupAddressState>()
            .having((s) => s.status, 'status', PickupAddressStatus.success)
            .having((s) => s.addresses.length, 'length', 1)
            .having((s) => s.addresses.first.id, 'id', 'addr-2'),
      ],
    );

    blocTest<PickupAddressBloc, PickupAddressState>(
      'PickupAddressSetDefault → updates default flag',
      build: () {
        final updated = _addr2.copyWith(isDefault: true);
        when(() => repository.setDefault('addr-2'))
            .thenAnswer((_) async => updated);
        return PickupAddressBloc(repository)
          ..emit(const PickupAddressState(
            status: PickupAddressStatus.success,
            addresses: [_addr1, _addr2],
          ));
      },
      act: (bloc) => bloc.add(const PickupAddressSetDefault('addr-2')),
      expect: () => [
        isA<PickupAddressState>()
            .having((s) => s.status, 'status', PickupAddressStatus.success)
            .having(
              (s) => s.addresses.firstWhere((a) => a.id == 'addr-2').isDefault,
              'isDefault addr-2',
              true,
            )
            .having(
              (s) => s.addresses.firstWhere((a) => a.id == 'addr-1').isDefault,
              'isDefault addr-1',
              false,
            ),
      ],
    );
  });
}
