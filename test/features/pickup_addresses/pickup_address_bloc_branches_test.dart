// Événements construits à l'exécution : un constructeur `const` n'est exécuté
// (donc compté par la couverture) que par un appel non `const`.
// ignore_for_file: prefer_const_constructors

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/pickup_addresses/bloc/pickup_address_bloc.dart';
import 'package:dony/features/pickup_addresses/data/models/pickup_address.dart';
import 'package:dony/features/pickup_addresses/data/repositories/pickup_address_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements PickupAddressRepository {}

PickupAddress _addr(String id, {bool isDefault = false}) => PickupAddress(
  id: id,
  label: 'Adresse $id',
  street: 'Rue $id',
  postalCode: '75001',
  city: 'Paris',
  country: 'France',
  isDefault: isDefault,
);

List<String> _defaults(PickupAddressState s) =>
    s.addresses.where((a) => a.isDefault).map((a) => a.id).toList();

void main() {
  late _MockRepo repo;

  setUp(() => repo = _MockRepo());

  PickupAddressState seeded() => PickupAddressState(
    status: PickupAddressStatus.success,
    addresses: [_addr('a-1', isDefault: true), _addr('a-2')],
  );

  blocTest<PickupAddressBloc, PickupAddressState>(
    'création par défaut : les autres perdent le défaut, champs optionnels '
    'transmis',
    build: () {
      when(
        () => repo.create(any()),
      ).thenAnswer((_) async => _addr('a-3', isDefault: true));
      return PickupAddressBloc(repo);
    },
    seed: seeded,
    act: (b) => b.add(
      PickupAddressCreated(
        label: 'Atelier',
        street: '1 rue Haute',
        postalCode: '69001',
        city: 'Lyon',
        country: 'France',
        floorApartment: '3e gauche',
        instructions: 'Code 1234',
        latitude: 45.76,
        longitude: 4.83,
        isDefault: true,
      ),
    ),
    expect: () => [
      isA<PickupAddressState>().having(
        (s) => s.status,
        'status',
        PickupAddressStatus.loading,
      ),
      isA<PickupAddressState>()
          .having((s) => s.status, 'status', PickupAddressStatus.success)
          .having(_defaults, 'défauts', ['a-3'])
          .having((s) => s.addresses.last.id, 'dernière', 'a-3'),
    ],
    verify: (_) => verify(
      () => repo.create({
        'label': 'Atelier',
        'street': '1 rue Haute',
        'postalCode': '69001',
        'city': 'Lyon',
        'country': 'France',
        'floorApartment': '3e gauche',
        'instructions': 'Code 1234',
        'latitude': 45.76,
        'longitude': 4.83,
        'isDefault': true,
      }),
    ).called(1),
  );

  blocTest<PickupAddressBloc, PickupAddressState>(
    'modification par défaut : adresse remplacée à sa place, défaut unique',
    build: () {
      when(
        () => repo.update('a-2', any()),
      ).thenAnswer((_) async => _addr('a-2', isDefault: true));
      return PickupAddressBloc(repo);
    },
    seed: seeded,
    act: (b) => b.add(
      PickupAddressUpdated(
        id: 'a-2',
        label: 'Bureau',
        street: '5 avenue',
        postalCode: '75008',
        city: 'Paris',
        country: 'France',
        floorApartment: 'RDC',
        isDefault: true,
      ),
    ),
    expect: () => [
      isA<PickupAddressState>().having(
        (s) => s.status,
        'status',
        PickupAddressStatus.loading,
      ),
      isA<PickupAddressState>()
          .having((s) => s.status, 'status', PickupAddressStatus.success)
          .having((s) => s.addresses.map((a) => a.id).toList(), 'ids', [
            'a-1',
            'a-2',
          ])
          .having(_defaults, 'défauts', ['a-2']),
    ],
    verify: (_) => verify(
      () =>
          repo.update('a-2', any(that: containsPair('floorApartment', 'RDC'))),
    ).called(1),
  );

  blocTest<PickupAddressBloc, PickupAddressState>(
    'modification en échec → erreur',
    build: () {
      when(() => repo.update(any(), any())).thenThrow(const ServerException());
      return PickupAddressBloc(repo);
    },
    seed: seeded,
    act: (b) => b.add(
      PickupAddressUpdated(
        id: 'a-2',
        label: 'Bureau',
        street: '5 avenue',
        postalCode: '75008',
        city: 'Paris',
        country: 'France',
      ),
    ),
    expect: () => [
      isA<PickupAddressState>().having(
        (s) => s.status,
        'status',
        PickupAddressStatus.loading,
      ),
      isA<PickupAddressState>()
          .having((s) => s.status, 'status', PickupAddressStatus.error)
          .having((s) => s.error, 'error', isA<ServerException>()),
    ],
  );

  blocTest<PickupAddressBloc, PickupAddressState>(
    'adresse par défaut en échec → erreur',
    build: () {
      when(() => repo.setDefault(any())).thenThrow(const ServerException());
      return PickupAddressBloc(repo);
    },
    seed: seeded,
    act: (b) => b.add(PickupAddressSetDefault('a-2')),
    expect: () => [
      isA<PickupAddressState>()
          .having((s) => s.status, 'status', PickupAddressStatus.error)
          .having(_defaults, 'défauts inchangés', ['a-1']),
    ],
  );

  blocTest<PickupAddressBloc, PickupAddressState>(
    'suppression en échec → erreur, liste conservée',
    build: () {
      when(() => repo.delete(any())).thenThrow(const ServerException());
      return PickupAddressBloc(repo);
    },
    seed: seeded,
    act: (b) => b.add(PickupAddressDeleted('a-2')),
    expect: () => [
      isA<PickupAddressState>()
          .having((s) => s.status, 'status', PickupAddressStatus.error)
          .having((s) => s.addresses, 'addresses', hasLength(2)),
    ],
  );

  blocTest<PickupAddressBloc, PickupAddressState>(
    'chargement construit à l’exécution → liste',
    build: () {
      when(() => repo.getAll()).thenAnswer((_) async => [_addr('a-1')]);
      return PickupAddressBloc(repo);
    },
    act: (b) => b.add(PickupAddressLoaded()),
    expect: () => [
      isA<PickupAddressState>(),
      isA<PickupAddressState>().having(
        (s) => s.addresses,
        'addresses',
        hasLength(1),
      ),
    ],
  );
}
