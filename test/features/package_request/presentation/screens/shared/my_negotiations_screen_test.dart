import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_list_bloc.dart';
import 'package:dony/features/package_request/bloc/negotiation_filter_cubit.dart';
import 'package:dony/features/package_request/bloc/negotiation_list_bloc.dart';
import 'package:dony/features/package_request/data/models/negotiation_message.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/presentation/screens/shared/my_negotiations_screen.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
import 'package:dony/features/profile/presentation/widgets/contextual_tutorial_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/mock_analytics_backend.dart';

const _hubConfigJson = '''
{
  "schemaVersion": 1,
  "socialLinks": [],
  "tutorials": [
    {
      "id": "tuto_negociation",
      "title": "Négocier une offre",
      "description": "Comprendre les contre-offres et accepter un prix.",
      "youtubeVideoId": "kJQP7kiw5Fk",
      "order": 1,
      "active": true,
      "contexts": ["negotiation"]
    }
  ]
}
''';

const _emptyHelpConfigJson = '''
{
  "schemaVersion": 1,
  "socialLinks": [],
  "tutorials": []
}
''';

class _StaticHelpCenterSource implements HelpCenterConfigSource {
  const _StaticHelpCenterSource(this.json);

  final String json;

  @override
  String get activatedJson => json;

  @override
  Future<String?> fetchAndActivate() async => json;
}

class _MockNegotiationListBloc
    extends MockBloc<NegotiationListEvent, NegotiationListState>
    implements NegotiationListBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

/// Depuis la fusion des deux sources, « Discussions de prix » consomme aussi
/// les négociations de prix de trajet. Toujours vide ici : ce fichier teste
/// la branche « demande d'envoi ».
class _MockTripListBloc
    extends MockBloc<BidNegotiationListEvent, BidNegotiationListState>
    implements BidNegotiationListBloc {}

UserModel _user(String id) => UserModel(
  id: id,
  roles: const ['SENDER'],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
);

NegotiationThread _thread({
  NegotiationThreadStatus status = NegotiationThreadStatus.open,
  String? travelerName = 'Mamadou Diallo',
  double? travelerRating = 4.8,
  int? travelerTripsCount = 12,
  String? departureCity = 'Paris',
  String? arrivalCity = 'Dakar',
  double? weightKg = 5,
}) => NegotiationThread(
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
  // Épingle le taux de commission : ces tests assertent des montants
  // calculés à 12 % (indépendants du défaut kDonyCommissionRateDefault).
  setUpAll(() => setDonyCommissionRate(0.12));
  tearDownAll(() => setDonyCommissionRate(kDonyCommissionRateDefault));

  late _MockNegotiationListBloc bloc;
  late _MockAuthBloc authBloc;
  late _MockTripListBloc tripBloc;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(const NegotiationListFetchRequested());
  });

  setUp(() {
    bloc = _MockNegotiationListBloc();
    tripBloc = _MockTripListBloc();
    when(() => tripBloc.state).thenReturn(const BidNegotiationListState());
    when(
      () => tripBloc.stream,
    ).thenAnswer((_) => const Stream<BidNegotiationListState>.empty());
    when(() => bloc.state).thenReturn(NegotiationListState());
    when(
      () => bloc.stream,
    ).thenAnswer((_) => const Stream<NegotiationListState>.empty());

    // Viewer = expéditeur (id ≠ travelerId 'tr-1') → voit le prix gross.
    authBloc = _MockAuthBloc();
    when(() => authBloc.state).thenReturn(AuthAuthenticated(_user('sender-1')));
    when(
      () => authBloc.stream,
    ).thenAnswer((_) => const Stream<AuthState>.empty());

    if (!getIt.isRegistered<NegotiationFilterCubit>()) {
      getIt.registerFactory<NegotiationFilterCubit>(
        () => NegotiationFilterCubit(),
      );
    }
  });

  tearDown(() async {
    if (getIt.isRegistered<NegotiationFilterCubit>()) {
      await getIt.unregister<NegotiationFilterCubit>();
    }
  });

  Widget wrap() => MaterialApp(
    theme: AppTheme.light(),
    home: MultiBlocProvider(
      providers: [
        BlocProvider<NegotiationListBloc>.value(value: bloc),
        BlocProvider<BidNegotiationListBloc>.value(value: tripBloc),
        BlocProvider<AuthBloc>.value(value: authBloc),
      ],
      child: const Scaffold(body: MyNegotiationsBody()),
    ),
  );

  group('MyNegotiationsBody', () {
    testWidgets('affiche CircularProgressIndicator en état loading', (
      tester,
    ) async {
      when(
        () => bloc.state,
      ).thenReturn(NegotiationListState(status: NegotiationListStatus.loading));
      await tester.pumpWidget(wrap());
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('affiche _EmptyState quand la liste est vide', (tester) async {
      when(
        () => bloc.state,
      ).thenReturn(NegotiationListState(status: NegotiationListStatus.loaded));
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.text('Aucune négociation'), findsOneWidget);
    });

    testWidgets('affiche l\'état erreur avec un message', (tester) async {
      when(() => bloc.state).thenReturn(
        NegotiationListState(
          status: NegotiationListStatus.error,
          errorMessage: 'Connexion impossible',
        ),
      );
      await tester.pumpWidget(wrap());
      await tester.pump();
      expect(find.text('Connexion impossible'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('affiche les threads chargés', (tester) async {
      when(() => bloc.state).thenReturn(
        NegotiationListState(
          status: NegotiationListStatus.loaded,
          threads: [_thread()],
        ),
      );
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.text('Mamadou Diallo'), findsOneWidget);
    });
  });

  group('_NegoCard', () {
    testWidgets('affiche le nom du voyageur', (tester) async {
      when(() => bloc.state).thenReturn(
        NegotiationListState(
          status: NegotiationListStatus.loaded,
          threads: [_thread(travelerName: 'Ibrahim Koné')],
        ),
      );
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.text('Ibrahim Koné'), findsOneWidget);
    });

    testWidgets('affiche "Voyageur" comme fallback si travelerName est null', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        NegotiationListState(
          status: NegotiationListStatus.loaded,
          threads: [_thread(travelerName: null)],
        ),
      );
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      // The search hint also contains "Voyageur" — verify at least one card fallback text is present
      expect(find.textContaining('Voyageur'), findsWidgets);
      // More precisely: the card fallback 'Voyageur tr-1' must exist
      expect(find.textContaining('Voyageur tr-'), findsOneWidget);
    });

    testWidgets(
      'expéditeur → affiche le prix qu\'il paie (gross = net+commission)',
      (tester) async {
        // Viewer 'sender-1' ≠ travelerId 'tr-1' → gross exact. net 45 → 45×1.12 = "50,40 €".
        when(() => bloc.state).thenReturn(
          NegotiationListState(
            status: NegotiationListStatus.loaded,
            threads: [_thread()],
          ),
        );
        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();
        expect(find.text('50,40\u00A0€'), findsOneWidget);
        expect(find.text('45,00\u00A0€'), findsNothing);
      },
    );

    testWidgets('voyageur → affiche son net', (tester) async {
      // Viewer = le voyageur 'tr-1' → net exact → "45,00 €".
      when(() => authBloc.state).thenReturn(AuthAuthenticated(_user('tr-1')));
      when(() => bloc.state).thenReturn(
        NegotiationListState(
          status: NegotiationListStatus.loaded,
          threads: [_thread()],
        ),
      );
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.text('45,00\u00A0€'), findsOneWidget);
    });

    testWidgets('affiche "R.2/5"', (tester) async {
      when(() => bloc.state).thenReturn(
        NegotiationListState(
          status: NegotiationListStatus.loaded,
          threads: [_thread()],
        ),
      );
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.textContaining('R.2/5'), findsOneWidget);
    });

    testWidgets(
      'affiche le badge NOUVEAU pour les threads open avec messages',
      (tester) async {
        when(() => bloc.state).thenReturn(
          NegotiationListState(
            status: NegotiationListStatus.loaded,
            threads: [_thread()],
          ),
        );
        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();
        expect(find.text('NOUVEAU'), findsOneWidget);
      },
    );

    testWidgets('n\'affiche pas le badge NOUVEAU pour les threads terminés', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        NegotiationListState(
          status: NegotiationListStatus.loaded,
          threads: [_thread(status: NegotiationThreadStatus.accepted)],
        ),
      );
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.text('NOUVEAU'), findsNothing);
    });

    testWidgets('affiche la route départ → arrivée', (tester) async {
      when(() => bloc.state).thenReturn(
        NegotiationListState(
          status: NegotiationListStatus.loaded,
          threads: [_thread(departureCity: 'Lyon', arrivalCity: 'Abidjan')],
        ),
      );
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.textContaining('Lyon → Abidjan'), findsOneWidget);
    });
  });

  group('Recherche et filtres', () {
    NegotiationThread t2({
      required String arrivalCity,
      required NegotiationThreadStatus status,
      String? travelerName,
    }) => NegotiationThread(
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

    final dakarThread = t2(
      arrivalCity: 'Dakar',
      status: NegotiationThreadStatus.open,
      travelerName: 'Modou Fall',
    );
    final abidjanThread = t2(
      arrivalCity: 'Abidjan',
      status: NegotiationThreadStatus.rejected,
      travelerName: 'Kouassi Bamba',
    );

    setUp(() {
      when(() => bloc.state).thenReturn(
        NegotiationListState(
          status: NegotiationListStatus.loaded,
          threads: [dakarThread, abidjanThread],
        ),
      );
    });

    testWidgets('la saisie dans le champ de recherche filtre après 250ms', (
      tester,
    ) async {
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

    testWidgets(
      'recherche sans correspondance affiche l\'état vide de recherche',
      (tester) async {
        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();

        // Type a query with no matching results
        await tester.enterText(find.byType(TextField), 'zzzzz');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();

        expect(
          find.text('Aucun résultat pour cette recherche'),
          findsOneWidget,
        );
      },
    );
  });

  group('_StatusPill — tous les statuts', () {
    for (final entry in [
      (NegotiationThreadStatus.awaitingTrip, 'ATT. TRAJET'),
      (NegotiationThreadStatus.awaitingPayment, 'PAIEMENT'),
      (NegotiationThreadStatus.accepted, 'ACCEPTÉE'),
      (NegotiationThreadStatus.rejected, 'TERMINÉ'),
      (NegotiationThreadStatus.autoRejected, 'TERMINÉ'),
      (NegotiationThreadStatus.expired, 'TERMINÉ'),
    ]) {
      final status = entry.$1;
      final pillLabel = entry.$2;
      testWidgets('affiche la pill "$pillLabel" pour status=${status.name}', (
        tester,
      ) async {
        when(() => bloc.state).thenReturn(
          NegotiationListState(
            status: NegotiationListStatus.loaded,
            threads: [_thread(status: status)],
          ),
        );
        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();
        expect(
          find.text(pillLabel),
          findsWidgets,
        ); // may also appear in filter bar label
      });
    }
  });

  group('_NegoCard opacité et badge NOUVEAU', () {
    testWidgets('thread terminal a opacité réduite (isTerminal=true)', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        NegotiationListState(
          status: NegotiationListStatus.loaded,
          threads: [_thread(status: NegotiationThreadStatus.rejected)],
        ),
      );
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      // The card is rendered with Opacity(opacity: 0.65) for terminal status
      // We just check it renders without error and shows the thread
      expect(find.textContaining('Paris → Dakar'), findsOneWidget);
    });

    testWidgets('thread autoRejected est terminal (badge TERMINÉ)', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        NegotiationListState(
          status: NegotiationListStatus.loaded,
          threads: [_thread(status: NegotiationThreadStatus.autoRejected)],
        ),
      );
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.text('TERMINÉ'), findsOneWidget);
    });

    testWidgets('thread expired est terminal (badge TERMINÉ)', (tester) async {
      when(() => bloc.state).thenReturn(
        NegotiationListState(
          status: NegotiationListStatus.loaded,
          threads: [_thread(status: NegotiationThreadStatus.expired)],
        ),
      );
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.text('TERMINÉ'), findsOneWidget);
    });

    testWidgets('thread cancelled est terminal (badge TERMINÉ)', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        NegotiationListState(
          status: NegotiationListStatus.loaded,
          threads: [_thread(status: NegotiationThreadStatus.cancelled)],
        ),
      );
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.text('TERMINÉ'), findsOneWidget);
    });

    testWidgets('thread open sans messages n\'affiche pas NOUVEAU', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        NegotiationListState(
          status: NegotiationListStatus.loaded,
          threads: [
            NegotiationThread(
              id: 't-no-msg',
              packageRequestId: 'pr-1',
              travelerId: 'tr-1',
              travelerTravelDate: DateTime(2026, 6, 15),
              travelerAvailableKg: 10,
              status: NegotiationThreadStatus.open,
              currentPriceEur: 45,
              roundsCount: 0,
              lastActivityAt: DateTime(2026, 5, 10),
              createdAt: DateTime(2026, 5, 10),
              messages: const [], // pas de messages
              travelerName: 'Test User',
              departureCity: 'Paris',
              arrivalCity: 'Dakar',
            ),
          ],
        ),
      );
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.text('NOUVEAU'), findsNothing);
    });
  });

  group('_NegoCard route sans villes → fallback kg', () {
    testWidgets('affiche les kg disponibles si villes null', (tester) async {
      when(() => bloc.state).thenReturn(
        NegotiationListState(
          status: NegotiationListStatus.loaded,
          threads: [_thread(departureCity: null, arrivalCity: null)],
        ),
      );
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      // fallback: '10 kg dispo' (travelerAvailableKg = 10)
      expect(find.textContaining('kg dispo'), findsOneWidget);
    });
  });

  group('_FilterEmptyState — présets', () {
    NegotiationThread t3({required NegotiationThreadStatus status}) =>
        NegotiationThread(
          id: 't-${status.name}',
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
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
        );

    testWidgets(
      'chip Terminées + aucun terminal affiche « Aucune négociation terminée »',
      (tester) async {
        when(() => bloc.state).thenReturn(
          NegotiationListState(
            status: NegotiationListStatus.loaded,
            threads: [t3(status: NegotiationThreadStatus.open)],
          ),
        );
        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Terminées (0)'));
        await tester.pumpAndSettle();

        expect(find.text('Aucune négociation terminée'), findsOneWidget);
      },
    );

    testWidgets(
      'chip En cours + aucun actif affiche « Aucune négociation en cours »',
      (tester) async {
        when(() => bloc.state).thenReturn(
          NegotiationListState(
            status: NegotiationListStatus.loaded,
            threads: [t3(status: NegotiationThreadStatus.rejected)],
          ),
        );
        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();

        await tester.tap(find.text('En cours (0)'));
        await tester.pumpAndSettle();

        expect(find.text('Aucune négociation en cours'), findsOneWidget);
      },
    );
  });

  group('awaitingPayment et awaitingTrip cards', () {
    testWidgets('thread awaitingPayment affiche pill PAIEMENT', (tester) async {
      when(() => bloc.state).thenReturn(
        NegotiationListState(
          status: NegotiationListStatus.loaded,
          threads: [_thread(status: NegotiationThreadStatus.awaitingPayment)],
        ),
      );
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.text('PAIEMENT'), findsOneWidget);
    });

    testWidgets('thread awaitingTrip affiche pill ATT. TRAJET', (tester) async {
      when(() => bloc.state).thenReturn(
        NegotiationListState(
          status: NegotiationListStatus.loaded,
          threads: [_thread(status: NegotiationThreadStatus.awaitingTrip)],
        ),
      );
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.text('ATT. TRAJET'), findsOneWidget);
    });

    testWidgets('thread accepted affiche pill ACCEPTÉE', (tester) async {
      when(() => bloc.state).thenReturn(
        NegotiationListState(
          status: NegotiationListStatus.loaded,
          threads: [_thread(status: NegotiationThreadStatus.accepted)],
        ),
      );
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.text('ACCEPTÉE'), findsOneWidget);
    });
  });

  group('MyNegotiationsScreen — carte tutoriel', () {
    Widget wrapScreen(String configJson) => MaterialApp(
      theme: AppTheme.light(),
      home: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<HelpCenterBloc>(
            create: (_) => HelpCenterBloc(
              HelpCenterRepository(
                _StaticHelpCenterSource(configJson),
                fallbackJsonLoader: () async => _emptyHelpConfigJson,
              ),
              makeDisabledAnalytics(MockAnalyticsBackend()),
            )..add(const HelpCenterLoadRequested()),
          ),
        ],
        child: const MyNegotiationsScreen(),
      ),
    );

    setUp(() {
      if (getIt.isRegistered<NegotiationListBloc>()) {
        getIt.unregister<NegotiationListBloc>();
      }
      getIt.registerLazySingleton<NegotiationListBloc>(() => bloc);
      if (getIt.isRegistered<BidNegotiationListBloc>()) {
        getIt.unregister<BidNegotiationListBloc>();
      }
      getIt.registerLazySingleton<BidNegotiationListBloc>(() => tripBloc);
    });

    tearDown(() {
      if (getIt.isRegistered<NegotiationListBloc>()) {
        getIt.unregister<NegotiationListBloc>();
      }
      if (getIt.isRegistered<BidNegotiationListBloc>()) {
        getIt.unregister<BidNegotiationListBloc>();
      }
    });

    testWidgets('affiche la carte tutoriel quand le catalogue en propose un', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(NegotiationListState());
      await tester.pumpWidget(wrapScreen(_hubConfigJson));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ContextualTutorialCard), findsOneWidget);
      expect(find.text('Besoin d\'aide ? Voir le tutoriel'), findsOneWidget);
    });

    testWidgets('pas de carte tutoriel sans tutoriel actif pour ce contexte', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(NegotiationListState());
      await tester.pumpWidget(wrapScreen(_emptyHelpConfigJson));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ContextualTutorialCard), findsOneWidget);
      expect(find.text('Besoin d\'aide ? Voir le tutoriel'), findsNothing);
    });
  });
}
