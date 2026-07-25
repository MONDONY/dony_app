import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/colis_card.dart';
import 'package:dony/features/matching/presentation/widgets/destinataire_card.dart';
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
  recipientName: 'Awa N.',
  recipientPhone: '+225070000000',
);

void main() {
  testWidgets('ColisCard montre le poids', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: ColisCard(bid: _bid())),
      ),
    );
    expect(find.textContaining('5'), findsWidgets);
  });

  testWidgets('DestinataireCard montre nom et téléphone', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: DestinataireCard(bid: _bid())),
      ),
    );
    expect(find.text('Awa N.'), findsOneWidget);
    expect(find.text('+225070000000'), findsOneWidget);
  });
}
