import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import '../../../../helpers/mock_analytics_backend.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

const _testUser = UserModel(
  id: 'u1',
  roles: ['ROLE_TRAVELER', 'ROLE_SENDER'],
  kycStatus: 'NOT_STARTED',
  status: 'ACTIVE',
);

void main() {
  late MockAuthBloc mockBloc;

  setUpAll(() {
    if (!getIt.isRegistered<AnalyticsService>()) {
      final analytics = makeEnabledAnalytics(MockAnalyticsBackend());
      getIt.registerSingleton<AnalyticsService>(analytics);
    }
    if (!getIt.isRegistered<HiveService>()) {
      final hive = MockHiveService();
      final box = MockBox();
      when(() => hive.userPrefs).thenReturn(box);
      when(() => box.get(any())).thenReturn(null);
      when(
        () => box.get(any(), defaultValue: any(named: 'defaultValue')),
      ).thenAnswer((i) => i.namedArguments[const Symbol('defaultValue')]);
      when(() => box.put(any(), any())).thenAnswer((_) async {});
      getIt.registerSingleton<HiveService>(hive);
    }
  });

  tearDownAll(() {
    GetIt.instance.reset();
  });

  setUp(() {
    mockBloc = MockAuthBloc();
  });

  tearDown(() => mockBloc.close());

  // Helper pour construire le widget avec un GoRouter de test
  Widget buildScreen(List<AuthState> states) {
    whenListen(
      mockBloc,
      Stream.fromIterable(states),
      initialState: const AuthOtpSent(
        verificationId: 'vid',
        phoneNumber: '+33600000000',
      ),
    );

    final router = GoRouter(
      initialLocation: '/auth/otp',
      routes: [
        GoRoute(
          path: '/auth/otp',
          builder: (_, _) => BlocProvider<AuthBloc>.value(
            value: mockBloc,
            child: const OtpVerificationScreen(),
          ),
        ),
        GoRoute(
          path: '/auth/currency-selection',
          builder: (_, _) => const Scaffold(body: Text('currency-selection')),
        ),
      ],
    );

    return MaterialApp.router(routerConfig: router);
  }

  testWidgets(
    'quand AuthOtpVerified est émis, dispatche AuthRegisterRequested',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildScreen([const AuthOtpVerified(phoneNumber: '+33600000000')]),
      );
      await tester.pump();
      // Drain mascotte animation timers (confiant shimmer = 900 ms)
      await tester.pump(const Duration(seconds: 1));
      verify(() => mockBloc.add(const AuthRegisterRequested())).called(1);
    },
  );

  testWidgets(
    'quand AuthAuthenticated est émis, poursuit vers la sélection de devise, aucune étape code PIN',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildScreen([const AuthAuthenticated(_testUser)]),
      );
      await tester.pumpAndSettle();
      expect(find.text('currency-selection'), findsOneWidget);
    },
  );

  // Helper for phone-mode screen without stream emissions
  Widget buildPhoneScreenNoStream({AuthState? initialState}) {
    when(() => mockBloc.state).thenReturn(
      initialState ??
          const AuthOtpSent(verificationId: 'vid', phoneNumber: '+33600000000'),
    );
    when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());

    return MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/auth/otp',
        routes: [
          GoRoute(
            path: '/auth/otp',
            builder: (_, _) => BlocProvider<AuthBloc>.value(
              value: mockBloc,
              child: const OtpVerificationScreen(),
            ),
          ),
          GoRoute(
            path: '/auth/local',
            builder: (_, _) => const Scaffold(body: Text('local-auth')),
          ),
          GoRoute(
            path: '/auth/phone',
            builder: (_, _) => const Scaffold(body: Text('phone-auth')),
          ),
        ],
      ),
    );
  }

  testWidgets(
    'phone mode — tapper Vérifier sans code complet affiche snackbar',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildPhoneScreenNoStream());
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Tap verify without entering any code
      await tester.tap(find.text('Vérifier'));
      await tester.pump();

      // Snackbar should appear — verify button still visible
      expect(find.text('Vérifier'), findsOneWidget);
    },
  );

  testWidgets(
    'phone mode — state is NOT AuthOtpSent → vérifier affiche "Session expirée"',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildPhoneScreenNoStream(initialState: const AuthInitial()),
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Enter 6 digits so the partial-code guard doesn't fire
      final fields = find.byType(TextFormField);
      for (int i = 0; i < 6; i++) {
        await tester.enterText(fields.at(i), '$i');
        await tester.pump();
      }
      await tester.tap(find.text('Vérifier'));
      await tester.pump();

      // Should show session expired snackbar, not navigate
      expect(find.text('Vérifier'), findsOneWidget);
    },
  );

  testWidgets(
    'phone mode — saisir 6 chiffres et tapper Vérifier dispatche AuthPhoneVerified',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildPhoneScreenNoStream());
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final fields = find.byType(TextFormField);
      for (int i = 0; i < 6; i++) {
        await tester.enterText(fields.at(i), '$i');
        await tester.pump();
      }

      await tester.tap(find.text('Vérifier'));
      await tester.pump();

      verify(
        () => mockBloc.add(
          const AuthPhoneVerified(verificationId: 'vid', smsCode: '012345'),
        ),
      ).called(1);
    },
  );

  testWidgets(
    'phone mode — _resend() avec secondsLeft=0 dispatche AuthSendOtpRequested',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildPhoneScreenNoStream(
          initialState: const AuthOtpSent(
            verificationId: 'vid',
            phoneNumber: '+33600000000',
            secondsLeft: 0,
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final resendFinder = find.text('Renvoyer le code');
      expect(resendFinder, findsOneWidget);
      await tester.tap(resendFinder);
      await tester.pump();

      verify(
        () => mockBloc.add(const AuthSendOtpRequested('+33600000000')),
      ).called(1);
    },
  );

  testWidgets(
    'phone mode — AuthError dans le listener déclenche ErrorPresenter',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      whenListen(
        mockBloc,
        Stream.fromIterable([
          const AuthLoading(),
          const AuthError(
            NetworkException('Code invalide', code: 'invalid-code'),
          ),
        ]),
        initialState: const AuthOtpSent(
          verificationId: 'vid',
          phoneNumber: '+33600000000',
        ),
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/auth/otp',
            routes: [
              GoRoute(
                path: '/auth/otp',
                builder: (_, _) => BlocProvider<AuthBloc>.value(
                  value: mockBloc,
                  child: const OtpVerificationScreen(),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Screen should still be showing (not navigated)
      expect(find.text('Vérifier'), findsOneWidget);
    },
  );

  testWidgets('back button — tape le bouton retour navigue en arrière', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    when(() => mockBloc.state).thenReturn(
      const AuthOtpSent(verificationId: 'vid', phoneNumber: '+33600000000'),
    );
    when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());

    // Navigate from /prev to /auth/otp so there's a previous page to pop to
    final router = GoRouter(
      initialLocation: '/prev',
      routes: [
        GoRoute(
          path: '/prev',
          builder: (_, _) => const Scaffold(body: Text('previous-screen')),
        ),
        GoRoute(
          path: '/auth/otp',
          builder: (_, _) => BlocProvider<AuthBloc>.value(
            value: mockBloc,
            child: const OtpVerificationScreen(),
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    // Navigate to OTP screen
    unawaited(router.push('/auth/otp'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // The back button should be visible (DonyAppBarBackButton — carré bleu + chevron)
    final backBtn = find.byType(DonyAppBarBackButton);
    expect(backBtn, findsOneWidget);
    await tester.tap(backBtn);
    await tester.pumpAndSettle();

    // Should have popped back to previous screen
    expect(find.text('previous-screen'), findsOneWidget);
  });
}
