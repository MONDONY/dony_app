import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/request_progress_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('progressStepForBid', () {
    expect(progressStepForBid(null), 1);
    expect(progressStepForBid('ACCEPTED'), 1);
    expect(progressStepForBid('HANDED_OVER'), 2);
    expect(progressStepForBid('IN_TRANSIT'), 2);
    expect(progressStepForBid('ARRIVED'), 3);
    expect(progressStepForBid('COMPLETED'), 4);
  });

  testWidgets('étapes nommées', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: Scaffold(body: RequestProgressTimeline(
      travelerName: 'Awa K.', arrivalCity: 'Annemasse', currentStep: 1))));
    expect(find.text('Accord et paiement'), findsOneWidget);
    expect(find.text('Remise du colis à Awa K.'), findsOneWidget);
    expect(find.text('En voyage'), findsOneWidget);
    expect(find.text('Livraison à Annemasse'), findsOneWidget);
  });
}
