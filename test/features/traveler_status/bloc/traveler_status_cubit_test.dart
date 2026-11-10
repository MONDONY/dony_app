import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/traveler_status/bloc/traveler_status_cubit.dart';
import 'package:dony/features/traveler_status/data/traveler_status.dart';
import 'package:dony/features/traveler_status/data/traveler_status_declaration.dart';
import 'package:dony/features/traveler_status/data/traveler_status_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRepository extends Mock implements TravelerStatusRepository {}

class MockAnalytics extends Mock implements AnalyticsService {}

TravelerStatusDeclaration _declared(TravelerStatus status) =>
    TravelerStatusDeclaration(
      status: status,
      declaredAt: DateTime.utc(2026, 11),
    );

void main() {
  late MockRepository repository;
  late MockAnalytics analytics;

  setUpAll(() => registerFallbackValue(TravelerStatus.individual));

  setUp(() {
    repository = MockRepository();
    analytics = MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  TravelerStatusCubit build() => TravelerStatusCubit(repository, analytics);

  group('état initial', () {
    test('rien n\'est présélectionné et on ne peut pas continuer', () {
      final cubit = build();
      expect(cubit.state, isA<TravelerStatusInitial>());
      expect(cubit.state.form.choice, isNull);
      expect(cubit.state.form.canContinue, isFalse);
      expect(cubit.state.form.canSubmit, isFalse);
    });

    test('continue() sans choix ne fait rien', () {
      final cubit = build()..continueToDetails();
      expect(cubit.state, isA<TravelerStatusInitial>());
    });
  });

  group('choix et navigation', () {
    blocTest<TravelerStatusCubit, TravelerStatusState>(
      'choisir un statut active « Continuer » sans changer d\'étape',
      build: build,
      act: (c) => c.choose(TravelerStatus.individual),
      verify: (c) {
        final s = c.state as TravelerStatusEditing;
        expect(s.choice, TravelerStatus.individual);
        expect(s.detailsStep, isFalse);
        expect(s.canContinue, isTrue);
      },
    );

    blocTest<TravelerStatusCubit, TravelerStatusState>(
      'continuer ouvre le détail, retour revient au choix en gardant le statut',
      build: build,
      act: (c) => c
        ..choose(TravelerStatus.professional)
        ..continueToDetails()
        ..back(),
      verify: (c) {
        final s = c.state as TravelerStatusEditing;
        expect(s.detailsStep, isFalse);
        expect(s.choice, TravelerStatus.professional);
      },
    );

    test('changer de statut efface la confirmation et les champs pro', () {
      final c = build()
        ..choose(TravelerStatus.individual)
        ..continueToDetails()
        ..setConfirmed(true)
        ..back()
        ..choose(TravelerStatus.professional)
        ..continueToDetails()
        ..updateBusiness(
          name: 'X SARL',
          registrationNumber: '12345678',
          country: 'CI',
        )
        ..back()
        ..choose(TravelerStatus.individual);
      final s = c.state as TravelerStatusEditing;
      expect(s.confirmed, isFalse);
      expect(s.businessName, isEmpty);
      expect(s.registrationNumber, isEmpty);
      expect(s.country, isNull);
    });
  });

  group('validation locale', () {
    test('particulier : « Enregistrer » exige la case cochée', () {
      final c = build()
        ..choose(TravelerStatus.individual)
        ..continueToDetails();
      expect((c.state as TravelerStatusEditing).canSubmit, isFalse);
      c.setConfirmed(true);
      expect((c.state as TravelerStatusEditing).canSubmit, isTrue);
      c.setConfirmed(false);
      expect((c.state as TravelerStatusEditing).canSubmit, isFalse);
    });

    test('professionnel : numéro de moins de 4 caractères, bouton inactif', () {
      final c = build()
        ..choose(TravelerStatus.professional)
        ..continueToDetails()
        ..updateBusiness(
          name: 'Diallo Express',
          registrationNumber: '123',
          country: 'CI',
        );
      expect((c.state as TravelerStatusEditing).canSubmit, isFalse);
      c.updateBusiness(registrationNumber: '1234');
      expect((c.state as TravelerStatusEditing).canSubmit, isTrue);
    });

    test('professionnel : chaque champ est exigé', () {
      final c = build()
        ..choose(TravelerStatus.professional)
        ..continueToDetails()
        ..updateBusiness(name: 'D', registrationNumber: '12345', country: 'CI');
      expect(
        (c.state as TravelerStatusEditing).canSubmit,
        isFalse,
      ); // nom 1 caractère
      c.updateBusiness(name: 'Di');
      expect((c.state as TravelerStatusEditing).canSubmit, isTrue);
      c.updateBusiness(country: '');
      expect(
        (c.state as TravelerStatusEditing).canSubmit,
        isFalse,
      ); // pays vidé
    });

    test(
      'professionnel : numéro avec un caractère interdit, bouton inactif',
      () {
        final c = build()
          ..choose(TravelerStatus.professional)
          ..continueToDetails()
          ..updateBusiness(
            name: 'Diallo',
            registrationNumber: '12<script>',
            country: 'CI',
          );
        expect((c.state as TravelerStatusEditing).canSubmit, isFalse);
      },
    );

    test('professionnel : numéro de plus de 40 caractères, bouton inactif', () {
      final c = build()
        ..choose(TravelerStatus.professional)
        ..continueToDetails()
        ..updateBusiness(
          name: 'Diallo',
          registrationNumber: 'A' * 41,
          country: 'CI',
        );
      expect((c.state as TravelerStatusEditing).canSubmit, isFalse);
    });

    test('submit() sans formulaire valide n\'appelle pas le back', () async {
      final c = build()
        ..choose(TravelerStatus.professional)
        ..continueToDetails();
      await c.submit();
      verifyNever(
        () => repository.declare(
          status: any(named: 'status'),
          personalUseConfirmed: any(named: 'personalUseConfirmed'),
          businessName: any(named: 'businessName'),
          registrationNumber: any(named: 'registrationNumber'),
          country: any(named: 'country'),
        ),
      );
      expect(c.state, isA<TravelerStatusEditing>());
    });
  });

  group('envoi', () {
    blocTest<TravelerStatusCubit, TravelerStatusState>(
      'particulier : submitting puis success, confirmation transmise',
      build: () {
        when(
          () => repository.declare(
            status: TravelerStatus.individual,
            personalUseConfirmed: true,
          ),
        ).thenAnswer((_) async => _declared(TravelerStatus.individual));
        return build();
      },
      act: (c) async {
        c
          ..choose(TravelerStatus.individual)
          ..continueToDetails()
          ..setConfirmed(true);
        await c.submit();
      },
      skip: 3,
      expect: () => [
        isA<TravelerStatusSubmitting>(),
        isA<TravelerStatusSuccess>().having(
          (s) => s.declaration.status,
          'statut',
          TravelerStatus.individual,
        ),
      ],
      verify: (_) {
        verify(
          () => analytics.logEvent(
            'traveler_status_declared',
            properties: {'status': 'INDIVIDUAL'},
          ),
        ).called(1);
      },
    );

    blocTest<TravelerStatusCubit, TravelerStatusState>(
      'professionnel : raison sociale, numéro et pays envoyés, jamais dans les analytics',
      build: () {
        when(
          () => repository.declare(
            status: TravelerStatus.professional,
            businessName: 'Diallo Express SARL',
            registrationNumber: 'CI-ABJ-2021-B-12345',
            country: 'CI',
          ),
        ).thenAnswer((_) async => _declared(TravelerStatus.professional));
        return build();
      },
      act: (c) async {
        c
          ..choose(TravelerStatus.professional)
          ..continueToDetails()
          ..updateBusiness(
            name: 'Diallo Express SARL',
            registrationNumber: 'CI-ABJ-2021-B-12345',
            country: 'CI',
          );
        await c.submit();
      },
      skip: 3,
      expect: () => [
        isA<TravelerStatusSubmitting>(),
        isA<TravelerStatusSuccess>(),
      ],
      verify: (_) {
        final props =
            verify(
                  () => analytics.logEvent(
                    'traveler_status_declared',
                    properties: captureAny(named: 'properties'),
                  ),
                ).captured.single
                as Map<String, Object?>;
        expect(props, {'status': 'PROFESSIONAL'});
      },
    );

    test(
      '422 du back : failure avec le code, le formulaire est conservé',
      () async {
        when(
          () => repository.declare(
            status: any(named: 'status'),
            personalUseConfirmed: any(named: 'personalUseConfirmed'),
            businessName: any(named: 'businessName'),
            registrationNumber: any(named: 'registrationNumber'),
            country: any(named: 'country'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/traveler-status/me'),
            error: const ValidationException(
              'invalide',
              code: 'traveler-status-invalid',
            ),
          ),
        );
        final c = build()
          ..choose(TravelerStatus.professional)
          ..continueToDetails()
          ..updateBusiness(
            name: 'Diallo',
            registrationNumber: '12345',
            country: 'CI',
          );

        await c.submit();

        final s = c.state as TravelerStatusFailure;
        expect(s.code, 'traveler-status-invalid');
        expect(s.form.businessName, 'Diallo');
        expect(s.form.detailsStep, isTrue);
        verifyNever(
          () => analytics.logEvent(
            'traveler_status_declared',
            properties: any(named: 'properties'),
          ),
        );
      },
    );

    test('échec 422 : événement d\'échec avec le code, jamais une valeur '
        'saisie', () async {
      when(
        () => repository.declare(
          status: any(named: 'status'),
          personalUseConfirmed: any(named: 'personalUseConfirmed'),
          businessName: any(named: 'businessName'),
          registrationNumber: any(named: 'registrationNumber'),
          country: any(named: 'country'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/traveler-status/me'),
          error: const ValidationException(
            'invalide',
            code: 'traveler-status-invalid',
          ),
        ),
      );
      final c = build()
        ..choose(TravelerStatus.professional)
        ..continueToDetails()
        ..updateBusiness(
          name: 'Diallo Express SARL',
          registrationNumber: 'CI-ABJ-2021-B-12345',
          country: 'CI',
        );

      await c.submit();

      final captured = verify(
        () => analytics.logEvent(
          'traveler_status_declare_failed',
          properties: captureAny(named: 'properties'),
        ),
      ).captured;
      expect(captured, hasLength(1));
      final props = captured.single as Map<String, Object?>;
      expect(props, {
        'status': 'PROFESSIONAL',
        'error_code': 'traveler-status-invalid',
      });
      expect(props.values.join(), isNot(contains('Diallo')));
      expect(props.values.join(), isNot(contains('12345')));
      expect(props.values.join(), isNot(contains('CI-')));
    });

    test('échec sans code : error_code vaut unknown', () async {
      when(
        () => repository.declare(
          status: any(named: 'status'),
          personalUseConfirmed: any(named: 'personalUseConfirmed'),
          businessName: any(named: 'businessName'),
          registrationNumber: any(named: 'registrationNumber'),
          country: any(named: 'country'),
        ),
      ).thenThrow(const NetworkException('coupure'));
      final c = build()
        ..choose(TravelerStatus.individual)
        ..continueToDetails()
        ..setConfirmed(true);

      await c.submit();

      verify(
        () => analytics.logEvent(
          'traveler_status_declare_failed',
          properties: {'status': 'INDIVIDUAL', 'error_code': 'unknown'},
        ),
      ).called(1);
    });

    test('après un échec, on peut corriger et renvoyer', () async {
      var calls = 0;
      when(
        () => repository.declare(
          status: any(named: 'status'),
          personalUseConfirmed: any(named: 'personalUseConfirmed'),
          businessName: any(named: 'businessName'),
          registrationNumber: any(named: 'registrationNumber'),
          country: any(named: 'country'),
        ),
      ).thenAnswer((_) async {
        calls++;
        if (calls == 1) throw const NetworkException('coupure');
        return _declared(TravelerStatus.individual);
      });
      final c = build()
        ..choose(TravelerStatus.individual)
        ..continueToDetails()
        ..setConfirmed(true);

      await c.submit();
      expect(c.state, isA<TravelerStatusFailure>());
      expect((c.state as TravelerStatusFailure).code, 'unknown');

      await c.submit();
      expect(c.state, isA<TravelerStatusSuccess>());
    });

    test('double appui : un seul appel au back', () async {
      when(
        () => repository.declare(
          status: any(named: 'status'),
          personalUseConfirmed: any(named: 'personalUseConfirmed'),
          businessName: any(named: 'businessName'),
          registrationNumber: any(named: 'registrationNumber'),
          country: any(named: 'country'),
        ),
      ).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return _declared(TravelerStatus.individual);
      });
      final c = build()
        ..choose(TravelerStatus.individual)
        ..continueToDetails()
        ..setConfirmed(true);

      await Future.wait([c.submit(), c.submit()]);

      verify(
        () => repository.declare(
          status: TravelerStatus.individual,
          personalUseConfirmed: true,
        ),
      ).called(1);
    });
  });
}
