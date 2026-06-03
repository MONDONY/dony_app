import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/package_request/bloc/negotiation_filter_cubit.dart';
import 'package:dony/features/package_request/bloc/negotiation_list_bloc.dart';
import 'package:dony/features/package_request/data/models/negotiation_message.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/presentation/screens/shared/my_negotiations_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockNegotiationListBloc
    extends MockBloc<NegotiationListEvent, NegotiationListState>
    implements NegotiationListBloc {}

NegotiationThread _thread({
  NegotiationThreadStatus status = NegotiationThreadStatus.open,
  String? travelerName = 'Mamadou Diallo',
  double? travelerRating = 4.8,
  int? travelerTripsCount = 12,
  String? departureCity = 'Paris',
  String? arrivalCity = 'Dakar',
  double? weightKg = 5,
}) =>
    NegotiationThread(
      id: 't-1',
      packageRequestId: 'pr-1',
      travelerId: 'tr-1',
      travelerTravelDate: DateTime(2026, 6, 15),
      travelerAvailableKg: 10,
      status: status,
      currentPriceEur: 45,
      roundsCount: 2,
      lastActivityAt: DateTime(2026, 5, 10),
      createdAt: DateTime(2026, 5, 10),
      messages: [
        NegotiationMessage(
          id: 'm1',
          threadId: 't-1',
          fromUserId: 'tr-1',
          kind: NegotiationMessageKind.proposal,
          proposedPriceEur: 45,
          createdAt: DateTime(2026, 5, 10),
        ),
      ],
      travelerName: travelerName,
      travelerRating: travelerRating,
      travelerTripsCount: travelerTripsCount,
      departureCity: departureCity,
      arrivalCity: arrivalCity,
      weightKg: weightKg,
    );

void main() {
  late _MockNegotiationListBloc bloc;

  setUpAll(() async {
    await initializeDateFormatting('fr', null);
    registerFallbackValue(const NegotiationListFetchRequested());
  });

  setUp(() {
    bloc = _MockNegotiationListBloc();
    when(() => bloc.state).thenReturn(const NegotiationListState());
    when(() => bloc.stream)
        .thenAnswer((_) => const Stream<NegotiationListState>.empty());

    if (!getIt.isRegistered<NegotiationFilterCubit>()) {
      getIt.registerFactory<NegotiationFilterCubit>(() => NegotiationFilterCubit());
    }
  });

  tearDown(() async {
    if (getIt.isRegistered<NegotiationFilterCubit>()) {
      await getIt.unregister<NegotiationFilterCubit>();
    }
  });

  Widget wrap() => MaterialApp(
        theme: AppTheme.light,
        home: BlocProvider<NegotiationListBloc>.value(
          value: bloc,
          child: const Scaffold(body: MyNegotiationsBody()),
        ),
      );

  group('MyNegotiationsBody', () {
    testWidgets('affiche CircularProgressIndicator en état loading',
        (tester) async {
      when(() => bloc.state).thenReturn(const NegotiationListState(
        status: NegotiationListStatus.loading,
        threads: [],
      ));
      await tester.pumpWidget(wrap());
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('affiche _EmptyState quand la liste est vide', (tester) async {
      when(() => bloc.state).thenReturn(const NegotiationListState(
        status: NegotiationListStatus.loaded,
        threads: [],
      ));
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.text('Aucune négociation'), findsOneWidget);
    });

    testWidgets('affiche l\'état erreur avec un message', (tester) async {
      when(() => bloc.state).thenReturn(const NegotiationListState(
        status: NegotiationListStatus.error,
        errorMessage: 'Connexion impossible',
      ));
      await tester.pumpWidget(wrap());
      await tester.pump();
      expect(find.text('Connexion impossible'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('affiche les threads chargés', (tester) async {
      when(() => bloc.state).thenReturn(NegotiationListState(
        status: NegotiationListStatus.loaded,
        threads: [_thread()],
      ));
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.text('Mamadou Diallo'), findsOneWidget);
    });
  });

  group('_NegoCard', () {

    testWidgets('affiche le nom du voyageur', (tester) async {
      when(() => bloc.state).thenReturn(NegotiationListState(
        status: NegotiationListStatus.loaded,
        threads: [_thread(travelerName: 'Ibrahim Koné')],
      ));
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.text('Ibrahim Koné'), findsOneWidget);
    });

    testWidgets('affiche "Voyageur" comme fallback si travelerName est null',
        (tester) async {
      when(() => bloc.state).thenReturn(NegotiationListState(
        status: NegotiationListStatus.loaded,
        threads: [_thread(travelerName: null)],
      ));
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      // The search hint also contains "Voyageur" — verify at least one card fallback text is present
      expect(find.textContaining('Voyageur'), findsWidgets);
      // More precisely: the card fallback 'Voyageur tr-1' must exist
      expect(find.textContaining('Voyageur tr-'), findsOneWidget);
    });

    testWidgets('affiche le prix actuel', (tester) async {
      when(() => bloc.state).thenReturn(NegotiationListState(
        status: NegotiationListStatus.loaded,
        threads: [_thread()],
      ));
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.text('45 €'), findsOneWidget);
    });

    testWidgets('affiche "R.2/5"', (tester) async {
      when(() => bloc.state).thenReturn(NegotiationListState(
        status: NegotiationListStatus.loaded,
        threads: [_thread()],
      ));
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.textContaining('R.2/5'), findsOneWidget);
    });

    testWidgets('affiche le badge NOUVEAU pour les threads open avec messages',
        (tester) async {
      when(() => bloc.state).thenReturn(NegotiationListState(
        status: NegotiationListStatus.loaded,
        threads: [_thread(status: NegotiationThreadStatus.open)],
      ));
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.text('NOUVEAU'), findsOneWidget);
    });

    testWidgets('n\'affiche pas le badge NOUVEAU pour les threads terminés',
        (tester) async {
      when(() => bloc.state).thenReturn(NegotiationListState(
        status: NegotiationListStatus.loaded,
        threads: [_thread(status: NegotiationThreadStatus.accepted)],
      ));
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.text('NOUVEAU'), findsNothing);
    });

    testWidgets('affiche la route départ → arrivée', (tester) async {
      when(() => bloc.state).thenReturn(NegotiationListState(
        status: NegotiationListStatus.loaded,
        threads: [_thread(departureCity: 'Lyon', arrivalCity: 'Abidjan')],
      ));
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.textContaining('Lyon → Abidjan'), findsOneWidget);
    });
  });

  group('Recherche et filtres', () {
    NegotiationThread _t2({
      required String arrivalCity,
      required NegotiationThreadStatus status,
      String? travelerName,
    }) =>
        NegotiationThread(
          id: 't-${arrivalCity.toLowerCase()}-${status.name}',
          packageRequestId: 'pr-1',
          travelerId: 'tr-1',
          travelerTravelDate: DateTime(2026, 6, 15),
          travelerAvailableKg: 10,
          status: status,
          currentPriceEur: 30,
          roundsCount: 1,
          lastActivityAt: DateTime(2026, 5, 10),
          createdAt: DateTime(2026, 5, 10),
          messages: const [],
          travelerName: travelerName,
          departureCity: 'Paris',
          arrivalCity: arrivalCity,
        );

    final dakarThread = _t2(
      arrivalCity: 'Dakar',
      status: NegotiationThreadStatus.open,
      travelerName: 'Modou Fall',
    );
    final abidjanThread = _t2(
      arrivalCity: 'Abidjan',
      status: NegotiationThreadStatus.rejected,
      travelerName: 'Kouassi Bamba',
    );

    setUp(() {
      when(() => bloc.state).thenReturn(NegotiationListState(
        status: NegotiationListStatus.loaded,
        threads: [dakarThread, abidjanThread],
      ));
    });

    testWidgets('la saisie dans le champ de recherche filtre après 250ms',
        (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // Both threads initially visible
      expect(find.text('Paris → Dakar'), findsOneWidget);
      expect(find.text('Paris → Abidjan'), findsOneWidget);

      // Type in search field
      await tester.enterText(find.byType(TextField), 'abidjan');

      // Before debounce: both still visible
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Paris → Dakar'), findsOneWidget);
      expect(find.text('Paris → Abidjan'), findsOneWidget);

      // After debounce: only Abidjan visible
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(find.text('Paris → Abidjan'), findsOneWidget);
      expect(find.text('Paris → Dakar'), findsNothing);
    });

    testWidgets('le chip En cours filtre par statut actif', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // Both threads visible
      expect(find.text('Paris → Dakar'), findsOneWidget);
      expect(find.text('Paris → Abidjan'), findsOneWidget);

      // Tap "En cours" chip
      await tester.tap(find.text('En cours (1)'));
      await tester.pumpAndSettle();

      // Only active (Dakar/open) should be visible
      expect(find.text('Paris → Dakar'), findsOneWidget);
      expect(find.text('Paris → Abidjan'), findsNothing);
    });

    testWidgets('recherche sans correspondance affiche l\'état vide de recherche',
        (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // Type a query with no matching results
      await tester.enterText(find.byType(TextField), 'zzzzz');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.text('Aucun résultat pour cette recherche'), findsOneWidget);
    });
  });
}
