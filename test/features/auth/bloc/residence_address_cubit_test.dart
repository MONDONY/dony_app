import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/residence_address_cubit.dart';
import 'package:dony/features/auth/data/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

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

  blocTest<ResidenceAddressCubit, ResidenceAddressState>(
    'enregistre puis émet Success',
    build: () {
      when(
        () => repo.updateResidenceAddress(
          street: any(named: 'street'),
          line2: any(named: 'line2'),
          postalCode: any(named: 'postalCode'),
          city: any(named: 'city'),
        ),
      ).thenAnswer((_) async {});
      return ResidenceAddressCubit(repo, analytics);
    },
    act: (c) => c.submit(
      street: '12 rue des Lilas',
      postalCode: '75011',
      city: 'Paris',
    ),
    expect: () => [
      isA<ResidenceAddressSaving>(),
      isA<ResidenceAddressSuccess>(),
    ],
  );

  blocTest<ResidenceAddressCubit, ResidenceAddressState>(
    'émet Error avec un message utilisable quand le réseau échoue',
    build: () {
      when(
        () => repo.updateResidenceAddress(
          street: any(named: 'street'),
          line2: any(named: 'line2'),
          postalCode: any(named: 'postalCode'),
          city: any(named: 'city'),
        ),
      ).thenThrow(Exception('boom'));
      return ResidenceAddressCubit(repo, analytics);
    },
    act: (c) => c.submit(street: 'x', postalCode: 'y', city: 'z'),
    expect: () => [isA<ResidenceAddressSaving>(), isA<ResidenceAddressError>()],
  );

  blocTest<ResidenceAddressCubit, ResidenceAddressState>(
    'skip marque l\'onboarding vu et n\'échoue jamais',
    build: () {
      when(() => repo.markOnboardingSeen()).thenThrow(Exception('hors ligne'));
      return ResidenceAddressCubit(repo, analytics);
    },
    act: (c) => c.skip(),
    expect: () => [
      isA<ResidenceAddressSaving>(),
      isA<ResidenceAddressSuccess>(),
    ],
  );

  test('aucune PII dans les properties analytics', () async {
    when(
      () => repo.updateResidenceAddress(
        street: any(named: 'street'),
        line2: any(named: 'line2'),
        postalCode: any(named: 'postalCode'),
        city: any(named: 'city'),
      ),
    ).thenAnswer((_) async {});

    await ResidenceAddressCubit(
      repo,
      analytics,
    ).submit(street: '12 rue des Lilas', postalCode: '75011', city: 'Paris');

    final captured = verify(
      () => analytics.logEvent(
        captureAny(),
        properties: captureAny(named: 'properties'),
      ),
    ).captured;
    expect(captured.toString(), isNot(contains('Lilas')));
    expect(captured.toString(), isNot(contains('75011')));
    expect(captured.toString(), isNot(contains('Paris')));
    expect(
      captured.toString(),
      contains(AnalyticsEvents.onboardingStepCompleted),
    );
  });
}
