// Recherche dans le sheet « Colis » de l'écran du trajet vu par son
// voyageur : champ présent seulement avec des colis, filtrage en direct
// (expéditeur, destinataire, numéro de suivi visible seulement après la
// remise), combinaison avec les puces de statut, compteur, état vide et
// « Effacer la recherche », bouton d'effacement du champ, saisie qui survit à
// une relecture des colis (et à l'arrivée du bloc gain), sheet rouvert vide,
// hauteur gardée pendant la recherche, bloc gain et résumé repliés pendant la
// recherche (focus ou texte) et de retour champ vide sans focus, mesure `trip_parcels_searched` après
// une pause de saisie et sans PII, FR et EN, 360 dp × 1,3, clavier ouvert.
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/activity_header_widgets.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_activity_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'trip_answer_harness.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

BidModel _parcel(
  String id, {
  String status = 'IN_TRANSIT',
  String sender = 'Expéditeur',
  String? recipient,
  String? tracking,
  bool declined = false,
  double? net,
}) => BidModel(
  id: id,
  announcementId: 'trip-1',
  senderId: 'sender-$id',
  senderName: sender,
  recipientName: recipient,
  recipientDeclined: declined,
  trackingNumber: tracking,
  weightKg: 3,
  totalAmountEur: net,
  status: status,
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

/// Quatre colis embarqués (deux statuts) et une demande hors liste.
final _parcels = [
  _parcel(
    'a1',
    status: 'ACCEPTED',
    sender: 'Aminata Traoré',
    recipient: 'Moussa Diallo',
    tracking: 'DON-HIDDEN01',
  ),
  _parcel(
    't1',
    sender: 'Awa Ndiaye',
    recipient: 'Fatoumata Bâ',
    tracking: 'DON-BGA8WV2R',
  ),
  _parcel(
    'a2',
    status: 'ACCEPTED',
    sender: 'Ibrahim Koné',
    recipient: 'Awa Sow',
  ),
  _parcel('t2', sender: 'Seydou Keita', recipient: 'Hélène Camara'),
  _parcel('p1', status: 'PENDING', sender: 'Aminata Demande'),
];

void main() {
  late AnswerHarness h;

  setUpAll(() async {
    AnswerHarness.registerFallbacks();
    await loadAppFonts();
  });

  setUp(() async {
    h = AnswerHarness();
    await h.setUp();
  });

  tearDown(() => h.tearDown());

  Future<void> open(
    WidgetTester tester, {
    List<BidModel>? bids,
    Locale locale = const Locale('fr'),
    double textScale = 1,
    Size size = const Size(400, 900),
  }) async {
    final trip = answerTrip();
    await h.pump(
      tester,
      trip: trip,
      bids: bids,
      locale: locale,
      textScale: textScale,
      size: size,
      body: (context) => TextButton(
        onPressed: () =>
            openTripActivitySheet(context, trip, TripActivity.parcels),
        child: const Text('open-activity'),
      ),
    );
    await tester.tap(find.text('open-activity'));
    await _settle(tester);
  }

  final field = find.byKey(const Key('trip-activity-parcels-search'));
  final counter = find.byKey(const Key('trip-activity-parcels-search-count'));
  final emptyState = find.byKey(
    const Key('trip-activity-parcels-search-empty'),
  );
  final clearLink = find.byKey(const Key('trip-activity-parcels-search-clear'));
  final summary = find.byKey(const Key('trip-parcels-summary'));
  final chips = find.byType(StatusChipsRow<String?>);
  Finder row(String id) => find.byKey(Key('trip-activity-parcel-$id'));

  String fieldText(WidgetTester tester) => tester
      .widget<EditableText>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      )
      .controller
      .text;

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(field, text);
    await tester.pump();
  }

  void expectRows(List<String> shown, List<String> hidden) {
    for (final id in shown) {
      expect(row(id), findsOneWidget, reason: id);
    }
    for (final id in hidden) {
      expect(row(id), findsNothing, reason: id);
    }
  }

  String plain(WidgetTester tester, Finder f) =>
      tester.widget<Text>(f).textSpan?.toPlainText() ??
      tester.widget<Text>(f).data!;

  group('présence du champ', () {
    testWidgets('un colis ou plus : champ pleine largeur sous le résumé, '
        'au-dessus des puces, indication FR', (tester) async {
      await open(tester, bids: _parcels);
      expect(field, findsOneWidget);
      expect(
        find.text('Rechercher un colis, un nom, un suivi'),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(field).dy,
        greaterThan(tester.getBottomLeft(summary).dy),
      );
      expect(
        tester.getBottomLeft(field).dy,
        lessThan(tester.getTopLeft(chips).dy),
      );
      expect(
        tester.getSize(field).width,
        closeTo(tester.getSize(row('a1')).width, 0.5),
      );
      expect(counter, findsNothing);
    });

    testWidgets('un seul colis : champ présent', (tester) async {
      await open(tester, bids: [_parcel('t1', sender: 'Awa')]);
      expect(field, findsOneWidget);
    });

    testWidgets('aucun colis : pas de champ, état vide habituel', (
      tester,
    ) async {
      await open(tester, bids: [_parcel('p1', status: 'PENDING')]);
      expect(field, findsNothing);
      expect(
        find.byKey(const Key('trip-activity-parcels-empty')),
        findsOneWidget,
      );
    });

    testWidgets('liste pas chargée : pas de champ', (tester) async {
      await open(tester);
      expect(field, findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('dernier colis retiré pendant l\'ouverture : le champ part', (
      tester,
    ) async {
      await open(tester, bids: _parcels);
      await type(tester, 'awa');
      h.screenStates.add(BidListLoaded([_parcel('p1', status: 'PENDING')]));
      await _settle(tester);
      expect(field, findsNothing);
      expect(
        find.byKey(const Key('trip-activity-parcels-empty')),
        findsOneWidget,
      );
    });
  });

  group('filtrage en direct', () {
    testWidgets('expéditeur, sans casse ni accents ; compteur ; résumé et '
        'titre inchangés', (tester) async {
      await open(tester, bids: _parcels);
      final before = plain(tester, summary);
      await type(tester, 'TRAORE');
      expectRows(['a1'], ['t1', 'a2', 't2', 'p1']);
      expect(plain(tester, counter), '1 colis trouvé');
      expect(find.text('Colis dans le trajet'), findsOneWidget);
      // Le résumé se replie pendant la recherche, mais il compte toujours
      // tous les colis : de retour, il dit la même chose.
      await tester.tap(find.byTooltip('Effacer'));
      FocusManager.instance.primaryFocus?.unfocus();
      await _settle(tester);
      expect(plain(tester, summary), before);
    });

    testWidgets('destinataire, sous-chaîne', (tester) async {
      await open(tester, bids: _parcels);
      await type(tester, 'camara');
      expectRows(['t2'], ['a1', 't1', 'a2']);
    });

    testWidgets('« awa » : expéditeur et destinataire, pluriel du compteur', (
      tester,
    ) async {
      await open(tester, bids: _parcels);
      await type(tester, '  awa ');
      expectRows(['t1', 'a2'], ['a1', 't2']);
      expect(plain(tester, counter), '2 colis trouvés');
    });

    testWidgets('numéro d\'un colis remis : trouvé, avec ou sans tiret, en '
        'partie', (tester) async {
      await open(tester, bids: _parcels);
      for (final q in ['DON-BGA8WV2R', 'donbga8wv2r', 'bga8']) {
        await type(tester, q);
        expectRows(['t1'], ['a1', 'a2', 't2']);
      }
    });

    testWidgets('numéro d\'un colis pas encore remis : jamais trouvé', (
      tester,
    ) async {
      await open(tester, bids: _parcels);
      for (final q in ['DON-HIDDEN01', 'hidden01', 'hidden']) {
        await type(tester, q);
        expectRows([], ['a1', 't1', 'a2', 't2']);
        expect(emptyState, findsOneWidget);
      }
    });

    testWidgets('destinataire en refus : son nom ne trouve rien', (
      tester,
    ) async {
      await open(
        tester,
        bids: [
          _parcel('t1', sender: 'Awa', recipient: 'Moussa', declined: true),
          _parcel('t2', sender: 'Ibrahim'),
        ],
      );
      await type(tester, 'moussa');
      expect(emptyState, findsOneWidget);
    });

    testWidgets('demande en attente : jamais dans les résultats', (
      tester,
    ) async {
      await open(tester, bids: _parcels);
      await type(tester, 'aminata');
      expectRows(['a1'], ['p1']);
    });

    testWidgets('espaces seuls : aucune recherche, tout reste', (tester) async {
      await open(tester, bids: _parcels);
      await type(tester, '   ');
      expectRows(['a1', 't1', 'a2', 't2'], []);
      expect(counter, findsNothing);
      expect(emptyState, findsNothing);
    });
  });

  group('avec les puces de statut', () {
    Finder chip(String text) =>
        find.descendant(of: chips, matching: find.textContaining(text));

    testWidgets('statut ET recherche ; les puces comptent les colis trouvés', (
      tester,
    ) async {
      await open(tester, bids: _parcels);
      await tester.tap(chip('Accepté'));
      await _settle(tester);
      expectRows(['a1', 'a2'], ['t1', 't2']);
      // « awa » : t1 (en transit) et a2 (accepté).
      await type(tester, 'awa');
      expectRows(['a2'], ['a1', 't1', 't2']);
      expect(find.text('Tous · 2'), findsOneWidget);
      expect(plain(tester, counter), '2 colis trouvés');
    });

    testWidgets('statut filtré sans colis trouvé : retour à « Tous »', (
      tester,
    ) async {
      await open(tester, bids: _parcels);
      await tester.tap(chip('Accepté'));
      await _settle(tester);
      // « keita » : seulement t2, en transit.
      await type(tester, 'keita');
      expectRows(['t2'], ['a1', 'a2', 't1']);
      // Un seul statut parmi les trouvés : pas de puces.
      expect(chips, findsNothing);
    });

    testWidgets('recherche sans résultat : ni puces ni lignes, état vide', (
      tester,
    ) async {
      await open(tester, bids: _parcels);
      await type(tester, 'zzz');
      expect(chips, findsNothing);
      expectRows([], ['a1', 't1', 'a2', 't2']);
      expect(counter, findsNothing);
    });
  });

  group('état vide et effacement', () {
    testWidgets('« Aucun colis ne correspond à « … » », puis « Effacer la '
        'recherche » remet tout', (tester) async {
      await open(tester, bids: _parcels);
      await type(tester, '  zzz  ');
      expect(emptyState, findsOneWidget);
      expect(find.text('Aucun colis ne correspond à « zzz »'), findsOneWidget);
      expect(find.text('Effacer la recherche'), findsOneWidget);
      expect(tester.getSize(clearLink).height, greaterThanOrEqualTo(44));
      // Lien texte : le seul DonyButton du sheet est celui du pied.
      expect(find.byKey(const Key('donyBottomSheetFooter')), findsOneWidget);
      await tester.tap(clearLink);
      await tester.pump();
      expect(fieldText(tester), '');
      expect(emptyState, findsNothing);
      expectRows(['a1', 't1', 'a2', 't2'], []);
    });

    testWidgets('bouton « Effacer » du champ : 44 px au moins, libellé '
        'lu, vide la saisie', (tester) async {
      await open(tester, bids: _parcels);
      final clear = find.descendant(
        of: field,
        matching: find.byType(IconButton),
      );
      expect(clear, findsNothing);
      await type(tester, 'awa');
      expect(clear, findsOneWidget);
      final s = tester.getSize(clear);
      expect(s.width, greaterThanOrEqualTo(44));
      expect(s.height, greaterThanOrEqualTo(44));
      expect(tester.widget<IconButton>(clear).tooltip, 'Effacer');
      final semantics = tester.ensureSemantics();
      expect(
        tester.getSemantics(clear),
        isSemantics(tooltip: 'Effacer', isButton: true),
      );
      semantics.dispose();
      await tester.tap(clear);
      await tester.pump();
      expect(fieldText(tester), '');
      expect(clear, findsNothing);
      expectRows(['a1', 't1', 'a2', 't2'], []);
    });
  });

  group('vie de la saisie', () {
    testWidgets('relecture des colis : la saisie reste, les résultats '
        'suivent', (tester) async {
      await open(tester, bids: _parcels);
      await type(tester, 'awa');
      h.screenStates.add(
        BidListLoaded([
          ..._parcels,
          _parcel('n1', status: 'ACCEPTED', sender: 'Awa Cissé'),
        ]),
      );
      await _settle(tester);
      expect(fieldText(tester), 'awa');
      expectRows(['t1', 'a2', 'n1'], ['a1', 't2']);
      expect(plain(tester, counter), '3 colis trouvés');
    });

    testWidgets('bloc gain apparu à une relecture : saisie et clavier '
        'gardés, bloc replié tant que la recherche dure', (tester) async {
      await open(tester, bids: [for (final b in _parcels) b]);
      await tester.showKeyboard(field);
      await type(tester, 'awa');
      expect(find.byKey(const Key('trip-activity-parcels-gain')), findsNothing);
      h.screenStates.add(
        BidListLoaded([..._parcels, _parcel('g1', sender: 'Gora', net: 40)]),
      );
      await _settle(tester);
      // Le gain existe maintenant, mais la recherche le garde replié.
      expect(find.byKey(const Key('trip-activity-parcels-gain')), findsNothing);
      expect(fieldText(tester), 'awa');
      final editable = tester.widget<EditableText>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      );
      expect(editable.focusNode.hasFocus, isTrue);
      // Recherche finie : le bloc apparu entre-temps se montre.
      await tester.tap(find.byTooltip('Effacer'));
      FocusManager.instance.primaryFocus?.unfocus();
      await _settle(tester);
      expect(
        find.byKey(const Key('trip-activity-parcels-gain')),
        findsOneWidget,
      );
    });

    testWidgets('fermer puis rouvrir : le champ repart vide', (tester) async {
      await open(tester, bids: _parcels);
      await type(tester, 'awa');
      await tester.tap(find.byTooltip('Fermer'));
      await _settle(tester);
      expect(field, findsNothing);
      await tester.tap(find.text('open-activity'));
      await _settle(tester);
      expect(fieldText(tester), '');
      expectRows(['a1', 't1', 'a2', 't2'], []);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('pendant la recherche, la feuille ne rapetisse pas : le '
        'champ ne bouge pas ; effacer rend la hauteur', (tester) async {
      final many = [
        for (var i = 0; i < 6; i++)
          _parcel('m$i', sender: i == 0 ? 'Unique Nom' : 'Commun $i'),
      ];
      await open(tester, bids: many);
      final top = tester.getTopLeft(field).dy;
      await type(tester, 'unique');
      await _settle(tester);
      expectRows(['m0'], ['m1']);
      expect(tester.getTopLeft(field).dy, closeTo(top, 0.5));
      await type(tester, 'zzz');
      await _settle(tester);
      expect(tester.getTopLeft(field).dy, closeTo(top, 0.5));
      await type(tester, '');
      await _settle(tester);
      expect(tester.getTopLeft(field).dy, closeTo(top, 0.5));
      await type(tester, 'unique');
      await tester.tap(find.byTooltip('Effacer'));
      await _settle(tester);
      expectRows(['m0', 'm5'], []);
    });
  });

  group('recherche en cours : gain et résumé repliés', () {
    final gainBlock = find.byKey(const Key('trip-activity-parcels-gain'));
    // Un colis en transit avec un gain : le bloc « Gain estimé » existe.
    final withGain = [..._parcels, _parcel('g1', sender: 'Gora', net: 40)];

    EditableText editable(WidgetTester tester) => tester.widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    );

    Future<void> unfocus(WidgetTester tester) async {
      FocusManager.instance.primaryFocus?.unfocus();
      await _settle(tester);
    }

    testWidgets('au départ : gain et résumé visibles, champ sans focus', (
      tester,
    ) async {
      await open(tester, bids: withGain);
      expect(gainBlock, findsOneWidget);
      expect(summary, findsOneWidget);
      expect(editable(tester).focusNode.hasFocus, isFalse);
    });

    testWidgets('focus sans texte : gain et résumé masqués ; champ, puces et '
        'lignes restent', (tester) async {
      await open(tester, bids: withGain);
      await tester.showKeyboard(field);
      await _settle(tester);
      expect(gainBlock, findsNothing);
      expect(summary, findsNothing);
      expect(field, findsOneWidget);
      expect(chips, findsOneWidget);
      expectRows(['a1', 't1', 'a2', 't2', 'g1'], ['p1']);
      expect(editable(tester).focusNode.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('du texte, focus perdu : toujours masqués', (tester) async {
      await open(tester, bids: withGain);
      await type(tester, 'awa');
      await unfocus(tester);
      expect(editable(tester).focusNode.hasFocus, isFalse);
      expect(fieldText(tester), 'awa');
      expect(gainBlock, findsNothing);
      expect(summary, findsNothing);
      // Compteur et lignes restent.
      expect(plain(tester, counter), '2 colis trouvés');
      expectRows(['t1', 'a2'], ['a1', 't2']);
    });

    testWidgets('des espaces seuls comptent comme du texte', (tester) async {
      await open(tester, bids: withGain);
      await type(tester, '   ');
      await unfocus(tester);
      expect(gainBlock, findsNothing);
      expect(summary, findsNothing);
    });

    testWidgets('champ vidé mais focus gardé : toujours masqués', (
      tester,
    ) async {
      await open(tester, bids: withGain);
      await tester.showKeyboard(field);
      await type(tester, 'awa');
      await type(tester, '');
      await _settle(tester);
      expect(editable(tester).focusNode.hasFocus, isTrue);
      expect(gainBlock, findsNothing);
      expect(summary, findsNothing);
    });

    testWidgets('vide ET sans focus : gain et résumé reviennent', (
      tester,
    ) async {
      await open(tester, bids: withGain);
      await tester.showKeyboard(field);
      await type(tester, 'awa');
      await _settle(tester);
      expect(gainBlock, findsNothing);
      // Effacer par le bouton du champ, puis fermer le clavier.
      await tester.tap(find.byTooltip('Effacer'));
      await unfocus(tester);
      expect(fieldText(tester), '');
      expect(gainBlock, findsOneWidget);
      expect(summary, findsOneWidget);
      expectRows(['a1', 't1', 'a2', 't2', 'g1'], []);
    });

    testWidgets('touche ailleurs que le champ, champ vide : reviennent', (
      tester,
    ) async {
      await open(tester, bids: withGain);
      await tester.tap(field);
      await _settle(tester);
      expect(gainBlock, findsNothing);
      // Toucher hors du champ ferme le clavier (DonySearchField).
      await tester.tap(find.text('Colis dans le trajet'));
      await _settle(tester);
      expect(gainBlock, findsOneWidget);
      expect(summary, findsOneWidget);
    });

    testWidgets('le champ garde focus, texte et curseur quand les blocs '
        'se replient', (tester) async {
      await open(tester, bids: withGain);
      await tester.showKeyboard(field);
      await type(tester, 'awa');
      await _settle(tester);
      final e = editable(tester);
      expect(e.focusNode.hasFocus, isTrue);
      expect(e.controller.text, 'awa');
      expect(e.controller.selection.baseOffset, 3);
      expect(tester.takeException(), isNull);
    });

    testWidgets('focus et texte survivent aux relectures des colis', (
      tester,
    ) async {
      await open(tester, bids: withGain);
      await tester.showKeyboard(field);
      await type(tester, 'awa');
      h.screenStates.add(
        BidListLoaded([
          ...withGain,
          _parcel('n1', status: 'ACCEPTED', sender: 'Awa Cissé'),
        ]),
      );
      await _settle(tester);
      expect(editable(tester).focusNode.hasFocus, isTrue);
      expect(fieldText(tester), 'awa');
      expect(gainBlock, findsNothing);
      expect(summary, findsNothing);
      expectRows(['t1', 'a2', 'n1'], ['a1', 't2']);
    });

    testWidgets('feuille qui épouse son contenu : le champ ne bouge pas au '
        'focus (image par image), à la frappe, à l\'effacement ni au retour '
        'des blocs', (tester) async {
      final short = [
        _parcel('g1', sender: 'Gora', net: 40),
        _parcel('g2', sender: 'Awa'),
      ];
      await open(tester, bids: short);
      expect(gainBlock, findsOneWidget);
      final top = tester.getTopLeft(field).dy;
      await tester.showKeyboard(field);
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        expect(tester.getTopLeft(field).dy, closeTo(top, 0.5), reason: '$i');
      }
      expect(gainBlock, findsNothing);
      await type(tester, 'gora');
      await _settle(tester);
      expect(tester.getTopLeft(field).dy, closeTo(top, 0.5));
      // L'état « aucun résultat » est plus haut que la liste de deux colis :
      // la feuille grandit vers le haut, le champ ne descend jamais.
      await type(tester, 'zzz');
      await _settle(tester);
      expect(tester.getTopLeft(field).dy, lessThanOrEqualTo(top + 0.5));
      await type(tester, '');
      await unfocus(tester);
      expect(gainBlock, findsOneWidget);
      expect(tester.getTopLeft(field).dy, closeTo(top, 0.5));
    });

    testWidgets('feuille déjà à sa hauteur maximale (longue liste) : le champ '
        'ne descend jamais, il remonte puis ne bouge plus pendant la '
        'frappe', (tester) async {
      await open(tester, bids: withGain);
      final top = tester.getTopLeft(field).dy;
      await tester.showKeyboard(field);
      var last = top;
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        final y = tester.getTopLeft(field).dy;
        expect(y, lessThanOrEqualTo(last + 0.5), reason: '$i');
        last = y;
      }
      expect(editable(tester).focusNode.hasFocus, isTrue);
      await _settle(tester);
      final settled = tester.getTopLeft(field).dy;
      expect(settled, lessThanOrEqualTo(top + 0.5));
      for (final q in ['g', 'go', 'gor', 'gora', 'zzz', '']) {
        await type(tester, q);
        await _settle(tester);
        expect(tester.getTopLeft(field).dy, closeTo(settled, 0.5), reason: q);
        expect(editable(tester).focusNode.hasFocus, isTrue, reason: q);
      }
    });

    testWidgets('transition courte : repli en 180 ms, pas d\'un coup', (
      tester,
    ) async {
      await open(tester, bids: withGain);
      final clip = find
          .ancestor(of: gainBlock, matching: find.byType(ClipRect))
          .first;
      final gainHeight = tester.getSize(clip).height;
      await tester.showKeyboard(field);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      // À mi-course : encore là, plus petit.
      expect(gainBlock, findsOneWidget);
      expect(tester.getSize(clip).height, lessThan(gainHeight));
      expect(tester.getSize(clip).height, greaterThan(0));
      await tester.pump(const Duration(milliseconds: 120));
      expect(gainBlock, findsNothing);
    });

    testWidgets('animations réduites par le système : repli immédiat', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await open(tester, bids: withGain);
      expect(gainBlock, findsOneWidget);
      await tester.showKeyboard(field);
      await tester.pump();
      await tester.pump();
      expect(gainBlock, findsNothing);
      expect(summary, findsNothing);
    });

    testWidgets('sans gain : seul le résumé se replie', (tester) async {
      await open(tester, bids: _parcels);
      expect(gainBlock, findsNothing);
      await tester.showKeyboard(field);
      await _settle(tester);
      expect(summary, findsNothing);
      expect(gainBlock, findsNothing);
      await unfocus(tester);
      expect(summary, findsOneWidget);
    });

    testWidgets('aucun résultat : champ, état vide et lien restent, blocs '
        'repliés', (tester) async {
      await open(tester, bids: withGain);
      await type(tester, 'zzz');
      await _settle(tester);
      expect(emptyState, findsOneWidget);
      expect(clearLink, findsOneWidget);
      expect(gainBlock, findsNothing);
      expect(summary, findsNothing);
      await tester.tap(clearLink);
      await unfocus(tester);
      expect(gainBlock, findsOneWidget);
      expect(summary, findsOneWidget);
    });

    testWidgets('dernier colis retiré pendant la recherche : le champ part '
        'avec son focus, l\'état vide habituel s\'affiche', (tester) async {
      await open(tester, bids: withGain);
      await tester.showKeyboard(field);
      await _settle(tester);
      expect(gainBlock, findsNothing);
      h.screenStates.add(BidListLoaded([_parcel('p1', status: 'PENDING')]));
      await _settle(tester);
      expect(field, findsNothing);
      expect(
        find.byKey(const Key('trip-activity-parcels-empty')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    for (final locale in const [Locale('fr'), Locale('en')]) {
      testWidgets('${locale.languageCode} : 360 dp × 1,3, clavier ouvert, '
          'blocs repliés puis de retour sans exception', (tester) async {
        await open(
          tester,
          bids: withGain,
          locale: locale,
          textScale: 1.3,
          size: const Size(360, 800),
        );
        expect(gainBlock, findsOneWidget);
        expect(summary, findsOneWidget);
        await tester.showKeyboard(field);
        tester.view.viewInsets = const FakeViewPadding(bottom: 320);
        addTearDown(tester.view.resetViewInsets);
        await _settle(tester);
        expect(gainBlock, findsNothing);
        expect(summary, findsNothing);
        expect(tester.takeException(), isNull);
        await type(tester, 'nom');
        await _settle(tester);
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
        await tester.tap(
          find.byTooltip(locale.languageCode == 'fr' ? 'Effacer' : 'Clear'),
        );
        await unfocus(tester);
        expect(gainBlock, findsOneWidget);
        expect(summary, findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('mesure trip_parcels_searched', () {
    void expectNoSearchEvent() => verifyNever(
      () => h.backend.capture(AnalyticsEvents.tripParcelsSearched, any()),
    );

    testWidgets('après 800 ms de pause, une fois par terme, matches et total '
        'seulement', (tester) async {
      await open(tester, bids: _parcels);
      await type(tester, 'aw');
      await tester.pump(const Duration(milliseconds: 500));
      await type(tester, 'awa');
      await tester.pump(const Duration(milliseconds: 700));
      expectNoSearchEvent();
      await tester.pump(const Duration(milliseconds: 150));
      final captured = verify(
        () => h.backend.capture(
          AnalyticsEvents.tripParcelsSearched,
          captureAny(),
        ),
      ).captured;
      expect(captured, [
        {'matches': 2, 'total': 4},
      ]);
      // Aucune donnée saisie, aucun nom, aucun numéro.
      final props = captured.single as Map<String, Object?>;
      expect(props.keys, unorderedEquals(['matches', 'total']));
      expect(props.values.whereType<String>(), isEmpty);

      // Même terme (casse, espaces) : pas de nouvelle mesure ; relecture non
      // plus.
      await type(tester, ' AWA ');
      await tester.pump(const Duration(seconds: 1));
      h.screenStates.add(BidListLoaded(_parcels));
      await _settle(tester);
      await tester.pump(const Duration(seconds: 1));
      expectNoSearchEvent();

      // Nouveau terme, sans résultat : mesuré avec 0.
      await type(tester, 'zzz');
      await tester.pump(const Duration(seconds: 1));
      verify(
        () => h.backend.capture(AnalyticsEvents.tripParcelsSearched, {
          'matches': 0,
          'total': 4,
        }),
      ).called(1);
    });

    testWidgets('champ vidé puis même terme : remesuré ; vide ou espaces : '
        'jamais', (tester) async {
      await open(tester, bids: _parcels);
      await type(tester, 'keita');
      await tester.pump(const Duration(seconds: 1));
      await type(tester, '   ');
      await tester.pump(const Duration(seconds: 1));
      await type(tester, '');
      await tester.pump(const Duration(seconds: 1));
      await type(tester, 'keita');
      await tester.pump(const Duration(seconds: 1));
      verify(
        () => h.backend.capture(AnalyticsEvents.tripParcelsSearched, {
          'matches': 1,
          'total': 4,
        }),
      ).called(2);
    });

    testWidgets('sheet fermé avant la pause : rien n\'est mesuré', (
      tester,
    ) async {
      await open(tester, bids: _parcels);
      await type(tester, 'awa');
      await tester.tap(find.byTooltip('Fermer'));
      // Sortie du sheet image par image : le contenu démonté annule la
      // mesure en attente.
      await _settle(tester);
      await tester.pump(const Duration(seconds: 2));
      expectNoSearchEvent();
    });
  });

  group('anglais', () {
    testWidgets('indication, compteur, état vide, lien', (tester) async {
      await open(tester, bids: _parcels, locale: const Locale('en'));
      expect(find.text('Search parcels, names, tracking'), findsOneWidget);
      await type(tester, 'awa');
      expect(plain(tester, counter), '2 parcels found');
      await type(tester, 'traore');
      expect(plain(tester, counter), '1 parcel found');
      await type(tester, 'zzz');
      expect(find.text('No parcel matches “zzz”'), findsOneWidget);
      expect(find.text('Clear search'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.descendant(of: field, matching: find.byType(IconButton)),
            )
            .tooltip,
        'Clear',
      );
    });
  });

  group('360 dp × 1,3, vraies polices', () {
    final many = [
      for (var i = 0; i < 8; i++)
        _parcel(
          'p$i',
          status: i.isEven ? 'IN_TRANSIT' : 'ACCEPTED',
          sender: 'Expéditeur au nom très long numéro $i',
        ),
    ];
    for (final locale in const [Locale('fr'), Locale('en')]) {
      testWidgets('${locale.languageCode} : champ, compteur et état vide sans '
          'exception, sur une ligne', (tester) async {
        await open(
          tester,
          bids: many,
          locale: locale,
          textScale: 1.3,
          size: const Size(360, 800),
        );
        expect(tester.takeException(), isNull);
        expect(tester.getSize(field).width, lessThanOrEqualTo(360));
        await type(tester, 'long');
        expect(tester.takeException(), isNull);
        final countHeight = tester.getSize(counter).height;
        await type(tester, 'numero 3');
        expect(tester.getSize(counter).height, closeTo(countHeight, 0.5));
        await type(tester, 'une recherche vraiment très longue');
        await _settle(tester);
        expect(tester.takeException(), isNull);
        expect(emptyState, findsOneWidget);
        final link = find.descendant(
          of: clearLink,
          matching: find.byType(Text),
        );
        expect(tester.widget<Text>(link).maxLines, 1);
        // Lien sur une ligne : hauteur d'une seule ligne de texte.
        expect(tester.getSize(link).height, lessThan(2 * 14 * 1.3));
      });

      testWidgets('${locale.languageCode} : clavier ouvert, pied visible au-'
          'dessus du clavier, lignes atteignables', (tester) async {
        await open(
          tester,
          bids: many,
          locale: locale,
          textScale: 1.3,
          size: const Size(360, 800),
        );
        await tester.showKeyboard(field);
        tester.view.viewInsets = const FakeViewPadding(bottom: 320);
        addTearDown(tester.view.resetViewInsets);
        await _settle(tester);
        await type(tester, 'nom');
        await _settle(tester);
        expect(tester.takeException(), isNull);
        final button = find.byKey(const Key('trip-activity-parcels-open-list'));
        expect(button, findsOneWidget);
        expect(tester.getBottomLeft(button).dy, lessThanOrEqualTo(800 - 320));
        final footerTop = tester
            .getTopLeft(find.byKey(const Key('donyBottomSheetFooter')))
            .dy;
        await tester.ensureVisible(row('p7'));
        await _settle(tester);
        expect(
          tester.getBottomLeft(row('p7')).dy,
          lessThanOrEqualTo(footerTop),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
