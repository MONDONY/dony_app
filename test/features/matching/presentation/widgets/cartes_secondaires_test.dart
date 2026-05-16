import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/trajet_card.dart';
import 'package:dony/features/matching/presentation/widgets/disclaimer_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BidModel _bid() => BidModel(
  id: 'b-1',
  announcementId: 'a-1',
  senderId: 's-1',
  weightKg: 5,
  status: 'ACCEPTED',
  createdAt: DateTime(2026, 5, 1),
  updatedAt: DateTime(2026, 5, 1),
  departureDate: DateTime(2026, 5, 11),
);

void main() {
  testWidgets('TrajetCard a un titre', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: TrajetCard(bid: _bid())),
      ),
    );
    expect(find.text('Détails du trajet'), findsOneWidget);
  });

  testWidgets('DisclaimerCard a un titre', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: DisclaimerCard(bid: _bid())),
      ),
    );
    expect(find.text('Responsabilité légale'), findsOneWidget);
  });
}
