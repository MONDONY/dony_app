// Pièces des colis du trajet vu par son voyageur, reprises par le sheet
// « Colis » de l'activité du trajet : résumé par étape du cycle
// (`TripParcelsSummary`, `tripParcelsCounts`, FLUTTER-GS) et ligne d'un colis
// (`TripParcelRow` : contenu, expéditeur, statut traduit). Le sheet lui-même
// (filtre des colis embarqués, vide, chargement, erreur) est testé par
// `trip_owner/trip_activity_sheets_test.dart`.
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/trip_parcels_section.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Fixture ───────────────────────────────────────────────────────────────────

BidModel _makeBid({
  required String status,
  String id = 'bid-00000001',
  String senderName = 'Moussa Traoré',
  String contentCategory = 'Vêtements',
}) => BidModel(
  id: id,
  announcementId: 'ann-1',
  senderId: 'sender-1',
  senderName: senderName,
  weightKg: 3,
  contentCategory: contentCategory,
  status: status,
  createdAt: DateTime(2026, 5),
  updatedAt: DateTime(2026, 5),
);

// ── Pump helper ───────────────────────────────────────────────────────────────

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('fr'),
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

Widget _rows(List<BidModel> bids, {ValueChanged<String>? onTap}) => Column(
  children: [
    for (final b in bids) TripParcelRow(bid: b, onTap: () => onTap?.call(b.id)),
  ],
);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('ligne d\'un colis', () {
    testWidgets('contenu, expéditeur et poids', (tester) async {
      await _pump(
        tester,
        _rows([
          _makeBid(
            status: 'ACCEPTED',
            senderName: 'Aïssa Camara',
            contentCategory: 'Documents',
          ),
        ]),
      );

      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('Aïssa Camara · 3 kg'), findsOneWidget);
      expect(find.text('Accepté'), findsOneWidget);
    });

    testWidgets('tap : la ligne appelle son action', (tester) async {
      final tapped = <String>[];
      await _pump(
        tester,
        _rows([_makeBid(status: 'ACCEPTED', id: 'b1')], onTap: tapped.add),
      );

      await tester.tap(find.byType(TripParcelRow));
      expect(tapped, ['b1']);
    });

    // Régression : sans entrée ARRIVED, le libellé retombait sur le défaut et
    // affichait la chaîne brute anglaise « ARRIVED » au voyageur.
    testWidgets('ARRIVED → libellé français « Arrivé », jamais la chaîne '
        'brute', (tester) async {
      await _pump(tester, _rows([_makeBid(status: 'ARRIVED')]));

      expect(find.text('Arrivé'), findsOneWidget);
      expect(find.text('ARRIVED'), findsNothing);
    });

    // Régression staging : un colis accepté en mobile money passe en
    // AWAITING_PAYMENT (30 min pour le séquestre côté expéditeur) ; sans
    // entrée dédiée, la chaîne brute anglaise s'affichait.
    testWidgets('AWAITING_PAYMENT (mobile money) → « Paiement en attente », '
        'jamais la chaîne brute', (tester) async {
      await _pump(tester, _rows([_makeBid(status: 'AWAITING_PAYMENT')]));

      expect(find.text('Paiement en attente'), findsOneWidget);
      expect(find.text('AWAITING_PAYMENT'), findsNothing);
    });

    testWidgets('en anglais : statuts traduits', (tester) async {
      await _pump(
        tester,
        _rows([
          _makeBid(status: 'AWAITING_PAYMENT', id: 'b1'),
          _makeBid(status: 'ARRIVED', id: 'b2'),
        ]),
        locale: const Locale('en'),
      );

      expect(find.text('Payment pending'), findsOneWidget);
      expect(find.text('Paiement en attente'), findsNothing);
    });
  });

  // ── Résumé de tête (FLUTTER-GS) ───────────────────────────────────────────
  group('résumé des colis', () {
    String summaryText(WidgetTester tester) => tester
        .widget<Text>(find.byKey(const Key('trip-parcels-summary')))
        .textSpan!
        .toPlainText();

    test('répartition par étape du cycle réel', () {
      final c = tripParcelsCounts([
        _makeBid(status: 'HANDED_OVER'),
        _makeBid(status: 'IN_TRANSIT'),
        _makeBid(status: 'ACCEPTED'),
        _makeBid(status: 'AWAITING_PAYMENT'),
        _makeBid(status: 'ARRIVED'),
        _makeBid(status: 'COMPLETED'),
        _makeBid(status: 'COMPLETED'),
        _makeBid(status: 'NO_SHOW'),
      ]);
      expect(c.inTransit, 2);
      expect(c.toCollect, 1);
      expect(c.arrived, 1);
      expect(c.delivered, 2);
    });

    testWidgets('pluriels FR, ordre fixe, segments vides omis', (tester) async {
      await _pump(
        tester,
        TripParcelsSummary(
          bids: [
            _makeBid(status: 'IN_TRANSIT', id: 'b1'),
            _makeBid(status: 'IN_TRANSIT', id: 'b2'),
            _makeBid(status: 'HANDED_OVER', id: 'b3'),
            _makeBid(status: 'ACCEPTED', id: 'b4'),
            _makeBid(status: 'COMPLETED', id: 'b5'),
            _makeBid(status: 'COMPLETED', id: 'b6'),
          ],
        ),
      );

      expect(
        summaryText(tester),
        '3 colis en route  ·  1 à récupérer  ·  2 livrés',
      );
      expect(
        find.bySemanticsLabel('3 colis en route · 1 à récupérer · 2 livrés'),
        findsOneWidget,
      );
    });

    testWidgets('singuliers FR et colis arrivé', (tester) async {
      await _pump(
        tester,
        TripParcelsSummary(
          bids: [
            _makeBid(status: 'ARRIVED', id: 'b1'),
            _makeBid(status: 'COMPLETED', id: 'b2'),
          ],
        ),
      );

      expect(summaryText(tester), '1 arrivé  ·  1 livré');
    });

    testWidgets('anglais : pluriels ICU', (tester) async {
      await _pump(
        tester,
        TripParcelsSummary(
          bids: [
            _makeBid(status: 'IN_TRANSIT', id: 'b1'),
            _makeBid(status: 'ACCEPTED', id: 'b2'),
            _makeBid(status: 'ACCEPTED', id: 'b3'),
          ],
        ),
        locale: const Locale('en'),
      );

      expect(summaryText(tester), '1 parcel in transit  ·  2 to pick up');
    });

    testWidgets('chiffres tabulaires', (tester) async {
      await _pump(
        tester,
        TripParcelsSummary(
          bids: [_makeBid(status: 'ACCEPTED', id: 'b1')],
        ),
      );

      final root =
          tester
                  .widget<Text>(find.byKey(const Key('trip-parcels-summary')))
                  .textSpan!
              as TextSpan;
      final number = root.children!.whereType<TextSpan>().firstWhere(
        (s) => s.text == '1',
      );
      expect(
        number.style!.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });

    testWidgets('que des clôturés → pas de résumé', (tester) async {
      await _pump(
        tester,
        TripParcelsSummary(
          bids: [_makeBid(status: 'NO_SHOW', id: 'b1')],
        ),
      );

      expect(find.byKey(const Key('trip-parcels-summary')), findsNothing);
    });
  });
}
