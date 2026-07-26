import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_list/bid_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

BidModel _makeBid({
  required String status,
  String id = 'bid-00000001',
  String senderName = 'Moussa Traoré',
  BidPaymentMethod paymentMethod = BidPaymentMethod.stripe,
  String? contentCategory = 'Vêtements',
  String? description,
}) =>
    BidModel(
      id: id,
      announcementId: 'ann-1',
      senderId: 'sender-1',
      senderName: senderName,
      weightKg: 3,
      pricePerKg: 15,
      contentCategory: contentCategory,
      description: description,
      status: status,
      paymentMethod: paymentMethod,
      createdAt: DateTime(2026, 5),
      updatedAt: DateTime(2026, 5),
    );

/// Pump une [BidCard] dans un Scaffold (sans router — pas de tap sur la carte).
Future<void> _pumpCard(WidgetTester tester, BidCard card) async {
  await initializeDateFormatting('fr_FR');
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: SingleChildScrollView(child: card)),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
      'PENDING cash avec callbacks → bandeau « Paiement en espèces » + Refuser/Accepter',
      (tester) async {
    await _pumpCard(
      tester,
      BidCard(
        bid: _makeBid(status: 'PENDING', paymentMethod: BidPaymentMethod.cash),
        isProcessing: false,
        onAccept: () {},
        onReject: () {},
      ),
    );

    expect(find.textContaining('Paiement en espèces'), findsOneWidget);
    expect(find.text('Refuser'), findsOneWidget);
    expect(find.text('Accepter'), findsOneWidget);
  });

  testWidgets(
      'PAYMENT_ESCROWED avec callbacks → bandeau « Paiement reçu »',
      (tester) async {
    await _pumpCard(
      tester,
      BidCard(
        bid: _makeBid(status: 'PAYMENT_ESCROWED'),
        isProcessing: false,
        onAccept: () {},
        onReject: () {},
      ),
    );

    expect(find.textContaining('Paiement reçu'), findsOneWidget);
    expect(find.textContaining('Paiement en espèces'), findsNothing);
    expect(find.text('Refuser'), findsOneWidget);
    expect(find.text('Accepter'), findsOneWidget);
  });

  testWidgets(
      'ACCEPTED sans callbacks → pas de bandeau, badge « Accepté », pas d\'actions',
      (tester) async {
    await _pumpCard(
      tester,
      BidCard(
        bid: _makeBid(status: 'ACCEPTED'),
        isProcessing: false,
      ),
    );

    expect(find.text('Accepté'), findsOneWidget);
    expect(find.textContaining('Paiement reçu'), findsNothing);
    expect(find.textContaining('Paiement en espèces'), findsNothing);
    expect(find.text('Refuser'), findsNothing);
    expect(find.text('Accepter'), findsNothing);
  });

  testWidgets('isProcessing: true → la carte se rend, Accepter en chargement',
      (tester) async {
    await _pumpCard(
      tester,
      BidCard(
        bid: _makeBid(status: 'PAYMENT_ESCROWED'),
        isProcessing: true,
        onAccept: () {},
        onReject: () {},
      ),
    );

    // La carte se rend correctement.
    expect(find.byType(BidCard), findsOneWidget);
    expect(find.text('Refuser'), findsOneWidget);

    // En chargement, le bouton Accepter remplace son libellé par un spinner :
    // « Accepter » n'est plus rendu, un CircularProgressIndicator l'est.
    expect(find.text('Accepter'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('tap sur la carte → context.push(/bids/:id)', (tester) async {
    await initializeDateFormatting('fr_FR');
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: SingleChildScrollView(
              child: BidCard(
                bid: _makeBid(status: 'ACCEPTED', id: 'bid-zzz'),
                isProcessing: false,
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/bids/:id',
          builder: (_, state) => Scaffold(
            body: Text('Bid detail ${state.pathParameters['id']}'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
    );
    await tester.pump();

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Bid detail bid-zzz'), findsOneWidget);
  });

  testWidgets(
      'plusieurs catégories → 1re catégorie + « +N », pas la chaîne complète',
      (tester) async {
    await _pumpCard(
      tester,
      BidCard(
        bid: _makeBid(
          status: 'ACCEPTED',
          contentCategory:
              'Vêtements & tissus, Documents & administratif, Alimentaire',
        ),
        isProcessing: false,
      ),
    );

    // 1re catégorie affichée seule, reste replié dans « +2 ».
    expect(find.text('Vêtements & tissus'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);
    // La chaîne jointe complète n'est jamais rendue telle quelle.
    expect(find.textContaining('Documents & administratif'), findsNothing);
  });

  testWidgets(
      'sans catégorie mais description → pill description (ellipsis, pas d\'overflow)',
      (tester) async {
    await _pumpCard(
      tester,
      BidCard(
        bid: _makeBid(
          status: 'ACCEPTED',
          contentCategory: null,
          description: 'Un très long texte de description du colis à transporter',
        ),
        isProcessing: false,
      ),
    );

    expect(
      find.textContaining('Un très long texte de description'),
      findsOneWidget,
    );
    // Aucun overflow rendu (le test échouerait sinon via l'exception Flutter).
    expect(tester.takeException(), isNull);
  });
}
