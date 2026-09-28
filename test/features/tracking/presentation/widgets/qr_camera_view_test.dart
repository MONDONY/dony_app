import 'package:dony/features/tracking/presentation/widgets/qr_camera_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

const _uuid = '3f2b6c1e-8a4d-4f6b-9c2e-1d7a5b3c9e0f';

void main() {
  group('extractBidIdFromQr', () {
    test('URL de suivi Yadony → identifiant du colis', () {
      expect(extractBidIdFromQr('https://yadony.com/tracking/$_uuid'), _uuid);
      expect(
        extractBidIdFromQr('  https://yadony.com/fr/tracking/$_uuid?c=qr '),
        _uuid,
      );
    });

    test('majuscules acceptées', () {
      final upper = _uuid.toUpperCase();
      expect(extractBidIdFromQr('https://yadony.com/tracking/$upper'), upper);
    });

    test('tout autre contenu → null', () {
      expect(extractBidIdFromQr('https://yadony.com/tracking/'), isNull);
      expect(
        extractBidIdFromQr('https://yadony.com/tracking/pas-un-id'),
        isNull,
      );
      expect(extractBidIdFromQr('https://menu.example/carte'), isNull);
      expect(extractBidIdFromQr('DON-ABC123'), isNull);
      expect(extractBidIdFromQr('http://[::1'), isNull);
    });
  });

  test('bidIdFromCapture prend le premier QR Yadony de la capture', () {
    expect(
      bidIdFromCapture(
        const BarcodeCapture(
          barcodes: [
            Barcode(),
            Barcode(rawValue: 'https://menu.example/carte'),
            Barcode(rawValue: 'https://yadony.com/tracking/$_uuid'),
          ],
        ),
      ),
      _uuid,
    );
    expect(
      bidIdFromCapture(
        const BarcodeCapture(barcodes: [Barcode(rawValue: 'bonjour')]),
      ),
      isNull,
    );
  });

  testWidgets('QrScanFrame : pastille de réussite seulement si détecté', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: QrScanFrame())),
    );
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.byType(Container), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: QrScanFrame(detected: true, size: 180)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.getSize(find.byType(QrScanFrame)), const Size(180, 180));
    expect(find.byType(Container), findsOneWidget);
  });

  testWidgets('QrTorchButton bascule la lampe', (tester) async {
    final torch = ValueNotifier(false);
    addTearDown(torch.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: QrTorchButton(torchOn: torch)),
      ),
    );
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(torch.value, isTrue);
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(torch.value, isFalse);
  });

  testWidgets('QrCameraView suit la pause et la lampe sans planter', (
    tester,
  ) async {
    final paused = ValueNotifier(true);
    final torch = ValueNotifier(false);
    addTearDown(paused.dispose);
    addTearDown(torch.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: QrCameraView(onBidId: (_) {}, paused: paused, torchOn: torch),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(MobileScanner), findsOneWidget);

    paused.value = false;
    torch.value = true;
    await tester.pump(const Duration(milliseconds: 600));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 600));

    // Nouveaux notifiers : l'écoute suit le widget.
    final paused2 = ValueNotifier(true);
    final torch2 = ValueNotifier(false);
    addTearDown(paused2.dispose);
    addTearDown(torch2.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: QrCameraView(onBidId: (_) {}, paused: paused2, torchOn: torch2),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
}
