import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/presentation/widgets/billet/billet_status_stamp.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// [isSender] par défaut à `false` (voyageur) : seuls les tests dédiés au
/// libellé AWAITING_PAYMENT selon le rôle le font varier, les autres statuts
/// étant identiques pour les deux rôles.
Future<void> _pump(
  WidgetTester tester,
  String status, {
  bool isSender = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Center(
          child: BilletStatusStamp(status: status, isSender: isSender),
        ),
      ),
    ),
  );
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

  testWidgets('NO_SHOW → libellé "Absent"', (tester) async {
    await _pump(tester, 'NO_SHOW');
    expect(find.text('Absent'), findsOneWidget);
  });

  testWidgets('PARCEL_REFUSED → libellé "Colis refusé"', (tester) async {
    await _pump(tester, 'PARCEL_REFUSED');
    expect(find.text('Colis refusé'), findsOneWidget);
  });

  testWidgets('EXPIRED → libellé "Expiré"', (tester) async {
    await _pump(tester, 'EXPIRED');
    expect(find.text('Expiré'), findsOneWidget);
  });

  testWidgets('statut inconnu → libellé brut', (tester) async {
    await _pump(tester, 'WEIRD');
    expect(find.text('WEIRD'), findsOneWidget);
  });

  // Régression staging : AWAITING_PAYMENT affichait « À payer » à tout le
  // monde, y compris au voyageur pour qui ce texte n'a pas de sens (c'est
  // l'expéditeur qui doit payer). Le rôle est le paramètre existant de
  // ColisBillet, pas un nouveau getIt.
  group('AWAITING_PAYMENT — libellé selon le rôle', () {
    testWidgets('expéditeur → libellé "À payer" (inchangé)', (tester) async {
      await _pump(tester, 'AWAITING_PAYMENT', isSender: true);
      expect(find.text('À payer'), findsOneWidget);
    });

    testWidgets('voyageur → libellé "Paiement en attente", jamais "À payer"', (
      tester,
    ) async {
      await _pump(tester, 'AWAITING_PAYMENT');
      expect(find.text('Paiement en attente'), findsOneWidget);
      expect(find.text('À payer'), findsNothing);
    });
  });
}
