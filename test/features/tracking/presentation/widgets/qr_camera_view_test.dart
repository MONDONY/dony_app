import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/services/camera_handoff.dart';
import 'package:dony/features/tracking/presentation/widgets/qr_camera_view.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../helpers/l10n_test_helpers.dart';

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

    test(
      'URL réelle du QR collé sur le colis (…/api/v1/tracking/<id>/scan)',
      () {
        expect(
          extractBidIdFromQr(
            'https://api.yadony.com/api/v1/tracking/$_uuid/scan',
          ),
          _uuid,
        );
      },
    );

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

  group('qrTorchStatusOf', () {
    const idle = MobileScannerState.uninitialized();
    MobileScannerState running(TorchState torch) =>
        idle.copyWith(isInitialized: true, isRunning: true, torchState: torch);

    test('caméra jamais démarrée → à l\'arrêt', () {
      expect(qrTorchStatusOf(idle), QrTorchStatus.stopped);
    });

    test('caméra en marche : état réel de la lampe', () {
      expect(qrTorchStatusOf(running(TorchState.on)), QrTorchStatus.on);
      expect(qrTorchStatusOf(running(TorchState.off)), QrTorchStatus.off);
      expect(qrTorchStatusOf(running(TorchState.auto)), QrTorchStatus.off);
      expect(
        qrTorchStatusOf(running(TorchState.unavailable)),
        QrTorchStatus.unavailable,
      );
    });

    test('caméra arrêtée → à l\'arrêt, avec ou sans lampe', () {
      expect(
        qrTorchStatusOf(running(TorchState.off).copyWith(isRunning: false)),
        QrTorchStatus.stopped,
      );
      expect(
        qrTorchStatusOf(
          running(TorchState.unavailable).copyWith(isRunning: false),
        ),
        QrTorchStatus.stopped,
      );
    });
  });

  group('QrTorchButton', () {
    Future<_FakeTorch> pumpButton(
      WidgetTester tester,
      QrTorchStatus status,
    ) async {
      enableEnglish();
      final torch = _FakeTorch()..value = status;
      addTearDown(torch.dispose);
      await tester.pumpWidget(
        localizedApp(
          Scaffold(
            body: Center(child: QrTorchButton(torch: torch)),
          ),
          locale: AppL10n.en,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      return torch;
    }

    Color background(WidgetTester tester) =>
        ((tester
                    .widget<AnimatedContainer>(
                      find.byKey(const Key('qr-torch-button')),
                    )
                    .decoration
                as BoxDecoration?)
            ?.color) ??
        const Color(0x00000000);

    testWidgets('éteinte : éclair barré, fond translucide, « Allumer »', (
      tester,
    ) async {
      final torch = await pumpButton(tester, QrTorchStatus.off);
      expect(find.byKey(const ValueKey('torch-off')), findsOneWidget);
      expect(find.byKey(const ValueKey('torch-on')), findsNothing);
      expect(find.byTooltip('Turn on the flashlight'), findsOneWidget);
      expect(background(tester), isNot(DonyColors.torchOn));
      expect(
        tester.getSemantics(find.byType(IconButton)),
        isSemantics(
          tooltip: 'Turn on the flashlight',
          isButton: true,
          isEnabled: true,
        ),
      );

      await tester.tap(find.byType(IconButton));
      await tester.pump();
      expect(torch.toggles, 1);
    });

    testWidgets('allumée : fond plein jaune, éclair, « Éteindre »', (
      tester,
    ) async {
      final torch = await pumpButton(tester, QrTorchStatus.on);
      expect(find.byKey(const ValueKey('torch-on')), findsOneWidget);
      expect(find.byKey(const ValueKey('torch-off')), findsNothing);
      expect(find.byTooltip('Turn off the flashlight'), findsOneWidget);
      expect(background(tester), DonyColors.torchOn);
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).isSelected,
        isTrue,
      );
      expect(
        tester.getSemantics(find.byType(IconButton)),
        isSemantics(tooltip: 'Turn off the flashlight', isButton: true),
      );

      await tester.tap(find.byType(IconButton));
      await tester.pump();
      expect(torch.toggles, 1);
    });

    testWidgets('le bouton suit l\'état réel, pas le tap', (tester) async {
      final torch = await pumpButton(tester, QrTorchStatus.off);
      await tester.tap(find.byType(IconButton));
      await tester.pump(const Duration(milliseconds: 300));
      // La caméra n'a encore rien confirmé : toujours éteinte.
      expect(find.byKey(const ValueKey('torch-off')), findsOneWidget);

      torch.value = QrTorchStatus.on;
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('torch-on')), findsOneWidget);
      expect(find.byTooltip('Turn off the flashlight'), findsOneWidget);
    });

    testWidgets('caméra à l\'arrêt : bouton désactivé', (tester) async {
      final torch = await pumpButton(tester, QrTorchStatus.stopped);
      expect(find.byTooltip('Flashlight unavailable'), findsOneWidget);
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNull,
      );
      await tester.tap(find.byType(IconButton), warnIfMissed: false);
      expect(torch.toggles, 0);
    });

    testWidgets('appareil sans lampe : bouton masqué', (tester) async {
      await pumpButton(tester, QrTorchStatus.unavailable);
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('libellés français', (tester) async {
      final torch = _FakeTorch()..value = QrTorchStatus.off;
      addTearDown(torch.dispose);
      await tester.pumpWidget(
        localizedApp(Scaffold(body: QrTorchButton(torch: torch))),
      );
      expect(find.byTooltip('Allumer la lampe'), findsOneWidget);
      torch.value = QrTorchStatus.on;
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byTooltip('Éteindre la lampe'), findsOneWidget);
    });
  });

  test('QrTorch.toggle sans caméra attachée : sans effet', () async {
    final torch = QrTorch()..value = QrTorchStatus.off;
    addTearDown(torch.dispose);
    expect(torch.canToggle, isTrue);
    await torch.toggle();
    expect(torch.value, QrTorchStatus.off);
    torch.value = QrTorchStatus.stopped;
    expect(torch.canToggle, isFalse);
    expect(torch.isOn, isFalse);
  });

  testWidgets('QrCameraView suit la pause et la lampe sans planter', (
    tester,
  ) async {
    final paused = ValueNotifier(true);
    final torch = QrTorch();
    addTearDown(paused.dispose);
    addTearDown(torch.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: QrCameraView(onBidId: (_) {}, paused: paused, torch: torch),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(MobileScanner), findsOneWidget);

    paused.value = false;
    await torch.toggle();
    await tester.pump(const Duration(milliseconds: 600));
    // Pas de vraie caméra en test : la lampe reste à l'arrêt.
    expect(torch.value, QrTorchStatus.stopped);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 600));

    // Nouveaux notifiers : l'écoute suit le widget.
    final paused2 = ValueNotifier(true);
    final torch2 = QrTorch();
    addTearDown(paused2.dispose);
    addTearDown(torch2.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: QrCameraView(onBidId: (_) {}, paused: paused2, torch: torch2),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    // L'ancienne lampe n'est plus pilotée : remise à l'arrêt.
    torch.value = QrTorchStatus.off;
    await torch.toggle();
    expect(torch.value, QrTorchStatus.off);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  group('QrCameraView : lecture des codes', () {
    Future<List<String>> pumpView(
      WidgetTester tester, {
      ValueNotifier<bool>? paused,
    }) async {
      final read = <String>[];
      await tester.pumpWidget(
        localizedApp(
          QrCameraView(onBidId: read.add, paused: paused),
          locale: AppL10n.en,
        ),
      );
      await tester.pump();
      return read;
    }

    void detect(WidgetTester tester, List<Barcode> barcodes) => tester
        .widget<MobileScanner>(find.byType(MobileScanner))
        .onDetect!(BarcodeCapture(barcodes: barcodes));

    double noticeOpacity(WidgetTester tester) => tester
        .widget<AnimatedOpacity>(
          find.ancestor(
            of: find.byKey(const Key('qr-foreign-notice')),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;

    testWidgets('QR Yadony : l\'identifiant du colis remonte', (tester) async {
      enableEnglish();
      final read = await pumpView(tester);
      detect(tester, const [
        Barcode(rawValue: 'https://yadony.com/tracking/$_uuid'),
      ]);
      expect(read, [_uuid]);
      expect(noticeOpacity(tester), 0);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('QR étranger : avis temporaire, une fois par rafale', (
      tester,
    ) async {
      enableEnglish();
      final read = await pumpView(tester);
      detect(tester, const [Barcode(rawValue: 'https://menu.example/carte')]);
      await tester.pump();
      expect(read, isEmpty);
      expect(noticeOpacity(tester), 1);
      expect(find.text("This QR isn't a Yadony parcel code"), findsOneWidget);

      // Même code relu à l'image suivante : pas de nouvel avis.
      detect(tester, const [Barcode(rawValue: 'https://menu.example/carte')]);
      await tester.pump(const Duration(seconds: 2));
      expect(noticeOpacity(tester), 0);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('code sans contenu : ignoré', (tester) async {
      final read = await pumpView(tester);
      detect(tester, const [Barcode()]);
      await tester.pump();
      expect(read, isEmpty);
      expect(noticeOpacity(tester), 0);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('caméra en pause : aucune lecture', (tester) async {
      final paused = ValueNotifier(true);
      addTearDown(paused.dispose);
      final read = await pumpView(tester, paused: paused);
      detect(tester, const [
        Barcode(rawValue: 'https://yadony.com/tracking/$_uuid'),
      ]);
      expect(read, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('caméra indisponible : message d\'aide', (tester) async {
      enableEnglish();
      await pumpView(tester);
      final scanner = tester.widget<MobileScanner>(find.byType(MobileScanner));
      await tester.pumpWidget(
        localizedApp(
          Builder(
            builder: (context) => scanner.errorBuilder!(
              context,
              const MobileScannerException(
                errorCode: MobileScannerErrorCode.permissionDenied,
              ),
            ),
          ),
          locale: AppL10n.en,
        ),
      );
      expect(
        find.text(
          'Camera unavailable. Allow camera access in your phone settings.',
        ),
        findsOneWidget,
      );
    });
  });

  group(
    'QrCameraView : relais avec l\'appareil photo (YADONY-FLUTTER-PROD-V)',
    () {
      testWidgets('s\'inscrit au relais, libère la caméra, se désinscrit', (
        tester,
      ) async {
        final handoff = CameraHandoff(settleDelay: Duration.zero);
        await tester.pumpWidget(
          MaterialApp(
            home: QrCameraView(onBidId: (_) {}, cameraHandoff: handoff),
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));
        expect(handoff.releaserCount, 1);

        // Ouverture de l'appareil photo : le lecteur rend la main et
        // l'ouverture aboutit.
        var opened = false;
        var activeDuringOpen = false;
        unawaited(
          handoff.runWithSystemCamera(() async {
            activeDuringOpen = handoff.systemCameraActive.value;
            opened = true;
          }),
        );
        // Pas de vraie caméra en test : le démarrage reste en suspens, le
        // relais n'attend pas plus que [releaseTimeout].
        await tester.pump(CameraHandoff.defaultReleaseTimeout);
        await tester.pump(const Duration(milliseconds: 100));
        expect(opened, isTrue);
        expect(activeDuringOpen, isTrue);
        expect(handoff.systemCameraActive.value, isFalse);
        // Appareil photo refermé : le lecteur repart sans planter.
        await tester.pump(const Duration(milliseconds: 600));

        await tester.pumpWidget(const SizedBox.shrink());
        expect(handoff.releaserCount, 0);
        await tester.pump(const Duration(seconds: 1));
      });

      testWidgets('nouveau relais : l\'ancien est quitté', (tester) async {
        final first = CameraHandoff(settleDelay: Duration.zero);
        final second = CameraHandoff(settleDelay: Duration.zero);
        await tester.pumpWidget(
          MaterialApp(
            home: QrCameraView(onBidId: (_) {}, cameraHandoff: first),
          ),
        );
        await tester.pump();
        await tester.pumpWidget(
          MaterialApp(
            home: QrCameraView(onBidId: (_) {}, cameraHandoff: second),
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));
        expect(first.releaserCount, 0);
        expect(second.releaserCount, 1);

        await tester.pumpWidget(const SizedBox.shrink());
        expect(second.releaserCount, 0);
        await tester.pump(const Duration(seconds: 1));
      });
    },
  );
}

/// Lampe sans caméra : compte les demandes, l'état réel reste piloté
/// par le test.
class _FakeTorch extends QrTorch {
  int toggles = 0;

  @override
  Future<void> toggle() async => toggles++;
}
