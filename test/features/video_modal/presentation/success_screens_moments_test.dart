import 'package:dony/features/package_request/presentation/screens/sender/negotiation_paid_success_screen.dart';
import 'package:dony/features/package_request/presentation/screens/traveler/negotiation_commission_settled_screen.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../moment_test_support.dart';
import 'video_modal_widget_harness.dart';

/// Écrans de succès de paiement : chacun émet « paiement réussi » en
/// s'affichant, sans changer l'écran.
void main() {
  Future<void> show(WidgetTester tester, Widget screen) async {
    usePhone360(tester);
    await tester.pumpWidget(appWith(home: screen));
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('paiement d\'une négociation par l\'expéditeur', (tester) async {
    final moments = useRecordingMoments();
    await show(tester, const NegotiationPaidSuccessScreen(threadId: 't1'));
    expect(moments.triggers, [VideoModalTrigger.paymentSucceeded]);
    expect(moments.origins.single, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('commission réglée par le voyageur', (tester) async {
    final moments = useRecordingMoments();
    await show(
      tester,
      const NegotiationCommissionSettledScreen(threadId: 't1'),
    );
    expect(moments.triggers, [VideoModalTrigger.paymentSucceeded]);
    expect(tester.takeException(), isNull);
  });
}
