import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/payments/money/data/models/money_overview_model.dart';
import 'package:dony/features/payments/money/presentation/widgets/money_parcel_line.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'money_fixtures.dart';

/// FLUTTER-P3 : un colis payé en mobile money ne se distinguait pas d'un
/// paiement par carte dans « Mon argent ».
void main() {
  Future<void> pump(WidgetTester tester, MoneyItemModel item) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: AppL10n.fr,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MoneyParcelLine(item: item, onTap: () {}),
          ),
        ),
      );

  testWidgets('colis payé en mobile money : canal mentionné', (tester) async {
    await pump(tester, item(channel: MoneyChannel.mobileMoney));
    expect(find.textContaining('Mobile Money'), findsOneWidget);
  });

  testWidgets('colis payé par carte : aucune mention de canal', (tester) async {
    await pump(tester, item());
    expect(find.textContaining('Mobile Money'), findsNothing);
  });

  // Le voyageur ne voit le numéro de suivi qu'à partir de la remise, comme
  // sur la fiche du colis : « Mon argent » ne le lui montre pas avant.
  group('numéro de suivi voyageur', () {
    const beforeHandover = ['PENDING', 'ACCEPTED', 'REJECTED', 'CANCELLED'];
    const fromHandover = [
      'HANDED_OVER',
      'IN_TRANSIT',
      'ARRIVED',
      'COMPLETED',
      'DELIVERED',
    ];

    for (final status in beforeHandover) {
      testWidgets('voyageur · $status : numéro masqué', (tester) async {
        await pump(
          tester,
          item(trackingNumber: 'DON-HIDDEN01', bidStatus: status),
        );
        expect(find.textContaining('DON-HIDDEN01'), findsNothing);
        // La ligne reste lisible : le trajet vient des détails.
        expect(find.byType(MoneyParcelLine), findsOneWidget);
      });
    }

    for (final status in fromHandover) {
      testWidgets('voyageur · $status : numéro affiché', (tester) async {
        await pump(
          tester,
          item(trackingNumber: 'DON-SHOWN001', bidStatus: status),
        );
        expect(find.textContaining('DON-SHOWN001'), findsOneWidget);
      });
    }

    testWidgets('voyageur · statut inconnu (ancien back) : numéro conservé', (
      tester,
    ) async {
      await pump(tester, item(trackingNumber: 'DON-NOSTATUS'));
      expect(find.textContaining('DON-NOSTATUS'), findsOneWidget);
    });

    testWidgets('expéditeur · ACCEPTED : numéro affiché', (tester) async {
      await pump(
        tester,
        item(
          trackingNumber: 'DON-SENDER001',
          bidStatus: 'ACCEPTED',
          role: MoneyRole.sender,
        ),
      );
      expect(find.textContaining('DON-SENDER001'), findsOneWidget);
    });
  });
}
