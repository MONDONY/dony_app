// Bottom sheets des tuiles « Votre trajet » de l'écran du trajet (vue du
// voyageur propriétaire) : itinéraire et lieux, paiements, conditions,
// affiche, arrivée. Contenu repris de l'ancien corps de détail (mêmes
// assertions que les anciens tests du corps et de son encart de paiement,
// supprimés avec lui, pour les sections déplacées), bouton dans le pied
// selon que le trajet est
// modifiable, trajet et colis relus suivis, fermeture seule, navigation,
// mesure d'ouverture, statuts REMOVED_BY_ADMIN et inconnu, FR / EN, libellés
// à taille nominale à 360 dp × 1,3.
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
import 'package:dony/features/matching/bloc/trip_audience_cubit.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/mobile_money_network.dart';
import 'package:dony/features/matching/data/models/trip_audience_model.dart';
import 'package:dony/features/matching/presentation/screens/create_trip_screen.dart';
import 'package:dony/features/matching/presentation/widgets/arrival_instructions_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/todo_tile_views.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_tile_sheets.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_tiles.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/mock_analytics_backend.dart';
import '../../../../../helpers/stripe_account_test_doubles.dart';

class _MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockTripAudienceCubit extends MockCubit<TripAudienceState>
    implements TripAudienceCubit {}

const _notReady = StripeAccountReady(
  ConnectAccountStatus(status: 'NOT_CREATED'),
);

const _pickup = AddressData(
  label: '12 rue de Paris, 75001',
  lat: 48.85,
  lng: 2.35,
);
const _delivery = AddressData(
  label: 'Marché Sandaga, Dakar',
  lat: 14.67,
  lng: -17.43,
);

const _orangeCi = MobileMoneyNetwork(
  code: 'ORANGE_CIV',
  label: 'Orange Money',
  brand: 'ORANGE',
  country: 'CI',
);
const _orangeSn = MobileMoneyNetwork(
  code: 'ORANGE_SEN',
  label: 'Orange Money',
  brand: 'ORANGE',
  country: 'SN',
);
const _mtnCi = MobileMoneyNetwork(
  code: 'MTN_MOMO_CIV',
  label: 'MTN MoMo',
  brand: 'MTN',
  country: 'CI',
);

/// Trajet complet (tous les lieux, moyens et conditions), celui des anciens
/// tests du corps de détail.
AnnouncementModel _trip({
  String id = 'trip-1',
  String status = 'ACTIVE',
  bool places = true,
  bool conditions = true,
  Set<BidPaymentMethod> methods = const {
    BidPaymentMethod.cash,
    BidPaymentMethod.stripe,
  },
  List<MobileMoneyNetwork> networks = const [],
  String currency = 'EUR',
  String? description = 'Pas de produits fragiles svp.',
  String? instructions,
  AddressData pickup = _pickup,
}) => AnnouncementModel(
  id: id,
  travelerId: 'trav-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2026, 8, 12),
  availableKg: 10,
  totalKg: 10,
  pricePerKg: 7,
  status: status,
  createdAt: DateTime(2026, 7),
  updatedAt: DateTime(2026, 7),
  pickupAddress: places ? pickup : null,
  deliveryAddress: places ? _delivery : null,
  handoverDeadline: places ? DateTime(2026, 8, 10, 18) : null,
  acceptedPaymentMethods: methods,
  acceptedMobileMoneyNetworks: networks,
  currency: currency,
  acceptedContentTypes: conditions ? const ['Vêtements', 'Documents'] : null,
  refusedTypes: conditions ? const ['Liquides'] : null,
  description: conditions ? description : null,
  arrivalInstructions: instructions,
);

AnnouncementModel _cashOnly({
  String status = 'ACTIVE',
  String currency = 'EUR',
}) => _trip(
  status: status,
  methods: const {BidPaymentMethod.cash},
  currency: currency,
);

BidModel _bid(String id, String status) => BidModel(
  id: id,
  announcementId: 'trip-1',
  senderId: 'sender-$id',
  status: status,
  createdAt: DateTime(2026, 7),
  updatedAt: DateTime(2026, 7),
);

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
  late List<({String location, Object? extra})> pushed;

  setUpAll(() async {
    registerFallbackValue(AnnouncementDetailRequested('fallback'));
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
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
    annBloc = _MockAnnouncementBloc();
    bidBloc = _MockBidBloc();
    pushed = [];

    await getIt.reset();
    getIt.registerSingleton<AnalyticsService>(analytics);
    DonySnackbar.clearDedup();
  });

  tearDown(() async => getIt.reset());

  /// Ouvre la feuille depuis un `Builder` posé sous les blocs de l'écran,
  /// comme le fera la grille « Votre trajet ».
  Future<void> open(
    WidgetTester tester, {
    required AnnouncementModel trip,
    required TripTile tile,
    List<BidModel>? bids = const [],
    StripeAccountState stripe = _notReady,
    bool withBlocs = true,
    Locale locale = const Locale('fr'),
    double textScale = 1,
    Size? size,
    TileSource source = TileSource.tile,
    List<BidModel>? screenBids,
    TripAudienceCubit? audience,
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
      initialState: bids == null ? BidLoading() : BidListLoaded(bids),
    );
    final stripeBloc = stubStripeAccountBloc(state: stripe);

    Widget screen(BuildContext context) {
      final opener = Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => openTripTileSheet(
              context,
              trip,
              tile,
              source: source,
              bids: screenBids,
            ),
            child: const Text('open-tile'),
          ),
        ),
      );
      if (!withBlocs) return opener;
      return MultiBlocProvider(
        providers: [
          BlocProvider<AnnouncementBloc>.value(value: annBloc),
          BlocProvider<BidBloc>.value(value: bidBloc),
          BlocProvider<StripeAccountBloc>.value(value: stripeBloc),
          if (audience != null)
            BlocProvider<TripAudienceCubit>.value(value: audience),
        ],
        child: opener,
      );
    }

    Widget stub(BuildContext context, GoRouterState state) {
      pushed.add((location: state.uri.toString(), extra: state.extra));
      return Scaffold(
        body: TextButton(
          onPressed: () => context.pop(true),
          child: const Text('save-trip'),
        ),
      );
    }

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, _) => screen(context)),
        GoRoute(path: '/trips/create', builder: stub),
        GoRoute(path: '/announcements/:id/affiche', builder: stub),
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
    await tester.tap(find.text('open-tile'));
    await tester.pumpAndSettle();
  }

  Finder footer() => find.byKey(const Key('donyBottomSheetFooter'));
  Finder inFooter(Finder f) => find.descendant(of: footer(), matching: f);
  Finder content(TripTile tile) =>
      find.byKey(Key('trip-tile-${tile.name}-content'));
  Finder editButton() => find.byKey(const Key('trip-tile-edit-button'));
  Finder posterButton() => find.byKey(const Key('trip-tile-poster-button'));
  Finder arrivalButton() =>
      find.byKey(const Key('trip-tile-arrival-edit-button'));

  /// Seul bouton du sheet : dans le pied, aucun dans le contenu défilant.
  void expectSingleFooterButton(Finder button) {
    expect(inFooter(button), findsOneWidget);
    expect(find.byType(DonyButton), findsOneWidget);
  }

  void expectNoButton() {
    expect(footer(), findsNothing);
    expect(find.byType(DonyButton), findsNothing);
  }

  group('itinéraire et lieux', () {
    testWidgets('lieux de remise et dépôt des colis, comme le corps', (
      tester,
    ) async {
      await open(tester, trip: _trip(), tile: TripTile.itinerary);

      expect(find.text('Itinéraire et lieux'), findsOneWidget);
      expect(find.text('LIEUX DE REMISE'), findsOneWidget);
      expect(find.text('12 rue de Paris, 75001'), findsOneWidget);
      expect(find.text('Marché Sandaga, Dakar'), findsOneWidget);
      expect(find.text('DÉPÔT DES COLIS'), findsOneWidget);
      expect(find.text("Jusqu'au lun. 10 août à 18:00"), findsOneWidget);
      // Les autres sections et les étapes du voyage restent hors du sheet.
      expect(find.text('PAIEMENTS ACCEPTÉS'), findsNothing);
      expect(find.text("CE QUE J'ACCEPTE"), findsNothing);
      expect(find.byKey(const Key('trip-legs-card')), findsNothing);
    });

    // PROD-1R : limite reçue en UTC, affichée à l'heure de la ville de départ.
    testWidgets("date limite à l'heure de Paris (18:30Z en été → 20:30)", (
      tester,
    ) async {
      final trip = AnnouncementModel.fromJson({
        'id': 'trip-1',
        'travelerId': 'trav-1',
        'departureCity': 'Paris',
        'arrivalCity': 'Dakar',
        'departureDate': DateTime(2026, 8, 12).toIso8601String(),
        'availableKg': 5,
        'totalKg': 5,
        'pricePerKg': 6,
        'status': 'ACTIVE',
        'handoverDeadline': '2026-08-10T18:30:00Z',
        'departureTimezone': 'Europe/Paris',
        'createdAt': DateTime(2026, 7).toIso8601String(),
        'updatedAt': DateTime(2026, 7).toIso8601String(),
      });
      await open(tester, trip: trip, tile: TripTile.itinerary);

      expect(find.textContaining('20:30'), findsOneWidget);
      expect(find.text('LIEUX DE REMISE'), findsNothing);
    });

    testWidgets('en anglais : titres de section traduits', (tester) async {
      await open(
        tester,
        trip: _trip(),
        tile: TripTile.itinerary,
        locale: const Locale('en'),
      );

      expect(find.text('Route and places'), findsOneWidget);
      expect(find.text('DROP-OFF LOCATIONS'), findsOneWidget);
      expect(find.text('PARCEL DROP-OFF DEADLINE'), findsOneWidget);
      expect(find.text('LIEUX DE REMISE'), findsNothing);
      expect(inFooter(find.text('Edit')), findsOneWidget);
    });

    testWidgets('trajet modifiable : « Modifier » dans le pied', (
      tester,
    ) async {
      await open(tester, trip: _trip(), tile: TripTile.itinerary);

      expectSingleFooterButton(editButton());
      expect(inFooter(find.text('Modifier')), findsOneWidget);
    });

    testWidgets('« Modifier » ferme le sheet, ouvre l\'édition, relit', (
      tester,
    ) async {
      await open(tester, trip: _trip(), tile: TripTile.itinerary);

      await tester.tap(editButton());
      await tester.pumpAndSettle();
      expect(content(TripTile.itinerary), findsNothing);
      expect(pushed.single.location, '/trips/create');
      expect(
        (pushed.single.extra! as CreateTripArgs).announcement?.id,
        'trip-1',
      );

      await tester.tap(find.text('save-trip'));
      await tester.pumpAndSettle();
      final captured = verify(() => annBloc.add(captureAny())).captured;
      expect((captured.single as AnnouncementDetailRequested).id, 'trip-1');
    });

    testWidgets('demandes ou colis : pas de pied, pas de bouton', (
      tester,
    ) async {
      await open(
        tester,
        trip: _trip(),
        tile: TripTile.itinerary,
        bids: [_bid('b1', 'ACCEPTED')],
      );

      expect(content(TripTile.itinerary), findsOneWidget);
      expectNoButton();
    });

    for (final status in const [
      'FULL',
      'IN_PROGRESS',
      'COMPLETED',
      'CANCELLED',
      'REMOVED_BY_ADMIN',
      'SOMETHING_NEW',
    ]) {
      testWidgets('$status : lecture seule', (tester) async {
        await open(
          tester,
          trip: _trip(status: status),
          tile: TripTile.itinerary,
        );

        expect(find.text('LIEUX DE REMISE'), findsOneWidget);
        expectNoButton();
      });
    }

    testWidgets('DRAFT sans demande : modifiable', (tester) async {
      await open(
        tester,
        trip: _trip(status: 'DRAFT'),
        tile: TripTile.itinerary,
      );

      expectSingleFooterButton(editButton());
    });

    testWidgets('colis pas encore chargés : compteurs du modèle', (
      tester,
    ) async {
      final engaged = AnnouncementModel(
        id: 'trip-1',
        travelerId: 'trav-1',
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        departureDate: DateTime(2026, 8, 12),
        availableKg: 10,
        totalKg: 10,
        status: 'ACTIVE',
        createdAt: DateTime(2026, 7),
        updatedAt: DateTime(2026, 7),
        pickupAddress: _pickup,
        confirmedParcelCount: 1,
      );
      await open(tester, trip: engaged, tile: TripTile.itinerary, bids: null);

      expectNoButton();
    });

    testWidgets('ouvert pendant un rechargement : les colis acceptés de '
        "l'écran comptent", (tester) async {
      await open(
        tester,
        trip: _trip(),
        tile: TripTile.itinerary,
        bids: null,
        screenBids: [_bid('b1', 'ACCEPTED')],
      );

      expectNoButton();
    });

    testWidgets('une demande arrive pendant que le sheet est ouvert : le '
        'bouton disparaît', (tester) async {
      await open(tester, trip: _trip(), tile: TripTile.itinerary);
      expect(editButton(), findsOneWidget);

      bidStates.add(BidListLoaded([_bid('b1', 'PENDING')]));
      await tester.pumpAndSettle();
      expect(editButton(), findsNothing);
      // Ni bordure ni ombre : plus aucun conteneur de pied.
      expect(footer(), findsNothing);
      expect(content(TripTile.itinerary), findsOneWidget);
    });

    testWidgets('le trajet redevient modifiable : le pied revient', (
      tester,
    ) async {
      await open(
        tester,
        trip: _trip(),
        tile: TripTile.itinerary,
        bids: [_bid('b1', 'PENDING')],
      );
      expectNoButton();

      // La demande a été refusée ailleurs : liste relue sans elle.
      bidStates.add(BidListLoaded([_bid('b1', 'REJECTED')]));
      await tester.pumpAndSettle();
      expectSingleFooterButton(editButton());
    });

    testWidgets('double appui sur « Modifier » : une seule édition', (
      tester,
    ) async {
      await open(tester, trip: _trip(), tile: TripTile.itinerary);

      // Second appui avant que la sortie du sheet ne soit dessinée.
      await tester.tap(editButton());
      await tester.tap(editButton(), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(pushed, hasLength(1));
      expect(pushed.single.location, '/trips/create');
    });

    testWidgets('suit le trajet relu (lieux modifiés)', (tester) async {
      await open(tester, trip: _trip(), tile: TripTile.itinerary);

      annStates.add(
        AnnouncementUpdated(
          _trip(
            pickup: const AddressData(
              label: '3 place Bellecour, Lyon',
              lat: 45.76,
              lng: 4.83,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('3 place Bellecour, Lyon'), findsOneWidget);
      expect(find.text('12 rue de Paris, 75001'), findsNothing);
    });
  });

  group('paiements', () {
    testWidgets('puces des moyens acceptés, sans bouton', (tester) async {
      await open(tester, trip: _trip(), tile: TripTile.payments);

      expect(find.text('Paiements'), findsOneWidget);
      expect(find.text('PAIEMENTS ACCEPTÉS'), findsOneWidget);
      expect(find.text('💵 Espèces'), findsOneWidget);
      expect(find.text('💳 Carte'), findsOneWidget);
      expect(find.text('LIEUX DE REMISE'), findsNothing);
      expectNoButton();
    });

    // La puce MOBILE_MONEY s'affichait avec la valeur brute de l'API.
    testWidgets('mobile money → puce « Mobile money », jamais la valeur '
        'brute', (tester) async {
      await open(
        tester,
        trip: _trip(
          methods: const {BidPaymentMethod.cash, BidPaymentMethod.mobileMoney},
        ),
        tile: TripTile.payments,
      );

      expect(find.textContaining('Mobile money'), findsOneWidget);
      expect(find.textContaining('MOBILE_MONEY'), findsNothing);
      expect(find.textContaining('Espèces'), findsOneWidget);
      expect(find.byKey(const Key('trip-mobile-money-networks')), findsNothing);
    });

    testWidgets('réseaux mobile money acceptés, pays si la marque se répète', (
      tester,
    ) async {
      await open(
        tester,
        trip: _trip(
          methods: const {BidPaymentMethod.mobileMoney},
          networks: const [_orangeCi, _orangeSn, _mtnCi],
          currency: 'XOF',
        ),
        tile: TripTile.payments,
      );

      expect(find.text('RÉSEAUX MOBILE MONEY'), findsOneWidget);
      expect(find.text('Orange CI'), findsOneWidget);
      expect(find.text('Orange SN'), findsOneWidget);
      expect(find.text('MTN'), findsOneWidget);
    });

    testWidgets('réseaux servis sans mobile money accepté : non affichés', (
      tester,
    ) async {
      await open(
        tester,
        trip: _trip(networks: const [_orangeCi]),
        tile: TripTile.payments,
      );

      expect(find.byKey(const Key('trip-mobile-money-networks')), findsNothing);
    });

    testWidgets('en anglais', (tester) async {
      await open(
        tester,
        trip: _trip(
          methods: const {BidPaymentMethod.mobileMoney},
          networks: const [_mtnCi],
          currency: 'XOF',
        ),
        tile: TripTile.payments,
        locale: const Locale('en'),
      );

      expect(find.text('Payments'), findsOneWidget);
      expect(find.text('ACCEPTED PAYMENT METHODS'), findsOneWidget);
      expect(find.text('MOBILE MONEY NETWORKS'), findsOneWidget);
    });

    testWidgets('espèces seules, carte possible : renvoi vers « À traiter », '
        'sans l\'encart ni son bouton', (tester) async {
      await open(tester, trip: _cashOnly(), tile: TripTile.payments);

      expect(
        find.byKey(const Key('trip-tile-payments-cash-note')),
        findsOneWidget,
      );
      expect(
        find.text(
          "Ce trajet n'accepte que les espèces. Pour ajouter la carte, voyez "
          '« À traiter ».',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('activate-card-payments-cta')), findsNothing);
      expect(find.byKey(const Key('enable-card-on-trip-cta')), findsNothing);
      expectNoButton();
    });

    testWidgets('renvoi en anglais : nom réel de la section', (tester) async {
      await open(
        tester,
        trip: _cashOnly(),
        tile: TripTile.payments,
        locale: const Locale('en'),
      );

      expect(
        find.text(
          'This trip only accepts cash. To add card payments, see “To do”.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('suit le trajet relu (moyens modifiés)', (tester) async {
      await open(tester, trip: _trip(), tile: TripTile.payments);
      expect(find.text('💳 Carte'), findsOneWidget);

      annStates.add(
        AnnouncementUpdated(_trip(methods: const {BidPaymentMethod.cash})),
      );
      await tester.pumpAndSettle();
      expect(find.text('💳 Carte'), findsNothing);
      expect(find.text('💵 Espèces'), findsOneWidget);
    });

    for (final (name, trip, stripe) in [
      ('devise sans carte (XOF)', _cashOnly(currency: 'XOF'), _notReady),
      ('Stripe absent du pays', _cashOnly(), stripeCountryUnavailableState),
      ('trajet terminé', _cashOnly(status: 'COMPLETED'), _notReady),
      ('trajet annulé', _cashOnly(status: 'CANCELLED'), _notReady),
      ('trajet retiré', _cashOnly(status: 'REMOVED_BY_ADMIN'), _notReady),
      ('carte déjà acceptée', _trip(), _notReady),
    ]) {
      testWidgets('$name : pas de renvoi', (tester) async {
        await open(tester, trip: trip, tile: TripTile.payments, stripe: stripe);

        expect(find.text('PAIEMENTS ACCEPTÉS'), findsOneWidget);
        expect(
          find.byKey(const Key('trip-tile-payments-cash-note')),
          findsNothing,
        );
      });
    }
  });

  group('conditions', () {
    testWidgets('accepté, refusé, note, comme le corps', (tester) async {
      await open(tester, trip: _trip(), tile: TripTile.conditions);

      expect(find.text('Conditions'), findsOneWidget);
      expect(find.text("CE QUE J'ACCEPTE"), findsOneWidget);
      expect(find.text('Vêtements'), findsOneWidget);
      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('CE QUE JE REFUSE'), findsOneWidget);
      expect(find.text('Liquides'), findsOneWidget);
      expect(find.text('NOTE AUX EXPÉDITEURS'), findsOneWidget);
      expect(find.text('Pas de produits fragiles svp.'), findsOneWidget);
      expect(find.text('LIEUX DE REMISE'), findsNothing);
      expectSingleFooterButton(editButton());
    });

    testWidgets('trajet engagé : lecture seule', (tester) async {
      await open(
        tester,
        trip: _trip(),
        tile: TripTile.conditions,
        bids: [_bid('b1', 'PAYMENT_ESCROWED')],
      );

      expect(find.text("CE QUE J'ACCEPTE"), findsOneWidget);
      expectNoButton();
    });

    testWidgets('REMOVED_BY_ADMIN : lecture seule', (tester) async {
      await open(
        tester,
        trip: _trip(status: 'REMOVED_BY_ADMIN'),
        tile: TripTile.conditions,
      );

      expect(find.text('NOTE AUX EXPÉDITEURS'), findsOneWidget);
      expectNoButton();
    });

    testWidgets('« Modifier » ouvre l\'édition', (tester) async {
      await open(tester, trip: _trip(), tile: TripTile.conditions);

      await tester.tap(editButton());
      await tester.pumpAndSettle();
      expect(pushed.single.location, '/trips/create');
    });

    testWidgets('suit le trajet relu, ignore un autre trajet', (tester) async {
      await open(tester, trip: _trip(), tile: TripTile.conditions);

      annStates.add(
        AnnouncementUpdated(_trip(id: 'other', description: 'Autre trajet')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Autre trajet'), findsNothing);

      annStates.add(AnnouncementUpdated(_trip(description: 'Merci beaucoup')));
      await tester.pumpAndSettle();
      expect(find.text('Merci beaucoup'), findsOneWidget);
      expect(find.text('Pas de produits fragiles svp.'), findsNothing);

      // Un chargement garde le dernier trajet connu.
      annStates.add(AnnouncementLoading());
      await tester.pumpAndSettle();
      expect(find.text('Merci beaucoup'), findsOneWidget);
    });

    testWidgets('plus rien à montrer après relecture : le sheet se ferme', (
      tester,
    ) async {
      await open(tester, trip: _trip(), tile: TripTile.conditions);

      annStates.add(AnnouncementDetailLoaded(_trip(conditions: false)));
      await tester.pumpAndSettle();
      expect(content(TripTile.conditions), findsNothing);
    });

    testWidgets('note faite d\'espaces : pas d\'encart vide', (tester) async {
      await open(
        tester,
        trip: _trip(description: '   '),
        tile: TripTile.conditions,
      );

      expect(find.text("CE QUE J'ACCEPTE"), findsOneWidget);
      expect(find.text('NOTE AUX EXPÉDITEURS'), findsNothing);
    });
  });

  group('affiche', () {
    final audienceLine = find.byKey(const Key('trip-audience-card'));

    _MockTripAudienceCubit audienceCubit(
      TripAudienceState initial, [
      Stream<TripAudienceState> states = const Stream.empty(),
    ]) {
      final cubit = _MockTripAudienceCubit();
      whenListen(cubit, states, initialState: initial);
      when(() => cubit.load(any())).thenAnswer((_) async {});
      return cubit;
    }

    testWidgets('audience chargée par l\'écran : sa ligne sous l\'aperçu, '
        'sans la recharger', (tester) async {
      final cubit = audienceCubit(
        const TripAudienceState.loaded(
          TripAudienceModel(uniqueViewerCount: 12, shareViewCount: 3),
        ),
      );
      await open(tester, trip: _trip(), tile: TripTile.poster, audience: cubit);
      expect(audienceLine, findsOneWidget);
      expect(
        find.text(
          '12 personnes ont vu votre trajet · 3 vues de votre affiche partagée',
        ),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(audienceLine).dy,
        greaterThan(
          tester.getTopLeft(find.textContaining('Votre trajet en image')).dy,
        ),
      );
      verifyNever(() => cubit.load(any()));
    });

    testWidgets('audience qui arrive pendant l\'ouverture : la ligne suit', (
      tester,
    ) async {
      final states = StreamController<TripAudienceState>.broadcast();
      addTearDown(states.close);
      final cubit = audienceCubit(
        const TripAudienceState.loading(),
        states.stream,
      );
      await open(tester, trip: _trip(), tile: TripTile.poster, audience: cubit);
      expect(audienceLine, findsNothing);
      states.add(
        const TripAudienceState.loaded(
          TripAudienceModel(uniqueViewerCount: 1, shareViewCount: 0),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('1 personne a vu votre trajet'), findsOneWidget);
    });

    testWidgets('audience en échec ou absente : pas de ligne', (tester) async {
      await open(
        tester,
        trip: _trip(),
        tile: TripTile.poster,
        audience: audienceCubit(const TripAudienceState.hidden()),
      );
      expect(audienceLine, findsNothing);
      expect(find.textContaining('Votre trajet en image'), findsOneWidget);
    });

    testWidgets('anglais', (tester) async {
      await open(
        tester,
        trip: _trip(),
        tile: TripTile.poster,
        locale: const Locale('en'),
        audience: audienceCubit(
          const TripAudienceState.loaded(
            TripAudienceModel(uniqueViewerCount: 12, shareViewCount: 0),
          ),
        ),
      );
      expect(find.text('12 people have seen your trip'), findsOneWidget);
    });

    testWidgets('aperçu et « Partager l\'affiche » dans le pied', (
      tester,
    ) async {
      await open(tester, trip: _trip(), tile: TripTile.poster);

      expect(find.text('Affiche'), findsOneWidget);
      expect(find.textContaining('Votre trajet en image'), findsOneWidget);
      expectSingleFooterButton(posterButton());
      expect(inFooter(find.text("Partager l'affiche")), findsOneWidget);
    });

    testWidgets('le bouton ferme le sheet et ouvre l\'affiche du trajet', (
      tester,
    ) async {
      final trip = _trip();
      await open(tester, trip: trip, tile: TripTile.poster);

      await tester.tap(posterButton());
      await tester.pumpAndSettle();
      expect(content(TripTile.poster), findsNothing);
      expect(pushed.single.location, '/announcements/trip-1/affiche');
      expect(pushed.single.extra, trip);
    });

    testWidgets('trajet devenu complet : le sheet se ferme', (tester) async {
      await open(tester, trip: _trip(), tile: TripTile.poster);

      annStates.add(AnnouncementDetailLoaded(_trip(status: 'FULL')));
      await tester.pumpAndSettle();
      expect(content(TripTile.poster), findsNothing);
      expect(pushed, isEmpty);
    });

    testWidgets('jamais refermé par-dessus une confirmation, fermé quand '
        'elle se referme', (tester) async {
      await open(tester, trip: _trip(), tile: TripTile.poster);

      unawaited(
        showDialog<void>(
          context: tester.element(content(TripTile.poster)),
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('close-dialog'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      annStates.add(AnnouncementDetailLoaded(_trip(status: 'FULL')));
      await tester.pumpAndSettle();
      expect(find.text('close-dialog'), findsOneWidget);
      expect(content(TripTile.poster), findsOneWidget);

      await tester.tap(find.text('close-dialog'));
      await tester.pumpAndSettle();
      expect(content(TripTile.poster), findsNothing);
    });

    testWidgets('double appui sur « Partager l\'affiche » : une seule '
        'affiche', (tester) async {
      await open(tester, trip: _trip(), tile: TripTile.poster);

      await tester.tap(posterButton());
      await tester.tap(posterButton(), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(pushed, hasLength(1));
    });
  });

  group('arrivée', () {
    testWidgets('instructions et colis arrivé : carte et bouton', (
      tester,
    ) async {
      await open(
        tester,
        trip: _trip(instructions: '  Au marché, stand 12  '),
        tile: TripTile.arrival,
        bids: [_bid('b1', 'ARRIVED')],
      );

      expect(find.text('Arrivée'), findsOneWidget);
      expect(
        find.byKey(const Key('arrival-instructions-card')),
        findsOneWidget,
      );
      expect(find.text('Au marché, stand 12'), findsOneWidget);
      expectSingleFooterButton(arrivalButton());
      expect(inFooter(find.text('Modifier les instructions')), findsOneWidget);
    });

    testWidgets('colis arrivé sans instructions : texte d\'invite', (
      tester,
    ) async {
      await open(
        tester,
        trip: _trip(),
        tile: TripTile.arrival,
        bids: [_bid('b1', 'ARRIVED'), _bid('b2', 'IN_TRANSIT')],
      );

      expect(find.byKey(const Key('trip-tile-arrival-empty')), findsOneWidget);
      expect(find.byKey(const Key('arrival-instructions-card')), findsNothing);
      expectSingleFooterButton(arrivalButton());
    });

    testWidgets('instructions sans colis arrivé (trajet soldé) : lecture '
        'seule, le back refuserait la modification', (tester) async {
      await open(
        tester,
        trip: _trip(status: 'COMPLETED', instructions: 'Au marché'),
        tile: TripTile.arrival,
        bids: [_bid('b1', 'COMPLETED')],
      );

      expect(
        find.byKey(const Key('arrival-instructions-card')),
        findsOneWidget,
      );
      expectNoButton();
    });

    testWidgets('le bouton ouvre l\'édition des instructions', (tester) async {
      await open(
        tester,
        trip: _trip(instructions: 'Au marché'),
        tile: TripTile.arrival,
        bids: [_bid('b1', 'ARRIVED')],
      );

      await tester.tap(arrivalButton());
      await tester.pumpAndSettle();
      expect(content(TripTile.arrival), findsNothing);
      final sheet = tester.widget<ArrivalInstructionsBottomSheet>(
        find.byType(ArrivalInstructionsBottomSheet),
      );
      expect(sheet.isEditing, isTrue);
      expect(sheet.announcementId, 'trip-1');
      expect(sheet.initialInstructions, 'Au marché');
      expect(find.text('Enregistrer'), findsOneWidget);
      // Feuille du parcours nommée, branche « édition » (piège n°14).
      expect(
        ModalRoute.of(
          tester.element(find.byType(ArrivalInstructionsBottomSheet)),
        )?.settings.name,
        '/sheet/trip-owner/arrival-instructions',
      );
    });

    testWidgets('instructions relues après modification', (tester) async {
      await open(
        tester,
        trip: _trip(instructions: 'Au marché'),
        tile: TripTile.arrival,
        bids: [_bid('b1', 'ARRIVED')],
      );

      annStates.add(
        AnnouncementArrivalInstructionsUpdated(
          _trip(instructions: 'À la gare routière'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('À la gare routière'), findsOneWidget);
    });

    testWidgets('sans blocs à l\'écran : instructions en lecture seule', (
      tester,
    ) async {
      await open(
        tester,
        trip: _trip(instructions: 'Au marché'),
        tile: TripTile.arrival,
        withBlocs: false,
      );

      expect(
        find.byKey(const Key('arrival-instructions-card')),
        findsOneWidget,
      );
      expectNoButton();
    });

    testWidgets('ouvert pendant un rechargement des colis, sans '
        'instructions : reste ouvert', (tester) async {
      await open(tester, trip: _trip(), tile: TripTile.arrival, bids: null);

      expect(content(TripTile.arrival), findsOneWidget);
      expect(find.byKey(const Key('trip-tile-arrival-empty')), findsOneWidget);
      expectNoButton();

      // La liste répond : un colis arrivé, le bouton apparaît.
      bidStates.add(BidListLoaded([_bid('b1', 'ARRIVED')]));
      await tester.pumpAndSettle();
      expect(content(TripTile.arrival), findsOneWidget);
      expectSingleFooterButton(arrivalButton());
    });

    testWidgets('ouvert pendant un rechargement : reprend les colis de '
        "l'écran", (tester) async {
      await open(
        tester,
        trip: _trip(instructions: 'Au marché'),
        tile: TripTile.arrival,
        bids: null,
        screenBids: [_bid('b1', 'ARRIVED')],
      );

      expectSingleFooterButton(arrivalButton());
    });

    testWidgets('colis relus sans colis arrivé ni instructions : le sheet se '
        'ferme', (tester) async {
      await open(tester, trip: _trip(), tile: TripTile.arrival, bids: null);

      bidStates.add(BidListLoaded([_bid('b1', 'IN_TRANSIT')]));
      await tester.pumpAndSettle();
      expect(content(TripTile.arrival), findsNothing);
    });
  });

  testWidgets('sans blocs à l\'écran : rendu statique', (tester) async {
    await open(
      tester,
      trip: _trip(),
      tile: TripTile.itinerary,
      withBlocs: false,
    );

    expect(find.text('LIEUX DE REMISE'), findsOneWidget);
    expectSingleFooterButton(editButton());
  });

  group('mesure et nom du sheet', () {
    for (final tile in TripTile.values) {
      testWidgets('${tile.name} : bid_detail_tile_opened et nom de route', (
        tester,
      ) async {
        await open(
          tester,
          trip: _trip(instructions: 'Au marché'),
          tile: tile,
          bids: [_bid('b1', 'ARRIVED')],
        );

        verify(
          () => backend.capture(AnalyticsEvents.bidDetailTileOpened, {
            'tile': tile.name,
            'role': 'trip_owner',
            'source': 'tile',
          }),
        ).called(1);
        final route = ModalRoute.of(tester.element(content(tile)))!;
        expect(route.settings.name, '/sheet/trip-owner/${tile.name}');
      });
    }

    testWidgets('ouvert depuis le menu : source menu', (tester) async {
      await open(
        tester,
        trip: _trip(instructions: 'Au marché'),
        tile: TripTile.arrival,
        source: TileSource.menu,
      );

      verify(
        () => backend.capture(AnalyticsEvents.bidDetailTileOpened, {
          'tile': 'arrival',
          'role': 'trip_owner',
          'source': 'menu',
        }),
      ).called(1);
    });
  });

  group('360 dp, texte × 1,3', () {
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

      for (final (tile, button, label) in [
        (TripTile.itinerary, editButton, l.commonEdit),
        (TripTile.conditions, editButton, l.commonEdit),
        (TripTile.poster, posterButton, l.tripPosterShareButton),
        (TripTile.arrival, arrivalButton, l.tripTileArrivalEditButton),
      ]) {
        testWidgets('${locale.languageCode} ${tile.name} : bouton à taille '
            'nominale', (tester) async {
          await open(
            tester,
            trip: _trip(instructions: 'Au marché'),
            tile: tile,
            // Un colis arrivé engage le trajet : « Modifier » n'y est plus.
            bids: tile == TripTile.arrival ? [_bid('b1', 'ARRIVED')] : const [],
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

      testWidgets('${locale.languageCode} paiements : contenu sans '
          'débordement', (tester) async {
        await open(
          tester,
          trip: _trip(
            methods: const {
              BidPaymentMethod.cash,
              BidPaymentMethod.stripe,
              BidPaymentMethod.mobileMoney,
            },
            networks: const [_orangeCi, _orangeSn, _mtnCi],
          ),
          tile: TripTile.payments,
          locale: locale,
          textScale: 1.3,
          size: const Size(360, 800),
        );

        expect(tester.takeException(), isNull);
        expect(content(TripTile.payments), findsOneWidget);
      });
    }
  });
}
