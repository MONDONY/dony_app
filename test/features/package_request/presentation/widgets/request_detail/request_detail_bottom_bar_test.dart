import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/presentation/request_screen_case.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/request_detail_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('primaryButtonFor', () {
    expect(primaryButtonFor(RequestPrimaryAction.publish).label, 'Publier');
    expect(primaryButtonFor(RequestPrimaryAction.share).icon, 'share-2');
    expect(primaryButtonFor(RequestPrimaryAction.pay, amount: '28,00 €').label, 'Payer 28,00 €');
    final wait = primaryButtonFor(RequestPrimaryAction.waitTrip, travelerName: 'Awa K.');
    expect(wait.label, 'Awa K. ajoute son trajet');
    expect(wait.enabled, isFalse);
    expect(primaryButtonFor(RequestPrimaryAction.rate, travelerName: 'Awa K.').label, 'Noter Awa K.');
    expect(primaryButtonFor(RequestPrimaryAction.republish).label, 'Republier avec de nouvelles dates');
    expect(primaryButtonFor(RequestPrimaryAction.publishSimilar).label, 'Publier une demande similaire');
    expect(primaryButtonFor(RequestPrimaryAction.trackParcel).label, 'Suivre mon colis');
    expect(primaryButtonFor(RequestPrimaryAction.openThread).label, 'Ouvrir la discussion');
    for (final a in RequestPrimaryAction.values) {
      expect(primaryButtonFor(a, travelerName: 'A', amount: '1 €').label.contains('—'), isFalse);
    }
  });

  testWidgets('Modifier + principal ; taps', (tester) async {
    var primary = 0, edit = 0;
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: Scaffold(bottomNavigationBar: RequestDetailBottomBar(
      actions: const RequestScreenActions(primary: RequestPrimaryAction.share, showEdit: true),
      busy: false, onPrimary: () => primary++, onEdit: () => edit++))));
    await tester.tap(find.text('Partager'));
    await tester.tap(find.text('Modifier'));
    expect((primary, edit), (1, 1));
  });

  testWidgets('Message affiché quand demandé ; occupé = boutons désactivés', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: Scaffold(bottomNavigationBar: RequestDetailBottomBar(
      actions: const RequestScreenActions(primary: RequestPrimaryAction.trackParcel, showMessage: true),
      busy: true, onPrimary: () {}, onMessage: () {}))));
    expect(find.text('Message'), findsOneWidget);
    for (final button in tester.widgetList<DonyButton>(find.byType(DonyButton))) {
      expect(button.onPressed, isNull);
    }
  });

  testWidgets('attente du trajet : principal désactivé même hors chargement', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: Scaffold(bottomNavigationBar: RequestDetailBottomBar(
      actions: const RequestScreenActions(primary: RequestPrimaryAction.waitTrip),
      busy: false, travelerName: 'Awa K.', onPrimary: () {}))));
    expect(find.text('Awa K. ajoute son trajet'), findsOneWidget);
    expect(tester.widget<DonyButton>(find.byType(DonyButton)).onPressed, isNull);
  });
}
