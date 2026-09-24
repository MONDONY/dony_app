import 'package:dony/features/tracking/presentation/screens/qr_picker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/l10n_test_helpers.dart';

Widget _wrap() => const MaterialApp(home: QrPickerScreen());

void main() {
  testWidgets('affiche le titre et le texte d\'aide en français', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pump();

    expect(find.text('Lire le QR code'), findsOneWidget);
    expect(find.text('Pointez vers le QR code du colis'), findsOneWidget);

    // Laisse le temps aux timers internes de se terminer avant la fin du
    // test (comme qr_scanner_screen_test.dart).
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('anglais — titre et texte d\'aide traduits', (tester) async {
    useEnglish();
    await tester.pumpWidget(_wrap());
    await tester.pump();

    expect(find.text('Scan the QR code'), findsOneWidget);
    expect(find.text('Point at the parcel\'s QR code'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
  });
}
