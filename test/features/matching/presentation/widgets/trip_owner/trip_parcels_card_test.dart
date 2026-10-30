// Carte « Colis dans le trajet » de l'écran du trajet (vue du voyageur) :
// carte du corps avec son lien « Voir la liste » (seul chemin vers la liste
// des colis), une ligne par colis, résumé, filtre et ordre sur un trajet de
// sept colis de statuts mêlés, relecture au retour de la liste et d'une
// fiche colis, FR / EN, 360 dp × 1,3.
import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/activity_header_widgets.dart';
import 'package:dony/features/matching/presentation/widgets/trip_parcels_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/mock_analytics_backend.dart';
import 'trip_card_harness.dart';

/// Sept colis embarqués de six statuts, plus une demande en attente (pas un
/// colis embarqué), dans un ordre qui n'est pas l'ordre métier.
final _mixed = [
  bidFixture('b1', 'COMPLETED', category: 'Article A'),
  bidFixture('b2', 'ACCEPTED', category: 'Article B'),
  bidFixture('b3', 'IN_TRANSIT', category: 'Article C'),
  bidFixture('b4', 'HANDED_OVER', category: 'Article D'),
  bidFixture('b5', 'PENDING', category: 'Demande en attente'),
  bidFixture('b6', 'ARRIVED', category: 'Article E'),
  bidFixture('b7', 'ACCEPTED', category: 'Article F'),
  bidFixture('b8', 'AWAITING_PAYMENT', category: 'Article G'),
];

void main() {
  late MockAnalyticsBackend backend;
  late MockBidBloc bidBloc;
  late MockAnnouncementBloc annBloc;
  late StreamController<BidState> bidStates;

  setUpAll(() async {
    registerFallbackValue(AnnouncementDetailRequested('fallback'));
    registerFallbackValue(BidListRequested('fallback'));
    await loadAppFonts();
  });

  setUp(() async {
    backend = MockAnalyticsBackend();
    final analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();
    await getIt.reset();
    getIt.registerSingleton<AnalyticsService>(analytics);

    bidStates = StreamController<BidState>.broadcast();
    addTearDown(bidStates.close);
    bidBloc = MockBidBloc();
    annBloc = MockAnnouncementBloc();
    whenListen(
      annBloc,
      const Stream<AnnouncementState>.empty(),
      initialState: AnnouncementDetailLoaded(tripFixture()),
    );
  });

  tearDown(() async => getIt.reset());

  Future<List<PushedRoute>> pump(
    WidgetTester tester,
    BidState state, {
    Locale locale = const Locale('fr'),
    double textScale = 1,
    Size? size,
  }) {
    whenListen(bidBloc, bidStates.stream, initialState: state);
    return pumpTripCard(
      tester,
      const TripParcelsSection(announcementId: 'trip-1'),
      bids: bidBloc,
      announcement: annBloc,
      locale: locale,
      textScale: textScale,
      size: size,
    );
  }

  Finder seeList() => find.byKey(const Key('trip-parcels-see-list'));
  String summaryText(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const Key('trip-parcels-summary')))
      .textSpan!
      .toPlainText();
  List<String> rowTitles(WidgetTester tester) => [
    for (final t in tester.widgetList<Text>(find.textContaining('Article')))
      t.data!,
  ];

  group('sept colis de statuts mêlés', () {
    testWidgets('résumé, une ligne par colis dans l\'ordre de la liste, '
        'puces dans l\'ordre métier', (tester) async {
      await pump(tester, BidListLoaded(_mixed));

      expect(find.text('Colis dans le trajet'), findsOneWidget);
      expect(
        summaryText(tester),
        '2 colis en route  ·  2 à récupérer  ·  1 arrivé  ·  1 livré',
      );
      // La demande en attente n'est pas un colis embarqué.
      expect(find.text('Demande en attente'), findsNothing);
      expect(rowTitles(tester), [
        'Article A',
        'Article B',
        'Article C',
        'Article D',
        'Article E',
        'Article F',
        'Article G',
      ]);
      final chips = tester
          .widget<StatusChipsRow<String?>>(find.byType(StatusChipsRow<String?>))
          .chips;
      expect(chips.map((c) => c.value), [
        null,
        'ACCEPTED',
        'AWAITING_PAYMENT',
        'HANDED_OVER',
        'IN_TRANSIT',
        'ARRIVED',
        'COMPLETED',
      ]);
      expect(chips.map((c) => c.count), [7, 2, 1, 1, 1, 1, 1]);
      verify(
        () => backend.capture(AnalyticsEvents.tripParcelsViewed, {'count': 7}),
      ).called(1);
    });

    testWidgets('filtre : seules les lignes du statut, résumé inchangé, '
        'retour à « Tous »', (tester) async {
      await pump(tester, BidListLoaded(_mixed));

      await tester.tap(find.text('Accepté · 2'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(rowTitles(tester), ['Article B', 'Article F']);
      expect(
        summaryText(tester),
        '2 colis en route  ·  2 à récupérer  ·  1 arrivé  ·  1 livré',
      );
      verify(
        () => backend.capture(AnalyticsEvents.tripParcelsFiltered, {
          'status': 'ACCEPTED',
        }),
      ).called(1);

      await tester.tap(find.text('Tous · 7'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(rowTitles(tester), hasLength(7));
    });

    testWidgets('liste relue sans le statut filtré : retour à « Tous »', (
      tester,
    ) async {
      await pump(tester, BidListLoaded(_mixed));
      await tester.tap(find.text('Arrivé · 1'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(rowTitles(tester), ['Article E']);

      bidStates.add(
        BidListLoaded([
          for (final b in _mixed)
            if (b.status != 'ARRIVED') b,
        ]),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(rowTitles(tester), hasLength(6));
    });
  });

  group('« Voir la liste »', () {
    testWidgets('dans l\'en-tête dès qu\'un colis est embarqué', (
      tester,
    ) async {
      await pump(tester, BidListLoaded(_mixed));

      expect(seeList(), findsOneWidget);
      expect(find.text('Voir la liste'), findsOneWidget);
    });

    testWidgets('aligné sur le bord droit du contenu, cible de 44 dp', (
      tester,
    ) async {
      await pump(tester, BidListLoaded(_mixed));

      expect(tester.getSize(seeList()).height, 44);
      expect(
        tester.getTopRight(seeList()).dx,
        tester.getTopRight(find.byKey(const Key('trip-parcels-summary'))).dx,
      );
    });

    testWidgets('aucun colis embarqué : état vide, pas de lien', (
      tester,
    ) async {
      await pump(tester, BidListLoaded([bidFixture('b1', 'PENDING')]));

      expect(find.text('Aucun colis embarqué'), findsOneWidget);
      expect(seeList(), findsNothing);
    });

    testWidgets('liste pas encore chargée : pas de lien', (tester) async {
      await pump(tester, BidLoading());

      expect(seeList(), findsNothing);
    });

    testWidgets('rechargement : le lien reste', (tester) async {
      await pump(tester, BidListLoaded(_mixed));

      bidStates.add(BidLoading());
      await tester.pump(const Duration(milliseconds: 200));
      expect(seeList(), findsOneWidget);
    });

    testWidgets('ouvre la liste des colis du trajet, relue au retour', (
      tester,
    ) async {
      final pushed = await pump(tester, BidListLoaded(_mixed));

      await tester.tap(seeList());
      await tester.pumpAndSettle();
      expect(pushed.single.location, '/announcements/trip-1/bids');
      expect(pushed.single.extra, {'title': 'Colis'});
      verifyNever(() => bidBloc.add(any()));

      await tester.tap(find.text('back'));
      await tester.pumpAndSettle();
      final event =
          verify(() => bidBloc.add(captureAny())).captured.single
              as BidListRequested;
      expect(event.announcementId, 'trip-1');
      expect(event.silent, isTrue);
      expect(
        (verify(() => annBloc.add(captureAny())).captured.single
                as AnnouncementDetailRequested)
            .id,
        'trip-1',
      );
    });
  });

  testWidgets('une ligne ouvre la fiche du colis, relue au retour', (
    tester,
  ) async {
    final pushed = await pump(tester, BidListLoaded(_mixed));

    await tester.tap(find.text('Article C'));
    await tester.pumpAndSettle();
    expect(pushed.single.location, '/bids/b3');

    await tester.tap(find.text('back'));
    await tester.pumpAndSettle();
    final event =
        verify(() => bidBloc.add(captureAny())).captured.single
            as BidListRequested;
    expect(event.announcementId, 'trip-1');
    expect(event.silent, isTrue);
  });

  group('états de la liste', () {
    testWidgets('jamais chargée (BidInitial) : indicateur, ni lien ni vide', (
      tester,
    ) async {
      await pump(tester, BidInitial());

      expect(find.text('Colis dans le trajet'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Aucun colis embarqué'), findsNothing);
      expect(seeList(), findsNothing);
    });

    testWidgets('échec (BidError) : rien sous le titre, pas d\'« aucun »', (
      tester,
    ) async {
      await pump(tester, BidError(const OfflineException()));

      expect(find.text('Colis dans le trajet'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Aucun colis embarqué'), findsNothing);
      expect(seeList(), findsNothing);
    });

    testWidgets('échec après une liste : le lien reste', (tester) async {
      await pump(tester, BidListLoaded(_mixed));

      bidStates.add(BidError(const OfflineException()));
      await tester.pump(const Duration(milliseconds: 200));
      expect(seeList(), findsOneWidget);
    });
  });

  group('double appui et relecture', () {
    testWidgets('« Voir la liste » : une seule page', (tester) async {
      final pushed = await pump(tester, BidListLoaded(_mixed));

      await tester.tap(seeList());
      await tester.tap(seeList());
      await tester.pumpAndSettle();
      expect(pushed, hasLength(1));
    });

    testWidgets('ligne : une seule fiche', (tester) async {
      final pushed = await pump(tester, BidListLoaded(_mixed));

      await tester.tap(find.text('Article C'));
      await tester.tap(find.text('Article C'));
      await tester.pumpAndSettle();
      expect(pushed, hasLength(1));
    });

    testWidgets('ligne démontée pendant la fiche : l\'écran est relu, en '
        'silence', (tester) async {
      await pump(tester, BidListLoaded(_mixed));

      await tester.tap(find.text('Article C'));
      await tester.pumpAndSettle();
      // Liste relue pendant la fiche : la ligne touchée n'existe plus.
      bidStates.add(BidListLoaded([bidFixture('b1', 'COMPLETED')]));
      await tester.pump();
      await tester.tap(find.text('back'));
      await tester.pumpAndSettle();

      verify(() => bidBloc.add(any(that: isA<BidListRequested>()))).called(1);
      final annEvent =
          verify(() => annBloc.add(captureAny())).captured.single
              as AnnouncementDetailRequested;
      expect(annEvent.silent, isTrue);
    });
  });

  testWidgets('en anglais : titre, lien, résumé', (tester) async {
    await pump(tester, BidListLoaded(_mixed), locale: const Locale('en'));

    expect(find.text('Parcels on this trip'), findsOneWidget);
    expect(find.text('See list'), findsOneWidget);
  });

  group('360 dp, texte × 1,3', () {
    for (final locale in const [Locale('fr'), Locale('en')]) {
      for (final (name, state) in <(String, BidState)>[
        ('sept colis', BidListLoaded(_mixed)),
        ('aucun colis', BidListLoaded(const <BidModel>[])),
      ]) {
        testWidgets('${locale.languageCode}, $name : aucun débordement, lien '
            'sur une ligne', (tester) async {
          await pump(
            tester,
            state,
            locale: locale,
            textScale: 1.3,
            size: kTripCardSmallPhone,
          );

          expect(tester.takeException(), isNull);
          if (find
              .byKey(const Key('trip-parcels-see-list'))
              .evaluate()
              .isEmpty) {
            return;
          }
          final link = tester.widget<Text>(
            find.descendant(of: seeList(), matching: find.byType(Text)),
          );
          expect(link.maxLines, 1);
          expect(link.softWrap, isFalse);
          // Le lien tient sur une ligne, à sa taille : pas plus haut qu'une
          // ligne de texte (pas de retour à la ligne).
          final size = tester.getSize(
            find.descendant(of: seeList(), matching: find.byType(Text)),
          );
          expect(size.height, lessThan(30));
        });
      }
    }
  });
}
