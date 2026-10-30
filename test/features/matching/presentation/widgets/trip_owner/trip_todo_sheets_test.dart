// Bottom sheets des tuiles « À traiter » de l'écran du trajet (vue du
// voyageur propriétaire) : demandes à traiter, « Je pars », carte à ajouter.
// Contenu, bouton dans le pied, blocs de l'écran reposés, navigation et
// rechargement au retour, fermeture seule quand la tuile n'a plus lieu
// d'être (jamais par-dessus une confirmation), mesure d'ouverture, libellés
// à taille nominale en FR et EN à 360 dp × 1,3.
import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/trip_parcels_summary.dart';
import 'package:dony/features/matching/presentation/screens/create_trip_screen.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/todo_tile_views.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_sheets.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_tiles.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/tracking/bloc/trip_depart_cubit.dart';
import 'package:dony/features/tracking/presentation/widgets/tracking_consent_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/mock_analytics_backend.dart';
import '../../../../../helpers/stripe_account_test_doubles.dart';

class _MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockDepart extends MockCubit<TripDepartState>
    implements TripDepartCubit {}

class _FakeContext extends Fake implements BuildContext {}

const _ready = StripeAccountReady(
  ConnectAccountStatus(status: 'ONBOARDING_COMPLETE'),
);
const _notReady = StripeAccountReady(
  ConnectAccountStatus(status: 'NOT_CREATED'),
);

const _summary = TripParcelsSummary(
  count: 1,
  totalKg: 3,
  netAmount: 30,
  currency: 'EUR',
);

AnnouncementModel _trip({
  String status = 'ACTIVE',
  int pendingBidCount = 0,
  bool trackingActive = false,
  TripParcelsSummary? parcelsSummary,
  Set<BidPaymentMethod> methods = const {BidPaymentMethod.stripe},
}) {
  final now = DateTime(2026, 10, 30);
  return AnnouncementModel(
    id: 'trip-1',
    travelerId: 'trav-1',
    departureCity: 'Paris',
    arrivalCity: 'Abidjan',
    departureDate: now.add(const Duration(days: 3)),
    availableKg: 20,
    totalKg: 20,
    status: status,
    createdAt: now,
    updatedAt: now,
    pendingBidCount: pendingBidCount,
    trackingActive: trackingActive,
    parcelsSummary: parcelsSummary,
    acceptedPaymentMethods: methods,
  );
}

AnnouncementModel _departTrip() =>
    _trip(trackingActive: true, parcelsSummary: _summary);

AnnouncementModel _cashTrip({String status = 'ACTIVE'}) =>
    _trip(status: status, methods: const {BidPaymentMethod.cash});

BidModel _bid(
  String id,
  String status, {
  String? description,
  double? weightKg,
  double? net,
}) => BidModel(
  id: id,
  announcementId: 'trip-1',
  senderId: 'sender-$id',
  status: status,
  description: description,
  weightKg: weightKg,
  totalAmountEur: net,
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

final _pendingBids = [
  _bid('b1', 'PENDING', description: 'Vêtements', weightKg: 3, net: 42),
  _bid('b2', 'PAYMENT_ESCROWED', description: 'Documents', weightKg: 1.5),
  _bid('b3', 'ACCEPTED', description: 'Épices', weightKg: 2, net: 20),
];

/// Vraies polices de l'app : la police de repli des tests donne un cadratin
/// par glyphe et fausserait la mesure des libellés.
Future<void> _loadAppFonts() async {
  const families = {
    'HankenGrotesk': [
      'HankenGrotesk-SemiBold',
      'HankenGrotesk-Bold',
      'HankenGrotesk-ExtraBold',
    ],
    'PlusJakartaSans': [
      'PlusJakartaSans-Regular',
      'PlusJakartaSans-Medium',
      'PlusJakartaSans-SemiBold',
      'PlusJakartaSans-Bold',
    ],
  };
  for (final MapEntry(key: family, value: files) in families.entries) {
    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = File('assets/fonts/$file.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

void main() {
  late MockAnalyticsBackend backend;
  late _MockAnnouncementBloc annBloc;
  late StreamController<AnnouncementState> annStates;
  late _MockBidBloc bidBloc;
  late StreamController<BidState> bidStates;
  late _MockDepart departCubit;
  late StreamController<TripDepartState> departStates;
  late List<String?> createdDepartIds;
  late Object? createTripExtra;

  setUpAll(() async {
    registerFallbackValue(_FakeContext());
    registerFallbackValue(BidListRequested('fallback'));
    registerFallbackValue(AnnouncementDetailRequested('fallback'));
    await _loadAppFonts();
  });

  setUp(() async {
    backend = MockAnalyticsBackend();
    final analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();

    annStates = StreamController<AnnouncementState>.broadcast();
    addTearDown(annStates.close);
    bidStates = StreamController<BidState>.broadcast();
    addTearDown(bidStates.close);
    departStates = StreamController<TripDepartState>.broadcast();
    addTearDown(departStates.close);

    annBloc = _MockAnnouncementBloc();
    bidBloc = _MockBidBloc();
    departCubit = _MockDepart();
    when(() => departCubit.depart(any())).thenAnswer((_) async {});
    createdDepartIds = [];
    createTripExtra = null;

    await getIt.reset();
    getIt
      ..registerSingleton<AnalyticsService>(analytics)
      ..registerFactoryParam<TripDepartCubit, String, void>((id, _) {
        createdDepartIds.add(id);
        return departCubit;
      });
    DonySnackbar.clearDedup();
  });

  tearDown(() async => getIt.reset());

  /// Ouvre la feuille depuis un `Builder` posé sous les blocs de l'écran,
  /// comme le fera la section « À traiter ». [withDepart] : l'écran fournit
  /// son `TripDepartCubit` (sinon le sheet « Je pars » en crée un).
  Future<void> open(
    WidgetTester tester, {
    required AnnouncementModel trip,
    required TripTodoTile tile,
    BidState? bidState,
    StripeAccountState stripe = _notReady,
    TripDepartState departState = const TripDepartState(),
    bool withBlocs = true,
    bool withDepart = true,
    Locale locale = const Locale('fr'),
    double textScale = 1,
    Size? size,
    TodoSource source = TodoSource.tile,
    bool settle = true,
  }) async {
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    whenListen(
      annBloc,
      annStates.stream,
      initialState: AnnouncementDetailLoaded(trip),
    );
    whenListen(
      bidBloc,
      bidStates.stream,
      initialState: bidState ?? BidListLoaded(_pendingBids),
    );
    whenListen(departCubit, departStates.stream, initialState: departState);
    final stripeBloc = stubStripeAccountBloc(state: stripe);

    Widget screen(BuildContext context) {
      final opener = Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                openTripTodoSheet(context, trip, tile, source: source),
            child: const Text('open-todo'),
          ),
        ),
      );
      if (!withBlocs) return opener;
      return MultiBlocProvider(
        providers: [
          BlocProvider<AnnouncementBloc>.value(value: annBloc),
          BlocProvider<BidBloc>.value(value: bidBloc),
          BlocProvider<StripeAccountBloc>.value(value: stripeBloc),
          if (withDepart)
            BlocProvider<TripDepartCubit>.value(value: departCubit),
        ],
        child: opener,
      );
    }

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, _) => screen(context)),
        GoRoute(
          path: '/demandes',
          builder: (context, state) =>
              Scaffold(body: Text('demandes:${state.uri.query}')),
        ),
        GoRoute(
          path: '/trips/create',
          builder: (context, state) {
            createTripExtra = state.extra;
            return Scaffold(
              body: TextButton(
                onPressed: () => context.pop(true),
                child: const Text('save-trip'),
              ),
            );
          },
        ),
        GoRoute(
          path: '/connect/onboarding/intro',
          builder: (context, _) =>
              const Scaffold(body: Text('stripe-onboarding-intro')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        routerConfig: router,
      ),
    );
    await tester.tap(find.text('open-todo'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // Indicateur de chargement : l'animation ne se pose jamais.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  Finder footer() => find.byKey(const Key('donyBottomSheetFooter'));
  Finder inFooter(Finder f) => find.descendant(of: footer(), matching: f);
  Finder requestsButton() => find.byKey(const Key('trip-todo-requests-button'));
  Finder departButton() => find.byKey(const Key('trip-depart-button'));
  Finder enableCard() => find.byKey(const Key('enable-card-on-trip-cta'));
  Finder activateCard() => find.byKey(const Key('activate-card-payments-cta'));

  /// Seul bouton du sheet : dans le pied, aucun dans le contenu défilant.
  void expectSingleFooterButton(Finder button) {
    expect(inFooter(button), findsOneWidget);
    expect(find.byType(DonyButton), findsOneWidget);
  }

  group('demandes à traiter', () {
    testWidgets('une ligne par demande en attente, bouton dans le pied', (
      tester,
    ) async {
      await open(tester, trip: _trip(), tile: TripTodoTile.requests);

      expect(tester.takeException(), isNull);
      expect(find.text('Demandes à traiter'), findsOneWidget);
      expect(find.byKey(const Key('trip-todo-request-b1')), findsOneWidget);
      expect(find.byKey(const Key('trip-todo-request-b2')), findsOneWidget);
      // Un colis déjà accepté n'est pas une demande à traiter.
      expect(find.byKey(const Key('trip-todo-request-b3')), findsNothing);
      expect(find.text('Vêtements'), findsOneWidget);
      expect(find.textContaining('3 kg'), findsOneWidget);
      expect(find.textContaining('1.5 kg'), findsOneWidget);
      // Net du voyageur quand le back le sert, rien sinon.
      expect(find.textContaining('42'), findsOneWidget);
      expect(
        find.text(
          'Vous acceptez ou refusez chaque demande depuis la liste des '
          'demandes.',
        ),
        findsOneWidget,
      );
      expectSingleFooterButton(requestsButton());
      expect(find.text('Voir les demandes (2)'), findsOneWidget);
    });

    testWidgets('liste pas encore chargée : nombre servi par le trajet', (
      tester,
    ) async {
      await open(
        tester,
        trip: _trip(pendingBidCount: 2),
        tile: TripTodoTile.requests,
        bidState: BidLoading(),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('2 demandes attendent votre réponse'), findsOneWidget);
      expect(find.byKey(const Key('trip-todo-request-b1')), findsNothing);
      expect(find.text('Voir les demandes (2)'), findsOneWidget);
    });

    testWidgets('« Voir les demandes » : sheet fermé, demandes du trajet, '
        'écran relu au retour', (tester) async {
      await open(tester, trip: _trip(), tile: TripTodoTile.requests);

      await tester.tap(requestsButton());
      await tester.pumpAndSettle();

      expect(find.text('Demandes à traiter'), findsNothing);
      expect(
        find.text('demandes:filter=aTraiter&announcement=trip-1'),
        findsOneWidget,
      );
      verifyNever(() => bidBloc.add(any()));

      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();

      final reloads = verify(() => bidBloc.add(captureAny())).captured;
      expect(reloads.single, isA<BidListRequested>());
      expect((reloads.single as BidListRequested).announcementId, 'trip-1');
      final details = verify(() => annBloc.add(captureAny())).captured;
      expect((details.single as AnnouncementDetailRequested).id, 'trip-1');
    });

    testWidgets('les demandes relues sont reprises par le sheet', (
      tester,
    ) async {
      await open(tester, trip: _trip(), tile: TripTodoTile.requests);

      bidStates.add(
        BidListLoaded([
          ..._pendingBids,
          _bid('b4', 'PENDING', description: 'Livres', weightKg: 4),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('trip-todo-request-b4')), findsOneWidget);
      expect(find.text('Voir les demandes (3)'), findsOneWidget);
    });

    testWidgets('un rechargement en cours garde les dernières demandes', (
      tester,
    ) async {
      await open(tester, trip: _trip(), tile: TripTodoTile.requests);

      bidStates.add(BidLoading());
      await tester.pumpAndSettle();

      expect(find.text('Demandes à traiter'), findsOneWidget);
      expect(find.byKey(const Key('trip-todo-request-b1')), findsOneWidget);
    });

    testWidgets('dernière demande traitée : le sheet se ferme seul', (
      tester,
    ) async {
      await open(tester, trip: _trip(), tile: TripTodoTile.requests);

      bidStates.add(BidListLoaded([_bid('b1', 'ACCEPTED')]));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Demandes à traiter'), findsNothing);
      expect(find.text('open-todo'), findsOneWidget);
    });

    testWidgets('trajet relu terminé : le sheet se ferme seul', (tester) async {
      await open(tester, trip: _trip(), tile: TripTodoTile.requests);

      annStates.add(AnnouncementDetailLoaded(_trip(status: 'COMPLETED')));
      await tester.pumpAndSettle();

      expect(find.text('Demandes à traiter'), findsNothing);
    });

    testWidgets('un autre trajet relu ne change rien', (tester) async {
      await open(tester, trip: _trip(), tile: TripTodoTile.requests);

      final other = AnnouncementModel(
        id: 'trip-2',
        travelerId: 'trav-1',
        departureCity: 'Lyon',
        arrivalCity: 'Dakar',
        departureDate: DateTime(2026, 11, 2),
        availableKg: 10,
        totalKg: 10,
        status: 'COMPLETED',
        createdAt: DateTime(2026, 10),
        updatedAt: DateTime(2026, 10),
      );
      annStates.add(AnnouncementDetailLoaded(other));
      await tester.pumpAndSettle();

      expect(find.text('Demandes à traiter'), findsOneWidget);
    });

    testWidgets('jamais refermé par-dessus une confirmation : fermé à son '
        'retour au premier plan', (tester) async {
      await open(tester, trip: _trip(), tile: TripTodoTile.requests);

      final sheetContext = tester.element(requestsButton());
      unawaited(
        showDialog<void>(
          context: sheetContext,
          builder: (_) => const AlertDialog(content: Text('confirmation')),
        ),
      );
      await tester.pumpAndSettle();

      bidStates.add(BidListLoaded(const []));
      await tester.pumpAndSettle();
      expect(find.text('confirmation'), findsOneWidget);
      expect(find.text('Demandes à traiter'), findsOneWidget);

      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();

      expect(find.text('confirmation'), findsNothing);
      expect(find.text('Demandes à traiter'), findsNothing);
    });

    testWidgets('sans blocs à l\'écran : contenu de l\'ouverture', (
      tester,
    ) async {
      await open(
        tester,
        trip: _trip(pendingBidCount: 1),
        tile: TripTodoTile.requests,
        withBlocs: false,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Une demande attend votre réponse'), findsOneWidget);
      expectSingleFooterButton(requestsButton());
    });
  });

  group('« Je pars »', () {
    testWidgets('explication du partage de l\'avancée, « Je pars » au pied', (
      tester,
    ) async {
      await open(tester, trip: _departTrip(), tile: TripTodoTile.depart);

      expect(tester.takeException(), isNull);
      expect(find.text('Je pars'), findsWidgets);
      expect(
        find.text(
          'Confirmez votre départ : vos expéditeurs voient que le trajet est '
          'lancé.',
        ),
        findsOneWidget,
      );
      expect(find.byType(TrackingConsentExplainer), findsOneWidget);
      expectSingleFooterButton(departButton());
    });

    testWidgets('« Je pars » appelle TripDepartCubit.depart', (tester) async {
      await open(tester, trip: _departTrip(), tile: TripTodoTile.depart);

      await tester.tap(departButton());
      await tester.pump();

      verify(() => departCubit.depart(any())).called(1);
      expect(createdDepartIds, isEmpty);
      expect(
        tester.element(departButton()).read<TripDepartCubit>(),
        same(departCubit),
      );
    });

    testWidgets('départ en cours : bouton en chargement, éteint', (
      tester,
    ) async {
      await open(
        tester,
        trip: _departTrip(),
        tile: TripTodoTile.depart,
        departState: const TripDepartState(loading: true),
        settle: false,
      );

      final button = tester.widget<DonyButton>(departButton());
      expect(button.isLoading, isTrue);
      expect(button.onPressed, isNull);
    });

    testWidgets('départ confirmé : confirmation et fermeture du sheet', (
      tester,
    ) async {
      await open(tester, trip: _departTrip(), tile: TripTodoTile.depart);

      departStates.add(const TripDepartState(departed: true));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(TrackingConsentExplainer), findsNothing);
      expect(find.text("C'est noté, bon voyage !"), findsOneWidget);
    });

    testWidgets('sans TripDepartCubit à l\'écran : le sheet crée le sien', (
      tester,
    ) async {
      await open(
        tester,
        trip: _departTrip(),
        tile: TripTodoTile.depart,
        withDepart: false,
      );

      expect(createdDepartIds, ['trip-1']);
      await tester.tap(departButton());
      await tester.pump();
      verify(() => departCubit.depart(any())).called(1);
    });

    testWidgets('fenêtre de suivi refermée par le trajet relu : fermeture', (
      tester,
    ) async {
      await open(tester, trip: _departTrip(), tile: TripTodoTile.depart);

      annStates.add(AnnouncementDetailLoaded(_trip(parcelsSummary: _summary)));
      await tester.pumpAndSettle();

      expect(find.byType(TrackingConsentExplainer), findsNothing);
    });
  });

  group('carte à ajouter', () {
    testWidgets('compte prêt : « Ajouter la carte à ce trajet »', (
      tester,
    ) async {
      await open(
        tester,
        trip: _cashTrip(),
        tile: TripTodoTile.card,
        stripe: _ready,
      );

      expect(tester.takeException(), isNull);
      expect(
        find.text(
          'Le paiement par carte est activé sur votre compte, mais ce trajet '
          "n'accepte encore que les espèces.",
        ),
        findsOneWidget,
      );
      expectSingleFooterButton(enableCard());
      // Titre et bouton : le même libellé existant.
      expect(find.text('Ajouter la carte à ce trajet'), findsNWidgets(2));
    });

    testWidgets('ajout : édition du trajet, trajet relu après enregistrement', (
      tester,
    ) async {
      await open(
        tester,
        trip: _cashTrip(),
        tile: TripTodoTile.card,
        stripe: _ready,
      );

      await tester.tap(enableCard());
      await tester.pumpAndSettle();

      expect(find.text('save-trip'), findsOneWidget);
      expect(createTripExtra, isA<CreateTripArgs>());
      expect((createTripExtra! as CreateTripArgs).announcement?.id, 'trip-1');
      verifyNever(() => annBloc.add(any()));

      await tester.tap(find.text('save-trip'));
      await tester.pumpAndSettle();

      final events = verify(() => annBloc.add(captureAny())).captured;
      expect((events.single as AnnouncementDetailRequested).id, 'trip-1');
    });

    testWidgets('édition quittée sans enregistrer : rien à relire', (
      tester,
    ) async {
      await open(
        tester,
        trip: _cashTrip(),
        tile: TripTodoTile.card,
        stripe: _ready,
      );

      await tester.tap(enableCard());
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();

      verifyNever(() => annBloc.add(any()));
    });

    testWidgets('compte pas prêt : « Activer les paiements par carte »', (
      tester,
    ) async {
      await open(tester, trip: _cashTrip(), tile: TripTodoTile.card);

      expect(tester.takeException(), isNull);
      expect(
        find.textContaining(
          'Beaucoup d\'expéditeurs préfèrent payer par carte',
        ),
        findsOneWidget,
      );
      expectSingleFooterButton(activateCard());

      await tester.tap(activateCard());
      await tester.pumpAndSettle();

      expect(find.text('stripe-onboarding-intro'), findsOneWidget);
    });

    testWidgets('carte ajoutée au trajet relu : fermeture', (tester) async {
      await open(
        tester,
        trip: _cashTrip(),
        tile: TripTodoTile.card,
        stripe: _ready,
      );

      annStates.add(
        AnnouncementUpdated(
          _trip(
            methods: const {BidPaymentMethod.cash, BidPaymentMethod.stripe},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ajouter la carte à ce trajet'), findsNothing);
    });

    testWidgets('trajet relu annulé : fermeture', (tester) async {
      await open(tester, trip: _cashTrip(), tile: TripTodoTile.card);

      annStates.add(AnnouncementDetailLoaded(_cashTrip(status: 'CANCELLED')));
      await tester.pumpAndSettle();

      expect(find.text('Activer les paiements par carte'), findsNothing);
    });
  });

  group('mesures', () {
    for (final tile in TripTodoTile.values) {
      testWidgets('bid_detail_tile_opened ${tile.name}, role trip_owner', (
        tester,
      ) async {
        await open(
          tester,
          trip: switch (tile) {
            TripTodoTile.requests => _trip(),
            TripTodoTile.depart => _departTrip(),
            TripTodoTile.card => _cashTrip(),
          },
          tile: tile,
        );
        verify(
          () => backend.capture(AnalyticsEvents.bidDetailTileOpened, {
            'tile': tile.name,
            'role': 'trip_owner',
            'source': 'tile',
          }),
        ).called(1);
      });
    }

    testWidgets('source link', (tester) async {
      await open(
        tester,
        trip: _trip(),
        tile: TripTodoTile.requests,
        source: TodoSource.link,
      );
      verify(
        () => backend.capture(AnalyticsEvents.bidDetailTileOpened, {
          'tile': 'requests',
          'role': 'trip_owner',
          'source': 'link',
        }),
      ).called(1);
    });
  });

  group('boutons à taille nominale', () {
    double labelScale(WidgetTester tester, Finder button, String label) {
      final fitted = find.descendant(
        of: button,
        matching: find.byWidgetPredicate(
          (w) => w is FittedBox && w.fit == BoxFit.scaleDown,
        ),
      );
      final text = find.descendant(of: button, matching: find.text(label));
      expect(fitted, findsOneWidget, reason: label);
      expect(text, findsOneWidget, reason: label);
      return tester.getSize(fitted).width / tester.getSize(text).width;
    }

    for (final locale in const [Locale('fr'), Locale('en')]) {
      final l = lookupAppLocalizations(locale);
      final cases =
          <
            (
              String,
              TripTodoTile,
              AnnouncementModel,
              StripeAccountState,
              Finder Function(),
              String,
            )
          >[
            (
              'demandes',
              TripTodoTile.requests,
              _trip(),
              _notReady,
              requestsButton,
              l.listingSeeRequestsButton(2),
            ),
            (
              'départ',
              TripTodoTile.depart,
              _departTrip(),
              _notReady,
              departButton,
              l.tripDepartButton,
            ),
            (
              'ajout de la carte',
              TripTodoTile.card,
              _cashTrip(),
              _ready,
              enableCard,
              l.listingEnableCardOnTripButton,
            ),
            (
              'activation de la carte',
              TripTodoTile.card,
              _cashTrip(),
              _notReady,
              activateCard,
              l.listingActivateCardPaymentsButton,
            ),
          ];
      for (final (name, tile, trip, stripe, button, label) in cases) {
        testWidgets('${locale.languageCode} $name à 360 dp, texte × 1,3', (
          tester,
        ) async {
          await open(
            tester,
            trip: trip,
            tile: tile,
            stripe: stripe,
            locale: locale,
            textScale: 1.3,
            size: const Size(360, 800),
          );

          expect(tester.takeException(), isNull);
          expect(tester.getSize(button()).height, 52, reason: label);
          expect(
            labelScale(tester, button(), label),
            closeTo(1, 0.001),
            reason: label,
          );
        });
      }
    }
  });
}
