import 'package:dony/features/support/bloc/support_unread_cubit.dart';
import 'package:dony/features/support/data/support_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSupportRepository extends Mock implements SupportRepository {}

void main() {
  late MockSupportRepository repository;

  setUp(() {
    repository = MockSupportRepository();
  });

  test('le compteur décroît après lecture sans attendre le serveur', () async {
    when(() => repository.loadUnreadCount()).thenAnswer((_) async => 3);
    final cubit = SupportUnreadCubit(repository);

    await cubit.refresh();
    expect(cubit.state, 3);

    cubit.decrementBy(3);
    expect(cubit.state, 0);

    await cubit.close();
  });

  test('decrementBy ne descend jamais sous zéro', () async {
    when(() => repository.loadUnreadCount()).thenAnswer((_) async => 1);
    final cubit = SupportUnreadCubit(repository);
    await cubit.refresh();

    cubit.decrementBy(5);
    expect(cubit.state, 0);

    await cubit.close();
  });

  test('refresh avale une erreur réseau et garde la valeur courante', () async {
    when(() => repository.loadUnreadCount()).thenThrow(Exception('hors ligne'));
    final cubit = SupportUnreadCubit(repository);

    await cubit.refresh();
    expect(cubit.state, 0);

    await cubit.close();
  });

  test('refresh met à jour le compteur après une erreur initiale', () async {
    var callCount = 0;
    when(() => repository.loadUnreadCount()).thenAnswer((_) async {
      callCount++;
      if (callCount == 1) throw Exception('hors ligne');
      return 5;
    });
    final cubit = SupportUnreadCubit(repository);

    await cubit.refresh(); // échec → reste à 0
    expect(cubit.state, 0);

    await cubit.refresh(); // succès → 5
    expect(cubit.state, 5);

    await cubit.close();
  });
}
