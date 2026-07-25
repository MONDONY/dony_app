import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/suivi_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BidModel _bid() => BidModel(
  id: 'bid-1',
  announcementId: 'a-1',
  senderId: 's-1',
  weightKg: 5,
  status: 'COMPLETED',
  createdAt: DateTime(2026, 5, 1),
  updatedAt: DateTime(2026, 5, 1),
  departureCity: 'Paris',
  arrivalCity: 'Abidjan',
);

void main() {
  testWidgets('affiche le libellé Suivi du colis', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: SuiviButton(bid: _bid())),
      ),
    );
    expect(find.text('Suivi du colis'), findsOneWidget);
  });
}
