import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/quick_actions_row.dart';
import 'package:dony/features/matching/presentation/widgets/billet/talon_tracking_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(
        body: TalonTrackingStrip(trackingNumber: 'DON-3TSTR9VH'),
      ),
    ),
  );
}

void main() {
  testWidgets('affiche le numéro de suivi', (tester) async {
    await _pump(tester);
    expect(find.text('DON-3TSTR9VH'), findsOneWidget);
  });

  testWidgets('le bouton Copier place le numéro dans le presse-papier', (
    tester,
  ) async {
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

  testWidgets('le bouton Partager est présent', (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('talon-share-button')), findsOneWidget);
  });

  group('partage', () {
    late List<Map<Object?, Object?>> shares;

    setUp(() {
      shares = [];
      const channel = MethodChannel('dev.fluttercommunity.plus/share');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            shares.add(call.arguments as Map<Object?, Object?>);
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
    });

    testWidgets('avec un jeton, le texte partagé porte le lien de suivi', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: TalonTrackingStrip(
              trackingNumber: 'DON-3TSTR9VH',
              trackingToken: 'tok-talon',
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('talon-share-button')));
      await tester.pump();

      expect(shares, hasLength(1));
      final text = shares.single['text'] as String;
      expect(text, contains('DON-3TSTR9VH'));
      expect(text, contains(trackingPublicUrl('tok-talon')));
    });

    testWidgets('sans jeton, le numéro seul est partagé', (tester) async {
      await _pump(tester);

      await tester.tap(find.byKey(const Key('talon-share-button')));
      await tester.pump();

      expect(shares, hasLength(1));
      expect(shares.single['text'], 'Suivez mon colis Yadony #DON-3TSTR9VH');
    });
  });
}
