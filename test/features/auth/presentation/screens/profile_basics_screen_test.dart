import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/bloc/profile_basics_cubit.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/auth/data/repositories/auth_repository.dart';
import 'package:dony/features/auth/presentation/screens/first_steps_screen.dart';
import 'package:dony/features/auth/presentation/screens/profile_basics_screen.dart';
import 'package:dony/features/referral/data/pending_referral_redeemer.dart';
import 'package:dony/features/settings/data/models/user_business_prefs_dto.dart';
import 'package:dony/features/settings/data/repositories/business_prefs_repository.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';
import '../../../../helpers/mock_analytics_backend.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockBusinessPrefsRepository extends Mock
    implements BusinessPrefsRepository {}

class _MockRedeemer extends Mock implements PendingReferralRedeemer {}

class _MockBox extends Mock implements Box<dynamic> {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _FakeAuthEvent extends Fake implements AuthEvent {}

class _FakeUserBusinessPrefsDto extends Fake implements UserBusinessPrefsDto {}

class _FakeUserModel extends Fake implements UserModel {}

const _prefs = UserBusinessPrefsDto(
  weightUnit: 'kg',
  currencyCode: 'XOF',
  defaultPackageWeightKg: 23,
  minBidPriceEur: 0,
);

/// Polices embarquées de l'app : sans elles les tests rendent en Ahem (1 em
/// par caractère), ce qui fausserait la mesure des libellés.
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
  late _MockAuthRepository auth;
  late _MockBusinessPrefsRepository businessPrefs;
  late _MockBox box;
  late MockAnalyticsBackend backend;
  late _MockAuthBloc authBloc;

  setUpAll(() {
    registerFallbackValue(_FakeAuthEvent());
    registerFallbackValue(_FakeUserBusinessPrefsDto());
  });

  setUp(() {
    DonySnackbar.clearDedup();
    auth = _MockAuthRepository();
    businessPrefs = _MockBusinessPrefsRepository();
    box = _MockBox();
    backend = MockAnalyticsBackend();
    authBloc = _MockAuthBloc();
    when(
      () => auth.updateProfile(
        firstName: any(named: 'firstName'),
        lastName: any(named: 'lastName'),
      ),
    ).thenAnswer((_) async => _FakeUserModel());
    when(() => businessPrefs.fetchPrefs()).thenAnswer((_) async => _prefs);
    when(
      () => businessPrefs.updatePrefs(any()),
    ).thenAnswer((_) async => _prefs);
    when(() => box.put(any(), any())).thenAnswer((_) async {});
    when(() => authBloc.state).thenReturn(const AuthInitial());
    when(() => authBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => authBloc.add(any())).thenReturn(null);
  });

  Future<void> pump(
    WidgetTester tester, {
    PendingReferralRedeemer? redeemer,
    String? initialCountryCode,
    Locale locale = AppL10n.fr,
    Size? size,
    ThemeData? theme,
  }) async {
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    final analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();
    final router = GoRouter(
      initialLocation: profileBasicsRoute,
      routes: [
        GoRoute(
          path: profileBasicsRoute,
          builder: (_, _) => BlocProvider(
            create: (_) =>
                ProfileBasicsCubit(auth, businessPrefs, box, analytics),
            child: ProfileBasicsScreen(
              initialCountryCode: initialCountryCode,
              redeemer: redeemer,
            ),
          ),
        ),
        GoRoute(
          path: firstStepsRoute,
          builder: (_, _) => const Scaffold(body: Text('Premiers pas')),
        ),
      ],
    );
    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: MaterialApp.router(
          theme: theme,
          routerConfig: router,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder continueButton() => find.byKey(const Key('profile-basics-continue'));
  Finder skipButton() =>
      find.widgetWithText(DonyButton, 'Passer pour l\'instant');

  testWidgets('prénom, nom et pays sur un seul écran, scarabée en en-tête', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Faisons connaissance'), findsOneWidget);
    // `DonyBadge` affiche son libellé en capitales.
    expect(find.text('FACULTATIF'), findsOneWidget);
    expect(find.byKey(const Key('profile-basics-first-name')), findsOneWidget);
    expect(find.byKey(const Key('profile-basics-last-name')), findsOneWidget);
    expect(find.byKey(const Key('profile-basics-country')), findsOneWidget);
    expect(find.text('Prénom'), findsOneWidget);
    expect(find.text('Nom'), findsOneWidget);
    expect(find.text('Pays de résidence'), findsOneWidget);
    expect(find.byType(DonyFeedbackButton), findsOneWidget);
  });

  testWidgets('profile_basics_viewed part à l\'ouverture', (tester) async {
    await pump(tester);
    verify(
      () => backend.capture(AnalyticsEvents.profileBasicsViewed, any()),
    ).called(1);
  });

  testWidgets(
    'le pays déduit du téléphone est affiché, avec la mention, sans rien '
    'écrire',
    (tester) async {
      await pump(tester, initialCountryCode: 'SN');

      expect(
        find.descendant(
          of: find.byKey(const Key('profile-basics-country')),
          matching: find.text('Sénégal'),
        ),
        findsOneWidget,
      );
      expect(
        find.text('Pays proposé d\'après votre numéro. Modifiable.'),
        findsOneWidget,
      );
      verifyZeroInteractions(businessPrefs);
      verifyZeroInteractions(box);
    },
  );

  testWidgets('sans pays prérempli, pas de mention', (tester) async {
    await pump(tester);
    expect(
      find.text('Pays proposé d\'après votre numéro. Modifiable.'),
      findsNothing,
    );
  });

  testWidgets('« Continuer » est actif sur un formulaire vide', (tester) async {
    await pump(tester);
    final button = tester.widget<DonyButton>(continueButton());
    expect(button.onPressed, isNotNull);
  });

  testWidgets(
    '« Passer pour l\'instant » va sur les premiers pas sans aucun appel',
    (tester) async {
      await pump(tester, initialCountryCode: 'SN');

      await tester.enterText(
        find.byKey(const Key('profile-basics-first-name')),
        'Awa',
      );
      await tester.tap(skipButton());
      await tester.pumpAndSettle();

      expect(find.text('Premiers pas'), findsOneWidget);
      verifyZeroInteractions(auth);
      verifyZeroInteractions(businessPrefs);
      verifyZeroInteractions(box);
      verifyNever(() => authBloc.add(const AuthProfileRefreshRequested()));
    },
  );

  testWidgets(
    '« Continuer » écrit le nom et le pays prérempli, rafraîchit le profil '
    'puis va sur les premiers pas',
    (tester) async {
      await pump(tester, initialCountryCode: 'SN');

      await tester.enterText(
        find.byKey(const Key('profile-basics-first-name')),
        ' Awa ',
      );
      await tester.tap(continueButton());
      await tester.pumpAndSettle();

      verify(() => auth.updateProfile(firstName: 'Awa')).called(1);
      verify(
        () => businessPrefs.updatePrefs(
          any(
            that: isA<UserBusinessPrefsDto>().having(
              (dto) => dto.country,
              'country',
              'SN',
            ),
          ),
        ),
      ).called(1);
      verify(() => authBloc.add(const AuthProfileRefreshRequested())).called(1);
      expect(find.text('Premiers pas'), findsOneWidget);
    },
  );

  testWidgets('choisir un autre pays dans la liste retire la mention', (
    tester,
  ) async {
    await pump(tester, initialCountryCode: 'SN');

    await tester.tap(find.byKey(const Key('profile-basics-country')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Mali'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Mali'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('profile-basics-country')),
        matching: find.text('Mali'),
      ),
      findsOneWidget,
    );
    expect(
      find.text('Pays proposé d\'après votre numéro. Modifiable.'),
      findsNothing,
    );

    await tester.tap(continueButton());
    await tester.pumpAndSettle();
    verify(
      () => businessPrefs.updatePrefs(
        any(
          that: isA<UserBusinessPrefsDto>().having(
            (dto) => dto.country,
            'country',
            'ML',
          ),
        ),
      ),
    ).called(1);
  });

  testWidgets('un échec du nom affiche une erreur et reste sur l\'écran', (
    tester,
  ) async {
    when(
      () => auth.updateProfile(
        firstName: any(named: 'firstName'),
        lastName: any(named: 'lastName'),
      ),
    ).thenThrow(Exception('offline'));
    await pump(tester);

    await tester.enterText(
      find.byKey(const Key('profile-basics-last-name')),
      'Diallo',
    );
    await tester.tap(continueButton());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.text(
        'Impossible d\'enregistrer pour le moment. Réessayez ou passez cette '
        'étape.',
      ),
      findsOneWidget,
    );
    expect(find.text('Premiers pas'), findsNothing);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  group('code de parrainage du lien', () {
    late _MockRedeemer redeemer;
    setUp(() => redeemer = _MockRedeemer());

    testWidgets('applied : snackbar de succès, apply appelé une fois', (
      tester,
    ) async {
      when(
        () => redeemer.apply(),
      ).thenAnswer((_) async => PendingReferralOutcome.applied);
      await pump(tester, redeemer: redeemer);

      expect(find.text('Code de parrainage appliqué.'), findsOneWidget);
      verify(() => redeemer.apply()).called(1);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    for (final outcome in [
      PendingReferralOutcome.none,
      PendingReferralOutcome.rejected,
    ]) {
      testWidgets('$outcome : aucun message', (tester) async {
        when(() => redeemer.apply()).thenAnswer((_) async => outcome);
        await pump(tester, redeemer: redeemer);

        expect(find.text('Code de parrainage appliqué.'), findsNothing);
        verify(() => redeemer.apply()).called(1);
      });
    }
  });

  group('360 dp, polices réelles', () {
    setUpAll(_loadAppFonts);

    for (final locale in const [AppL10n.fr, AppL10n.en]) {
      testWidgets('boutons sur une ligne (${locale.languageCode})', (
        tester,
      ) async {
        if (locale == AppL10n.en) enableEnglish();
        await pump(
          tester,
          locale: locale,
          size: const Size(360, 800),
          theme: AppTheme.light(),
        );
        expect(tester.takeException(), isNull);

        final buttons = find.byType(DonyButton);
        expect(buttons, findsNWidgets(2));
        for (var i = 0; i < 2; i++) {
          final button = buttons.at(i);
          expect(tester.getSize(button).height, 52);
          // `DonyButton` rétrécit un libellé trop long (FittedBox scaleDown)
          // au lieu de le couper : il doit tenir à sa taille normale.
          final fitted = find
              .ancestor(
                of: find.descendant(of: button, matching: find.byType(Text)),
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
      });
    }
  });
}
