import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/qr_sheet.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/models/qr_code_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

// ── Mock ──────────────────────────────────────────────────────────────────────

class _MockTrackingBloc extends MockBloc<TrackingEvent, TrackingState>
    implements TrackingBloc {}

// ── Fake PathProvider (replaces FFI-based path_provider_foundation) ───────────

class _FakePathProvider extends PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async => '/tmp';
}

// ── Tiny PNG fixture (1×1 px) ─────────────────────────────────────────────────

const _tinyPngB64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

// ── Host widget ───────────────────────────────────────────────────────────────

Widget _host(_MockTrackingBloc bloc) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: Builder(
        builder: (ctx) => TextButton(
          onPressed: () {
            QrSheet.show(
              ctx,
              bidId: 'bid-1',
              status: 'ACCEPTED',
              trackingBlocFactory: () => bloc,
            );
          },
          child: const Text('Open'),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(TrackingQrCodeRequested('bid-1'));
  });

  // ── Test 1: Loading state → spinner ──────────────────────────────────────────

  testWidgets('état TrackingQrLoading → spinner visible dans le sheet', (
    tester,
  ) async {
    final bloc = _MockTrackingBloc();
    whenListen<TrackingState>(
      bloc,
      Stream<TrackingState>.fromIterable([TrackingQrLoading()]),
      initialState: TrackingQrLoading(),
    );

    await tester.pumpWidget(_host(bloc));
    await tester.tap(find.text('Open'));
    // Use pump with timeout instead of pumpAndSettle because CircularProgressIndicator
    // is animated and would cause pumpAndSettle to loop indefinitely.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  // ── Test 2: Loaded state → Image, texte, boutons ─────────────────────────────

  testWidgets(
    'état TrackingQrLoaded → Image + texte imprimer + boutons Enregistrer et Partager',
    (tester) async {
      final bloc = _MockTrackingBloc();
      const qr = QrCodeModel(
        bidId: 'bid-1',
        scanUrl: 'https://dony.app/track/bid-1',
        qrCodeBase64: _tinyPngB64,
      );
      whenListen<TrackingState>(
        bloc,
        Stream<TrackingState>.fromIterable([TrackingQrLoaded(qr)]),
        initialState: TrackingQrLoaded(qr),
      );

      await tester.pumpWidget(_host(bloc));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);
      expect(find.textContaining('imprimer'), findsOneWidget);
      expect(find.text('Enregistrer'), findsOneWidget);
      expect(find.text('Partager'), findsOneWidget);
    },
  );

  // ── Test 3: Error state → Réessayer + re-dispatch ────────────────────────────

  testWidgets(
    'état TrackingQrError → bouton Réessayer visible, tap re-dispatch TrackingQrCodeRequested',
    (tester) async {
      final bloc = _MockTrackingBloc();
      const error = NetworkException('Erreur réseau', code: 'NETWORK_ERROR');
      whenListen<TrackingState>(
        bloc,
        Stream<TrackingState>.fromIterable([TrackingQrError(error)]),
        initialState: TrackingQrError(error),
      );

      await tester.pumpWidget(_host(bloc));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Réessayer'), findsOneWidget);

      await tester.tap(find.text('Réessayer'));
      await tester.pump();

      // The initial add (from BlocProvider create) + retry tap = 2 calls
      verify(
        () => bloc.add(any(that: isA<TrackingQrCodeRequested>())),
      ).called(2);
    },
  );

  // ── Test 4: No use-after-dispose when sheet is dismissed during handler ───────

  testWidgets(
    'fermeture du sheet pendant le handler Partager → aucune exception use-after-dispose',
    (tester) async {
      final bloc = _MockTrackingBloc();
      const qr = QrCodeModel(
        bidId: 'bid-1',
        scanUrl: 'https://dony.app/track/bid-1',
        qrCodeBase64: _tinyPngB64,
      );
      whenListen<TrackingState>(
        bloc,
        Stream<TrackingState>.fromIterable([TrackingQrLoaded(qr)]),
        initialState: TrackingQrLoaded(qr),
      );

      await tester.pumpWidget(_host(bloc));
      await tester.tap(find.text('Open'));
      // Use bounded pumps to avoid infinite animation loops (CircularProgressIndicator).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Tap 'Partager' — the handler awaits Share.shareXFiles which throws
      // MissingPluginException in the test environment. The catch block runs,
      // then the finally tries to write sharing.value. If not guarded this
      // would hit the disposed notifier.
      await tester.tap(find.text('Partager'));
      await tester.pump();

      // Dismiss the sheet before the handler's finally runs. Tapping the
      // barrier (outside the bottom sheet) closes it.
      await tester.tapAt(const Offset(200, 100));
      // Pump through the close animation with bounded duration.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // No FlutterError / use-after-dispose exception must surface.
      expect(tester.takeException(), isNull);
    },
  );

  // ── Test 5: Initial/unknown state → fallback spinner ─────────────────────────

  testWidgets('état TrackingInitial → fallback spinner visible', (tester) async {
    final bloc = _MockTrackingBloc();
    whenListen<TrackingState>(
      bloc,
      Stream<TrackingState>.fromIterable([TrackingInitial()]),
      initialState: TrackingInitial(),
    );

    await tester.pumpWidget(_host(bloc));
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  // ── Test 6: tap 'Enregistrer' → Gal success → snackbar ───────────────────────

  testWidgets(
    'état TrackingQrLoaded → tap "Enregistrer" → Gal succès → snackbar galerie',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

      // Gal calls requestAccess then putImageBytes — mock both
      const galChannel = MethodChannel('gal');
      messenger.setMockMethodCallHandler(galChannel, (call) async {
        if (call.method == 'requestAccess') return true;
        if (call.method == 'putImageBytes') return null;
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(galChannel, null));

      final bloc = _MockTrackingBloc();
      const qr = QrCodeModel(
        bidId: 'bid-1',
        scanUrl: 'https://dony.app/track/bid-1',
        qrCodeBase64: _tinyPngB64,
      );
      whenListen<TrackingState>(
        bloc,
        Stream<TrackingState>.fromIterable([TrackingQrLoaded(qr)]),
        initialState: TrackingQrLoaded(qr),
      );

      await tester.pumpWidget(_host(bloc));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('enregistré dans votre galerie'),
        findsOneWidget,
      );
    },
  );

  // ── Test 7: tap 'Enregistrer' → Gal failure → snackbar erreur ────────────────

  testWidgets(
    'état TrackingQrLoaded → tap "Enregistrer" → Gal erreur → snackbar erreur',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

      const galChannel = MethodChannel('gal');
      messenger.setMockMethodCallHandler(galChannel, (call) async {
        if (call.method == 'requestAccess') return false;
        if (call.method == 'putImageBytes') {
          throw PlatformException(
            code: 'ACCESS_DENIED',
            message: 'No permission',
          );
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(galChannel, null));

      final bloc = _MockTrackingBloc();
      const qr = QrCodeModel(
        bidId: 'bid-1',
        scanUrl: 'https://dony.app/track/bid-1',
        qrCodeBase64: _tinyPngB64,
      );
      whenListen<TrackingState>(
        bloc,
        Stream<TrackingState>.fromIterable([TrackingQrLoaded(qr)]),
        initialState: TrackingQrLoaded(qr),
      );

      await tester.pumpWidget(_host(bloc));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(find.textContaining("Impossible d'enregistrer"), findsOneWidget);
    },
  );

  // ── Test 8: tap 'Partager' → share status dismissed → aucune erreur ──────────

  testWidgets(
    'état TrackingQrLoaded → tap "Partager" → share dismissed → aucune erreur',
    (tester) async {
      // Replace the FFI-based path provider with a fake that returns /tmp
      final originalPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _FakePathProvider();
      addTearDown(() => PathProviderPlatform.instance = originalPathProvider);

      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

      // Mock share_plus — '' = dismissed
      const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
      messenger.setMockMethodCallHandler(shareChannel, (call) async {
        if (call.method == 'shareFiles') return '';
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(shareChannel, null));

      final bloc = _MockTrackingBloc();
      const qr = QrCodeModel(
        bidId: 'bid-1',
        scanUrl: 'https://dony.app/track/bid-1',
        qrCodeBase64: _tinyPngB64,
      );
      whenListen<TrackingState>(
        bloc,
        Stream<TrackingState>.fromIterable([TrackingQrLoaded(qr)]),
        initialState: TrackingQrLoaded(qr),
      );

      await tester.pumpWidget(_host(bloc));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Open the sheet and wait for it to render
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // runAsync drives the complete async chain (file write + channel mock)
      // in real time, then pump drives widget rebuilds.
      await tester.runAsync(() async {
        await tester.tap(find.text('Partager'));
        // Wait for the async handler to fully complete
        await Future<void>.delayed(const Duration(seconds: 1));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // dismissed path: no error snackbar
      expect(
        find.textContaining('Impossible de partager'),
        findsNothing,
      );
    },
  );

  // ── Test 9: tap 'Partager' → share success → analytics branch ────────────────

  testWidgets(
    'état TrackingQrLoaded → tap "Partager" → share success → pas de snackbar erreur',
    (tester) async {
      final originalPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _FakePathProvider();
      addTearDown(() => PathProviderPlatform.instance = originalPathProvider);

      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

      // Return a non-empty/non-unavailable string → ShareResultStatus.success
      const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
      messenger.setMockMethodCallHandler(shareChannel, (call) async {
        if (call.method == 'shareFiles') return 'com.some.app';
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(shareChannel, null));

      final bloc = _MockTrackingBloc();
      const qr = QrCodeModel(
        bidId: 'bid-1',
        scanUrl: 'https://dony.app/track/bid-1',
        qrCodeBase64: _tinyPngB64,
      );
      whenListen<TrackingState>(
        bloc,
        Stream<TrackingState>.fromIterable([TrackingQrLoaded(qr)]),
        initialState: TrackingQrLoaded(qr),
      );

      await tester.pumpWidget(_host(bloc));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.runAsync(() async {
        await tester.tap(find.text('Partager'));
        await Future<void>.delayed(const Duration(seconds: 1));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // success path: no error snackbar
      expect(
        find.textContaining('Impossible de partager'),
        findsNothing,
      );
    },
  );

  // ── Test 10: sheet dismissed → whenComplete disposes notifiers ────────────────

  testWidgets(
    'fermeture du sheet → whenComplete dispose les ValueNotifiers sans erreur',
    (tester) async {
      final bloc = _MockTrackingBloc();
      const qr = QrCodeModel(
        bidId: 'bid-1',
        scanUrl: 'https://dony.app/track/bid-1',
        qrCodeBase64: _tinyPngB64,
      );
      whenListen<TrackingState>(
        bloc,
        Stream<TrackingState>.fromIterable([TrackingQrLoaded(qr)]),
        initialState: TrackingQrLoaded(qr),
      );

      await tester.pumpWidget(_host(bloc));
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Dismiss the sheet by tapping the barrier
      await tester.tapAt(const Offset(200, 100));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // whenComplete ran: no use-after-dispose exception
      expect(tester.takeException(), isNull);
    },
  );
}
