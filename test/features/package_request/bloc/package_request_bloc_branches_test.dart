// Événements construits à l'exécution : un appel `const` n'est jamais exécuté
// et deux instances `const` identiques court-circuitent la comparaison.
// ignore_for_file: prefer_const_constructors

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/package_request/bloc/package_request_bloc.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/value_equality.dart';

class _MockRepo extends Mock implements PackageRequestRepository {}

void main() {
  late _MockRepo repo;

  setUp(() => repo = _MockRepo());

  group('événements — égalité de valeur', () {
    test('chargement et rafraîchissement : sans champ, distincts', () {
      expectValueEquality(() => FetchMyRequests(), [RefreshMyRequests()]);
      expectValueEquality(() => RefreshMyRequests(), [FetchMyRequests()]);
      expect(FetchMyRequests().props, isEmpty);
    });

    test('annulation : identifiant de la demande', () {
      expectValueEquality(() => CancelRequest('r-1'), [CancelRequest('r-2')]);
    });
  });

  blocTest<PackageRequestBloc, PackageRequestState>(
    'rafraîchissement en échec → erreur sans passer par le chargement',
    build: () {
      when(() => repo.findMine()).thenThrow(const ServerException());
      return PackageRequestBloc(repo);
    },
    act: (b) => b.add(RefreshMyRequests()),
    expect: () => [
      isA<PackageRequestState>()
          .having((s) => s.status, 'status', PackageRequestListStatus.error)
          .having((s) => s.errorMessage, 'error', isA<ServerException>()),
    ],
    verify: (_) => verify(() => repo.findMine()).called(1),
  );
}
