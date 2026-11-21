import 'dart:io';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/auth/presentation/screens/first_steps_screen.dart';
import 'package:dony/features/auth/presentation/screens/referral_code_screen.dart';
import 'package:dony/features/referral/bloc/referral_bloc.dart';
import 'package:dony/features/referral/data/referral_repository.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';
import '../../../../helpers/mock_analytics_backend.dart';

class _MockRepo extends Mock implements ReferralRepository {}

/// Polices embarquées : sans elles les tests rendent en Ahem et faussent la
/// mesure des libellés.
Future<void> _loadAppFonts() async {
  const families = {
    'HankenGrotesk': [
      'HankenGrotesk-SemiBold',
      'HankenGrotesk-Bold',
      'HankenGrotesk-ExtraBold',
    ],
    'PlusJakartaSans': [
      'PlusJakartaSans-Regular',
      'PlusJakartaSans-Medium',
      'PlusJakartaSans-SemiBold',
      'PlusJakartaSans-Bold',
    ],
  };
  for (final MapEntry(key: family, value: files) in families.entries) {
    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = File('assets/fonts/$file.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

void main() {
  late _MockRepo repo;
  late MockAnalyticsBackend backend;

  setUp(() {
    DonySnackbar.clearDedup();
    repo = _MockRepo();
    backend = MockAnalyticsBackend();
    when(() => repo.redeemCode(any())).thenAnswer((_) async {});
  });

  Future<void> pump(
    WidgetTester tester, {
    Locale locale = AppL10n.fr,
    Size? size,
    ThemeData? theme,
    double textScale = 1.0,
  }) async {
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    final analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();
    final router = GoRouter(
      initialLocation: referralCodeRoute,
      routes: [
        GoRoute(
          path: referralCodeRoute,
          builder: (_, _) => BlocProvider(
            create: (_) => ReferralBloc(repo, analytics),
            child: ReferralCodeScreen(analytics: analytics),
          ),
        ),
        GoRoute(
          path: firstStepsRoute,
          builder: (_, _) => const Scaffold(body: Text('Premiers pas')),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        theme: theme,
        routerConfig: router,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field() => find.byKey(const Key('referral-code-field'));
  Finder apply() => find.byKey(const Key('referral-code-apply'));
  Finder skip() => find.byKey(const Key('referral-code-skip'));

  testWidgets('champ, bouton de validation et « Passer » sont présents', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Un code de parrainage ?'), findsOneWidget);
    expect(field(), findsOneWidget);
    expect(find.text('Code de parrainage'), findsOneWidget);
    expect(apply(), findsOneWidget);
    expect(skip(), findsOneWidget);
    expect(find.text('Passer'), findsOneWidget);
  });

  testWidgets('le bouton de validation est grisé tant que le champ est vide', (
    tester,
  ) async {
    await pump(tester);
    expect(tester.widget<DonyButton>(apply()).onPressed, isNull);

    await tester.enterText(field(), 'amina05');
    await tester.pump();
    expect(tester.widget<DonyButton>(apply()).onPressed, isNotNull);
  });

  testWidgets('l\'écran est mesuré à l\'ouverture (sans le code)', (
    tester,
  ) async {
    await pump(tester);
    verify(
      () => backend.capture(AnalyticsEvents.referralSignupViewed, any()),
    ).called(1);
  });

  testWidgets(
    'succès : le code (majuscules) est appliqué, snackbar puis premiers pas',
    (tester) async {
      await pump(tester);

      await tester.enterText(field(), ' amina05 ');
      await tester.pump();
      await tester.tap(apply());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      verify(() => repo.redeemCode('AMINA05')).called(1);
      expect(find.text('Code de parrainage appliqué.'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(find.text('Premiers pas'), findsOneWidget);
      verify(
        () => backend.capture(AnalyticsEvents.referralSignupApplied, any()),
      ).called(1);
    },
  );

  final refusals = <String, (Object, String)>{
    '404 code inconnu': (
      const ValidationException('x', code: 'referral-code-not-found'),
      'Ce code de parrainage n\'existe pas',
    ),
    '409 déjà parrainé': (
      const ValidationException('x', code: 'already-referred'),
      'Vous avez déjà utilisé un code de parrainage.',
    ),
    '409 auto-parrainage': (
      const ValidationException('x', code: 'self-referral'),
      'Vous ne pouvez pas utiliser votre propre code',
    ),
    'réseau': (const OfflineException(), ''),
  };
  for (final entry in refusals.entries) {
    testWidgets('refus (${entry.key}) : message, reste sur l\'écran, '
        '« Passer » visible', (tester) async {
      when(() => repo.redeemCode(any())).thenThrow(entry.value.$1);
      await pump(tester);

      await tester.enterText(field(), 'ZZZZ99');
      await tester.pump();
      await tester.tap(apply());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byKey(const Key('referral-code-error')), findsOneWidget);
      if (entry.value.$2.isNotEmpty) {
        expect(
          tester
              .widget<Text>(find.byKey(const Key('referral-code-error')))
              .data,
          contains(entry.value.$2),
        );
      }
      expect(find.text('Premiers pas'), findsNothing);
      expect(skip(), findsOneWidget);
      expect(tester.widget<DonyButton>(skip()).onPressed, isNotNull);
      verify(
        () => backend.capture(AnalyticsEvents.referralSignupRejected, any()),
      ).called(1);
    });
  }

  testWidgets('après un refus, une nouvelle saisie efface l\'erreur et '
      'permet de réessayer', (tester) async {
    when(() => repo.redeemCode('BAD123')).thenThrow(
      const ValidationException('x', code: 'referral-code-not-found'),
    );
    await pump(tester);

    await tester.enterText(field(), 'bad123');
    await tester.pump();
    await tester.tap(apply());
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.byKey(const Key('referral-code-error')), findsOneWidget);

    await tester.enterText(field(), 'GOOD99');
    await tester.pump();
    expect(find.byKey(const Key('referral-code-error')), findsNothing);
    await tester.tap(apply());
    await tester.pumpAndSettle(const Duration(seconds: 5));

    verify(() => repo.redeemCode('GOOD99')).called(1);
    expect(find.text('Premiers pas'), findsOneWidget);
  });

  testWidgets('« Passer » va aux premiers pas sans appeler redeemCode', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(skip());
    await tester.pumpAndSettle();

    expect(find.text('Premiers pas'), findsOneWidget);
    verifyNever(() => repo.redeemCode(any()));
    verify(
      () => backend.capture(AnalyticsEvents.referralSignupSkipped, any()),
    ).called(1);
  });

  testWidgets('l\'analytics ne contient jamais la valeur du code', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(field(), 'amina05');
    await tester.pump();
    await tester.tap(apply());
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final captured = verify(
      () => backend.capture(any(), captureAny()),
    ).captured;
    for (final props in captured) {
      expect(props.toString().toUpperCase(), isNot(contains('AMINA05')));
    }
  });

  group('360 dp, polices réelles', () {
    setUpAll(_loadAppFonts);

    for (final locale in const [AppL10n.fr, AppL10n.en]) {
      for (final scale in const [1.0, 1.3]) {
        testWidgets(
          'boutons sur une ligne, taille normale (${locale.languageCode}, '
          'x$scale)',
          (tester) async {
            if (locale == AppL10n.en) enableEnglish();
            await pump(
              tester,
              locale: locale,
              size: const Size(360, 800),
              theme: AppTheme.light(),
              textScale: scale,
            );
            expect(tester.takeException(), isNull);

            final buttons = find.byType(DonyButton);
            expect(buttons, findsNWidgets(2));
            for (var i = 0; i < 2; i++) {
              final button = buttons.at(i);
              expect(tester.getSize(button).height, 52);
              final fitted = find
                  .ancestor(
                    of: find.descendant(
                      of: button,
                      matching: find.byType(Text),
                    ),
                    matching: find.byType(FittedBox),
                  )
                  .first;
              final box = tester.renderObject<RenderFittedBox>(fitted);
              final label = tester.widget<Text>(
                find.descendant(of: fitted, matching: find.byType(Text)),
              );
              expect(
                box.child!.size.width,
                lessThanOrEqualTo(box.size.width + 0.01),
                reason: 'libellé « ${label.data} » rétréci',
              );
            }
          },
        );
      }
    }
  });
}
