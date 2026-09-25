import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/utils/phone_dialer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/l10n_test_helpers.dart';

void _mockUrlLauncher({required bool canLaunch}) {
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'canLaunch') return canLaunch;
        if (call.method == 'launch') return canLaunch;
        return null;
      });
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
}

Future<void> _pump(WidgetTester tester, String? phone) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => dialPhoneNumber(context, phone),
            child: const Text('Appeler'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Appeler'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('fr : aucun numéro -> message dédié', (tester) async {
    await _pump(tester, null);
    expect(
      find.text('Aucun numéro disponible pour ce contact'),
      findsOneWidget,
    );
  });

  testWidgets('en : aucun numéro -> message traduit', (tester) async {
    useEnglish();
    await _pump(tester, null);
    expect(find.text('No number available for this contact'), findsOneWidget);
  });

  testWidgets('fr : pas de composeur -> numéro affiché avec repli copie', (
    tester,
  ) async {
    _mockUrlLauncher(canLaunch: false);
    await _pump(tester, '+33600000000');
    expect(
      find.text('Aucune application téléphone. Numéro : +33600000000'),
      findsOneWidget,
    );
    expect(find.text('Copier'), findsOneWidget);
  });

  testWidgets('en : pas de composeur -> numéro affiché avec repli copie', (
    tester,
  ) async {
    useEnglish();
    _mockUrlLauncher(canLaunch: false);
    await _pump(tester, '+33600000000');
    expect(find.text('No phone app. Number: +33600000000'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
  });
}
