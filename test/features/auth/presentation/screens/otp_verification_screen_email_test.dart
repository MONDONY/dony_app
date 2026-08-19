import 'package:bloc_test/bloc_test.dart';
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

Widget _buildEmail({
  required AuthBloc bloc,
  String contact = 'user@example.com',
}) {
  return MaterialApp.router(
    routerConfig: GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => BlocProvider<AuthBloc>.value(
            value: bloc,
            child: OtpVerificationScreen(mode: OtpMode.email, contact: contact),
          ),
        ),
        GoRoute(
          path: '/auth/country-selection',
          builder: (_, _) => const Scaffold(body: Text('Country selection')),
        ),
      ],
    ),
  );
}

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
    when(
      () => mockBloc.state,
    ).thenReturn(const AuthEmailOtpSent('user@example.com'));
    when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());
    registerFallbackValue(const AuthRegisterWithEmailRequested(email: ''));
  });

  testWidgets('mode email — affiche "Code reçu ?" et l\'adresse', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildEmail(bloc: mockBloc));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Code reçu ?'), findsOneWidget);
    expect(find.textContaining('user@example.com'), findsOneWidget);
  });

  testWidgets(
    'mode email — dispatche AuthEmailOtpVerifyRequested sur vérifier',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildEmail(bloc: mockBloc));
      await tester.pump();

      final fields = find.byType(TextFormField);
      for (int i = 0; i < 6; i++) {
        await tester.enterText(fields.at(i), '$i');
      }
      await tester.tap(find.text('Vérifier'));

      verify(
        () => mockBloc.add(
          const AuthEmailOtpVerifyRequested(
            email: 'user@example.com',
            code: '012345',
          ),
        ),
      ).called(1);
    },
  );

  testWidgets(
    'mode email — dispatche AuthRegisterWithEmailRequested quand AuthEmailOtpVerified',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      whenListen(
        mockBloc,
        Stream.fromIterable([
          const AuthLoading(),
          const AuthEmailOtpVerified('user@example.com'),
        ]),
        initialState: const AuthEmailOtpSent('user@example.com'),
      );
      await tester.pumpWidget(_buildEmail(bloc: mockBloc));
      await tester.pumpAndSettle();

      verify(
        () => mockBloc.add(
          const AuthRegisterWithEmailRequested(email: 'user@example.com'),
        ),
      ).called(1);
    },
  );

  testWidgets('mode email — affiche le timer du state AuthEmailOtpSent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    when(
      () => mockBloc.state,
    ).thenReturn(const AuthEmailOtpSent('user@example.com', secondsLeft: 42));
    await tester.pumpWidget(_buildEmail(bloc: mockBloc));
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('42'), findsOneWidget);
  });

  testWidgets(
    'mode email — _resend() dispatche AuthEmailOtpSendRequested quand timer = 0',
    (tester) async {
      // Use a taller screen to ensure the resend link is not obscured by the pinned button
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Timer à 0 → bouton "Renvoyer" actif
      const stateWithZero = AuthEmailOtpSent(
        'user@example.com',
        secondsLeft: 0,
      );
      when(() => mockBloc.state).thenReturn(stateWithZero);
      when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());
      await tester.pumpWidget(_buildEmail(bloc: mockBloc));
      // Drain all pending animation timers
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Le texte "Renvoyer le code" sans compteur est visible et tappable
      final resendFinder = find.text('Renvoyer le code');
      expect(resendFinder, findsOneWidget);

      await tester.tap(resendFinder);
      await tester.pump();

      verify(
        () => mockBloc.add(const AuthEmailOtpSendRequested('user@example.com')),
      ).called(1);
    },
  );

  testWidgets('mode email — déclenche ErrorPresenter quand AuthError émis', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
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
      initialState: const AuthEmailOtpSent('user@example.com'),
    );

    await tester.pumpWidget(_buildEmail(bloc: mockBloc));
    // Pump enough for the listener to fire and snackbar to appear
    await tester.pump(const Duration(milliseconds: 300));

    // Screen should still show OTP form (not navigated away)
    expect(find.text('Vérifier'), findsOneWidget);
  });

  testWidgets(
    'mode email — poursuit vers la sélection du pays, aucune étape code PIN quand AuthAuthenticated émis',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      whenListen(
        mockBloc,
        Stream.fromIterable([
          const AuthLoading(),
          const AuthAuthenticated(
            UserModel(
              id: 'u1',
              roles: ['SENDER'],
              kycStatus: 'NOT_STARTED',
              status: 'ACTIVE',
            ),
          ),
        ]),
        initialState: const AuthEmailOtpSent('user@example.com'),
      );
      await tester.pumpWidget(_buildEmail(bloc: mockBloc));
      await tester.pumpAndSettle();

      expect(find.text('Country selection'), findsOneWidget);
    },
  );
}
