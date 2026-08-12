import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/incident_report/bloc/incident_report_cubit.dart';
import 'package:dony/features/incident_report/data/repositories/incident_report_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class MockIncidentReportRepository extends Mock
    implements IncidentReportRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(IncidentTargetType.app);
  });

  late MockIncidentReportRepository repository;
  late MockAnalyticsBackend analyticsBackend;

  setUp(() {
    repository = MockIncidentReportRepository();
    analyticsBackend = MockAnalyticsBackend();
  });

  IncidentReportCubit build() =>
      IncidentReportCubit(repository, makeDisabledAnalytics(analyticsBackend));

  group('submit', () {
    blocTest<IncidentReportCubit, IncidentReportState>(
      'émet Submitting puis Success avec l\'id du signalement',
      build: () {
        when(
          () => repository.submit(
            targetType: IncidentTargetType.app,
            targetId: null,
            reason: 'Bug de l\'application',
            description: 'Crash',
            photoKeys: const ['k1'],
          ),
        ).thenAnswer((_) async => 'r-7');
        return build();
      },
      act: (cubit) => cubit.submit(
        targetType: IncidentTargetType.app,
        reason: 'Bug de l\'application',
        description: 'Crash',
        photoKeys: const ['k1'],
      ),
      expect: () => [
        isA<IncidentReportSubmitting>(),
        isA<IncidentReportSuccess>().having(
          (s) => s.reportId,
          'reportId',
          'r-7',
        ),
      ],
    );

    blocTest<IncidentReportCubit, IncidentReportState>(
      'émet Error avec le message de l\'AppException',
      build: () {
        when(
          () => repository.submit(
            targetType: any(named: 'targetType'),
            targetId: any(named: 'targetId'),
            reason: any(named: 'reason'),
            description: any(named: 'description'),
            photoKeys: any(named: 'photoKeys'),
          ),
        ).thenThrow(const ValidationException('Le motif est obligatoire'));
        return build();
      },
      act: (cubit) =>
          cubit.submit(targetType: IncidentTargetType.app, reason: ''),
      expect: () => [
        isA<IncidentReportSubmitting>(),
        isA<IncidentReportError>().having(
          (s) => s.message,
          'message',
          'Le motif est obligatoire',
        ),
      ],
    );

    blocTest<IncidentReportCubit, IncidentReportState>(
      'émet Error générique sur exception inconnue',
      build: () {
        when(
          () => repository.submit(
            targetType: any(named: 'targetType'),
            targetId: any(named: 'targetId'),
            reason: any(named: 'reason'),
            description: any(named: 'description'),
            photoKeys: any(named: 'photoKeys'),
          ),
        ).thenThrow(Exception('boom'));
        return build();
      },
      act: (cubit) =>
          cubit.submit(targetType: IncidentTargetType.app, reason: 'Autre'),
      expect: () => [
        isA<IncidentReportSubmitting>(),
        isA<IncidentReportError>(),
      ],
    );

    blocTest<IncidentReportCubit, IncidentReportState>(
      'ignore un second submit pendant Submitting',
      build: () {
        when(
          () => repository.submit(
            targetType: any(named: 'targetType'),
            targetId: any(named: 'targetId'),
            reason: any(named: 'reason'),
            description: any(named: 'description'),
            photoKeys: any(named: 'photoKeys'),
          ),
        ).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return 'r-1';
        });
        return build();
      },
      act: (cubit) async {
        unawaited(
          cubit.submit(targetType: IncidentTargetType.app, reason: 'Autre'),
        );
        await cubit.submit(targetType: IncidentTargetType.app, reason: 'Autre');
      },
      wait: const Duration(milliseconds: 100),
      expect: () => [
        isA<IncidentReportSubmitting>(),
        isA<IncidentReportSuccess>(),
      ],
      verify: (_) {
        verify(
          () => repository.submit(
            targetType: any(named: 'targetType'),
            targetId: any(named: 'targetId'),
            reason: any(named: 'reason'),
            description: any(named: 'description'),
            photoKeys: any(named: 'photoKeys'),
          ),
        ).called(1);
      },
    );
  });
}
