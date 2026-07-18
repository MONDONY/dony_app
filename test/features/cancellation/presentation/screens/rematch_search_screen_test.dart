import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/widgets/dony_feedback_button.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/cancellation/data/models/cancellation_model.dart';
import 'package:dony/features/cancellation/presentation/screens/rematch_search_screen.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockCancellationBloc extends MockBloc<CancellationEvent, CancellationState>
    implements CancellationBloc {}

class _MockAnnouncementBloc extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

UserModel _makeUser() => const UserModel(
      id: 'uid-1',
      phoneNumber: '+33600000000',
      firstName: 'Test',
      lastName: 'User',
      roles: ['ROLE_SENDER'],
      kycStatus: 'VERIFIED',
      status: 'ACTIVE',
    );

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
    travelerAvatarUrl: 'https://s3.example/avatar-awa.jpg',
  ),
];

/// Le VRAI `AnnouncementModel` renvoyé par `GET /announcements/ann-2` — champs
/// distincts du stub de rendu de liste (`_toAnnouncementModel`) pour rendre le
/// test sensible aux mutations : `pricingMode: MIXED` + `priceGridItems` ne
/// sont jamais produits par le stub (toujours `pricingMode: 'KG'` par défaut),
/// et `travelerId`/`traveler.id` sont réels (jamais `'temp'`).
AnnouncementModel _makeRealAnnouncement() => AnnouncementModel(
      id: 'ann-2',
      travelerId: 'trav-real-42',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime(2024, 2, 1),
      availableKg: 5.0,
      totalKg: 5.0,
      pricePerKg: 12.0,
      status: 'ACTIVE',
      createdAt: DateTime(2024, 1, 15),
      updatedAt: DateTime(2024, 1, 15),
      pricingMode: 'MIXED',
      priceGridItems: const [
        AnnouncementGridItemModel(
          id: 'grid-1',
          label: 'Valise 23kg',
          unitPriceNet: 40,
          unitPriceDisplay: 45,
        ),
      ],
      traveler: const TravelerProfile(
        id: 'trav-real-42',
        displayName: 'Awa',
        averageRating: 4.8,
      ),
    );

/// [AnnouncementBloc] mocké au repos — nécessaire dans tous les tests car
/// `RematchSearchScreen` enveloppe désormais son body dans un
/// `BlocListener<AnnouncementBloc, AnnouncementState>` (fetch au tap).
_MockAnnouncementBloc _idleAnnouncementBloc() {
  final bloc = _MockAnnouncementBloc();
  when(() => bloc.state).thenReturn(AnnouncementInitial());
  whenListen(bloc, const Stream<AnnouncementState>.empty(),
      initialState: AnnouncementInitial());
  return bloc;
}

Widget _wrap(
  CancellationBloc bloc, {
  required String cancellationId,
  AnnouncementBloc? announcementBloc,
}) =>
    MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<CancellationBloc>.value(value: bloc),
          BlocProvider<AnnouncementBloc>.value(
            value: announcementBloc ?? _idleAnnouncementBloc(),
          ),
        ],
        child: RematchSearchScreen(cancellationId: cancellationId),
      ),
    );

/// Variant avec [AuthBloc]/[BidBloc] mockés — nécessaire pour les tests qui
/// exercent le tap sur une `TravelerCard` : celui-ci fetch le vrai trajet via
/// `AnnouncementBloc`, puis (succès) ouvre `showTravelerAnnouncementSheet`,
/// qui lit `context.read<AuthBloc>()` (non défensif — lève si absent) et
/// tente `context.read<BidBloc>()` (défensif). Pas de `GoRouter` ici : ouvrir
/// la sheet ne navigue nulle part, seul un `Navigator` standard (fourni par
/// `MaterialApp`) est nécessaire (`useRootNavigator: true` dans
/// `DonyBottomSheet.show`).
Widget _wrapWithBlocs(
  CancellationBloc bloc, {
  required String cancellationId,
  required AuthBloc authBloc,
  required BidBloc bidBloc,
  required AnnouncementBloc announcementBloc,
}) =>
    MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<CancellationBloc>.value(value: bloc),
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<BidBloc>.value(value: bidBloc),
          BlocProvider<AnnouncementBloc>.value(value: announcementBloc),
        ],
        child: RematchSearchScreen(cancellationId: cancellationId),
      ),
    );

void main() {
  setUpAll(() async {
    registerFallbackValue(RematchSuggestionsRequested('fallback'));
    registerFallbackValue(AnnouncementDetailRequested('fallback'));
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

  testWidgets(
      'tire rematch_alternatives_opened à l\'ouverture (source deep_link en '
      'self-fetching) et affiche le bouton de signalement de bug', (tester) async {
    when(() => bloc.state).thenReturn(CancellationInitial());

    await tester.pumpWidget(_wrap(bloc, cancellationId: 'canc-1'));

    verify(() => analytics.logEvent(
          AnalyticsEvents.rematchAlternativesOpened,
          properties: {'source': 'deep_link'},
        )).called(1);
    expect(find.byType(DonyFeedbackButton), findsOneWidget);
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
    // L'avatar du voyageur est propagé au stub d'affichage (photo de profil
    // sur la carte au lieu de l'initiale).
    final card = tester.widget<TravelerCard>(find.byType(TravelerCard));
    expect(card.announcement.traveler?.avatarUrl,
        'https://s3.example/avatar-awa.jpg');
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
      'tap sur la TravelerCard fetch le vrai trajet par announcementId, tire '
      'rematch_accepted (count) puis ouvre la sheet avec le modèle réel '
      '(pas le stub)', (tester) async {
    when(() => bloc.state).thenReturn(RematchSuggestionsLoaded(_suggestions));

    final authBloc = _MockAuthBloc();
    when(() => authBloc.state).thenReturn(AuthAuthenticated(_makeUser()));
    when(() => authBloc.stream).thenAnswer((_) => const Stream.empty());
    addTearDown(authBloc.close);

    final bidBloc = _MockBidBloc();
    when(() => bidBloc.state).thenReturn(BidInitial());
    when(() => bidBloc.stream).thenAnswer((_) => const Stream.empty());
    addTearDown(bidBloc.close);

    final announcementBloc = _MockAnnouncementBloc();
    when(() => announcementBloc.state).thenReturn(AnnouncementInitial());
    // StreamController piloté à la main : le stream ne doit émettre qu'APRÈS
    // le tap (pas dès la souscription du BlocListener), sinon la sheet
    // s'ouvrirait avant même le tap et masquerait la TravelerCard.
    final controller = StreamController<AnnouncementState>();
    addTearDown(controller.close);
    whenListen(
      announcementBloc,
      controller.stream,
      initialState: AnnouncementInitial(),
    );

    await tester.pumpWidget(_wrapWithBlocs(
      bloc,
      cancellationId: 'canc-1',
      authBloc: authBloc,
      bidBloc: bidBloc,
      announcementBloc: announcementBloc,
    ));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byType(TravelerCard));
    await tester.pump();

    // Fetch déclenché avec le bon announcementId de la suggestion tapée —
    // un mauvais id ici doit faire échouer le test.
    verify(() => announcementBloc.add(any(
          that: isA<AnnouncementDetailRequested>()
              .having((e) => e.id, 'id', 'ann-2'),
        ))).called(1);

    controller.add(AnnouncementDetailLoaded(_makeRealAnnouncement()));
    await tester.pumpAndSettle();

    verify(() => analytics.logEvent(
          AnalyticsEvents.rematchAccepted,
          properties: {'count': 1},
        )).called(1);

    // Le tap ouvre bien un vrai bottom sheet (showTravelerAnnouncementSheet) —
    // pas une navigation vers une route inexistante.
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Détail du trajet'), findsOneWidget);
    // Marqueur exclusif au VRAI modèle (pricingMode MIXED + priceGridItems) —
    // le stub `_toAnnouncementModel` est toujours en mode 'KG' par défaut et
    // n'a jamais de grille tarifaire. Une régression qui ouvrirait la sheet
    // avec le stub ferait échouer ces deux assertions.
    expect(find.text('Grille tarifaire'), findsOneWidget);
    expect(find.text('Valise 23kg'), findsOneWidget);
  });

  testWidgets(
      'échec du fetch (annonce introuvable) → SnackBar d\'erreur, pas de sheet '
      'ouverte avec un stub', (tester) async {
    when(() => bloc.state).thenReturn(RematchSuggestionsLoaded(_suggestions));

    final authBloc = _MockAuthBloc();
    when(() => authBloc.state).thenReturn(AuthAuthenticated(_makeUser()));
    when(() => authBloc.stream).thenAnswer((_) => const Stream.empty());
    addTearDown(authBloc.close);

    final bidBloc = _MockBidBloc();
    when(() => bidBloc.state).thenReturn(BidInitial());
    when(() => bidBloc.stream).thenAnswer((_) => const Stream.empty());
    addTearDown(bidBloc.close);

    final announcementBloc = _MockAnnouncementBloc();
    when(() => announcementBloc.state).thenReturn(AnnouncementInitial());
    final controller = StreamController<AnnouncementState>();
    addTearDown(controller.close);
    whenListen(
      announcementBloc,
      controller.stream,
      initialState: AnnouncementInitial(),
    );

    await tester.pumpWidget(_wrapWithBlocs(
      bloc,
      cancellationId: 'canc-1',
      authBloc: authBloc,
      bidBloc: bidBloc,
      announcementBloc: announcementBloc,
    ));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byType(TravelerCard));
    await tester.pump();

    verify(() => announcementBloc.add(any(
          that: isA<AnnouncementDetailRequested>()
              .having((e) => e.id, 'id', 'ann-2'),
        ))).called(1);

    controller.add(AnnouncementNotFound());
    await tester.pumpAndSettle();

    // Aucun crash, aucune sheet ouverte avec un stub, aucun analytics tiré.
    expect(find.byType(BottomSheet), findsNothing);
    verifyNever(() => analytics.logEvent(
          AnalyticsEvents.rematchAccepted,
          properties: any(named: 'properties'),
        ));
    // SnackBar d'erreur affichée.
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
