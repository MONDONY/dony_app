import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/tracking/presentation/widgets/tracking_consent_sheet.dart';
import 'package:dony/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/l10n_test_helpers.dart';

void main() {
  bool? result;

  Future<void> open(WidgetTester tester) async {
    result = null;
    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  result = await TrackingConsentSheet.show(context),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('sheetButtonsAreInStickyBottom', (tester) async {
    await open(tester);
    final accept = find.byKey(const Key('tracking-consent-accept'));
    final decline = find.byKey(const Key('tracking-consent-decline'));
    expect(accept, findsOneWidget);
    expect(decline, findsOneWidget);
    // Aucun DonyButton dans la zone défilante.
    final scrollable = find.byType(SingleChildScrollView);
    expect(
      find.descendant(of: scrollable, matching: find.byType(DonyButton)),
      findsNothing,
    );
  });

  testWidgets('texte clair, sans tiret cadratin', (tester) async {
    await open(tester);
    final l = await AppLocalizations.delegate.load(const Locale('fr'));
    expect(find.text(l.trackingConsentTitle), findsOneWidget);
    expect(find.text(l.trackingConsentPointApproximate), findsOneWidget);
    expect(l.trackingConsentPointApproximate, isNot(contains('—')));
  });

  testWidgets('Autoriser rend vrai', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('tracking-consent-accept')));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('Pas maintenant rend faux', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('tracking-consent-decline')));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('fermer par geste rend nul', (tester) async {
    await open(tester);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
