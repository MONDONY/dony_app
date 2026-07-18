import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/cancellation/data/models/cancellation_model.dart';
import 'package:dony/features/cancellation/presentation/screens/rematch_search_screen.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockCancellationBloc extends MockBloc<CancellationEvent, CancellationState>
    implements CancellationBloc {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

final _suggestions = [
  RematchSuggestionModel(
    suggestionId: 'sug-1',
    announcementId: 'ann-2',
    departureCity: 'Paris',
    arrivalCity: 'Dakar',
    departureDate: DateTime(2024, 2, 1),
    availableKg: 5.0,
    pricePerKg: 12.0,
    travelerFirstName: 'Awa',
    travelerRating: 4.8,
    travelerRatingCount: 12,
  ),
];

Widget _wrap(CancellationBloc bloc, {required String cancellationId}) => MaterialApp(
      home: BlocProvider<CancellationBloc>.value(
        value: bloc,
        child: RematchSearchScreen(cancellationId: cancellationId),
      ),
    );

/// Variant avec un vrai [GoRouter] — nécessaire pour les tests qui exercent
/// `context.push(...)` (tap sur une TravelerCard → flux de création de bid).
Widget _wrapWithRouter(CancellationBloc bloc, {required String cancellationId}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, _) => BlocProvider<CancellationBloc>.value(
          value: bloc,
          child: RematchSearchScreen(cancellationId: cancellationId),
        ),
      ),
      GoRoute(
        path: '/search/:id/bid',
        builder: (_, state) => Scaffold(
          body: Text('Bid create ${state.pathParameters['id']}'),
        ),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  setUpAll(() async {
    registerFallbackValue(RematchSuggestionsRequested('fallback'));
    await initializeDateFormatting('fr');
  });

  late _MockCancellationBloc bloc;
  late _MockAnalyticsService analytics;

  setUp(() {
    bloc = _MockCancellationBloc();
    analytics = _MockAnalyticsService();

    when(() => analytics.logEvent(any(), properties: any(named: 'properties')))
        .thenAnswer((_) async {});

    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    getIt.registerLazySingleton<AnalyticsService>(() => analytics);
  });

  tearDown(() {
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
  });

  testWidgets('déclenche le fetch avec le bon cancellationId au démarrage', (tester) async {
    when(() => bloc.state).thenReturn(CancellationInitial());

    await tester.pumpWidget(_wrap(bloc, cancellationId: 'canc-42'));

    verify(() => bloc.add(any(
          that: isA<RematchSuggestionsRequested>()
              .having((e) => e.cancellationId, 'cancellationId', 'canc-42'),
        ))).called(1);
  });

  testWidgets('affiche un loader pendant CancellationLoading', (tester) async {
    when(() => bloc.state).thenReturn(CancellationLoading());

    await tester.pumpWidget(_wrap(bloc, cancellationId: 'canc-1'));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('rend une TravelerCard par suggestion avec la note voyageur', (tester) async {
    when(() => bloc.state).thenReturn(RematchSuggestionsLoaded(_suggestions));

    await tester.pumpWidget(_wrap(bloc, cancellationId: 'canc-1'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(TravelerCard), findsOneWidget);
    expect(find.text('Paris'), findsOneWidget);
    expect(find.text('Dakar'), findsOneWidget);
    // Note voyageur affichée car travelerRating non null.
    expect(find.text('4.8'), findsOneWidget);
    expect(find.text('1 voyageur disponible'), findsOneWidget);
    // Pas de compteur d'expéditeurs remboursés dans le chemin self-fetching.
    expect(find.text('Votre remboursement est en cours.'), findsOneWidget);
  });

  testWidgets('sans note voyageur, la TravelerCard affiche le repli "-"', (tester) async {
    final noRating = [
      RematchSuggestionModel(
        suggestionId: 'sug-2',
        announcementId: 'ann-3',
        departureCity: 'Lyon',
        arrivalCity: 'Abidjan',
        departureDate: DateTime(2024, 3, 1),
        availableKg: 8.0,
        pricePerKg: 10.0,
      ),
    ];
    when(() => bloc.state).thenReturn(RematchSuggestionsLoaded(noRating));

    await tester.pumpWidget(_wrap(bloc, cancellationId: 'canc-1'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(TravelerCard), findsOneWidget);
    expect(find.text('-'), findsOneWidget);
  });

  testWidgets('affiche un état vide explicite quand aucune suggestion', (tester) async {
    when(() => bloc.state).thenReturn(RematchSuggestionsLoaded(const []));

    await tester.pumpWidget(_wrap(bloc, cancellationId: 'canc-1'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Aucun voyageur disponible'), findsOneWidget);
    expect(
      find.text(
          'Aucun voyageur disponible dans les 72h — votre remboursement est traité'),
      findsOneWidget,
    );
  });

  testWidgets('affiche une erreur avec retry sur CancellationError, et le retry redispatch',
      (tester) async {
    when(() => bloc.state)
        .thenReturn(CancellationError(const NetworkException('boom')));

    await tester.pumpWidget(_wrap(bloc, cancellationId: 'canc-1'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Réessayer'), findsOneWidget);

    // Le fetch initial (initState) a déjà eu lieu — on réinitialise le compteur
    // d'appels avant de taper "Réessayer" pour ne vérifier que le retry.
    clearInteractions(bloc);

    await tester.tap(find.text('Réessayer'));
    await tester.pump();

    verify(() => bloc.add(any(
          that: isA<RematchSuggestionsRequested>()
              .having((e) => e.cancellationId, 'cancellationId', 'canc-1'),
        ))).called(1);
  });

  testWidgets(
      'tap sur la TravelerCard tire rematch_accepted (count) puis pousse le flux de bid',
      (tester) async {
    when(() => bloc.state).thenReturn(RematchSuggestionsLoaded(_suggestions));

    await tester.pumpWidget(_wrapWithRouter(bloc, cancellationId: 'canc-1'));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byType(TravelerCard));
    await tester.pumpAndSettle();

    verify(() => analytics.logEvent(
          AnalyticsEvents.rematchAccepted,
          properties: {'count': 1},
        )).called(1);
    expect(find.text('Bid create ann-2'), findsOneWidget);
  });
}
