import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/config/google_auth_flag.dart';
import 'package:dony/core/config/sms_auth_flag.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/presentation/screens/auth_method_screen.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/stripe_account_test_doubles.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockBusinessPrefsBloc
    extends MockBloc<BusinessPrefsEvent, BusinessPrefsState>
    implements BusinessPrefsBloc {}

/// Charge les vraies polices de l'app : avec la police de repli des tests,
/// chaque glyphe fait un cadratin et le texte prend deux fois plus de lignes
/// que sur un téléphone, ce qui fausserait la mesure.
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

/// FLUTTER-RG : en arrivant sur l'écran de connexion, tout le panneau est
/// visible sans défiler, jusqu'à « Parcourir sans compte ».
void main() {
  setUpAll(_loadAppFonts);

  late _MockAuthBloc bloc;

  setUp(() {
    setSmsAuthEnabled(true);
    bloc = _MockAuthBloc();
    when(() => bloc.state).thenReturn(const AuthInitial());
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
  });

  tearDown(() {
    setSmsAuthEnabled(kSmsAuthEnabledDefault);
    debugEnvironmentOverride = null;
    debugDefaultTargetPlatformOverride = null;
  });

  Future<void> pumpOn(
    WidgetTester tester, {
    required Size size,
    required double top,
    required double bottom,
    Locale locale = const Locale('fr'),
  }) async {
    tester.view
      ..devicePixelRatio = 3
      ..physicalSize = size * 3
      ..padding = FakeViewPadding(top: top * 3, bottom: bottom * 3)
      ..viewPadding = FakeViewPadding(top: top * 3, bottom: bottom * 3);
    addTearDown(tester.view.reset);
    final prefs = _MockBusinessPrefsBloc();
    when(() => prefs.state).thenReturn(const BusinessPrefsState());
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => MultiBlocProvider(
                providers: [
                  BlocProvider<AuthBloc>.value(value: bloc),
                  BlocProvider<StripeAccountBloc>.value(
                    value: stubStripeAccountBloc(),
                  ),
                  BlocProvider<BusinessPrefsBloc>.value(value: prefs),
                ],
                child: const AuthMethodScreen(),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Le rectangle de [finder] tient entier dans la zone visible.
  void expectOnScreen(
    WidgetTester tester,
    Finder finder, {
    required Size size,
    required double bottom,
  }) {
    expect(finder, findsOneWidget);
    final rect = tester.getRect(finder);
    expect(rect.top, greaterThanOrEqualTo(0), reason: '$finder');
    expect(
      rect.bottom,
      lessThanOrEqualTo(size.height - bottom),
      reason: '$finder sort de l’écran ($rect)',
    );
  }

  void expectWholePanelVisible(
    WidgetTester tester, {
    required Size size,
    required double bottom,
    required bool apple,
    Locale locale = const Locale('fr'),
  }) {
    final fr = locale.languageCode == 'fr';
    final labels = [
      if (fr) 'Continuer avec mon téléphone' else 'Continue with phone',
      if (apple) fr ? 'Continuer avec Apple' : 'Continue with Apple',
      if (fr) 'Continuer avec Google' else 'Continue with Google',
      if (fr) 'Continuer avec mon email' else 'Continue with email',
      if (fr) 'Parcourir sans compte' else 'Browse without an account',
    ];
    for (final label in labels) {
      expectOnScreen(tester, find.text(label), size: size, bottom: bottom);
    }
    expectOnScreen(
      tester,
      find.byKey(const Key('auth-guest-cta')),
      size: size,
      bottom: bottom,
    );
    expectOnScreen(tester, find.byType(Checkbox), size: size, bottom: bottom);
  }

  const iphone12 = Size(390, 844);
  const iphoneSe = Size(375, 667);

  testWidgets('iPhone 12 (iOS, toutes les options) : tout est visible', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await pumpOn(tester, size: iphone12, top: 47, bottom: 34);
    expectWholePanelVisible(tester, size: iphone12, bottom: 34, apple: true);
    // L'accroche reste lisible.
    expect(find.text('Connectez-vous en toute confiance'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('iPhone 12 en anglais : tout est visible', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await pumpOn(
      tester,
      size: iphone12,
      top: 47,
      bottom: 34,
      locale: const Locale('en'),
    );
    expectWholePanelVisible(
      tester,
      size: iphone12,
      bottom: 34,
      apple: true,
      locale: const Locale('en'),
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('iPhone SE (iOS, toutes les options) : tout est visible', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await pumpOn(tester, size: iphoneSe, top: 20, bottom: 0);
    expectWholePanelVisible(tester, size: iphoneSe, bottom: 0, apple: true);
    // Boutons jamais sous la cible tactile minimale.
    expect(
      tester.getSize(find.byKey(const Key('auth-guest-cta'))).height,
      greaterThanOrEqualTo(44),
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Android 375×667 : tout est visible', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    debugEnvironmentOverride = 'prod';
    await pumpOn(tester, size: iphoneSe, top: 24, bottom: 0);
    expectWholePanelVisible(tester, size: iphoneSe, bottom: 0, apple: false);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('grand écran : densité d’origine, panneau en bas', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    const proMax = Size(430, 932);
    await pumpOn(tester, size: proMax, top: 59, bottom: 34);
    expectWholePanelVisible(tester, size: proMax, bottom: 34, apple: true);
    expect(
      tester.getSize(find.text('Continuer avec mon téléphone')).height,
      greaterThan(0),
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('très petit écran : défilement de secours, rien ne déborde', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await pumpOn(tester, size: const Size(375, 520), top: 20, bottom: 0);
    expect(tester.takeException(), isNull);
    final guest = find.text('Parcourir sans compte');
    await tester.scrollUntilVisible(guest, 200);
    expect(tester.getRect(guest).bottom, lessThanOrEqualTo(520));
    debugDefaultTargetPlatformOverride = null;
  });
}
