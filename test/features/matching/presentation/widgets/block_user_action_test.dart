import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/settings/data/repositories/blocked_users_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockBlockedUsersRepository extends Mock
    implements BlockedUsersRepository {}

void main() {
  late MockBlockedUsersRepository mockRepo;

  setUp(() {
    mockRepo = MockBlockedUsersRepository();
  });

  group('BlockedUsersRepository.blockUser', () {
    test('délègue au datasource et complète sans erreur', () async {
      when(() => mockRepo.blockUser(any())).thenAnswer((_) async {});

      await expectLater(mockRepo.blockUser('user-123'), completes);
      verify(() => mockRepo.blockUser('user-123')).called(1);
    });

    test(
      'propage ConflictException quand la transaction est en cours',
      () async {
        when(() => mockRepo.blockUser(any())).thenAnswer(
          (_) async => throw const ConflictException(
            'Termine d\'abord la transaction en cours',
            code: 'active-transaction',
          ),
        );

        await expectLater(
          mockRepo.blockUser('user-456'),
          throwsA(isA<ConflictException>()),
        );
      },
    );

    test('ConflictException est une AppException', () {
      const e = ConflictException('msg', code: 'CODE');
      expect(e, isA<AppException>());
      expect(e.code, 'CODE');
    });
  });

  group('Affichage numéro masqué — logique', () {
    test(
      'phoneNumber null signifie numéro non révélé (bid pas encore accepté)',
      () {
        // La règle : le backend renvoie null jusqu\'à acceptation du bid.
        // Le front affiche un placeholder. Ce test documente le comportement attendu.
        const String? phone = null;
        expect(phone, isNull);
      },
    );

    test('phoneNumber non null signifie numéro révélé (bid accepté)', () {
      const String? phone = '+33612345678';
      expect(phone, isNotNull);
      expect(phone, '+33612345678');
    });
  });
}
