import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/trip_series_cubit.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/trip_series_result.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/matching/presentation/widgets/trip_series/trip_series_card.dart';
import 'package:dony/features/matching/presentation/widgets/trip_series/trip_series_sheets.dart';
import 'package:dony/features/trip_templates/data/models/trip_template.dart';
import 'package:dony/features/trip_templates/data/repositories/trip_template_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

class _MockAnnouncements extends Mock implements AnnouncementRepository {}

class _MockTemplates extends Mock implements TripTemplateRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

AnnouncementModel _trip({String id = 'a1'}) => AnnouncementModel(
  id: id,
  travelerId: 't1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2026, 11, 20),
  availableKg: 23,
  totalKg: 23,
  pricePerKg: 8,
  status: 'ACTIVE',
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
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

  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(<DateTime>[]);
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    announcements = _MockAnnouncements();
    templates = _MockTemplates();
    final analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    when(() => analytics.logEvent(any())).thenAnswer((_) async {});
    getIt.registerFactoryParam<TripSeriesCubit, AnnouncementModel, void>(
      (a, _) => TripSeriesCubit(
        a,
        announcements,
        templates,
        analytics,
        now: () => DateTime(2026, 10, 15),
      ),
    );
  });

  tearDown(getIt.reset);

  void stubSeries(TripSeriesResult result) => when(
    () => announcements.createSeries(
      any(),
      dates: any(named: 'dates'),
      saveAsDraft: any(named: 'saveAsDraft'),
    ),
  ).thenAnswer((_) async => result);

  Future<void> pumpCard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      localizedApp(
        Scaffold(
          body: SingleChildScrollView(
            child: TripSeriesCard(announcement: _trip()),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> openCalendar(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('trip-series-open')));
    await tester.pumpAndSettle();
  }

  testWidgets('carte : titre, texte et bouton', (tester) async {
    await pumpCard(tester);
    expect(find.text('Vous faites ce trajet souvent ?'), findsOneWidget);
    expect(find.text('Rendre ce trajet récurrent'), findsOneWidget);
  });

  testWidgets('calendrier : mois du trajet, jour d\'origine non cochable', (
    tester,
  ) async {
    await pumpCard(tester);
    await openCalendar(tester);

    expect(find.text('Quand refaites-vous ce trajet ?'), findsOneWidget);
    expect(find.text('Novembre 2026'), findsOneWidget);
    expect(find.byKey(const Key('trip-series-day-2026-11-20')), findsNothing);
    expect(find.text('Choisissez au moins une date'), findsOneWidget);
    expect(find.byKey(const Key('trip-series-drafts')), findsNothing);

    await tester.tap(find.byKey(const Key('trip-series-next-month')));
    await tester.pumpAndSettle();
    expect(find.text('Décembre 2026'), findsOneWidget);

    await tester.tap(find.byKey(const Key('trip-series-prev-month')));
    await tester.pumpAndSettle();
    expect(find.text('Novembre 2026'), findsOneWidget);
  });

  testWidgets('publier deux dates puis enregistrer le modèle', (tester) async {
    stubSeries(
      TripSeriesResult(
        seriesId: 's1',
        created: [
          _trip(id: 'c1'),
          _trip(id: 'c2'),
        ],
        failed: const [],
      ),
    );
    when(() => templates.create(any())).thenAnswer((_) async => _template());
    await pumpCard(tester);
    await openCalendar(tester);

    await tester.tap(find.byKey(const Key('trip-series-day-2026-11-27')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('trip-series-day-2026-11-30')));
    await tester.pump();
    expect(find.text('Publier 2 trajets'), findsOneWidget);
    expect(find.text('Créer 2 brouillons'), findsOneWidget);

    await tester.tap(find.byKey(const Key('trip-series-publish')));
    await tester.pumpAndSettle();

    verify(
      () => announcements.createSeries(
        'a1',
        dates: [DateTime(2026, 11, 27), DateTime(2026, 11, 30)],
        saveAsDraft: false,
      ),
    ).called(1);
    expect(find.text('2 trajets publiés'), findsOneWidget);
    expect(find.text('En faire un modèle de trajet ?'), findsOneWidget);
    expect(find.byKey(const Key('trip-series-partial')), findsNothing);

    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('trip-template-name')),
        matching: find.byType(TextField),
      ),
      'Navette',
    );
    await tester.tap(find.byKey(const Key('trip-template-save')));
    await tester.pumpAndSettle();

    final body =
        verify(() => templates.create(captureAny())).captured.single
            as Map<String, dynamic>;
    expect(body['label'], 'Navette');
    expect(find.text('Modèle enregistré'), findsOneWidget);
    // La carte reflète la série créée.
    expect(find.text('2 autres dates ajoutées'), findsOneWidget);
    expect(find.byKey(const Key('trip-series-open')), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('brouillons en partie refusés : badge et motif du refus', (
    tester,
  ) async {
    stubSeries(
      TripSeriesResult(
        seriesId: 's1',
        created: [_trip(id: 'c1')],
        failed: [
          TripSeriesFailure(
            date: DateTime(2026, 11, 30),
            code: 'draft-limit-reached',
          ),
        ],
      ),
    );
    await pumpCard(tester);
    await openCalendar(tester);

    await tester.tap(find.byKey(const Key('trip-series-day-2026-11-27')));
    await tester.tap(find.byKey(const Key('trip-series-day-2026-11-30')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('trip-series-drafts')));
    await tester.pumpAndSettle();

    expect(find.text('1 brouillon créé'), findsOneWidget);
    expect(find.byKey(const Key('trip-series-partial')), findsOneWidget);
    expect(find.textContaining('Limite de brouillons'), findsOneWidget);

    await tester.tap(find.byKey(const Key('trip-template-skip')));
    await tester.pumpAndSettle();
    verifyNever(() => templates.create(any()));
    expect(find.text('1 autre date ajoutée'), findsOneWidget);
  });

  testWidgets('tout refusé : message dans le calendrier, qui reste ouvert', (
    tester,
  ) async {
    stubSeries(
      TripSeriesResult(
        seriesId: 's1',
        created: const [],
        failed: [
          TripSeriesFailure(
            date: DateTime(2026, 11, 27),
            code: 'kyc-not-verified',
          ),
        ],
      ),
    );
    await pumpCard(tester);
    await openCalendar(tester);

    await tester.tap(find.byKey(const Key('trip-series-day-2026-11-27')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('trip-series-publish')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trip-series-error')), findsOneWidget);
    expect(find.textContaining('Vérifiez votre identité'), findsOneWidget);
    expect(find.text('Quand refaites-vous ce trajet ?'), findsOneWidget);
  });

  testWidgets('modèle non enregistré : message, la feuille reste ouverte', (
    tester,
  ) async {
    stubSeries(
      TripSeriesResult(
        seriesId: 's1',
        created: [_trip(id: 'c1')],
        failed: const [],
      ),
    );
    when(() => templates.create(any())).thenThrow(Exception('x'));
    await pumpCard(tester);
    await openCalendar(tester);
    await tester.tap(find.byKey(const Key('trip-series-day-2026-11-27')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('trip-series-publish')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('trip-template-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trip-template-error')), findsOneWidget);
    expect(find.text('En faire un modèle de trajet ?'), findsOneWidget);
  });

  testWidgets('tripSeriesErrorText : un texte par code métier', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(
      tripSeriesErrorText(ctx, 'pro-limit-reached'),
      'Limite de trajets du mois atteinte.',
    );
    expect(
      tripSeriesErrorText(ctx, 'stripe-onboarding-incomplete'),
      contains('paiements par carte'),
    );
    expect(tripSeriesErrorText(ctx, null), contains('Réessayez'));
  });
}
