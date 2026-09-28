import 'dart:io';

import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/media_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/tracking/data/models/scan_method.dart';
import 'package:dony/features/tracking/data/scan_locator.dart';
import 'package:dony/features/tracking/presentation/screens/scan_photo_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/l10n_test_helpers.dart';

/// Extras reçus par la confirmation au dernier passage.
Map<String, dynamic>? _confirmExtra;

GoRouter _router(String etape, {ScanMethod? scanMethod}) => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => ScanPhotoScreen(
        bidId: 'test-bid-id',
        etape: etape,
        packageLabel: 'DON-TEST01',
        scanMethod: scanMethod,
      ),
    ),
    GoRoute(
      path: '/tracking/scan/confirm',
      builder: (_, state) {
        _confirmExtra = state.extra as Map<String, dynamic>?;
        return const Scaffold(body: Text('confirm'));
      },
    ),
  ],
);

class _MockMedia extends Mock implements DonyMediaService {}

class _MockLocator extends Mock implements ScanLocator {}

const _here = ScanPosition(lat: 14.7, lon: -17.4, label: 'Dakar');

/// Onglet Suivi : l'écran photo rend sa photo à l'appelant.
GoRouter _resultRouter(
  String etape,
  ScanLocator locator,
  ValueChanged<ScanPhotoResult?> onResult,
) => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, _) => Scaffold(
        body: TextButton(
          onPressed: () async =>
              onResult(await context.push<ScanPhotoResult>('/photo')),
          child: const Text('ouvrir'),
        ),
      ),
    ),
    GoRoute(
      path: '/photo',
      builder: (_, _) => ScanPhotoScreen(
        bidId: 'bid-1',
        etape: etape,
        packageLabel: 'Madou',
        returnResult: true,
        locator: locator,
      ),
    ),
  ],
);

void main() {
  // ─── Bouton Passer (optionnel) ─────────────────────────────────────────────
  testWidgets('DEPART — pas de bouton Passer', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: _router('DEPART'),
      ),
    );
    await tester.pump();
    expect(find.text('Passer : continuer sans photo'), findsNothing);
  });

  testWidgets('ARRIVEE — pas de bouton Passer', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: _router('ARRIVEE'),
      ),
    );
    await tester.pump();
    expect(find.text('Passer : continuer sans photo'), findsNothing);
  });

  testWidgets('TRANSIT — bouton Passer visible', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: _router('TRANSIT'),
      ),
    );
    await tester.pump();
    expect(find.text('Passer : continuer sans photo'), findsOneWidget);
  });

  testWidgets('Passer : la provenance suit vers la confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: _router('TRANSIT', scanMethod: ScanMethod.manual),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Passer : continuer sans photo'));
    await tester.pumpAndSettle();
    expect(find.text('confirm'), findsOneWidget);
    expect(_confirmExtra?['scanMethod'], ScanMethod.manual);
  });

  // ─── Label du colis ────────────────────────────────────────────────────────
  testWidgets('affiche label du colis', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: _router('DEPART'),
      ),
    );
    await tester.pump();
    expect(find.text('DON-TEST01'), findsOneWidget);
  });

  // ─── Badges photo ─────────────────────────────────────────────────────────
  testWidgets('badge obligatoire pour DEPART', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: _router('DEPART'),
      ),
    );
    await tester.pump();
    expect(find.text('Photo obligatoire'), findsOneWidget);
  });

  testWidgets('badge optionnelle pour TRANSIT', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: _router('TRANSIT'),
      ),
    );
    await tester.pump();
    expect(find.text('Photo optionnelle'), findsOneWidget);
  });

  testWidgets('badge obligatoire pour ARRIVEE', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: _router('ARRIVEE'),
      ),
    );
    await tester.pump();
    expect(find.text('Photo obligatoire'), findsOneWidget);
  });

  // ─── Bouton "Prendre la photo" toujours présent ──────────────────────────
  testWidgets('bouton Prendre la photo présent pour DEPART', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: _router('DEPART'),
      ),
    );
    await tester.pump();
    expect(find.text('Prendre la photo'), findsOneWidget);
  });

  testWidgets('bouton Prendre la photo présent pour TRANSIT', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: _router('TRANSIT'),
      ),
    );
    await tester.pump();
    expect(find.text('Prendre la photo'), findsOneWidget);
  });

  // ─── Label étape visible ──────────────────────────────────────────────────
  testWidgets('DEPART — label étape Départ visible', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: _router('DEPART'),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Départ'), findsOneWidget);
  });

  testWidgets('TRANSIT — label étape Transit visible', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: _router('TRANSIT'),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Transit'), findsOneWidget);
  });

  testWidgets('ARRIVEE — label étape Arrivée visible', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: _router('ARRIVEE'),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Arrivée'), findsOneWidget);
  });

  // ─── Icône fermeture ─────────────────────────────────────────────────────
  testWidgets('icône close présente', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: _router('DEPART'),
      ),
    );
    await tester.pump();
    expect(
      find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'x'),
      findsOneWidget,
    );
  });

  // ─── Titre écran ─────────────────────────────────────────────────────────
  testWidgets('titre Photo du colis affiché', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: _router('DEPART'),
      ),
    );
    await tester.pump();
    expect(find.text('Photo du colis'), findsOneWidget);
  });

  // ─── Géolocalisation label ────────────────────────────────────────────────
  testWidgets('label Géolocalisation automatique affiché', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: _router('DEPART'),
      ),
    );
    await tester.pump();
    expect(find.text('Géolocalisation automatique'), findsOneWidget);
  });

  // ─── anglais — titre, badges et boutons traduits ─────────────────────────
  testWidgets('anglais — titre, badges et boutons traduits', (tester) async {
    useEnglish();
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: _router('TRANSIT'),
      ),
    );
    await tester.pump();
    expect(find.text('Parcel photo'), findsOneWidget);
    expect(find.text('Step: Transit'), findsOneWidget);
    expect(find.text('Photo optional'), findsOneWidget);
    expect(find.text('Take the photo'), findsOneWidget);
    expect(find.text('Skip: continue without a photo'), findsOneWidget);
    expect(find.text('Automatic geolocation'), findsOneWidget);
  });

  group('mode retour de résultat (onglet Suivi)', () {
    late _MockLocator locator;
    late _MockMedia media;
    late Directory tmp;

    setUp(() {
      locator = _MockLocator();
      media = _MockMedia();
      tmp = Directory.systemTemp.createTempSync('scan_photo');
      registerFallbackValue(_here);
      when(() => locator.capture()).thenAnswer((_) async => _here);
      when(() => locator.writeExif(any(), any())).thenAnswer((_) async {});
      if (getIt.isRegistered<DonyMediaService>()) {
        getIt.unregister<DonyMediaService>();
      }
      getIt.registerSingleton<DonyMediaService>(media);
    });

    tearDown(() {
      getIt.unregister<DonyMediaService>();
      tmp.deleteSync(recursive: true);
    });

    Future<void> open(WidgetTester tester, GoRouter router) async {
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('titre du colis, photo obligatoire même au transit', (
      tester,
    ) async {
      await open(tester, _resultRouter('TRANSIT', locator, (_) {}));
      expect(find.text('Photo du colis de Madou'), findsOneWidget);
      expect(find.text('Obligatoire pour valider le transit'), findsOneWidget);
      expect(find.text('Passer : continuer sans photo'), findsNothing);
      expect(find.text('Position enregistrée · Dakar'), findsOneWidget);
    });

    testWidgets('photo prise : rendue avec la position relevée avant', (
      tester,
    ) async {
      final file = File('${tmp.path}/colis.jpg')..writeAsBytesSync([1, 2, 3]);
      when(
        () => media.pick(source: ImageSource.camera),
      ).thenAnswer((_) async => XFile(file.path));
      ScanPhotoResult? result;
      await open(tester, _resultRouter('DEPART', locator, (r) => result = r));

      await tester.tap(find.text('Prendre la photo'));
      // Lecture réelle du fichier : on laisse tourner l'horloge réelle
      // jusqu'au retour de l'écran.
      for (var i = 0; i < 40 && result == null; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(result?.photoPath, file.path);
      expect(result?.position?.label, 'Dakar');
      verify(() => locator.writeExif(file.path, _here)).called(1);
      expect(find.text('ouvrir'), findsOneWidget);
    });

    testWidgets('photo de plus de 10 Mo : refusée, écran conservé', (
      tester,
    ) async {
      final file = File('${tmp.path}/lourde.jpg')
        ..writeAsBytesSync(List.filled(ScanPhotoScreen.maxPhotoBytes + 1, 0));
      when(
        () => media.pick(source: ImageSource.camera),
      ).thenAnswer((_) async => XFile(file.path));
      ScanPhotoResult? result;
      await open(tester, _resultRouter('DEPART', locator, (r) => result = r));

      await tester.tap(find.text('Prendre la photo'));
      final tooLarge = find.textContaining('Photo trop lourde (max 10 Mo)');
      for (var i = 0; i < 40 && tooLarge.evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      expect(tooLarge, findsOneWidget);
      expect(result, isNull);
      expect(find.text('Photo du colis de Madou'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
