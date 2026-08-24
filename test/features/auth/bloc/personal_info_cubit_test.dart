import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/personal_info_cubit.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/auth/data/repositories/auth_repository.dart';
import 'package:dony/features/auth/presentation/onboarding_step.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

const _user = UserModel(
  id: 'u1',
  roles: ['TRAVELER'],
  kycStatus: 'NONE',
  status: 'ACTIVE',
);

void main() {
  late _MockAuthRepository repo;
  late _MockAnalytics analytics;

  setUp(() {
    repo = _MockAuthRepository();
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  void stubUpdate() {
    when(
      () => repo.updateProfile(
        firstName: any(named: 'firstName'),
        lastName: any(named: 'lastName'),
      ),
    ).thenAnswer((_) async => _user);
  }

  blocTest<PersonalInfoCubit, PersonalInfoState>(
    'enregistre puis émet Success',
    build: () {
      stubUpdate();
      return PersonalInfoCubit(repo, analytics);
    },
    act: (c) => c.submit(firstName: 'Awa', lastName: 'Diallo'),
    expect: () => [isA<PersonalInfoSaving>(), isA<PersonalInfoSuccess>()],
    verify: (_) => verify(
      () => repo.updateProfile(firstName: 'Awa', lastName: 'Diallo'),
    ).called(1),
  );

  blocTest<PersonalInfoCubit, PersonalInfoState>(
    'émet Error avec un message utilisable quand le réseau échoue',
    build: () {
      when(
        () => repo.updateProfile(
          firstName: any(named: 'firstName'),
          lastName: any(named: 'lastName'),
        ),
      ).thenThrow(Exception('boom'));
      return PersonalInfoCubit(repo, analytics);
    },
    act: (c) => c.submit(firstName: 'Awa', lastName: 'Diallo'),
    expect: () => [isA<PersonalInfoSaving>(), isA<PersonalInfoError>()],
  );

  blocTest<PersonalInfoCubit, PersonalInfoState>(
    'n\'écrit ni date de naissance ni adresse : Stripe les demande lui-même',
    build: () {
      stubUpdate();
      return PersonalInfoCubit(repo, analytics);
    },
    act: (c) => c.submit(firstName: 'Awa', lastName: 'Diallo'),
    // `updateProfile` n'expose plus ces champs, et l'écriture d'adresse
    // n'existe plus du tout côté application : ce test verrouille le fait
    // qu'aucun second appel ne parte vers le profil pendant cette étape.
    verify: (_) {
      verify(
        () => repo.updateProfile(firstName: 'Awa', lastName: 'Diallo'),
      ).called(1);
      verifyNoMoreInteractions(repo);
    },
  );

  blocTest<PersonalInfoCubit, PersonalInfoState>(
    'skip n\'échoue jamais et ne pose pas onboarding_seen_at',
    build: () => PersonalInfoCubit(repo, analytics),
    act: (c) => c.skip(),
    expect: () => [isA<PersonalInfoSaving>(), isA<PersonalInfoSuccess>()],
    // Il reste l'identité et les paiements après cette étape : poser la date
    // ici empêcherait le parcours de se réimposer au prochain lancement.
    verify: (_) => verifyNever(() => repo.markOnboardingSeen()),
  );

  // Le cubit écrit `'personal_info'` en dur plutôt que d'importer
  // `OnboardingStep` : `bloc/` ne dépend jamais de `presentation/`, et aucun
  // autre cubit du dossier ne le fait. Ce test est le garde-fou qui remplace
  // la dépendance — renommer le wireName sans toucher au cubit casse ici, au
  // lieu de produire en silence un `step` incohérent avec celui qu'émet
  // `resolvePostSignupRoute` pour la même étape.
  test('le step émis reste celui de l\'énumération', () async {
    stubUpdate();
    final cubit = PersonalInfoCubit(repo, analytics);

    await cubit.submit(firstName: 'Awa', lastName: 'Diallo');
    await cubit.skip();

    final captured = verify(
      () => analytics.logEvent(
        any(),
        properties: captureAny(named: 'properties'),
      ),
    ).captured.whereType<Map<String, dynamic>>();

    final steps = captured
        .where((p) => p.containsKey('step'))
        .map((p) => p['step'])
        .toSet();
    expect(steps, {OnboardingStep.personalInfo.wireName});
  });

  test('aucune PII dans les properties analytics', () async {
    stubUpdate();

    await PersonalInfoCubit(
      repo,
      analytics,
    ).submit(firstName: 'Awa', lastName: 'Diallo');

    final captured = verify(
      () => analytics.logEvent(
        captureAny(),
        properties: captureAny(named: 'properties'),
      ),
    ).captured;
    expect(captured.toString(), isNot(contains('Awa')));
    expect(captured.toString(), isNot(contains('Diallo')));
    expect(
      captured.toString(),
      contains(AnalyticsEvents.onboardingStepCompleted),
    );
  });
}
