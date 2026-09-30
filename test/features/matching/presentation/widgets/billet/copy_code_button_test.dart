import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/presentation/widgets/billet/copy_code_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// FLUTTER-4P : la copie du code de retrait ne se voyait pas (snackbar caché
// par la feuille). Le bouton confirme désormais sur place.
void main() {
  late List<MethodCall> clipboardCalls;

  setUp(() {
    clipboardCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method.startsWith('Clipboard')) clipboardCalls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Widget host() => MaterialApp(
    theme: AppTheme.light(),
    home: const Scaffold(
      body: CopyCodeButton(
        code: '482913',
        label: 'Copier le code',
        copiedLabel: 'Code copié',
      ),
    ),
  );

  testWidgets('tap : copie le code et affiche « Code copié » sur le bouton', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    expect(find.text('Copier le code'), findsOneWidget);

    await tester.tap(find.byKey(const Key('copy-code-button')));
    await tester.pumpAndSettle();

    final setData = clipboardCalls.firstWhere(
      (c) => c.method == 'Clipboard.setData',
    );
    expect((setData.arguments as Map)['text'], '482913');
    expect(find.text('Code copié'), findsOneWidget);
    expect(find.text('Copier le code'), findsNothing);
  });

  testWidgets('le libellé revient à « Copier le code » après 2 s', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.tap(find.byKey(const Key('copy-code-button')));
    await tester.pumpAndSettle();
    expect(find.text('Code copié'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Copier le code'), findsOneWidget);
    expect(find.text('Code copié'), findsNothing);
  });
}
