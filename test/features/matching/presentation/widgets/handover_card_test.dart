import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/handover_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BidModel _bid({
  String? handoverLocation,
  DateTime? handoverWindowStart,
  DateTime? handoverWindowEnd,
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
  handoverWindowStart: handoverWindowStart,
  handoverWindowEnd: handoverWindowEnd,
  voyageurConfirmed: voyageurConfirmed,
);

Future<void> _pump(WidgetTester tester, BidModel bid) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: HandoverCard(bid: bid)),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('affiche le titre "Fenêtre de remise"', (tester) async {
    await _pump(tester, _bid());
    expect(find.text('Fenêtre de remise'), findsOneWidget);
  });

  testWidgets('affiche le lieu de remise quand renseigné', (tester) async {
    await _pump(tester, _bid(handoverLocation: 'Aéroport CDG — Terminal 2E'));
    expect(find.text('Lieu'), findsOneWidget);
    expect(find.text('Aéroport CDG — Terminal 2E'), findsOneWidget);
  });

  testWidgets('lieu absent → "—" affiché', (tester) async {
    await _pump(tester, _bid(handoverLocation: null));
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('affiche les dates début/fin quand renseignées', (tester) async {
    await _pump(
      tester,
      _bid(
        handoverWindowStart: DateTime(2026, 6, 15, 9, 0),
        handoverWindowEnd: DateTime(2026, 6, 15, 12, 0),
      ),
    );
    expect(find.text('Début'), findsOneWidget);
    expect(find.text('Fin'), findsOneWidget);
  });

  testWidgets('pas de dates → "Début" et "Fin" absents', (tester) async {
    await _pump(tester, _bid());
    expect(find.text('Début'), findsNothing);
    expect(find.text('Fin'), findsNothing);
  });

  testWidgets('voyageurConfirmed=true → "Oui ✓"', (tester) async {
    await _pump(tester, _bid(voyageurConfirmed: true));
    expect(find.text('Présence confirmée'), findsOneWidget);
    expect(find.text('Oui ✓'), findsOneWidget);
  });

  testWidgets('voyageurConfirmed=false → "Non encore"', (tester) async {
    await _pump(tester, _bid(voyageurConfirmed: false));
    expect(find.text('Non encore'), findsOneWidget);
  });
}
