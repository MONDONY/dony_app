// Carte « Colis dans le trajet » de l'écran du trajet (vue du voyageur) :
// carte du corps avec son lien « Voir la liste », le total au titre, le
// résumé calculé sur tous les colis, deux lignes au plus (colis qui
// attendent un geste du voyageur d'abord) et « Voir les N autres colis »
// au-delà (0, 1, 2, 3, 10 colis, statuts mêlés), relecture au retour de la
// liste et d'une fiche colis, FR / EN, 360 dp × 1,3.
import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
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

/// [n] colis acceptés « Article 1 » à « Article n », dans l'ordre.
List<BidModel> _parcels(int n) => [
  for (var i = 1; i <= n; i++)
    bidFixture('p$i', 'ACCEPTED', category: 'Article $i'),
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
  Finder seeMore() => find.byKey(const Key('trip-parcels-see-more'));
  String summaryText(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const Key('trip-parcels-summary')))
      .textSpan!
      .toPlainText();
  List<String> rowTitles(WidgetTester tester) => [
    for (final t in tester.widgetList<Text>(find.textContaining('Article')))
      t.data!,
  ];

  group('sept colis de statuts mêlés', () {
    testWidgets('total au titre, résumé sur tous les colis, deux lignes '
        '(colis qui attendent un geste du voyageur d\'abord), sans puces', (
      tester,
    ) async {
      await pump(tester, BidListLoaded(_mixed));

      expect(find.text('Colis dans le trajet · 7'), findsOneWidget);
      // Résumé calculé sur les sept colis, pas sur les deux lignes.
      expect(
        summaryText(tester),
        '2 colis en route  ·  2 à récupérer  ·  1 arrivé  ·  1 livré',
      );
      // La demande en attente n'est pas un colis embarqué.
      expect(find.text('Demande en attente'), findsNothing);
      // b1 (livré) passe après les colis qui attendent le voyageur ; ordre
      // reçu gardé parmi eux (b2 puis b3).
      expect(rowTitles(tester), ['Article B', 'Article C']);
      expect(find.text('Voir les 5 autres colis'), findsOneWidget);
      // Plus de filtre par statut sur la carte.
      expect(find.byType(StatusChipsRow<String?>), findsNothing);
      expect(find.text('Tous · 7'), findsNothing);
      verify(
        () => backend.capture(AnalyticsEvents.tripParcelsViewed, {'count': 7}),
      ).called(1);
    });
  });

  group('aperçu limité à deux colis', () {
    test('deux colis au plus', () {
      expect(kTripParcelsPreviewCount, 2);
    });

    for (final (n, title, rows, more) in <(int, String, int, String?)>[
      (1, 'Colis dans le trajet · 1', 1, null),
      (2, 'Colis dans le trajet · 2', 2, null),
      (3, 'Colis dans le trajet · 3', 2, 'Voir 1 autre colis'),
      (10, 'Colis dans le trajet · 10', 2, 'Voir les 8 autres colis'),
    ]) {
      testWidgets('$n colis : $rows ligne(s), ${more ?? 'pas de bouton'}', (
        tester,
      ) async {
        await pump(tester, BidListLoaded(_parcels(n)));

        expect(find.text(title), findsOneWidget);
        expect(rowTitles(tester), hasLength(rows));
        expect(seeList(), findsOneWidget);
        if (more == null) {
          expect(seeMore(), findsNothing);
        } else {
          expect(
            find.descendant(of: seeMore(), matching: find.text(more)),
            findsOneWidget,
          );
        }
        verify(
          () =>
              backend.capture(AnalyticsEvents.tripParcelsViewed, {'count': n}),
        ).called(1);
      });
    }

    testWidgets('0 colis : titre sans total, état vide, ni lien ni bouton', (
      tester,
    ) async {
      await pump(tester, BidListLoaded([bidFixture('b1', 'PENDING')]));

      expect(find.text('Colis dans le trajet'), findsOneWidget);
      expect(find.textContaining('Colis dans le trajet ·'), findsNothing);
      expect(find.text('Aucun colis embarqué'), findsOneWidget);
      expect(seeList(), findsNothing);
      expect(seeMore(), findsNothing);
      verify(
        () => backend.capture(AnalyticsEvents.tripParcelsViewed, {'count': 0}),
      ).called(1);
    });

    testWidgets('dix colis de statuts mêlés : résumé sur les dix', (
      tester,
    ) async {
      await pump(
        tester,
        BidListLoaded([
          for (var i = 0; i < 4; i++) bidFixture('c$i', 'COMPLETED'),
          for (var i = 0; i < 3; i++) bidFixture('t$i', 'IN_TRANSIT'),
          for (var i = 0; i < 2; i++) bidFixture('a$i', 'ACCEPTED'),
          bidFixture('r0', 'ARRIVED'),
        ]),
      );

      expect(
        summaryText(tester),
        '3 colis en route  ·  2 à récupérer  ·  1 arrivé  ·  4 livrés',
      );
      expect(find.text('Voir les 8 autres colis'), findsOneWidget);
    });

    testWidgets('liste relue : total, lignes et bouton suivent', (
      tester,
    ) async {
      await pump(tester, BidListLoaded(_parcels(10)));
      expect(find.text('Voir les 8 autres colis'), findsOneWidget);

      bidStates.add(BidListLoaded(_parcels(3)));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Colis dans le trajet · 3'), findsOneWidget);
      expect(find.text('Voir 1 autre colis'), findsOneWidget);

      bidStates.add(BidListLoaded(_parcels(2)));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Colis dans le trajet · 2'), findsOneWidget);
      expect(seeMore(), findsNothing);
    });

    testWidgets('rechargement : le titre garde son total', (tester) async {
      await pump(tester, BidListLoaded(_parcels(10)));

      bidStates.add(BidLoading());
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Colis dans le trajet · 10'), findsOneWidget);
    });

    testWidgets('bouton secondaire en pleine largeur, 46 à 52 dp', (
      tester,
    ) async {
      await pump(tester, BidListLoaded(_parcels(10)));

      final button = tester.widget<DonyButton>(seeMore());
      expect(button.variant, DonyButtonVariant.secondary);
      expect(button.fullWidth, isTrue);
      final height = tester.getSize(seeMore()).height;
      expect(height, inInclusiveRange(46, 52));
      // Même largeur que le contenu de la carte (le résumé, en pleine
      // largeur).
      expect(
        tester.getSize(seeMore()).width,
        tester.getSize(find.byKey(const Key('trip-parcels-summary'))).width,
      );
    });

    testWidgets('« Voir les autres colis » ouvre la liste, relue au retour', (
      tester,
    ) async {
      final pushed = await pump(tester, BidListLoaded(_parcels(10)));

      await tester.tap(seeMore());
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
      final annEvent =
          verify(() => annBloc.add(captureAny())).captured.single
              as AnnouncementDetailRequested;
      expect(annEvent.id, 'trip-1');
      expect(annEvent.silent, isTrue);
    });

    testWidgets('« Voir les autres colis » : double appui, une seule page', (
      tester,
    ) async {
      final pushed = await pump(tester, BidListLoaded(_parcels(10)));

      await tester.tap(seeMore());
      await tester.tap(seeMore());
      await tester.pumpAndSettle();
      expect(pushed, hasLength(1));
    });

    testWidgets('en anglais : total, singulier et pluriel', (tester) async {
      await pump(
        tester,
        BidListLoaded(_parcels(3)),
        locale: const Locale('en'),
      );
      expect(find.text('Parcels on this trip · 3'), findsOneWidget);
      expect(find.text('See 1 other parcel'), findsOneWidget);

      bidStates.add(BidListLoaded(_parcels(10)));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('See the 8 other parcels'), findsOneWidget);
    });
  });

  group('ordre de l\'aperçu', () {
    List<String> ids(List<BidModel> bids) => [
      for (final b in tripParcelsPreview(bids)) b.id,
    ];

    test('les colis qui attendent un geste du voyageur d\'abord, ordre reçu '
        'gardé', () {
      expect(
        ids([
          bidFixture('done', 'COMPLETED'),
          bidFixture('pay', 'AWAITING_PAYMENT'),
          bidFixture('lost', 'NO_SHOW'),
          bidFixture('arr', 'ARRIVED'),
          bidFixture('acc', 'ACCEPTED'),
          bidFixture('tr', 'IN_TRANSIT'),
        ]),
        ['arr', 'acc'],
      );
      expect(
        ids([
          bidFixture('ho', 'HANDED_OVER'),
          bidFixture('done', 'COMPLETED'),
          bidFixture('tr', 'IN_TRANSIT'),
        ]),
        ['ho', 'tr'],
      );
    });

    test('un seul colis à traiter : il passe en tête, puis l\'ordre reçu', () {
      expect(
        ids([
          bidFixture('done', 'COMPLETED'),
          bidFixture('ref', 'PARCEL_REFUSED'),
          bidFixture('acc', 'ACCEPTED'),
        ]),
        ['acc', 'done'],
      );
    });

    test('aucun colis à traiter : ordre reçu', () {
      expect(
        ids([
          bidFixture('c1', 'COMPLETED'),
          bidFixture('pay', 'AWAITING_PAYMENT'),
          bidFixture('c2', 'CANCELLED'),
        ]),
        ['c1', 'pay'],
      );
    });

    test('moins de deux colis : tous', () {
      expect(ids(const []), isEmpty);
      expect(ids([bidFixture('c1', 'COMPLETED')]), ['c1']);
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

  testWidgets('en anglais : titre, lien, résumé, bouton', (tester) async {
    await pump(tester, BidListLoaded(_mixed), locale: const Locale('en'));

    expect(find.text('Parcels on this trip · 7'), findsOneWidget);
    expect(find.text('See list'), findsOneWidget);
    expect(
      summaryText(tester),
      '2 parcels in transit  ·  2 to pick up  ·  1 arrived  ·  1 delivered',
    );
    expect(find.text('See the 5 other parcels'), findsOneWidget);
  });

  testWidgets('en anglais, aucun colis : titre sans total', (tester) async {
    await pump(
      tester,
      BidListLoaded(const <BidModel>[]),
      locale: const Locale('en'),
    );

    expect(find.text('Parcels on this trip'), findsOneWidget);
    expect(find.text('No parcels on board'), findsOneWidget);
  });

  group('360 dp, texte × 1,3', () {
    /// Rapport entre la largeur rendue du libellé dans le `FittedBox` du
    /// bouton et sa largeur à taille nominale : 1 quand rien n'est rétréci.
    double labelScale(WidgetTester tester, String label) {
      final fitted = find.descendant(
        of: seeMore(),
        matching: find.byWidgetPredicate(
          (w) => w is FittedBox && w.fit == BoxFit.scaleDown,
        ),
      );
      final text = find.descendant(of: seeMore(), matching: find.text(label));
      expect(fitted, findsOneWidget, reason: label);
      expect(text, findsOneWidget, reason: label);
      return tester.getSize(fitted).width / tester.getSize(text).width;
    }

    for (final locale in const [Locale('fr'), Locale('en')]) {
      for (final (name, state, more) in <(String, BidState, String?)>[
        ('sept colis', BidListLoaded(_mixed), null),
        ('aucun colis', BidListLoaded(const <BidModel>[]), null),
        (
          'trois colis',
          BidListLoaded(_parcels(3)),
          locale.languageCode == 'fr'
              ? 'Voir 1 autre colis'
              : 'See 1 other parcel',
        ),
        (
          'cent douze colis',
          BidListLoaded(_parcels(112)),
          locale.languageCode == 'fr'
              ? 'Voir les 110 autres colis'
              : 'See the 110 other parcels',
        ),
      ]) {
        testWidgets('${locale.languageCode}, $name : aucun débordement, lien '
            'et bouton sur une ligne à taille nominale', (tester) async {
          await pump(
            tester,
            state,
            locale: locale,
            textScale: 1.3,
            size: kTripCardSmallPhone,
          );

          expect(tester.takeException(), isNull);
          if (more != null) {
            expect(labelScale(tester, more), closeTo(1, 0.001));
            // Une ligne : hauteur du bouton inchangée (52 dp).
            expect(tester.getSize(seeMore()).height, 52);
          }
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
