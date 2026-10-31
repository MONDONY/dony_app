// Menu ⋮ de l'écran du trajet vu par son voyageur : entrées par état (table
// explicite), verrou du report, actions (dialogues Dépublier et Supprimer
// confirmés, annulation avec les colis remis, instructions de retrait,
// trajet récurrent et modèle), bouton de la barre d'application, FR / EN,
// 360 dp × 1,3.
import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/cancellation/presentation/widgets/cancellation_bottom_sheet.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/trip_group_cubit.dart';
import 'package:dony/features/matching/bloc/trip_series_cubit.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/trip_legs_info.dart';
import 'package:dony/features/matching/data/models/trip_series_result.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/matching/presentation/screens/create_trip_screen.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_owner_actions.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_owner_options_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/trip_reschedule_bottom_sheet.dart';
import 'package:dony/features/trip_templates/data/models/trip_template.dart';
import 'package:dony/features/trip_templates/data/repositories/trip_template_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/mock_analytics_backend.dart';
import 'trip_owner_harness.dart';

class _MockCancellationBloc
    extends MockBloc<CancellationEvent, CancellationState>
    implements CancellationBloc {}

class _MockAnnouncements extends Mock implements AnnouncementRepository {}

class _MockTemplates extends Mock implements TripTemplateRepository {}

class _MockTripGroupCubit extends MockCubit<TripGroupState>
    implements TripGroupCubit {}

List<TripMenuEntry> _entries(
  AnnouncementModel trip,
  List<BidModel>? bids, {
  bool isOwner = true,
}) => tripMenuEntriesFor(trip: trip, bids: bids, isOwner: isOwner);

void main() {
  group('tripMenuEntriesFor', () {
    const edit = TripMenuEntry.edit;
    const reschedule = TripMenuEntry.reschedule;
    const unpublish = TripMenuEntry.unpublish;
    const poster = TripMenuEntry.sharePoster;
    const arrival = TripMenuEntry.arrivalInstructions;
    const recurring = TripMenuEntry.makeRecurring;
    const template = TripMenuEntry.saveTemplate;
    const cancel = TripMenuEntry.cancelTrip;
    const delete = TripMenuEntry.delete;

    final pending = [ownerBid('b1', 'PENDING')];
    final accepted = [ownerBid('b1', 'ACCEPTED')];
    final handedOver = [ownerBid('b1', 'HANDED_OVER')];
    final arrived = [ownerBid('b1', 'ARRIVED')];
    final delivered = [ownerBid('b1', 'COMPLETED')];

    // Table explicite : (cas, trajet, colis chargés, entrées attendues).
    final table = <(String, AnnouncementModel, List<BidModel>?, List)>[
      ('DRAFT vide', ownerTrip(status: 'DRAFT'), const [], [edit, delete]),
      (
        'DRAFT étape d’un voyage',
        ownerTrip(status: 'DRAFT', tripGroupId: 'g1'),
        const [],
        [edit, delete],
      ),
      (
        'ACTIVE sans demande',
        ownerTrip(),
        const [],
        [edit, unpublish, poster, recurring, template, delete],
      ),
      (
        'ACTIVE étape d’un voyage, sans demande',
        ownerTrip(tripGroupId: 'g1'),
        const [],
        [edit, unpublish, poster, template, delete],
      ),
      (
        'ACTIVE avec une demande',
        ownerTrip(),
        pending,
        [reschedule, poster, recurring, template, cancel],
      ),
      (
        'ACTIVE avec un colis accepté',
        ownerTrip(),
        accepted,
        [reschedule, poster, recurring, template, cancel],
      ),
      (
        'ACTIVE avec un colis remis',
        ownerTrip(),
        handedOver,
        [reschedule, poster, recurring, template, cancel],
      ),
      (
        'ACTIVE avec un colis arrivé',
        ownerTrip(),
        arrived,
        [reschedule, poster, arrival, recurring, template, cancel],
      ),
      (
        'ACTIVE, colis pas chargés, demande au modèle',
        ownerTrip(pendingBidCount: 1),
        null,
        [reschedule, poster, recurring, template, cancel],
      ),
      (
        'ACTIVE, colis pas chargés, bidsCount au modèle',
        ownerTrip(bidsCount: 2),
        null,
        [reschedule, poster, recurring, template, cancel],
      ),
      (
        'FULL avec un colis accepté',
        ownerTrip(status: 'FULL'),
        accepted,
        [reschedule],
      ),
      (
        'FULL avec un colis arrivé',
        ownerTrip(status: 'FULL'),
        arrived,
        [reschedule, arrival],
      ),
      ('FULL sans colis', ownerTrip(status: 'FULL'), const [], const []),
      (
        'IN_PROGRESS avec un colis remis',
        ownerTrip(status: 'IN_PROGRESS'),
        handedOver,
        [reschedule],
      ),
      (
        'IN_PROGRESS avec instructions et colis arrivé',
        ownerTrip(status: 'IN_PROGRESS', arrivalInstructions: 'Rue 10'),
        arrived,
        [reschedule, arrival],
      ),
      (
        'COMPLETED sans colis',
        ownerTrip(status: 'COMPLETED'),
        const [],
        [recurring, template],
      ),
      (
        'COMPLETED livré avec instructions',
        ownerTrip(status: 'COMPLETED', arrivalInstructions: 'Rue 10'),
        delivered,
        [arrival, recurring, template],
      ),
      (
        'COMPLETED étape d’un voyage',
        ownerTrip(status: 'COMPLETED', tripGroupId: 'g1'),
        delivered,
        [template],
      ),
      (
        'CANCELLED sans colis',
        ownerTrip(status: 'CANCELLED'),
        const [],
        [delete],
      ),
      (
        'CANCELLED avec des colis',
        ownerTrip(status: 'CANCELLED'),
        accepted,
        [delete],
      ),
      (
        'REMOVED_BY_ADMIN',
        ownerTrip(status: 'REMOVED_BY_ADMIN'),
        accepted,
        const [],
      ),
      (
        'REMOVED_BY_ADMIN avec instructions',
        ownerTrip(status: 'REMOVED_BY_ADMIN', arrivalInstructions: 'Rue 10'),
        const [],
        [arrival],
      ),
      (
        'statut inconnu',
        ownerTrip(status: 'SOMETHING_NEW'),
        const [],
        const [],
      ),
    ];

    for (final (name, trip, bids, expected) in table) {
      test(name, () => expect(_entries(trip, bids), expected));
    }

    test('« Modifier » grisé n’existe plus : absent dès qu’on est engagé', () {
      expect(_entries(ownerTrip(), pending), isNot(contains(edit)));
    });

    test('FULL : ni annuler ni supprimer, quels que soient les colis', () {
      for (final bids in [const <BidModel>[], pending, accepted, arrived]) {
        final entries = _entries(ownerTrip(status: 'FULL'), bids);
        expect(entries, isNot(contains(cancel)));
        expect(entries, isNot(contains(delete)));
      }
    });

    test('visiteur : aucune entrée', () {
      for (final status in kTripStatuses) {
        expect(
          _entries(ownerTrip(status: status), arrived, isOwner: false),
          isEmpty,
        );
      }
    });
  });

  group('tripRescheduleBlockFor', () {
    test('colis en route, arrivé ou livré : verrouillé (FLUTTER-BD)', () {
      for (final s in ['IN_TRANSIT', 'ARRIVED', 'COMPLETED']) {
        expect(
          tripRescheduleBlockFor(ownerTrip(), [ownerBid('b1', s)]),
          TripRescheduleBlock.parcelOnTheWay,
          reason: s,
        );
      }
    });

    test('deux reports faits : verrouillé ; le colis en route prime', () {
      expect(
        tripRescheduleBlockFor(ownerTrip(remainingReschedules: 0), const []),
        TripRescheduleBlock.limitReached,
      );
      expect(
        tripRescheduleBlockFor(ownerTrip(remainingReschedules: 0), [
          ownerBid('b1', 'ARRIVED'),
        ]),
        TripRescheduleBlock.parcelOnTheWay,
      );
    });

    test('colis remis, reports restants, back ancien : ouvert', () {
      expect(
        tripRescheduleBlockFor(ownerTrip(remainingReschedules: 1), [
          ownerBid('b1', 'HANDED_OVER'),
        ]),
        isNull,
      );
      expect(tripRescheduleBlockFor(ownerTrip(), null), isNull);
    });

    test('tripCanReschedule : engagé et ACTIVE, FULL ou IN_PROGRESS', () {
      for (final status in kTripStatuses) {
        expect(
          tripCanReschedule(ownerTrip(status: status), true),
          const {'ACTIVE', 'FULL', 'IN_PROGRESS'}.contains(status),
          reason: status,
        );
        expect(tripCanReschedule(ownerTrip(status: status), false), isFalse);
      }
    });
  });

  group('menu', () {
    late MockAnnouncementBloc annBloc;
    late MockBidBloc bidBloc;
    late _MockCancellationBloc cancelBloc;
    late MockAnalyticsBackend backend;
    late _MockTemplates templates;
    late _MockAnnouncements announcements;
    late List<TripSeriesCubit> cubits;

    setUpAll(() async {
      registerFallbackValue(AnnouncementDetailRequested('fallback'));
      registerFallbackValue(<String, dynamic>{});
      await initializeDateFormatting('fr');
      await initializeDateFormatting('en');
      await loadAppFonts();
    });

    setUp(() async {
      annBloc = MockAnnouncementBloc();
      bidBloc = MockBidBloc();
      cancelBloc = _MockCancellationBloc();
      whenListen(
        annBloc,
        const Stream<AnnouncementState>.empty(),
        initialState: AnnouncementInitial(),
      );
      whenListen(
        bidBloc,
        const Stream<BidState>.empty(),
        initialState: BidInitial(),
      );
      whenListen(
        cancelBloc,
        const Stream<CancellationState>.empty(),
        initialState: CancellationInitial(),
      );
      backend = MockAnalyticsBackend();
      final analytics = makeEnabledAnalytics(backend);
      await analytics.onConfigured();
      templates = _MockTemplates();
      announcements = _MockAnnouncements();
      cubits = [];
      await getIt.reset();
      getIt
        ..registerSingleton<AnalyticsService>(analytics)
        ..registerFactoryParam<TripSeriesCubit, AnnouncementModel, void>((
          a,
          _,
        ) {
          final cubit = TripSeriesCubit(
            a,
            announcements,
            templates,
            analytics,
            now: () => DateTime(2026, 10, 15),
          );
          cubits.add(cubit);
          return cubit;
        });
      DonySnackbar.clearDedup();
    });

    tearDown(() async => getIt.reset());

    Future<List<PushedRoute>> openMenu(
      WidgetTester tester, {
      required AnnouncementModel trip,
      List<BidModel>? bids = const [],
      Locale locale = const Locale('fr'),
      double textScale = 1,
      Size size = const Size(360, 800),
      TripGroupCubit? group,
    }) async {
      final pushed = await pumpTripOwnerScreen(
        tester,
        announcement: annBloc,
        bids: bidBloc,
        cancellation: cancelBloc,
        group: group,
        locale: locale,
        textScale: textScale,
        size: size,
        body: (context) => TextButton(
          onPressed: () =>
              showTripOwnerOptionsSheet(context, trip: trip, bids: bids),
          child: const Text('open-menu'),
        ),
      );
      await tester.tap(find.text('open-menu'));
      await tester.pumpAndSettle();
      return pushed;
    }

    Finder entry(TripMenuEntry e) => find.byKey(Key('trip-menu-${e.name}'));

    testWidgets('entrées dans l’ordre, libellés et sous-titres FR', (
      tester,
    ) async {
      await openMenu(tester, trip: ownerTrip());
      expect(find.text('Options'), findsOneWidget);
      final expected = {
        TripMenuEntry.edit: (
          'Modifier',
          'Villes, dates, kilos, prix et conditions',
        ),
        TripMenuEntry.unpublish: (
          'Dépublier',
          'Le trajet ne sera plus visible et restera dans vos brouillons.',
        ),
        TripMenuEntry.sharePoster: ("Partager l'affiche", 'Partager le trajet'),
        TripMenuEntry.makeRecurring: (
          'Rendre ce trajet récurrent',
          "Le même trajet à d'autres dates",
        ),
        TripMenuEntry.saveTemplate: (
          'Enregistrer en modèle',
          'Pour le republier en quelques gestes',
        ),
        TripMenuEntry.delete: (
          'Supprimer',
          'Le trajet disparaît de vos trajets',
        ),
      };
      double? lastTop;
      for (final MapEntry(key: e, value: (label, subtitle))
          in expected.entries) {
        expect(
          find.descendant(of: entry(e), matching: find.text(label)),
          findsOneWidget,
          reason: e.name,
        );
        expect(
          find.descendant(of: entry(e), matching: find.text(subtitle)),
          findsOneWidget,
          reason: e.name,
        );
        final top = tester.getTopLeft(entry(e)).dy;
        if (lastTop != null) expect(top, greaterThan(lastTop));
        lastTop = top;
      }
      for (final e in [
        TripMenuEntry.reschedule,
        TripMenuEntry.arrivalInstructions,
        TripMenuEntry.cancelTrip,
      ]) {
        expect(entry(e), findsNothing, reason: e.name);
      }
    });

    testWidgets('libellés EN', (tester) async {
      await openMenu(
        tester,
        trip: ownerTrip(arrivalInstructions: 'Gate 2'),
        bids: [ownerBid('b1', 'ARRIVED')],
        locale: const Locale('en'),
      );
      for (final text in [
        'Reschedule',
        'Share the poster',
        'Pickup instructions',
        'Make this trip recurring',
        'Save as template',
        'Cancel the trip',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
    });

    // Le sheet n'a « Modifier les instructions » qu'après l'arrivée (un
    // colis ARRIVED) : avant, ou sur un trajet terminé ou annulé, l'entrée
    // n'annonce pas de saisie.
    group('Instructions de retrait : sous-titre', () {
      Finder subtitle(String text) => find.descendant(
        of: entry(TripMenuEntry.arrivalInstructions),
        matching: find.text(text),
      );

      testWidgets('colis arrivé : saisie annoncée', (tester) async {
        await openMenu(
          tester,
          trip: ownerTrip(status: 'IN_PROGRESS', arrivalInstructions: 'Rue 10'),
          bids: [ownerBid('b1', 'ARRIVED')],
        );
        expect(
          subtitle('Indiquez où et comment récupérer le colis'),
          findsOneWidget,
        );
        expect(subtitle('Ce que voient les destinataires'), findsNothing);
      });

      for (final (status, bids) in [
        ('COMPLETED', [ownerBid('b1', 'COMPLETED')]),
        ('CANCELLED', <BidModel>[]),
        ('IN_PROGRESS', [ownerBid('b1', 'IN_TRANSIT')]),
      ]) {
        testWidgets('$status sans colis arrivé : lecture seule', (
          tester,
        ) async {
          await openMenu(
            tester,
            trip: ownerTrip(status: status, arrivalInstructions: 'Rue 10'),
            bids: bids,
          );
          expect(subtitle('Ce que voient les destinataires'), findsOneWidget);
          expect(
            subtitle('Indiquez où et comment récupérer le colis'),
            findsNothing,
          );
        });
      }

      testWidgets('anglais', (tester) async {
        await openMenu(
          tester,
          trip: ownerTrip(status: 'COMPLETED', arrivalInstructions: 'Rue 10'),
          locale: const Locale('en'),
        );
        expect(subtitle('What recipients see'), findsOneWidget);
        await openMenu(
          tester,
          trip: ownerTrip(status: 'IN_PROGRESS', arrivalInstructions: 'Rue 10'),
          bids: [ownerBid('b1', 'ARRIVED')],
          locale: const Locale('en'),
        );
        expect(
          subtitle('Say where and how to pick up the parcel'),
          findsOneWidget,
        );
      });
    });

    testWidgets('Reporter verrouillé : la vraie raison, aucun effet', (
      tester,
    ) async {
      await openMenu(
        tester,
        trip: ownerTrip(status: 'IN_PROGRESS'),
        bids: [ownerBid('b1', 'IN_TRANSIT')],
      );
      expect(
        find.text(
          'Un colis est déjà en route, arrivé ou livré : le trajet ne peut '
          'plus être reporté.',
        ),
        findsOneWidget,
      );
      await tester.tap(entry(TripMenuEntry.reschedule));
      await tester.pumpAndSettle();
      expect(entry(TripMenuEntry.reschedule), findsOneWidget);
      expect(find.byType(TripRescheduleBottomSheet), findsNothing);

      await openMenu(
        tester,
        trip: ownerTrip(remainingReschedules: 0),
        bids: [ownerBid('b1', 'ACCEPTED')],
      );
      expect(
        find.text('Déjà reporté 2 fois : annulez et publiez un nouveau trajet'),
        findsOneWidget,
      );
    });

    testWidgets('Reporter ouvert : feuille du report nommée', (tester) async {
      await openMenu(
        tester,
        trip: ownerTrip(status: 'FULL', remainingReschedules: 2),
        bids: [ownerBid('b1', 'ACCEPTED')],
      );
      expect(
        find.text(
          'Vol annulé ou voyage repoussé : choisissez la nouvelle date.',
        ),
        findsOneWidget,
      );
      await tester.tap(entry(TripMenuEntry.reschedule));
      await tester.pumpAndSettle();
      expect(entry(TripMenuEntry.reschedule), findsNothing);
      final sheet = find.byType(TripRescheduleBottomSheet);
      expect(sheet, findsOneWidget);
      expect(sheetRouteName(tester, sheet), '/sheet/trip-owner/reschedule');
    });

    testWidgets('Modifier ouvre l’édition du trajet', (tester) async {
      final pushed = await openMenu(tester, trip: ownerTrip(status: 'DRAFT'));
      await tester.tap(entry(TripMenuEntry.edit));
      await tester.pumpAndSettle();
      expect(pushed.single.location, '/trips/create');
      expect(
        (pushed.single.extra! as CreateTripArgs).announcement?.id,
        'trip-1',
      );
    });

    testWidgets('Partager l’affiche ouvre l’affiche', (tester) async {
      final pushed = await openMenu(tester, trip: ownerTrip());
      await tester.tap(entry(TripMenuEntry.sharePoster));
      await tester.pumpAndSettle();
      expect(pushed.single.location, '/announcements/trip-1/affiche');
    });

    testWidgets('Dépublier : confirmé, AnnouncementUnpublishRequested', (
      tester,
    ) async {
      await openMenu(tester, trip: ownerTrip());
      await tester.tap(entry(TripMenuEntry.unpublish));
      await tester.pumpAndSettle();
      expect(find.text('Dépublier ce trajet ?'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Dépublier'),
        ),
      );
      await tester.pumpAndSettle();
      final added = verify(() => annBloc.add(captureAny())).captured;
      expect(added.single, isA<AnnouncementUnpublishRequested>());
      expect((added.single as AnnouncementUnpublishRequested).id, 'trip-1');
    });

    testWidgets('Dépublier : renoncer ne fait rien', (tester) async {
      await openMenu(tester, trip: ownerTrip());
      await tester.tap(entry(TripMenuEntry.unpublish));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      verifyNever(() => annBloc.add(any()));
    });

    for (final (status, message) in const [
      (
        'ACTIVE',
        'Cette action est irréversible. Le trajet ne sera plus visible pour '
            'les expéditeurs.',
      ),
      (
        'CANCELLED',
        'Cette action est irréversible. Le trajet annulé et toutes les '
            'demandes associées seront définitivement retirés de la '
            'plateforme.',
      ),
    ]) {
      testWidgets('Supprimer ($status) : confirmé, DeleteRequested', (
        tester,
      ) async {
        await openMenu(tester, trip: ownerTrip(status: status));
        await tester.tap(entry(TripMenuEntry.delete));
        await tester.pumpAndSettle();
        expect(find.text(message), findsOneWidget);
        await tester.tap(
          find.descendant(
            of: find.byType(Dialog),
            matching: find.text('Supprimer'),
          ),
        );
        await tester.pumpAndSettle();
        final added = verify(() => annBloc.add(captureAny())).captured;
        final event = added.single as AnnouncementDeleteRequested;
        expect(event.id, 'trip-1');
        // Trajet isolé : aucune étape suivante à annuler.
        expect(event.followingLegIds, isEmpty);
      });
    }

    testWidgets('Supprimer : renoncer ne fait rien', (tester) async {
      await openMenu(tester, trip: ownerTrip(status: 'DRAFT'));
      await tester.tap(entry(TripMenuEntry.delete));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      verifyNever(() => annBloc.add(any()));
    });

    testWidgets('Annuler le voyage : feuille nommée, colis remis passés', (
      tester,
    ) async {
      await openMenu(
        tester,
        trip: ownerTrip(),
        bids: [
          ownerBid('b1', 'HANDED_OVER'),
          ownerBid('b2', 'IN_TRANSIT'),
          ownerBid('b3', 'ACCEPTED'),
          ownerBid('b4', 'PENDING'),
        ],
      );
      await tester.tap(entry(TripMenuEntry.cancelTrip));
      await tester.pumpAndSettle();
      final sheet = find.byType(CancellationBottomSheet);
      expect(sheet, findsOneWidget);
      expect(
        tester.widget<CancellationBottomSheet>(sheet).handedOverParcels,
        2,
      );
      expect(
        find.byKey(const Key('cancellation-handed-over-notice')),
        findsOneWidget,
      );
      expect(sheetRouteName(tester, sheet), '/sheet/trip-owner/cancel');
    });

    testWidgets('Instructions de retrait : sheet « Arrivée », source menu', (
      tester,
    ) async {
      await openMenu(
        tester,
        trip: ownerTrip(status: 'IN_PROGRESS', arrivalInstructions: 'Rue 10'),
        bids: [ownerBid('b1', 'ARRIVED')],
      );
      verifyNever(() => backend.capture(any(), any()));
      await tester.tap(entry(TripMenuEntry.arrivalInstructions));
      await tester.pumpAndSettle();
      expect(find.text('Rue 10'), findsOneWidget);
      expect(
        sheetRouteName(tester, find.text('Rue 10')),
        '/sheet/trip-owner/arrival',
      );
      verify(
        () => backend.capture(AnalyticsEvents.bidDetailTileOpened, {
          'tile': 'arrival',
          'role': 'trip_owner',
          'source': 'menu',
        }),
      ).called(1);
    });

    testWidgets('Rendre récurrent : calendrier, trip_series_opened', (
      tester,
    ) async {
      await openMenu(tester, trip: ownerTrip(status: 'COMPLETED'));
      await tester.tap(entry(TripMenuEntry.makeRecurring));
      await tester.pumpAndSettle();
      expect(find.text('Quand refaites-vous ce trajet ?'), findsOneWidget);
      expect(cubits, hasLength(1));
      expect(cubits.single.announcement.id, 'trip-1');
      verify(
        () => backend.capture(AnalyticsEvents.tripSeriesOpened, any()),
      ).called(1);

      // Fermé sans rien créer : le cubit du parcours est fermé.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(cubits.single.isClosed, isTrue);
    });

    testWidgets('Enregistrer en modèle : feuille seule, enregistrement', (
      tester,
    ) async {
      when(() => templates.create(any())).thenAnswer(
        (_) async => const TripTemplate(
          id: 'tpl',
          label: 'Paris → Dakar',
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          transportMode: 'PLANE',
          capacityUnit: 'KG',
          availableKg: 20,
          pricePerKg: 7,
          acceptedCategories: [],
        ),
      );
      await openMenu(tester, trip: ownerTrip());
      await tester.tap(entry(TripMenuEntry.saveTemplate));
      await tester.pumpAndSettle();
      expect(find.text('En faire un modèle de trajet ?'), findsOneWidget);
      // Pas de série : ni pastille de trajets publiés, ni « Non merci ».
      expect(find.byKey(const Key('trip-series-badge')), findsNothing);
      expect(find.byKey(const Key('trip-template-skip')), findsNothing);
      verifyNever(
        () => backend.capture(AnalyticsEvents.tripSeriesOpened, any()),
      );

      await tester.tap(find.byKey(const Key('trip-template-save')));
      await tester.pumpAndSettle();
      final payload =
          verify(() => templates.create(captureAny())).captured.single
              as Map<String, dynamic>;
      expect(payload['label'], 'Paris → Dakar');
      expect(find.text('Modèle enregistré'), findsOneWidget);
      verify(
        () => backend.capture(AnalyticsEvents.tripSeriesTemplateSaved, any()),
      ).called(1);
      expect(cubits.single.isClosed, isTrue);
      await tester.pump(const Duration(seconds: 5));
    });

    group('Supprimer une étape d\'un voyage (FLUTTER-4D)', () {
      final legs = TripLegsInfo.fromJson(const {
        'tripGroupId': 'g',
        'legCount': 3,
        'legs': [
          {'id': 'trip-1', 'legIndex': 1, 'departureDate': '2026-11-12'},
          {'id': 'leg-2', 'legIndex': 2, 'departureDate': '2026-11-14'},
          {'id': 'leg-3', 'legIndex': 3, 'departureDate': '2026-11-20'},
        ],
      });

      TripGroupCubit groupCubit() {
        final cubit = _MockTripGroupCubit();
        whenListen(
          cubit,
          const Stream<TripGroupState>.empty(),
          initialState: TripGroupState(
            status: TripGroupStatus.loaded,
            info: legs,
          ),
        );
        return cubit;
      }

      Future<void> deleteAndConfirm(WidgetTester tester) async {
        await openMenu(
          tester,
          trip: ownerTrip(tripGroupId: 'g'),
          group: groupCubit(),
        );
        await tester.tap(entry(TripMenuEntry.delete));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(Dialog),
            matching: find.text('Supprimer'),
          ),
        );
        await tester.pumpAndSettle();
        // Puis la question des étapes suivantes, après la confirmation.
        expect(
          find.text('Annuler aussi les étapes suivantes ?'),
          findsOneWidget,
        );
        verifyNever(() => annBloc.add(any()));
      }

      testWidgets('« Annuler les suivantes » : leurs identifiants', (
        tester,
      ) async {
        await deleteAndConfirm(tester);
        await tester.tap(find.text('Annuler les suivantes'));
        await tester.pumpAndSettle();
        final event =
            verify(() => annBloc.add(captureAny())).captured.single
                as AnnouncementDeleteRequested;
        expect(event.id, 'trip-1');
        expect(event.followingLegIds, ['leg-2', 'leg-3']);
      });

      testWidgets('« Les garder » : aucune étape en plus', (tester) async {
        await deleteAndConfirm(tester);
        await tester.tap(find.text('Les garder'));
        await tester.pumpAndSettle();
        final event =
            verify(() => annBloc.add(captureAny())).captured.single
                as AnnouncementDeleteRequested;
        expect(event.followingLegIds, isEmpty);
      });

      testWidgets('question fermée sans choisir : rien n\'est supprimé', (
        tester,
      ) async {
        await deleteAndConfirm(tester);
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        verifyNever(() => annBloc.add(any()));
      });
    });

    group('trajet récurrent : la réponse n\'est jamais perdue', () {
      final created = TripSeriesResult(
        seriesId: 's1',
        created: [ownerTrip(), ownerTrip()],
        failed: const [],
      );

      void stubSeries(Future<TripSeriesResult> Function() answer) => when(
        () => announcements.createSeries(
          any(),
          dates: any(named: 'dates'),
          saveAsDraft: any(named: 'saveAsDraft'),
        ),
      ).thenAnswer((_) => answer());

      Future<void> pickDateAndPublish(WidgetTester tester) async {
        await openMenu(tester, trip: ownerTrip());
        await tester.tap(entry(TripMenuEntry.makeRecurring));
        await tester.pumpAndSettle();
        expect(
          sheetRouteName(
            tester,
            find.text(
              'Quand refaites-vous ce '
              'trajet ?',
            ),
          ),
          '/sheet/trip-series/calendar',
        );
        await tester.tap(find.byKey(const Key('trip-series-day-2026-11-20')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('trip-series-publish')));
        await tester.pump();
      }

      testWidgets('calendrier fermé pendant l\'envoi : trip_series_created, '
          'confirmation sur l\'écran, cubit fermé ensuite', (tester) async {
        final reply = Completer<TripSeriesResult>();
        stubSeries(() => reply.future);
        await pickDateAndPublish(tester);

        // Le voyageur ferme la feuille d'un geste, réponse encore en vol.
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        expect(find.text('Quand refaites-vous ce trajet ?'), findsNothing);
        expect(cubits.single.isClosed, isFalse);

        reply.complete(created);
        await tester.pumpAndSettle();
        verify(
          () => backend.capture(AnalyticsEvents.tripSeriesCreated, {
            'count': 2,
            'failed': 0,
            'draft': false,
          }),
        ).called(1);
        expect(find.text('2 trajets publiés'), findsOneWidget);
        expect(cubits.single.isClosed, isTrue);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 5));
      });

      testWidgets('calendrier fermé pendant l\'envoi refusé : le motif', (
        tester,
      ) async {
        final reply = Completer<TripSeriesResult>();
        stubSeries(() => reply.future);
        await pickDateAndPublish(tester);
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();

        reply.completeError(Exception('offline'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            "Impossible d'ajouter ces dates pour le moment. Réessayez.",
          ),
          findsOneWidget,
        );
        expect(cubits.single.isClosed, isTrue);
        await tester.pump(const Duration(seconds: 5));
      });

      testWidgets('« Non merci » au modèle : les trajets créés restent dits', (
        tester,
      ) async {
        stubSeries(() async => created);
        await pickDateAndPublish(tester);
        await tester.pumpAndSettle();
        expect(find.text('En faire un modèle de trajet ?'), findsOneWidget);
        expect(
          sheetRouteName(tester, find.text('En faire un modèle de trajet ?')),
          '/sheet/trip-series/template',
        );

        await tester.tap(find.byKey(const Key('trip-template-skip')));
        await tester.pumpAndSettle();
        expect(find.text('En faire un modèle de trajet ?'), findsNothing);
        expect(find.text('2 trajets publiés'), findsOneWidget);
        expect(cubits.single.isClosed, isTrue);
        await tester.pump(const Duration(seconds: 5));
      });

      testWidgets('offre du modèle fermée d\'un geste : idem', (tester) async {
        stubSeries(() async => created);
        await pickDateAndPublish(tester);
        await tester.pumpAndSettle();

        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        expect(find.text('2 trajets publiés'), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
      });

      testWidgets('modèle enregistré après la série : une seule confirmation', (
        tester,
      ) async {
        stubSeries(() async => created);
        when(() => templates.create(any())).thenAnswer((_) async => _tpl);
        await pickDateAndPublish(tester);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('trip-template-save')));
        await tester.pumpAndSettle();
        expect(find.text('Modèle enregistré'), findsOneWidget);
        expect(find.text('2 trajets publiés'), findsNothing);
        await tester.pump(const Duration(seconds: 5));
      });
    });

    testWidgets('Enregistrer en modèle : feuille fermée pendant l\'envoi, '
        'confirmation sur l\'écran', (tester) async {
      final reply = Completer<TripTemplate>();
      when(() => templates.create(any())).thenAnswer((_) => reply.future);
      await openMenu(tester, trip: ownerTrip());
      await tester.tap(entry(TripMenuEntry.saveTemplate));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('trip-template-save')));
      await tester.pump();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(cubits.single.isClosed, isFalse);

      reply.complete(_tpl);
      await tester.pumpAndSettle();
      expect(find.text('Modèle enregistré'), findsOneWidget);
      verify(
        () => backend.capture(AnalyticsEvents.tripSeriesTemplateSaved, any()),
      ).called(1);
      expect(cubits.single.isClosed, isTrue);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('entrée verrouillée : raison à contraste normal, lue d\'un '
        'trait, annoncée désactivée', (tester) async {
      final handle = tester.ensureSemantics();
      await openMenu(
        tester,
        trip: ownerTrip(status: 'IN_PROGRESS'),
        bids: [ownerBid('b1', 'IN_TRANSIT')],
      );
      const reason =
          'Un colis est déjà en route, arrivé ou livré : le trajet ne peut '
          'plus être reporté.';
      // Ni la raison ni aucun de ses parents n'est estompé.
      expect(
        find.ancestor(of: find.text(reason), matching: find.byType(Opacity)),
        findsNothing,
      );
      // Le libellé, lui, l'est.
      final labelOpacity = tester.widget<Opacity>(
        find.ancestor(
          of: find.text('Reporter'),
          matching: find.byType(Opacity),
        ),
      );
      expect(labelOpacity.opacity, 0.4);
      expect(
        tester.getSemantics(entry(TripMenuEntry.reschedule)),
        matchesSemantics(
          label: 'Reporter\n$reason',
          isButton: true,
          hasEnabledState: true,
          // isEnabled faux par défaut : annoncée désactivée.
        ),
      );
      await openMenu(tester, trip: ownerTrip());
      expect(
        tester.getSemantics(entry(TripMenuEntry.saveTemplate)),
        matchesSemantics(
          label: 'Enregistrer en modèle\nPour le republier en quelques gestes',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('le menu lui-même n’émet aucun événement', (tester) async {
      await openMenu(tester, trip: ownerTrip());
      verifyNever(() => backend.capture(any(), any()));
    });

    for (final locale in const [Locale('fr'), Locale('en')]) {
      testWidgets(
        'toutes les entrées à 360 dp × 1,3 (${locale.languageCode})',
        (tester) async {
          await openMenu(
            tester,
            trip: ownerTrip(arrivalInstructions: 'Rue 10'),
            bids: [ownerBid('b1', 'ARRIVED'), ownerBid('b2', 'PENDING')],
            locale: locale,
            textScale: 1.3,
            size: const Size(360, 640),
          );
          expect(tester.takeException(), isNull);
          expect(entry(TripMenuEntry.cancelTrip), findsOneWidget);
          await tester.drag(
            find.byType(SingleChildScrollView).last,
            const Offset(0, -600),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  group('bouton ⋮', () {
    setUpAll(() async {
      await initializeDateFormatting('fr');
    });

    setUp(() async {
      await getIt.reset();
      getIt.registerSingleton<AnalyticsService>(
        makeEnabledAnalytics(MockAnalyticsBackend()),
      );
    });

    tearDown(() async => getIt.reset());

    Future<void> pumpBar(
      WidgetTester tester,
      AnnouncementModel trip, {
      bool isOwner = true,
      Locale locale = const Locale('fr'),
    }) => pumpTripOwnerScreen(
      tester,
      locale: locale,
      appBar: DonyAppBar(
        title: 'Trajet',
        actions: [
          TripOwnerOptionsButton(trip: trip, bids: const [], isOwner: isOwner),
        ],
      ),
    );

    const button = Key('trip-owner-menu-button');

    testWidgets('avant le scarabée, cible ≥ 44 px, nom accessible', (
      tester,
    ) async {
      await pumpBar(tester, ownerTrip());
      final menu = find.byKey(button);
      expect(menu, findsOneWidget);
      final feedback = find.byType(DonyFeedbackButton);
      expect(feedback, findsOneWidget);
      expect(
        tester.getCenter(menu).dx,
        lessThan(tester.getCenter(feedback).dx),
      );
      final size = tester.getSize(menu);
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
      expect(find.byTooltip('Options du trajet'), findsOneWidget);
    });

    testWidgets('EN : nom accessible', (tester) async {
      await pumpBar(tester, ownerTrip(), locale: const Locale('en'));
      expect(find.byTooltip('Trip options'), findsOneWidget);
    });

    testWidgets('ouvre le menu', (tester) async {
      await pumpBar(tester, ownerTrip());
      await tester.tap(find.byKey(button));
      await tester.pumpAndSettle();
      expect(find.text('Options'), findsOneWidget);
      expect(find.byKey(const Key('trip-menu-edit')), findsOneWidget);
    });

    testWidgets('absent sans entrée ou pour un visiteur', (tester) async {
      await pumpBar(tester, ownerTrip(status: 'REMOVED_BY_ADMIN'));
      expect(find.byKey(button), findsNothing);
      await pumpBar(tester, ownerTrip(), isOwner: false);
      expect(find.byKey(button), findsNothing);
    });
  });
}

const _tpl = TripTemplate(
  id: 'tpl',
  label: 'Paris → Dakar',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  transportMode: 'PLANE',
  capacityUnit: 'KG',
  availableKg: 20,
  pricePerKg: 7,
  acceptedCategories: [],
);
