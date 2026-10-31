// « À traiter » complet branché sur l'écran du trajet vu par son voyageur
// (rangement « 3 · Prochaine action », décision du 31/10) : pastille du
// billet, grosse carte de chaque type (titre, étiquette, échéance, bouton),
// carte de réponse directe quand les demandes sont en tête, file (0, 1, 3
// lignes et « + N autres »), toute la liste, gestes de chaque type (flux
// existants du trajet, sheets par colis), pied collant qui suit l'action,
// ligne Colis et sheet Colis, mesures, scénarios de la maquette, FR / EN,
// 360 dp × 1,3 avec les vraies polices, trajets brouillon, annulé, retiré.
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart' as acs;
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/trip_audience_cubit.dart';
import 'package:dony/features/matching/bloc/trip_group_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/arrival_instructions_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/recipient_contact/notify_recipients_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_bid_answer.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_owner_body.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_owner_sticky_bar.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_labels.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_live.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/tracking/bloc/trip_depart_cubit.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/stripe_account_test_doubles.dart';
import 'trip_answer_harness.dart';
import 'trip_todo_fixtures.dart';

class _MockDepart extends MockCubit<TripDepartState>
    implements TripDepartCubit {}

void main() {
  late AnswerHarness h;

  setUpAll(() async {
    AnswerHarness.registerFallbacks();
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
    await loadAppFonts();
  });

  setUp(() async {
    h = AnswerHarness();
    await h.setUp();
    tripTodoNow = () => kTodoNow;
  });

  tearDown(() async {
    tripTodoNow = DateTime.now;
    await h.tearDown();
  });

  /// Monte le corps et le pied collant de l'écran sous ses blocs et le
  /// scope de réponse, comme l'écran (le pied lit départ et compte de
  /// paiement par `TripTodoLive`). Les écrans poussés sont notés.
  Future<List<String>> pump(
    WidgetTester tester,
    TodoScenario s, {
    Locale locale = const Locale('fr'),
    double textScale = 1,
    Size size = const Size(400, 2400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    whenListen(
      h.annBloc,
      h.annStates.stream,
      initialState: AnnouncementDetailLoaded(s.trip),
    );
    whenListen(
      h.screenBids,
      h.screenStates.stream,
      initialState: BidListLoaded(s.bids),
    );
    whenListen(h.answerBids, h.answerStates.stream, initialState: BidInitial());
    whenListen(
      h.acceptance,
      h.acceptanceStates.stream,
      initialState: acs.BidAcceptanceInitial(),
    );
    final audience = MockTripAudienceCubit();
    whenListen(
      audience,
      const Stream<TripAudienceState>.empty(),
      initialState: const TripAudienceState.hidden(),
    );
    when(() => audience.load(any())).thenAnswer((_) async {});
    final depart = _MockDepart();
    whenListen(
      depart,
      const Stream<TripDepartState>.empty(),
      initialState: TripDepartState(departed: s.departed),
    );
    final group = MockTripGroupCubit();
    whenListen(
      group,
      const Stream<TripGroupState>.empty(),
      initialState: const TripGroupState(),
    );

    final pushed = <String>[];
    Widget stub(BuildContext context, GoRouterState state) {
      pushed.add(state.uri.toString());
      return Scaffold(
        body: TextButton(
          onPressed: () => context.pop(),
          child: const Text('back'),
        ),
      );
    }

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => MultiBlocProvider(
            providers: [
              BlocProvider<AnnouncementBloc>.value(value: h.annBloc),
              BlocProvider<BidBloc>.value(value: h.screenBids),
              BlocProvider<TripAudienceCubit>.value(value: audience),
              BlocProvider<TripGroupCubit>.value(value: group),
              BlocProvider<TripDepartCubit>.value(value: depart),
              BlocProvider<StripeAccountBloc>.value(
                value: stubStripeAccountBloc(state: s.stripe),
              ),
            ],
            child: TripBidAnswerScope(
              tripId: s.trip.id,
              bidBloc: h.answerBids,
              acceptanceBloc: h.acceptance,
              child: Scaffold(
                body: TripOwnerBody(trip: s.trip, isOwner: true),
                bottomNavigationBar: Builder(
                  builder: (context) => TripTodoLive(
                    trip: s.trip,
                    blocs: TripTodoBlocs.of(context),
                    builder: (context, live) => TripOwnerStickyBar(
                      trip: live.trip,
                      bids: live.bids,
                      isOwner: true,
                      departed: live.departed,
                      stripe: live.stripe,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        GoRoute(path: '/bids/:bidId', builder: stub),
        GoRoute(path: '/tracking/validate', builder: stub),
        GoRoute(path: '/connect/onboarding/intro', builder: stub),
        GoRoute(path: '/trips/create', builder: stub),
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
    await tester.pump(const Duration(milliseconds: 400));
    return pushed;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Finder key(String k) => find.byKey(Key(k));
  Finder semanticsLabel(String label) => find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == label,
  );
  Finder bar() => key('trip-owner-sticky-bar');
  Finder inBar(Finder f) => find.descendant(of: bar(), matching: f);
  Finder inCard(TripTodoKind kind, Finder f) =>
      find.descendant(of: key('trip-todo-next-${kind.name}'), matching: f);
  final fr = lookupAppLocalizations(const Locale('fr'));

  void verifyOpened(String tile, String source) => verify(
    () => h.backend.capture(AnalyticsEvents.bidDetailTileOpened, {
      'tile': tile,
      'role': 'trip_owner',
      'source': source,
    }),
  ).called(1);

  group('pastille « À traiter · N » du billet', () {
    testWidgets('0 : rien', (tester) async {
      await pump(tester, todoMockupScenarios()['calme']!);
      expect(key('trip-todo-badge'), findsNothing);
      expect(key('trip-todo-section'), findsNothing);
    });

    testWidgets('1 : « À traiter · 1 », dans l\'en-tête du billet', (
      tester,
    ) async {
      await pump(tester, todoScenarioFor(TripTodoKind.publish));
      expect(
        find.descendant(
          of: key('trip-billet-header'),
          matching: find.text('À traiter · 1'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('N : demandes et colis comptés un par un, lue « N choses à '
        'traiter »', (tester) async {
      await pump(tester, todoMockupScenarios()['3 demandes + 2 présences']!);
      expect(find.text('À traiter · 5'), findsOneWidget);
      expect(semanticsLabel('5 choses à traiter'), findsOneWidget);
    });
  });

  group('grosse carte de chaque type', () {
    for (final kind in TripTodoKind.values) {
      testWidgets(kind.name, (tester) async {
        final s = todoScenarioFor(kind);
        final item = todoOf(s).first;
        await pump(tester, s);
        final cardReady = s.stripe == kTodoStripeReady;
        final button = tripTodoButton(fr, item, cardReady: cardReady);
        if (kind == TripTodoKind.requests) {
          // La carte de réponse directe EST la grosse carte, sans doublon.
          expect(key('trip-direct-request-card'), findsOneWidget);
          expect(key('trip-todo-next-requests'), findsNothing);
          expect(key('trip-todo-row-requests'), findsNothing);
          expect(find.text('Demande 1 sur 1'), findsOneWidget);
        } else {
          expect(key('trip-todo-next-${kind.name}'), findsOneWidget);
          expect(key('trip-direct-request-card'), findsNothing);
          // Titre (« Je pars », « Arrivé à destination » : le même texte
          // que le bouton, libellé existant repris).
          expect(
            inCard(
              kind,
              find.text(tripTodoTitle(fr, item, cardReady: cardReady)),
            ),
            findsWidgets,
          );
          expect(
            inCard(kind, find.text(tripTodoUrgencyLabel(fr, item.urgency))),
            findsOneWidget,
          );
          final due = tripTodoDueLabel(
            fr,
            item.dueAt,
            now: kTodoNow,
            trip: s.trip,
          );
          expect(
            key('trip-todo-next-due'),
            due == null ? findsNothing : findsOneWidget,
          );
          if (due != null) expect(inCard(kind, find.text(due)), findsOneWidget);
          expect(
            find.descendant(
              of: key('trip-todo-next-button'),
              matching: find.text(button),
            ),
            findsOneWidget,
          );
        }
        // Le pied suit l'action quand elle peut le porter : même libellé que
        // le bouton de la carte. Sinon il garde ses règles d'avant.
        if (kind.drivesFooter) {
          expect(inBar(key('trip-footer-todo-${kind.name}')), findsOneWidget);
          expect(inBar(find.text(button)), findsOneWidget);
        } else {
          expect(inBar(key('trip-footer-todo-${kind.name}')), findsNothing);
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('échéances : « Expire dans 5 h » (présence), « Avant le 2 '
        'nov. à 12:00 » (modification)', (tester) async {
      await pump(tester, todoScenarioFor(TripTodoKind.presence));
      expect(find.text('Expire dans 5 h'), findsOneWidget);
      expect(find.text('Urgent'), findsOneWidget);
      await pump(tester, todoScenarioFor(TripTodoKind.amendment));
      expect(find.text('Avant le 2 nov. à 12:00'), findsOneWidget);
    });

    testWidgets('action importante : « Prochaine action », sans échéance', (
      tester,
    ) async {
      await pump(tester, todoScenarioFor(TripTodoKind.depart));
      expect(find.text('Prochaine action'), findsOneWidget);
      expect(key('trip-todo-next-due'), findsNothing);
    });
  });

  group('file', () {
    testWidgets('une seule action : pas de file', (tester) async {
      await pump(tester, todoScenarioFor(TripTodoKind.publish));
      expect(key('trip-todo-queue'), findsNothing);
      expect(key('trip-todo-more'), findsNothing);
    });

    testWidgets('deux actions : une ligne, sans « + N autres »', (
      tester,
    ) async {
      final s = (
        trip: todoTrip(status: 'DRAFT', methods: const {BidPaymentMethod.cash}),
        bids: const <BidModel>[],
        stripe: kTodoStripeReady as StripeAccountState,
        departed: false,
      );
      await pump(tester, s);
      expect(key('trip-todo-next-publish'), findsOneWidget);
      expect(key('trip-todo-row-addCard'), findsOneWidget);
      expect(key('trip-todo-more'), findsNothing);
      expect(find.text('À traiter · 2'), findsOneWidget);
    });

    testWidgets('quatre actions : trois lignes, chevron, compteur au-delà '
        'd\'un colis', (tester) async {
      final s = todoMockupScenarios()['jour du départ']!;
      final todo = todoOf(s);
      await pump(tester, s);
      final queue = todo.skip(1).toList();
      expect(queue.length, 2);
      for (final item in queue) {
        expect(key('trip-todo-row-${item.kind.name}'), findsOneWidget);
      }
      // Récupérer 2 colis : en tête ; présence (1 colis) : sans compteur.
      expect(key('trip-todo-next-scan'), findsOneWidget);
      expect(key('trip-todo-row-count-presence'), findsNothing);
      expect(key('trip-todo-more'), findsNothing);
    });

    testWidgets('très chargé : trois lignes puis « + N autres à traiter »', (
      tester,
    ) async {
      final s = todoMockupScenarios()['très chargé']!;
      final todo = todoOf(s);
      await pump(tester, s);
      final rows = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('trip-todo-row-') &&
            !(w.key! as ValueKey<String>).value.startsWith(
              'trip-todo-row-count-',
            ),
      );
      expect(rows, findsNWidgets(3));
      final hidden = todo.length - 4;
      expect(hidden, greaterThan(0));
      expect(find.text('+ $hidden autres à traiter'), findsOneWidget);
      expect(find.text('Voir toute la liste'), findsOneWidget);
      // Les 8 demandes passent en tête des urgents, devant la récupération
      // dans 3 h : la grosse carte est la carte de réponse directe.
      expect(todo.first.kind, TripTodoKind.requests);
      expect(key('trip-direct-request-card'), findsOneWidget);
      expect(find.text(fr.tripDirectRequestLabel(8)), findsOneWidget);
      expect(key('trip-todo-row-requests'), findsNothing);
    });

    testWidgets('« + N autres » : toute la liste, une ligne ouvre son geste', (
      tester,
    ) async {
      final s = todoMockupScenarios()['très chargé']!;
      final todo = todoOf(s);
      await pump(tester, s);
      await tester.ensureVisible(key('trip-todo-more'));
      await tester.tap(key('trip-todo-more'));
      await settle(tester);
      final all = key('trip-todo-all');
      expect(all, findsOneWidget);
      expect(sheetName(tester, all), '/sheet/trip-owner/todo-all');
      for (final item in todo) {
        expect(
          find.descendant(
            of: all,
            matching: key('trip-todo-row-${item.kind.name}'),
          ),
          findsOneWidget,
        );
      }
      // Une action par colis cachée derrière « + N autres » : son sheet.
      final last = todo.skip(4).firstWhere((i) => i.kind.perParcel).kind;
      await tester.tap(
        find.descendant(of: all, matching: key('trip-todo-row-${last.name}')),
      );
      await settle(tester);
      expect(all, findsNothing);
      expect(key('trip-todo-parcels-${last.name}'), findsOneWidget);
      verifyOpened(last.name, 'list');
    });
  });

  group('gestes du trajet (flux existants)', () {
    Future<void> tapCard(WidgetTester tester) async {
      await tester.ensureVisible(key('trip-todo-next-button'));
      await tester.tap(key('trip-todo-next-button'));
      await settle(tester);
    }

    testWidgets('demandes : lien de la carte directe, sheet des demandes, '
        'source card', (tester) async {
      await pump(tester, todoScenarioFor(TripTodoKind.requests));
      // Une seule demande : pas de lien, le pied ouvre le sheet.
      await tester.tap(inBar(key('trip-footer-todo-requests')));
      await settle(tester);
      expect(key('trip-activity-requests-content'), findsOneWidget);
      verifyOpened('requests', 'footer');
    });

    testWidgets('demandes dans toute la liste : sheet des demandes, source '
        'list', (tester) async {
      await pump(tester, todoMockupScenarios()['très chargé']!);
      await tester.ensureVisible(key('trip-todo-more'));
      await tester.tap(key('trip-todo-more'));
      await settle(tester);
      final row = find.descendant(
        of: key('trip-todo-all'),
        matching: key('trip-todo-row-requests'),
      );
      await tester.ensureVisible(row);
      await tester.tap(row);
      await settle(tester);
      expect(key('trip-activity-requests-content'), findsOneWidget);
      verifyOpened('requests', 'list');
    });

    testWidgets('Je pars : son sheet, source card', (tester) async {
      await pump(tester, todoScenarioFor(TripTodoKind.depart));
      await tapCard(tester);
      expect(key('trip-todo-depart-content'), findsOneWidget);
      verifyOpened('depart', 'card');
    });

    testWidgets('Ajouter la carte : son sheet', (tester) async {
      await pump(tester, todoScenarioFor(TripTodoKind.addCard));
      await tapCard(tester);
      expect(key('trip-todo-card-content'), findsOneWidget);
      expect(
        sheetName(tester, key('trip-todo-card-content')),
        '/sheet/trip-owner/todo-addCard',
      );
      verifyOpened('addCard', 'card');
    });

    testWidgets('Arrivé à destination : feuille de l\'arrivée', (tester) async {
      await pump(tester, todoScenarioFor(TripTodoKind.arrive));
      await tapCard(tester);
      final sheet = find.byType(ArrivalInstructionsBottomSheet);
      expect(sheet, findsOneWidget);
      expect(
        tester.widget<ArrivalInstructionsBottomSheet>(sheet).isEditing,
        isFalse,
      );
      verifyOpened('arrive', 'card');
    });

    testWidgets('Prévenir les destinataires : leur feuille (manual)', (
      tester,
    ) async {
      await pump(tester, todoScenarioFor(TripTodoKind.notify));
      await tapCard(tester);
      final sheet = find.byType(NotifyRecipientsSheet);
      expect(sheet, findsOneWidget);
      expect(tester.widget<NotifyRecipientsSheet>(sheet).bids, hasLength(2));
      verifyOpened('notify', 'card');
    });

    testWidgets('Instructions de retrait : leur édition', (tester) async {
      await pump(tester, todoScenarioFor(TripTodoKind.instructions));
      await tapCard(tester);
      final sheet = find.byType(ArrivalInstructionsBottomSheet);
      expect(sheet, findsOneWidget);
      expect(
        tester.widget<ArrivalInstructionsBottomSheet>(sheet).isEditing,
        isTrue,
      );
      verifyOpened('instructions', 'card');
    });

    testWidgets('Publier : AnnouncementPublishRequested, sans sheet', (
      tester,
    ) async {
      await pump(tester, todoScenarioFor(TripTodoKind.publish));
      await tapCard(tester);
      expect(
        h.annEvents.whereType<AnnouncementPublishRequested>().single.id,
        'trip-1',
      );
      verifyNever(
        () => h.backend.capture(AnalyticsEvents.bidDetailTileOpened, any()),
      );
    });

    testWidgets('double appui sur la grosse carte : un seul sheet', (
      tester,
    ) async {
      await pump(tester, todoScenarioFor(TripTodoKind.depart));
      await tester.tap(key('trip-todo-next-button'));
      await tester.tap(key('trip-todo-next-button'), warnIfMissed: false);
      await settle(tester);
      expect(key('trip-todo-depart-content'), findsOneWidget);
    });
  });

  group('sheets par colis', () {
    for (final kind in TripTodoKind.values.where((k) => k.perParcel)) {
      testWidgets('${kind.name} : sheet nommé, une ligne par colis, mesuré', (
        tester,
      ) async {
        final s = todoScenarioFor(kind);
        final item = todoOf(s).first;
        await pump(tester, s);
        await tester.ensureVisible(key('trip-todo-next-button'));
        await tester.tap(key('trip-todo-next-button'));
        await settle(tester);
        final content = key('trip-todo-parcels-${kind.name}');
        expect(content, findsOneWidget);
        expect(
          sheetName(tester, content),
          '/sheet/trip-owner/todo-${kind.name}',
        );
        for (final id in item.bidIds) {
          expect(key('trip-todo-parcel-$id'), findsOneWidget);
        }
        final banner = tripTodoDueBanner(
          fr,
          item,
          now: kTodoNow,
          trip: s.trip,
          bids: s.bids,
        );
        expect(
          key('trip-todo-parcels-banner'),
          banner == null ? findsNothing : findsOneWidget,
        );
        if (banner != null) expect(find.text(banner), findsOneWidget);
        // Bouton « Lire le QR du colis » au pied pour la récupération seule.
        expect(
          key('trip-todo-parcels-scan-button'),
          kind == TripTodoKind.scan ? findsOneWidget : findsNothing,
        );
        verifyOpened(kind.name, 'card');
      });
    }

    testWidgets('récupérer : bandeau, ligne du colis (avatar, contenu · '
        'poids, échéance), toucher ouvre la fiche puis relit en silence', (
      tester,
    ) async {
      final pushed = await pump(tester, todoScenarioFor(TripTodoKind.scan));
      await tester.tap(key('trip-todo-next-button'));
      await settle(tester);
      // Colis payé en espèces : annulé à la date limite + 1 h, jamais
      // « déclaré absent » (back `expireUnconfirmedCashHandover`).
      expect(
        find.text('Avant 15:00, sinon le colis est annulé.'),
        findsOneWidget,
      );
      final row = key('trip-todo-parcel-b1');
      expect(
        find.descendant(of: row, matching: find.byType(DonyAvatar)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('Expéditeur b1')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('Contenu b1 · 3 kg')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('Expire dans 3 h')),
        findsOneWidget,
      );
      await tester.tap(row);
      await settle(tester);
      expect(pushed, ['/bids/b1']);
      expect(h.screenEvents, isEmpty);
      await tester.tap(find.text('back'));
      await settle(tester);
      expect(
        h.screenEvents.whereType<BidListRequested>().single.silent,
        isTrue,
      );
      expect(
        h.annEvents.whereType<AnnouncementDetailRequested>().single.silent,
        isTrue,
      );
    });

    testWidgets('récupérer, paiements mêlés : bandeau des deux issues, une '
        'conséquence par ligne, rien sur un colis déjà déclaré', (
      tester,
    ) async {
      final deadline = kTodoNow.add(const Duration(hours: 2));
      await pump(tester, (
        trip: todoTrip(status: 'FULL'),
        bids: [
          todoBid(
            'cash',
            'ACCEPTED',
            voyageurConfirmed: true,
            handoverDeadline: deadline,
          ),
          todoBid(
            'card',
            'ACCEPTED',
            paymentMethod: BidPaymentMethod.stripe,
            voyageurConfirmed: true,
            handoverDeadline: deadline,
          ),
          todoBid(
            'declared',
            'ACCEPTED',
            paymentMethod: BidPaymentMethod.stripe,
            handoverDeadline: kTodoNow.subtract(const Duration(minutes: 20)),
            cancellationNoShowStatus: 'PENDING_CONFIRMATION',
          ),
        ],
        stripe: const StripeAccountInitial(),
        departed: false,
      ));
      await tester.tap(key('trip-todo-next-button'));
      await settle(tester);
      expect(key('trip-todo-parcels-scan'), findsOneWidget);
      expect(
        find.text(
          'Avant 15:00, sinon le colis est annulé ou vous êtes déclaré absent.',
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<Text>(key('trip-todo-parcel-consequence-cash')).data,
        'Sinon le colis est annulé',
      );
      expect(
        tester.widget<Text>(key('trip-todo-parcel-consequence-card')).data,
        'Sinon vous êtes déclaré absent',
      );
      // Déclaration d'absence en attente : listé (le scan la lève), sans
      // échéance ni menace (back `findNoShowBids` l'exclut).
      expect(key('trip-todo-parcel-declared'), findsOneWidget);
      expect(key('trip-todo-parcel-consequence-declared'), findsNothing);
      expect(
        find.descendant(
          of: key('trip-todo-parcel-declared'),
          matching: find.textContaining('Délai'),
        ),
        findsNothing,
      );
    });

    testWidgets('« Lire le QR du colis » : Suivi › Valider sur ce trajet, '
        'relu au retour', (tester) async {
      final pushed = await pump(tester, todoScenarioFor(TripTodoKind.scan));
      await tester.tap(key('trip-todo-next-button'));
      await settle(tester);
      await tester.tap(key('trip-todo-parcels-scan-button'));
      await settle(tester);
      expect(pushed, ['/tracking/validate?trip=trip-1']);
      await tester.tap(find.text('back'));
      await settle(tester);
      expect(
        h.screenEvents.whereType<BidListRequested>().single.silent,
        isTrue,
      );
    });

    testWidgets('l\'action résolue à la relecture : le sheet se ferme', (
      tester,
    ) async {
      await pump(tester, todoScenarioFor(TripTodoKind.scan));
      await tester.tap(key('trip-todo-next-button'));
      await settle(tester);
      expect(key('trip-todo-parcels-scan'), findsOneWidget);
      h.screenStates.add(BidListLoaded([todoBid('b1', 'HANDED_OVER')]));
      await settle(tester);
      expect(key('trip-todo-parcels-scan'), findsNothing);
    });

    testWidgets('pied « Lire le QR du colis » : le même sheet, source footer', (
      tester,
    ) async {
      await pump(tester, todoScenarioFor(TripTodoKind.scan));
      await tester.tap(inBar(key('trip-footer-todo-scan')));
      await settle(tester);
      expect(key('trip-todo-parcels-scan'), findsOneWidget);
      verifyOpened('scan', 'footer');
    });
  });

  group('ligne Colis', () {
    testWidgets('colis en attente d\'un geste : compteur et « N attendent '
        'votre geste »', (tester) async {
      await pump(tester, todoMockupScenarios()['3 demandes + 2 présences']!);
      expect(find.text('2 attendent votre geste'), findsOneWidget);
      expect(
        find.descendant(
          of: key('trip-parcels-line-awaiting-count'),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('un seul colis : au singulier', (tester) async {
      await pump(tester, todoScenarioFor(TripTodoKind.presence));
      expect(find.text('1 attend votre geste'), findsOneWidget);
    });

    testWidgets('demandes et gestes du trajet seuls : rien en orange', (
      tester,
    ) async {
      await pump(tester, todoScenarioFor(TripTodoKind.requests));
      expect(key('trip-parcels-line-awaiting'), findsNothing);
      expect(key('trip-parcels-line-awaiting-count'), findsNothing);
      await pump(tester, todoScenarioFor(TripTodoKind.arrive));
      expect(key('trip-parcels-line-awaiting'), findsNothing);
    });

    testWidgets('sheet Colis : point orange sur les colis qui attendent, '
        'lu « Attend votre geste »', (tester) async {
      await pump(tester, todoMockupScenarios()['jour du départ']!);
      await tester.tap(key('trip-parcels-line'));
      await settle(tester);
      for (final id in ['a1', 'a2', 'a3']) {
        expect(key('trip-parcel-awaiting-$id'), findsOneWidget, reason: id);
      }
      expect(key('trip-parcel-awaiting-h1'), findsNothing);
      expect(semanticsLabel('Attend votre geste'), findsNWidgets(3));
    });
  });

  group('mesure d\'affichage', () {
    testWidgets('chaque action visible, une fois par type et nombre', (
      tester,
    ) async {
      final s = todoMockupScenarios()['très chargé']!;
      final todo = todoOf(s);
      await pump(tester, s);
      await tester.pump();
      for (final item in todo.take(4)) {
        verify(
          () => h.backend.capture(AnalyticsEvents.bidDetailTodoTileShown, {
            'tile': item.kind.name,
            'role': 'trip_owner',
            'status': 'ACTIVE',
            'count': item.count,
          }),
        ).called(1);
      }
      // Cachées derrière « + N autres » : mesurées à l'ouverture de la liste.
      for (final item in todo.skip(4)) {
        verifyNever(
          () => h.backend.capture(
            AnalyticsEvents.bidDetailTodoTileShown,
            any(that: containsPair('tile', item.kind.name)),
          ),
        );
      }
      await tester.ensureVisible(key('trip-todo-more'));
      await tester.tap(key('trip-todo-more'));
      await settle(tester);
      for (final item in todo.skip(4)) {
        verify(
          () => h.backend.capture(
            AnalyticsEvents.bidDetailTodoTileShown,
            any(that: containsPair('tile', item.kind.name)),
          ),
        ).called(1);
      }
    });
  });

  group('scénarios de la maquette', () {
    final expectedFirst = <String, TripTodoKind?>{
      'calme': null,
      '3 demandes + 2 présences': TripTodoKind.requests,
      'jour du départ': TripTodoKind.scan,
      'en route': TripTodoKind.arrive,
      'arrivé': TripTodoKind.deliver,
      'très chargé': TripTodoKind.requests,
    };
    for (final MapEntry(key: name, value: s) in todoMockupScenarios().entries) {
      for (final locale in const [Locale('fr'), Locale('en')]) {
        testWidgets('$name (${locale.languageCode})', (tester) async {
          await pump(tester, s, locale: locale);
          expect(tester.takeException(), isNull);
          final first = expectedFirst[name];
          if (first == null) {
            expect(key('trip-todo-section'), findsNothing);
            // Sans action : règles d'avant du pied (Modifier | affiche).
            expect(inBar(key('trip-footer-sharePoster')), findsOneWidget);
          } else {
            expect(key('trip-todo-section'), findsOneWidget);
            expect(
              inBar(key('trip-footer-todo-${first.name}')),
              findsOneWidget,
            );
            if (first != TripTodoKind.requests) {
              expect(key('trip-todo-next-${first.name}'), findsOneWidget);
            }
          }
        });
      }
    }

    testWidgets('anglais : pastille, étiquette, titres', (tester) async {
      await pump(
        tester,
        todoMockupScenarios()['jour du départ']!,
        locale: const Locale('en'),
      );
      expect(find.text('To do'), findsOneWidget);
      expect(find.text('To do · 4'), findsOneWidget);
      expect(find.text('Urgent'), findsOneWidget);
      expect(find.text('Collect 2 parcels'), findsOneWidget);
      expect(find.text('Expires in 3 h'), findsOneWidget);
      expect(inBar(find.text('Scan the parcel QR')), findsOneWidget);
    });
  });

  group('statuts du trajet', () {
    testWidgets('brouillon : « Publier » en tête, « Modifier » au pied', (
      tester,
    ) async {
      await pump(tester, todoScenarioFor(TripTodoKind.publish));
      expect(key('trip-todo-next-publish'), findsOneWidget);
      expect(inBar(key('trip-footer-todo-publish')), findsOneWidget);
      expect(inBar(key('trip-footer-edit')), findsOneWidget);
    });

    testWidgets('annulé avec un colis à rendre : action et pied', (
      tester,
    ) async {
      await pump(tester, todoScenarioFor(TripTodoKind.returnParcel));
      expect(key('trip-todo-next-returnParcel'), findsOneWidget);
      expect(inBar(key('trip-footer-todo-returnParcel')), findsOneWidget);
    });

    testWidgets('annulé sans rien à rendre : ni section ni pied', (
      tester,
    ) async {
      await pump(tester, (
        trip: todoTrip(status: 'CANCELLED'),
        bids: const <BidModel>[],
        stripe: const StripeAccountInitial(),
        departed: false,
      ));
      expect(key('trip-todo-section'), findsNothing);
      expect(bar(), findsNothing);
    });

    testWidgets('retiré par l\'équipe : ni section, ni pastille, ni pied', (
      tester,
    ) async {
      await pump(tester, (
        trip: todoTrip(status: 'REMOVED_BY_ADMIN'),
        bids: [
          todoBid(
            'r1',
            'PAYMENT_ESCROWED',
            paymentMethod: BidPaymentMethod.stripe,
          ),
          todoBid('t1', 'IN_TRANSIT'),
        ],
        stripe: const StripeAccountInitial(),
        departed: false,
      ));
      expect(key('trip-todo-section'), findsNothing);
      expect(key('trip-todo-badge'), findsNothing);
      expect(bar(), findsNothing);
    });
  });

  group('360 dp × 1,3, vraies polices : boutons à taille nominale', () {
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
      for (final kind in TripTodoKind.values) {
        testWidgets('${locale.languageCode} ${kind.name}', (tester) async {
          final s = todoScenarioFor(kind);
          final item = todoOf(s).first;
          await pump(
            tester,
            s,
            locale: locale,
            textScale: 1.3,
            size: const Size(360, 2400),
          );
          expect(tester.takeException(), isNull);
          final label = tripTodoButton(
            l,
            item,
            cardReady: s.stripe == kTodoStripeReady,
          );
          // Pied : seulement les actions qui le portent (urgentes et gestes
          // du trajet, `drivesFooter`) ; jamais « Ajouter la carte »,
          // « Noter » ni le destinataire refusé.
          final footer = inBar(key('trip-footer-todo-${kind.name}'));
          if (kind.drivesFooter) {
            expect(tester.getSize(footer).height, 52, reason: label);
            expect(labelScale(tester, footer, label), closeTo(1, 0.001));
          } else {
            expect(footer, findsNothing, reason: kind.name);
          }
          // La grosse carte (sauf les demandes : la carte de réponse directe,
          // vérifiée par son propre test).
          if (kind != TripTodoKind.requests) {
            final card = key('trip-todo-next-button');
            expect(tester.getSize(card).height, 52, reason: label);
            expect(
              labelScale(tester, card, label),
              closeTo(1, 0.001),
              reason: label,
            );
          }
        });
      }
    }
  });
}

/// Nom de route de la feuille qui contient [finder].
String? sheetName(WidgetTester tester, Finder finder) =>
    ModalRoute.of(tester.element(finder))?.settings.name;
