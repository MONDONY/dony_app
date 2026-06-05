// Task 11 — Vue candidats côté expéditeur (sélection du voyageur, prix ferme)
//
// Vérifie que :
//  1. 3 cartes candidats avec bouton "Choisir" sont affichées
//  2. Chaque carte affiche "Tu paies 39,20 €"
//  3. Tapper "Choisir" sur la première carte déclenche NegotiationAcceptRequested
//  4. La note "Les autres seront déclinés automatiquement." est visible

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/content_category.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/presentation/screens/sender/package_request_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockNegotiationBloc
    extends MockBloc<NegotiationEvent, NegotiationState>
    implements NegotiationBloc {}

// ─── Helpers ─────────────────────────────────────────────────────────────────

PackageRequest _firmRequest() => PackageRequest(
      id: 'pr-firm',
      senderId: 'sender-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      desiredDate: DateTime(2026, 8, 1),
      dateToleranceDays: 2,
      weightKg: 5,
      parcelSize: ParcelSize.small,
      transportMode: TransportMode.plane,
      contentCategory: ContentCategory.vetements,
      status: PackageRequestStatus.negotiating,
      createdAt: DateTime(2026, 6, 1),
      negotiable: false,
      targetPriceEur: 35,
    );

NegotiationThread _thread({
  required String id,
  required String travelerId,
  required String travelerName,
}) =>
    NegotiationThread(
      id: id,
      packageRequestId: 'pr-firm',
      travelerId: travelerId,
      travelerTravelDate: DateTime(2026, 8, 15),
      travelerAvailableKg: 10,
      status: NegotiationThreadStatus.open,
      currentPriceEur: 35.0,
      grossPriceEur: 39.20,
      roundsCount: 1,
      lastActivityAt: DateTime(2026, 6, 2),
      createdAt: DateTime(2026, 6, 1),
      messages: const [],
      travelerName: travelerName,
      travelerRating: 4.8,
    );

List<NegotiationThread> _threeThreads() => [
      _thread(id: 't-1', travelerId: 'tv-1', travelerName: 'Alice Traoré'),
      _thread(id: 't-2', travelerId: 'tv-2', travelerName: 'Bob Diallo'),
      _thread(id: 't-3', travelerId: 'tv-3', travelerName: 'Charles Sow'),
    ];

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late _MockNegotiationBloc bloc;

  setUpAll(() async {
    await initializeDateFormatting('fr', null);
    registerFallbackValue(const NegotiationAcceptRequested(threadId: 't-1'));
  });

  setUp(() {
    bloc = _MockNegotiationBloc();
    when(() => bloc.state).thenReturn(const NegotiationInitial());
    when(() => bloc.stream)
        .thenAnswer((_) => const Stream<NegotiationState>.empty());
  });

  Widget wrap({
    required PackageRequest request,
    required List<NegotiationThread> threads,
  }) =>
      MaterialApp(
        theme: AppTheme.light,
        home: BlocProvider<NegotiationBloc>.value(
          value: bloc,
          child: Scaffold(
            body: SingleChildScrollView(
              child: CandidatesSection(
                request: request,
                threads: threads,
              ),
            ),
          ),
        ),
      );

  // GoRouter harness pour les tests de navigation : « Choisir » / tap carte
  // ouvre `/negotiations/:id` (rendu ici par une sentinelle « THREAD <id> »).
  Widget wrapRouter({
    required PackageRequest request,
    required List<NegotiationThread> threads,
  }) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
            body: SingleChildScrollView(
              child: CandidatesSection(request: request, threads: threads),
            ),
          ),
        ),
        GoRoute(
          path: '/negotiations/:id',
          builder: (_, state) =>
              Scaffold(body: Text('THREAD ${state.pathParameters['id']}')),
        ),
      ],
    );
    return MaterialApp.router(theme: AppTheme.light, routerConfig: router);
  }

  group('CandidatesSection — prix ferme (negotiable=false)', () {
    testWidgets(
      '3 cartes candidats sont affichées',
      (tester) async {
        await tester.pumpWidget(wrap(
          request: _firmRequest(),
          threads: _threeThreads(),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Choisir'), findsNWidgets(3));
      },
    );

    testWidgets(
      'chaque carte affiche "Tu paies 39,20 €"',
      (tester) async {
        await tester.pumpWidget(wrap(
          request: _firmRequest(),
          threads: _threeThreads(),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Tu paies 39,20 €'), findsNWidgets(3));
      },
    );

    testWidgets(
      'tapper "Choisir" sur la première carte ouvre /negotiations/t-1',
      (tester) async {
        await tester.pumpWidget(wrapRouter(
          request: _firmRequest(),
          threads: _threeThreads(),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('choose-traveler-t-1')));
        await tester.pumpAndSettle();

        expect(find.text('THREAD t-1'), findsOneWidget);
      },
    );

    testWidgets(
      'tapper la carte (hors bouton) ouvre aussi la négociation correspondante',
      (tester) async {
        await tester.pumpWidget(wrapRouter(
          request: _firmRequest(),
          threads: _threeThreads(),
        ));
        await tester.pumpAndSettle();

        // Tap on the 2nd candidate's name (inside the card InkWell, pas le bouton)
        await tester.tap(find.text('Bob Diallo'));
        await tester.pumpAndSettle();

        expect(find.text('THREAD t-2'), findsOneWidget);
      },
    );

    testWidgets(
      'la note "Les autres seront déclinés automatiquement." est visible',
      (tester) async {
        await tester.pumpWidget(wrap(
          request: _firmRequest(),
          threads: _threeThreads(),
        ));
        await tester.pumpAndSettle();

        expect(
          find.text('Les autres seront déclinés automatiquement.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'les noms des voyageurs sont affichés',
      (tester) async {
        await tester.pumpWidget(wrap(
          request: _firmRequest(),
          threads: _threeThreads(),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Alice Traoré'), findsOneWidget);
        expect(find.text('Bob Diallo'), findsOneWidget);
        expect(find.text('Charles Sow'), findsOneWidget);
      },
    );
  });

  group('CandidatesSection — requête négociable (negotiable=true)', () {
    testWidgets(
      'section non affichée si negotiable=true',
      (tester) async {
        final negotiableRequest = PackageRequest(
          id: 'pr-neg',
          senderId: 'sender-1',
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          desiredDate: DateTime(2026, 8, 1),
          dateToleranceDays: 2,
          weightKg: 5,
          parcelSize: ParcelSize.small,
          transportMode: TransportMode.plane,
          contentCategory: ContentCategory.vetements,
          status: PackageRequestStatus.negotiating,
          createdAt: DateTime(2026, 6, 1),
          negotiable: true,
          targetPriceEur: 35,
        );

        await tester.pumpWidget(wrap(
          request: negotiableRequest,
          threads: _threeThreads(),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Choisir'), findsNothing);
        expect(
          find.text('Les autres seront déclinés automatiquement.'),
          findsNothing,
        );
      },
    );
  });

  group('CandidatesSection — aucun thread OPEN', () {
    testWidgets(
      'section non affichée si aucun thread OPEN',
      (tester) async {
        final noOpenThreads = [
          NegotiationThread(
            id: 't-closed',
            packageRequestId: 'pr-firm',
            travelerId: 'tv-1',
            travelerTravelDate: DateTime(2026, 8, 15),
            travelerAvailableKg: 10,
            status: NegotiationThreadStatus.rejected,
            currentPriceEur: 35.0,
            roundsCount: 1,
            lastActivityAt: DateTime(2026, 6, 2),
            createdAt: DateTime(2026, 6, 1),
            messages: const [],
          ),
        ];

        await tester.pumpWidget(wrap(
          request: _firmRequest(),
          threads: noOpenThreads,
        ));
        await tester.pumpAndSettle();

        expect(find.text('Choisir'), findsNothing);
      },
    );
  });
}
