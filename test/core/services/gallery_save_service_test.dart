import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/gallery_save_service.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gal/gal.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/mock_analytics_backend.dart';

GalException _gal(GalExceptionType type) => GalException(
  type: type,
  platformException: PlatformException(code: type.code),
  stackTrace: StackTrace.empty,
);

void main() {
  final bytes = Uint8List.fromList([1, 2, 3]);
  late MockAnalyticsBackend backend;
  late AnalyticsService analytics;
  late List<(Uint8List, String)> written;
  late int settingsOpened;

  setUp(() async {
    DonySnackbar.clearDedup();
    backend = MockAnalyticsBackend();
    analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();
    written = [];
    settingsOpened = 0;
  });

  GallerySaveService service({
    bool granted = true,
    Object? requestError,
    Object? writeError,
    Object? settingsError,
  }) {
    return GallerySaveService(
      requestAccess: () async {
        if (requestError != null) throw requestError;
        return granted;
      },
      putImageBytes: (b, name) async {
        if (writeError != null) throw writeError;
        written.add((b, name));
      },
      openSettings: () async {
        settingsOpened++;
        if (settingsError != null) throw settingsError;
      },
      analytics: () => analytics,
    );
  }

  Map<String, Object> failure() =>
      verify(
            () => backend.capture(
              AnalyticsEvents.gallerySaveFailed,
              captureAny(),
            ),
          ).captured.single
          as Map<String, Object>;

  group('save', () {
    test('accès accordé : écrit l’image, aucun échec tracé', () async {
      final outcome = await service().save(
        bytes,
        name: 'a.png',
        context: 'trip_poster',
      );
      expect(outcome, GallerySaveOutcome.saved);
      expect(outcome.isSaved, isTrue);
      expect(written.single.$2, 'a.png');
      verifyNever(
        () => backend.capture(AnalyticsEvents.gallerySaveFailed, any()),
      );
    });

    test('accès refusé (iOS ne redemande plus) : accessDenied, rien '
        'n’est écrit, échec tracé', () async {
      final outcome = await service(
        granted: false,
      ).save(bytes, name: 'a.png', context: 'bid_qr');
      expect(outcome, GallerySaveOutcome.accessDenied);
      expect(written, isEmpty);
      expect(failure(), {
        'context': 'bid_qr',
        'stage': 'request_access',
        'error_code': 'access_denied',
      });
    });

    test('GalException accessDenied à l’écriture : accessDenied', () async {
      final outcome = await service(
        writeError: _gal(GalExceptionType.accessDenied),
      ).save(bytes, name: 'a.png', context: 'trip_poster');
      expect(outcome, GallerySaveOutcome.accessDenied);
      expect(failure(), {
        'context': 'trip_poster',
        'stage': 'write',
        'error_code': 'access_denied',
      });
    });

    test('stockage plein : notEnoughSpace', () async {
      final outcome = await service(
        writeError: _gal(GalExceptionType.notEnoughSpace),
      ).save(bytes, name: 'a.png', context: 'package_request_poster');
      expect(outcome, GallerySaveOutcome.notEnoughSpace);
      expect(failure()['error_code'], 'not_enough_space');
    });

    test('format refusé et erreur inattendue : failed', () async {
      expect(
        await service(
          writeError: _gal(GalExceptionType.notSupportedFormat),
        ).save(bytes, name: 'a.png', context: 'trip_poster'),
        GallerySaveOutcome.failed,
      );
      expect(failure()['error_code'], 'not_supported_format');
      expect(
        await service(
          requestError: _gal(GalExceptionType.unexpected),
        ).save(bytes, name: 'a.png', context: 'trip_poster'),
        GallerySaveOutcome.failed,
      );
      expect(failure(), {
        'context': 'trip_poster',
        'stage': 'request_access',
        'error_code': 'unexpected',
      });
    });

    test('exception étrangère au plugin : failed, code unknown', () async {
      final outcome = await service(
        writeError: StateError('boom'),
      ).save(bytes, name: 'a.png', context: 'trip_poster');
      expect(outcome, GallerySaveOutcome.failed);
      expect(failure()['error_code'], 'unknown');
    });

    test('sans analytics enregistré : ne lève pas', () async {
      const plain = GallerySaveService(requestAccess: _denied);
      expect(
        await plain.save(bytes, name: 'a.png', context: 'trip_poster'),
        GallerySaveOutcome.accessDenied,
      );
    });
  });

  test('resolve sans GetIt : instance par défaut', () {
    expect(GallerySaveService.resolve(), isA<GallerySaveService>());
  });

  group('notifyFailure', () {
    Future<BuildContext> host(WidgetTester tester, Locale locale) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (c) {
                ctx = c;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      return ctx;
    }

    testWidgets('accès refusé : message dédié et « Ouvrir les Réglages »', (
      tester,
    ) async {
      final s = service();
      final ctx = await host(tester, const Locale('fr'));
      s.notifyFailure(
        ctx,
        GallerySaveOutcome.accessDenied,
        fallback: 'Générique',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.text(
          'Autorisez Yadony à ajouter des photos dans Réglages, '
          'puis réessayez.',
        ),
        findsOneWidget,
      );
      expect(find.text('Générique'), findsNothing);
      await tester.tap(find.text('Ouvrir les Réglages'));
      await tester.pump();
      expect(settingsOpened, 1);
      await tester.pumpAndSettle(const Duration(seconds: 7));
    });

    testWidgets('anglais', (tester) async {
      final s = service();
      final ctx = await host(tester, const Locale('en'));
      s.notifyFailure(
        ctx,
        GallerySaveOutcome.accessDenied,
        fallback: 'Generic',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.text('Allow Yadony to add photos in Settings, then try again.'),
        findsOneWidget,
      );
      expect(find.text('Open Settings'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 7));
    });

    testWidgets('stockage plein, erreur générique, succès', (tester) async {
      final s = service();
      final ctx = await host(tester, const Locale('fr'));
      s.notifyFailure(
        ctx,
        GallerySaveOutcome.notEnoughSpace,
        fallback: 'Générique',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.text(
          "Espace insuffisant sur le téléphone pour enregistrer l'image.",
        ),
        findsOneWidget,
      );
      await tester.pumpAndSettle(const Duration(seconds: 7));

      s.notifyFailure(ctx, GallerySaveOutcome.failed, fallback: 'Générique');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Générique'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 7));

      s.notifyFailure(ctx, GallerySaveOutcome.saved, fallback: 'Générique');
      await tester.pump();
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  test('openSettings : une erreur du plugin est avalée', () async {
    final s = service(settingsError: StateError('no settings'));
    await s.openSettings();
    expect(settingsOpened, 1);
  });
}

Future<bool> _denied() async => false;
