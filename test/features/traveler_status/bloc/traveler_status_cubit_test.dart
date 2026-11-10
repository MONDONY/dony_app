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

TravelerStatusDeclaration _declared() => TravelerStatusDeclaration(
  status: TravelerStatus.individual,
  declaredAt: DateTime.utc(2026, 11),
);

void main() {
  late MockRepository repository;
  late MockAnalytics analytics;

  setUp(() {
    repository = MockRepository();
    analytics = MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  TravelerStatusCubit build() => TravelerStatusCubit(repository, analytics);

  test('état initial : rien n\'est envoyé', () {
    expect(build().state, isA<TravelerStatusInitial>());
    verifyNever(() => repository.declareIndividual());
  });

  group('chooseIndividual', () {
    blocTest<TravelerStatusCubit, TravelerStatusState>(
      'succès : envoi, puis déclaration reçue, événement avec le statut seul',
      build: () {
        when(
          () => repository.declareIndividual(),
        ).thenAnswer((_) async => _declared());
        return build();
      },
      act: (c) => c.chooseIndividual(),
      expect: () => [
        isA<TravelerStatusSubmitting>(),
        isA<TravelerStatusSuccess>().having(
          (s) => s.declaration.status,
          'status',
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
      'refus du back : échec avec son code, événement d\'échec avec '
      'error_code seul',
      build: () {
        when(() => repository.declareIndividual()).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/traveler-status/me'),
            error: const ValidationException(
              'invalide',
              code: 'traveler-status-invalid',
            ),
          ),
        );
        return build();
      },
      act: (c) => c.chooseIndividual(),
      expect: () => [
        isA<TravelerStatusSubmitting>(),
        isA<TravelerStatusFailure>().having(
          (s) => s.code,
          'code',
          'traveler-status-invalid',
        ),
      ],
      verify: (_) {
        final captured = verify(
          () => analytics.logEvent(
            'traveler_status_declare_failed',
            properties: captureAny(named: 'properties'),
          ),
        ).captured;
        expect(captured.single, {
          'status': 'INDIVIDUAL',
          'error_code': 'traveler-status-invalid',
        });
      },
    );

    test('échec sans code : error_code vaut unknown', () async {
      when(
        () => repository.declareIndividual(),
      ).thenThrow(const NetworkException('coupure'));
      final c = build();

      await c.chooseIndividual();

      expect(c.state, isA<TravelerStatusFailure>());
      verify(
        () => analytics.logEvent(
          'traveler_status_declare_failed',
          properties: {'status': 'INDIVIDUAL', 'error_code': 'unknown'},
        ),
      ).called(1);
    });

    test('après un échec, on peut renvoyer', () async {
      var calls = 0;
      when(() => repository.declareIndividual()).thenAnswer((_) async {
        calls++;
        if (calls == 1) throw const NetworkException('coupure');
        return _declared();
      });
      final c = build();

      await c.chooseIndividual();
      expect(c.state, isA<TravelerStatusFailure>());

      await c.chooseIndividual();
      expect(c.state, isA<TravelerStatusSuccess>());
    });

    test('double appui : un seul appel au back', () async {
      when(() => repository.declareIndividual()).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return _declared();
      });
      final c = build();

      await Future.wait([c.chooseIndividual(), c.chooseIndividual()]);

      verify(() => repository.declareIndividual()).called(1);
    });

    test('une fois la déclaration reçue, un nouvel appui est ignoré', () async {
      when(
        () => repository.declareIndividual(),
      ).thenAnswer((_) async => _declared());
      final c = build();

      await c.chooseIndividual();
      await c.chooseIndividual();

      verify(() => repository.declareIndividual()).called(1);
    });

    test('cubit fermé pendant l\'envoi : aucun état émis après', () async {
      when(() => repository.declareIndividual()).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return _declared();
      });
      final c = build();

      final pending = c.chooseIndividual();
      await c.close();
      await pending;

      verifyNever(
        () => analytics.logEvent(
          'traveler_status_declared',
          properties: any(named: 'properties'),
        ),
      );
    });
  });
}
