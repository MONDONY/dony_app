import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/presentation/widgets/billet/talon_tracking_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    home: const Scaffold(
        body: TalonTrackingStrip(trackingNumber: 'DON-3TSTR9VH')),
  ));
}

void main() {
  testWidgets('affiche le numéro de suivi', (tester) async {
    await _pump(tester);
    expect(find.text('DON-3TSTR9VH'), findsOneWidget);
  });

  testWidgets('le bouton Copier place le numéro dans le presse-papier',
      (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    await _pump(tester);
    await tester.tap(find.byKey(const Key('talon-copy-button')));
    await tester.pump();
    expect(copied, 'DON-3TSTR9VH');
  });
}
