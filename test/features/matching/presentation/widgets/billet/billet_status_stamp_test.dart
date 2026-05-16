import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/presentation/widgets/billet/billet_status_stamp.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, String status) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: Center(child: BilletStatusStamp(status: status))),
  ));
}

void main() {
  testWidgets('ACCEPTED → libellé "Confirmé"', (tester) async {
    await _pump(tester, 'ACCEPTED');
    expect(find.text('Confirmé'), findsOneWidget);
  });

  testWidgets('HANDED_OVER → libellé "En route"', (tester) async {
    await _pump(tester, 'HANDED_OVER');
    expect(find.text('En route'), findsOneWidget);
  });

  testWidgets('COMPLETED → libellé "Livré"', (tester) async {
    await _pump(tester, 'COMPLETED');
    expect(find.text('Livré'), findsOneWidget);
  });

  testWidgets('PENDING → libellé "En attente"', (tester) async {
    await _pump(tester, 'PENDING');
    expect(find.text('En attente'), findsOneWidget);
  });

  testWidgets('statut inconnu → libellé brut', (tester) async {
    await _pump(tester, 'WEIRD');
    expect(find.text('WEIRD'), findsOneWidget);
  });
}
