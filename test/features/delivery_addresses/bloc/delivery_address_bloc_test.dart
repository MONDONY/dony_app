// Événements construits à l'exécution : un constructeur `const` n'est exécuté
// (donc compté par la couverture) que par un appel non `const`.
// ignore_for_file: prefer_const_constructors

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/delivery_addresses/bloc/delivery_address_bloc.dart';
import 'package:dony/features/delivery_addresses/bloc/delivery_address_event.dart';
import 'package:dony/features/delivery_addresses/bloc/delivery_address_state.dart';
import 'package:dony/features/delivery_addresses/data/models/delivery_address.dart';
import 'package:dony/features/delivery_addresses/data/repositories/delivery_address_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements DeliveryAddressRepository {}

DeliveryAddress _addr(String id, {bool isDefault = false, String? label}) =>
    DeliveryAddress(
      id: id,
      label: label ?? 'Adresse $id',
      street: 'Rue $id',
      city: 'Dakar',
      country: 'SN',
      isDefault: isDefault,
    );

final _home = _addr('a-1', isDefault: true);
final _office = _addr('a-2');

TypeMatcher<DeliveryAddressState> _state(
  DeliveryAddressStatus status, {
  List<String>? ids,
  List<String>? defaults,
  bool hasError = false,
}) {
  var m = isA<DeliveryAddressState>().having((s) => s.status, 'status', status);
  if (ids != null) {
    m = m.having((s) => s.addresses.map((a) => a.id).toList(), 'ids', ids);
  }
  if (defaults != null) {
    m = m.having(
      (s) => s.addresses.where((a) => a.isDefault).map((a) => a.id).toList(),
      'defaults',
      defaults,
    );
  }
  if (hasError) {
    m = m.having((s) => s.error, 'error', isA<AppException>());
  }
  return m;
}

void main() {
  late _MockRepo repo;

  setUp(() => repo = _MockRepo());

  DeliveryAddressState seeded() => DeliveryAddressState(
    status: DeliveryAddressStatus.success,
    addresses: [_home, _office],
  );

  test('état initial : aucune adresse, statut initial', () {
    final bloc = DeliveryAddressBloc(repo);
    expect(bloc.state.status, DeliveryAddressStatus.initial);
    expect(bloc.state.addresses, isEmpty);
    expect(bloc.state.error, isNull);
    bloc.close();
  });

  group('chargement', () {
    blocTest<DeliveryAddressBloc, DeliveryAddressState>(
      'succès → loading puis liste',
      build: () {
        when(() => repo.getAll()).thenAnswer((_) async => [_home, _office]);
        return DeliveryAddressBloc(repo);
      },
      act: (b) => b.add(DeliveryAddressLoaded()),
      expect: () => [
        _state(DeliveryAddressStatus.loading),
        _state(DeliveryAddressStatus.success, ids: ['a-1', 'a-2']),
      ],
    );

    blocTest<DeliveryAddressBloc, DeliveryAddressState>(
      'échec → statut erreur avec l’exception déballée',
      build: () {
        when(() => repo.getAll()).thenThrow(const ServerException());
        return DeliveryAddressBloc(repo);
      },
      act: (b) => b.add(DeliveryAddressLoaded()),
      expect: () => [
        _state(DeliveryAddressStatus.loading),
        _state(DeliveryAddressStatus.error, hasError: true),
      ],
    );
  });

  group('création', () {
    DeliveryAddressCreated event({required bool isDefault}) =>
        DeliveryAddressCreated(
          label: 'Famille',
          street: 'Rue 10',
          city: 'Thiès',
          country: 'SN',
          instructions: 'Portail bleu',
          latitude: 14.79,
          longitude: -16.92,
          isDefault: isDefault,
        );

    blocTest<DeliveryAddressBloc, DeliveryAddressState>(
      'adresse par défaut : placée en tête, les autres perdent le défaut, '
      'payload complet envoyé',
      build: () {
        when(
          () => repo.create(any()),
        ).thenAnswer((_) async => _addr('a-3', isDefault: true));
        return DeliveryAddressBloc(repo);
      },
      seed: seeded,
      act: (b) => b.add(event(isDefault: true)),
      expect: () => [
        _state(DeliveryAddressStatus.loading),
        _state(
          DeliveryAddressStatus.success,
          ids: ['a-3', 'a-1', 'a-2'],
          defaults: ['a-3'],
        ),
      ],
      verify: (_) => verify(
        () => repo.create({
          'label': 'Famille',
          'street': 'Rue 10',
          'city': 'Thiès',
          'country': 'SN',
          'instructions': 'Portail bleu',
          'latitude': 14.79,
          'longitude': -16.92,
          'isDefault': true,
        }),
      ).called(1),
    );

    blocTest<DeliveryAddressBloc, DeliveryAddressState>(
      'adresse secondaire : ajoutée en tête, défaut existant conservé',
      build: () {
        when(() => repo.create(any())).thenAnswer((_) async => _addr('a-3'));
        return DeliveryAddressBloc(repo);
      },
      seed: seeded,
      act: (b) => b.add(event(isDefault: false)),
      expect: () => [
        _state(DeliveryAddressStatus.loading),
        _state(
          DeliveryAddressStatus.success,
          ids: ['a-3', 'a-1', 'a-2'],
          defaults: ['a-1'],
        ),
      ],
    );

    blocTest<DeliveryAddressBloc, DeliveryAddressState>(
      'échec → erreur, liste inchangée',
      build: () {
        when(() => repo.create(any())).thenThrow(const ServerException());
        return DeliveryAddressBloc(repo);
      },
      seed: seeded,
      act: (b) => b.add(event(isDefault: false)),
      expect: () => [
        _state(DeliveryAddressStatus.loading),
        _state(
          DeliveryAddressStatus.error,
          ids: ['a-1', 'a-2'],
          hasError: true,
        ),
      ],
    );
  });

  group('modification', () {
    DeliveryAddressUpdated event({required bool isDefault}) =>
        DeliveryAddressUpdated(
          id: 'a-2',
          label: 'Bureau',
          street: 'Rue 2',
          city: 'Dakar',
          country: 'SN',
          isDefault: isDefault,
        );

    blocTest<DeliveryAddressBloc, DeliveryAddressState>(
      'devient l’adresse par défaut → remplacée, l’ancienne perd le défaut',
      build: () {
        when(
          () => repo.update('a-2', any()),
        ).thenAnswer((_) async => _addr('a-2', isDefault: true, label: 'B'));
        return DeliveryAddressBloc(repo);
      },
      seed: seeded,
      act: (b) => b.add(event(isDefault: true)),
      expect: () => [
        _state(DeliveryAddressStatus.loading),
        _state(
          DeliveryAddressStatus.success,
          ids: ['a-1', 'a-2'],
          defaults: ['a-2'],
        ).having((s) => s.addresses.last.label, 'label', 'B'),
      ],
    );

    blocTest<DeliveryAddressBloc, DeliveryAddressState>(
      'sans changement de défaut → les autres adresses restent intactes',
      build: () {
        when(
          () => repo.update('a-2', any()),
        ).thenAnswer((_) async => _addr('a-2', label: 'B'));
        return DeliveryAddressBloc(repo);
      },
      seed: seeded,
      act: (b) => b.add(event(isDefault: false)),
      expect: () => [
        _state(DeliveryAddressStatus.loading),
        _state(
          DeliveryAddressStatus.success,
          ids: ['a-1', 'a-2'],
          defaults: ['a-1'],
        ),
      ],
    );

    blocTest<DeliveryAddressBloc, DeliveryAddressState>(
      'échec → erreur',
      build: () {
        when(
          () => repo.update(any(), any()),
        ).thenThrow(const ServerException());
        return DeliveryAddressBloc(repo);
      },
      seed: seeded,
      act: (b) => b.add(event(isDefault: false)),
      expect: () => [
        _state(DeliveryAddressStatus.loading),
        _state(DeliveryAddressStatus.error, hasError: true),
      ],
    );
  });

  group('adresse par défaut', () {
    blocTest<DeliveryAddressBloc, DeliveryAddressState>(
      'succès → une seule adresse par défaut, sans état de chargement',
      build: () {
        when(
          () => repo.setDefault('a-2'),
        ).thenAnswer((_) async => _addr('a-2', isDefault: true));
        return DeliveryAddressBloc(repo);
      },
      seed: seeded,
      act: (b) => b.add(DeliveryAddressSetDefault('a-2')),
      expect: () => [
        _state(DeliveryAddressStatus.success, defaults: ['a-2']),
      ],
    );

    blocTest<DeliveryAddressBloc, DeliveryAddressState>(
      'échec → erreur',
      build: () {
        when(() => repo.setDefault(any())).thenThrow(const ServerException());
        return DeliveryAddressBloc(repo);
      },
      seed: seeded,
      act: (b) => b.add(DeliveryAddressSetDefault('a-2')),
      expect: () => [_state(DeliveryAddressStatus.error, hasError: true)],
    );
  });

  group('suppression', () {
    blocTest<DeliveryAddressBloc, DeliveryAddressState>(
      'succès → adresse retirée de la liste',
      build: () {
        when(() => repo.delete('a-2')).thenAnswer((_) async {});
        return DeliveryAddressBloc(repo);
      },
      seed: seeded,
      act: (b) => b.add(DeliveryAddressDeleted('a-2')),
      expect: () => [
        _state(DeliveryAddressStatus.success, ids: ['a-1']),
      ],
      verify: (_) => verify(() => repo.delete('a-2')).called(1),
    );

    blocTest<DeliveryAddressBloc, DeliveryAddressState>(
      'échec → erreur, adresse conservée',
      build: () {
        when(() => repo.delete(any())).thenThrow(const ServerException());
        return DeliveryAddressBloc(repo);
      },
      seed: seeded,
      act: (b) => b.add(DeliveryAddressDeleted('a-2')),
      expect: () => [
        _state(
          DeliveryAddressStatus.error,
          ids: ['a-1', 'a-2'],
          hasError: true,
        ),
      ],
    );
  });
}
