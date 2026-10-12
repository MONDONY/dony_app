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
}
