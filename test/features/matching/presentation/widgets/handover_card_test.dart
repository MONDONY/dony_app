import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/handover_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BidModel _bid({
  String? handoverLocation,
  DateTime? handoverDeadline,
  bool voyageurConfirmed = false,
}) => BidModel(
  id: 'bid-1',
  announcementId: 'a-1',
  senderId: 's-1',
  weightKg: 4,
  status: 'ACCEPTED',
  createdAt: DateTime(2026, 5, 10),
  updatedAt: DateTime(2026, 5, 10),
  handoverLocation: handoverLocation,
  handoverDeadline: handoverDeadline,
  voyageurConfirmed: voyageurConfirmed,
);

Future<void> _pump(WidgetTester tester, BidModel bid) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: HandoverCard(bid: bid)),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('affiche le titre "Dépôt du colis"', (tester) async {
    await _pump(tester, _bid());
    expect(find.text('Dépôt du colis'), findsOneWidget);
  });

  testWidgets('affiche le lieu de remise quand renseigné', (tester) async {
    await _pump(tester, _bid(handoverLocation: 'Aéroport CDG — Terminal 2E'));
    expect(find.text('Lieu'), findsOneWidget);
    expect(find.text('Aéroport CDG — Terminal 2E'), findsOneWidget);
  });

  testWidgets('lieu absent → "-" affiché', (tester) async {
    await _pump(tester, _bid());
    expect(find.text('-'), findsOneWidget);
  });

  testWidgets('affiche la date limite quand renseignée', (tester) async {
    await _pump(tester, _bid(handoverDeadline: DateTime(2026, 6, 15, 12)));
    expect(find.text('Date limite'), findsOneWidget);
    expect(find.text('15/06/2026'), findsOneWidget);
  });

  testWidgets('pas de date limite → la ligne est absente', (tester) async {
    await _pump(tester, _bid());
    expect(find.text('Date limite'), findsNothing);
  });

  testWidgets('voyageurConfirmed=true → "Oui ✓"', (tester) async {
    await _pump(tester, _bid(voyageurConfirmed: true));
    expect(find.text('Présence confirmée'), findsOneWidget);
    expect(find.text('Oui ✓'), findsOneWidget);
  });

  testWidgets('voyageurConfirmed=false → "Non encore"', (tester) async {
    await _pump(tester, _bid());
    expect(find.text('Non encore'), findsOneWidget);
  });
}
