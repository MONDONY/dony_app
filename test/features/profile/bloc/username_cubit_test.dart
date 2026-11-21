import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/profile/bloc/username/username_cubit.dart';
import 'package:dony/features/profile/data/models/username_availability.dart';
import 'package:dony/features/profile/data/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements ProfileRepository {}

const _fast = Duration(milliseconds: 20);
const _wait = Duration(milliseconds: 120);

UserModel _user(String username) => UserModel(
  id: 'u1',
  username: username,
  roles: const [],
  kycStatus: 'NOT_STARTED',
  status: 'ACTIVE',
);

void main() {
  late _MockRepo repo;
  late UsernameCubit cubit;

  setUp(() {
    repo = _MockRepo();
    cubit = UsernameCubit(repo, debounce: _fast);
  });

  tearDown(() => cubit.close());

  void stubCheck(UsernameAvailability a) {
    when(
      () => repo.checkUsername(any(), cancelToken: any(named: 'cancelToken')),
    ).thenAnswer((_) async => a);
  }

  test('le délai par défaut est de 400 ms', () {
    expect(UsernameCubit.defaultDebounce, const Duration(milliseconds: 400));
  });

  test('deux frappes rapprochées ne font qu une requête', () async {
    stubCheck(const UsernameAvailability(available: true));
    cubit.inputChanged('awa');
    cubit.inputChanged('awa.d');
    await Future<void>.delayed(_wait);
    verify(
      () => repo.checkUsername('awa.d', cancelToken: any(named: 'cancelToken')),
    ).called(1);
    verifyNever(
      () => repo.checkUsername('awa', cancelToken: any(named: 'cancelToken')),
    );
    expect(cubit.state.status, UsernameStatus.available);
  });

  test('la saisie est mise en minuscules', () async {
    stubCheck(const UsernameAvailability(available: true));
    cubit.inputChanged('Awa.D');
    await Future<void>.delayed(_wait);
    verify(
      () => repo.checkUsername('awa.d', cancelToken: any(named: 'cancelToken')),
    ).called(1);
    expect(cubit.state.input, 'awa.d');
  });

  for (final bad in ['a', 'ab', 'awa d', '.awa', 'awa.', 'aw..a', 'awa-b']) {
    test('« $bad » : format local invalide, aucune requête', () async {
      cubit.inputChanged(bad);
      await Future<void>.delayed(_wait);
      verifyNever(
        () => repo.checkUsername(any(), cancelToken: any(named: 'cancelToken')),
      );
      expect(cubit.state.status, UsernameStatus.idle);
      expect(cubit.state.showsFormatHint, isTrue);
    });
  }

  test('saisie vidée : retour à l état neutre sans astuce', () async {
    cubit.inputChanged('ab');
    cubit.inputChanged('');
    expect(cubit.state.status, UsernameStatus.idle);
    expect(cubit.state.showsFormatHint, isFalse);
  });

  test('TAKEN : indisponible avec 3 suggestions', () async {
    stubCheck(
      const UsernameAvailability(
        available: false,
        reason: UsernameReason.taken,
        suggestions: ['awa1', 'awa.d', 'awa_d'],
      ),
    );
    cubit.inputChanged('awa');
    await Future<void>.delayed(_wait);
    expect(cubit.state.status, UsernameStatus.unavailable);
    expect(cubit.state.reason, UsernameReason.taken);
    expect(cubit.state.suggestions, hasLength(3));
    expect(cubit.state.canSave, isFalse);
  });

  test('toucher une suggestion remplit la saisie et revérifie', () async {
    stubCheck(
      const UsernameAvailability(
        available: false,
        reason: UsernameReason.taken,
        suggestions: ['awa1'],
      ),
    );
    cubit.inputChanged('awa');
    await Future<void>.delayed(_wait);
    stubCheck(const UsernameAvailability(available: true));
    cubit.suggestionTapped('awa1');
    expect(cubit.state.input, 'awa1');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    verify(
      () => repo.checkUsername('awa1', cancelToken: any(named: 'cancelToken')),
    ).called(1);
    expect(cubit.state.status, UsernameStatus.available);
    expect(cubit.state.canSave, isTrue);
  });

  test('une réponse périmée est ignorée', () async {
    when(
      () => repo.checkUsername('awa', cancelToken: any(named: 'cancelToken')),
    ).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return const UsernameAvailability(
        available: false,
        reason: UsernameReason.taken,
      );
    });
    when(
      () => repo.checkUsername('awa.d', cancelToken: any(named: 'cancelToken')),
    ).thenAnswer((_) async => const UsernameAvailability(available: true));
    cubit.inputChanged('awa');
    await Future<void>.delayed(const Duration(milliseconds: 40));
    cubit.inputChanged('awa.d');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(cubit.state.status, UsernameStatus.available);
    expect(cubit.state.input, 'awa.d');
  });

  test('submit : enregistre puis passe à saved avec l utilisateur', () async {
    stubCheck(const UsernameAvailability(available: true));
    when(
      () => repo.changeUsername('awa.d'),
    ).thenAnswer((_) async => _user('awa.d'));
    cubit.inputChanged('awa.d');
    await Future<void>.delayed(_wait);
    await cubit.submit();
    expect(cubit.state.status, UsernameStatus.saved);
    expect(cubit.state.savedUser?.username, 'awa.d');
  });

  test('submit sans disponibilité confirmée : rien n est envoyé', () async {
    await cubit.submit();
    verifyNever(() => repo.changeUsername(any()));
  });

  Future<void> submitFailing(AppException e) async {
    stubCheck(const UsernameAvailability(available: true));
    when(() => repo.changeUsername('awa.d')).thenThrow(e);
    cubit.inputChanged('awa.d');
    await Future<void>.delayed(_wait);
    await cubit.submit();
  }

  test('409 username-change-too-soon : tooSoon avec la date', () async {
    await submitFailing(
      const ConflictException(
        'x',
        code: 'username-change-too-soon',
        extensions: {'nextChangeAt': '2026-12-20T10:00:00Z'},
      ),
    );
    expect(cubit.state.status, UsernameStatus.tooSoon);
    expect(cubit.state.nextChangeAt, DateTime.parse('2026-12-20T10:00:00Z'));
    expect(cubit.state.canSave, isFalse);
  });

  test(
    '409 username-taken au submit : indisponible avec suggestions',
    () async {
      await submitFailing(
        const ConflictException(
          'x',
          code: 'username-taken',
          extensions: {
            'suggestions': ['awa.d1', 'awa.d2'],
          },
        ),
      );
      expect(cubit.state.status, UsernameStatus.unavailable);
      expect(cubit.state.reason, UsernameReason.taken);
      expect(cubit.state.suggestions, ['awa.d1', 'awa.d2']);
    },
  );

  test('type sans code : le suffixe de type fait foi', () async {
    await submitFailing(
      const ConflictException(
        'x',
        extensions: {'type': 'https://api.yadony.com/problems/username-taken'},
      ),
    );
    expect(cubit.state.reason, UsernameReason.taken);
  });

  test('422 username-reserved : indisponible, motif réservé', () async {
    await submitFailing(
      const ValidationException('x', code: 'username-reserved'),
    );
    expect(cubit.state.status, UsernameStatus.unavailable);
    expect(cubit.state.reason, UsernameReason.reserved);
  });

  test('429 : état quota, à la vérification comme à l envoi', () async {
    when(
      () => repo.checkUsername(any(), cancelToken: any(named: 'cancelToken')),
    ).thenThrow(const RateLimitException('x', 'username-availability-quota'));
    cubit.inputChanged('awa');
    await Future<void>.delayed(_wait);
    expect(cubit.state.status, UsernameStatus.quota);

    final other = UsernameCubit(repo, debounce: _fast);
    addTearDown(other.close);
    await Future<void>.delayed(Duration.zero);
    stubCheck(const UsernameAvailability(available: true));
    when(
      () => repo.changeUsername('awa.d'),
    ).thenThrow(const RateLimitException());
    other.inputChanged('awa.d');
    await Future<void>.delayed(_wait);
    await other.submit();
    expect(other.state.status, UsernameStatus.quota);
  });

  test('erreur réseau à la vérification : état error', () async {
    when(
      () => repo.checkUsername(any(), cancelToken: any(named: 'cancelToken')),
    ).thenThrow(const OfflineException());
    cubit.inputChanged('awa');
    await Future<void>.delayed(_wait);
    expect(cubit.state.status, UsernameStatus.error);
  });
}
