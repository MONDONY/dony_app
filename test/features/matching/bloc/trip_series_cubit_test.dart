import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/trip_series_cubit.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/trip_series_result.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/trip_templates/data/models/trip_template.dart';
import 'package:dony/features/trip_templates/data/repositories/trip_template_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnnouncements extends Mock implements AnnouncementRepository {}

class _MockTemplates extends Mock implements TripTemplateRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

AnnouncementModel _trip({String id = 'a1', DateTime? date}) =>
    AnnouncementModel(
      id: id,
      travelerId: 't1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: date ?? DateTime(2026, 11, 20),
      availableKg: 23,
      totalKg: 23,
      pricePerKg: 8,
      status: 'ACTIVE',
      createdAt: DateTime(2026, 10),
      updatedAt: DateTime(2026, 10),
    );

TripSeriesResult _result({int created = 1, List<TripSeriesFailure>? failed}) =>
    TripSeriesResult(
      seriesId: 's1',
      created: [for (var i = 0; i < created; i++) _trip(id: 'c$i')],
      failed: failed ?? const [],
    );

TripTemplate _template() => const TripTemplate(
  id: 'tpl',
  label: 'x',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  transportMode: 'PLANE',
  capacityUnit: 'SUITCASE_23KG',
  availableKg: 23,
  pricePerKg: 8,
  acceptedCategories: [],
);

void main() {
  late _MockAnnouncements announcements;
  late _MockTemplates templates;
  late _MockAnalytics analytics;
  final today = DateTime(2026, 10, 15, 9);

  setUpAll(() => registerFallbackValue(<DateTime>[]));

  setUp(() {
    announcements = _MockAnnouncements();
    templates = _MockTemplates();
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    when(() => analytics.logEvent(any())).thenAnswer((_) async {});
  });

  TripSeriesCubit build({DateTime? date}) => TripSeriesCubit(
    _trip(date: date),
    announcements,
    templates,
    analytics,
    now: () => today,
  );

  void stubSeries(Future<TripSeriesResult> Function() answer) => when(
    () => announcements.createSeries(
      any(),
      dates: any(named: 'dates'),
      saveAsDraft: any(named: 'saveAsDraft'),
    ),
  ).thenAnswer((_) => answer());

  group('calendrier', () {
    test(
      'ouvre sur le mois du trajet, ou sur le mois courant s\'il est passé',
      () {
        expect(build().state.visibleMonth, DateTime(2026, 11));
        expect(
          build(date: DateTime(2026, 9, 2)).state.visibleMonth,
          DateTime(2026, 10),
        );
      },
    );

    test('jours passés et jour du trajet ne se cochent pas', () {
      final cubit = build();
      expect(cubit.sourceDay, DateTime(2026, 11, 20));
      expect(cubit.isSelectable(DateTime(2026, 10, 14)), isFalse);
      expect(cubit.isSelectable(DateTime(2026, 10, 15, 22)), isTrue);
      expect(cubit.isSelectable(DateTime(2026, 11, 20)), isFalse);

      cubit
        ..toggle(DateTime(2026, 10, 14))
        ..toggle(DateTime(2026, 11, 20, 8));
      expect(cubit.state.selected, isEmpty);
    });

    test('cocher, trier, décocher', () {
      final cubit = build()
        ..toggle(DateTime(2026, 12, 4, 15))
        ..toggle(DateTime(2026, 11, 27));
      expect(cubit.state.selected, [
        DateTime(2026, 11, 27),
        DateTime(2026, 12, 4),
      ]);

      cubit.toggle(DateTime(2026, 11, 27));
      expect(cubit.state.selected, [DateTime(2026, 12, 4)]);
    });

    test('pas plus de douze dates', () {
      final cubit = build();
      for (var i = 0; i < 14; i++) {
        cubit.toggle(DateTime(2026, 12, 1 + i));
      }
      expect(cubit.state.selected, hasLength(TripSeriesCubit.maxDates));
    });

    test('mois : pas avant le mois courant, pas au-delà d\'un an', () {
      final cubit = build(date: DateTime(2026, 10, 20));
      expect(cubit.canGoBack, isFalse);
      cubit.showMonth(-1);
      expect(cubit.state.visibleMonth, DateTime(2026, 10));

      for (var i = 0; i < 20; i++) {
        cubit.showMonth(1);
      }
      expect(cubit.state.visibleMonth, DateTime(2027, 10));
      expect(cubit.canGoForward, isFalse);
      expect(cubit.canGoBack, isTrue);

      cubit.showMonth(-1);
      expect(cubit.state.visibleMonth, DateTime(2027, 9));
    });

    test('trackOpened journalise l\'ouverture', () {
      build().trackOpened();
      verify(
        () => analytics.logEvent(AnalyticsEvents.tripSeriesOpened),
      ).called(1);
    });
  });

  group('envoi', () {
    blocTest<TripSeriesCubit, TripSeriesState>(
      'sans date : rien n\'est envoyé',
      build: build,
      act: (c) => c.submit(draft: false),
      expect: () => const <TripSeriesState>[],
    );

    test('réussi : dates envoyées, résultat gardé, analytics', () async {
      stubSeries(
        () async => _result(
          created: 2,
          failed: [
            TripSeriesFailure(
              date: DateTime(2026, 12, 11),
              code: 'draft-limit-reached',
            ),
          ],
        ),
      );
      final cubit = build()
        ..toggle(DateTime(2026, 12, 4))
        ..toggle(DateTime(2026, 11, 27));

      await cubit.submit(draft: true);

      expect(cubit.state.status, TripSeriesStatus.done);
      expect(cubit.state.draft, isTrue);
      expect(cubit.state.result!.created, hasLength(2));
      verify(
        () => announcements.createSeries(
          'a1',
          dates: [DateTime(2026, 11, 27), DateTime(2026, 12, 4)],
          saveAsDraft: true,
        ),
      ).called(1);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.tripSeriesCreated,
          properties: {'count': 2, 'failed': 1, 'draft': true},
        ),
      ).called(1);
    });

    test('toutes les dates refusées : échec avec le code du back', () async {
      stubSeries(
        () async => _result(
          created: 0,
          failed: [
            TripSeriesFailure(
              date: DateTime(2026, 12, 4),
              code: 'kyc-not-verified',
            ),
          ],
        ),
      );
      final cubit = build()..toggle(DateTime(2026, 12, 4));

      await cubit.submit(draft: false);

      expect(cubit.state.status, TripSeriesStatus.failed);
      expect(cubit.state.errorCode, 'kyc-not-verified');
      expect(cubit.state.errorSeq, 1);
    });

    test('rien créé et aucun refus détaillé : code inconnu', () async {
      stubSeries(() async => _result(created: 0));
      final cubit = build()..toggle(DateTime(2026, 12, 4));
      await cubit.submit(draft: false);
      expect(cubit.state.errorCode, 'unknown');
    });

    test('AppException : son code, ou inconnu', () async {
      stubSeries(
        () async =>
            throw const ServerException('refus', 'series-multi-leg-trip'),
      );
      final cubit = build()..toggle(DateTime(2026, 12, 4));
      await cubit.submit(draft: false);
      expect(cubit.state.errorCode, 'series-multi-leg-trip');

      stubSeries(() async => throw const NetworkException('offline'));
      await cubit.submit(draft: false);
      expect(cubit.state.errorCode, 'unknown');
      expect(cubit.state.errorSeq, 2);
    });

    test('erreur inattendue : code inconnu', () async {
      stubSeries(() async => throw StateError('x'));
      final cubit = build()..toggle(DateTime(2026, 12, 4));
      await cubit.submit(draft: false);
      expect(cubit.state.status, TripSeriesStatus.failed);
      expect(cubit.state.errorCode, 'unknown');
    });

    test('pendant l\'envoi : ni second envoi ni changement de dates', () async {
      stubSeries(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return _result();
      });
      final cubit = build()..toggle(DateTime(2026, 12, 4));

      final first = cubit.submit(draft: false);
      cubit.toggle(DateTime(2026, 12, 11));
      await cubit.submit(draft: false);
      await first;

      expect(cubit.state.selected, [DateTime(2026, 12, 4)]);
      verify(
        () => announcements.createSeries(
          any(),
          dates: any(named: 'dates'),
          saveAsDraft: any(named: 'saveAsDraft'),
        ),
      ).called(1);
    });
  });

  group('modèle', () {
    test('nom par défaut : l\'itinéraire', () {
      expect(build().templateName, 'Paris → Dakar');
    });

    test('enregistré avec le nom saisi', () async {
      when(() => templates.create(any())).thenAnswer((_) async => _template());
      final cubit = build()..setTemplateName('  Navette  ');

      await cubit.saveTemplate();

      expect(cubit.state.templateStatus, TripSeriesTemplateStatus.saved);
      final body =
          verify(() => templates.create(captureAny())).captured.single
              as Map<String, dynamic>;
      expect(body['label'], 'Navette');
      expect(body['departureCity'], 'Paris');
      verify(
        () => analytics.logEvent(AnalyticsEvents.tripSeriesTemplateSaved),
      ).called(1);
    });

    test('nom vide : repli sur l\'itinéraire', () async {
      when(() => templates.create(any())).thenAnswer((_) async => _template());
      final cubit = build()..setTemplateName('   ');

      await cubit.saveTemplate();

      final body =
          verify(() => templates.create(captureAny())).captured.single
              as Map<String, dynamic>;
      expect(body['label'], 'Paris → Dakar');
    });

    test('échec : état failed, un second essai reste possible', () async {
      when(
        () => templates.create(any()),
      ).thenThrow(const NetworkException('x'));
      final cubit = build();

      await cubit.saveTemplate();

      expect(cubit.state.templateStatus, TripSeriesTemplateStatus.failed);
    });

    test('pendant l\'enregistrement : pas de doublon', () async {
      when(() => templates.create(any())).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return _template();
      });
      final cubit = build();

      final first = cubit.saveTemplate();
      await cubit.saveTemplate();
      await first;

      verify(() => templates.create(any())).called(1);
    });
  });

  test('fermé pendant l\'envoi : aucun état émis après', () async {
    stubSeries(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return _result();
    });
    final cubit = build()..toggle(DateTime(2026, 12, 4));
    final pending = cubit.submit(draft: false);
    await cubit.close();
    await pending;
    expect(cubit.state.status, TripSeriesStatus.submitting);
  });
}
