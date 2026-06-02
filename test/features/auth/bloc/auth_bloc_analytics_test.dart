import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/auth/data/repositories/auth_repository.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class _MockAuthRepo extends Mock implements AuthRepository {}
class _MockLocalAuth extends Mock implements LocalAuthService {}
class _MockFirebaseAuth extends Mock implements FirebaseAuth {}
class _MockFirebaseUser extends Mock implements User {}

void main() {
  late _MockAuthRepo repo;
  late _MockLocalAuth localAuth;
  late _MockFirebaseAuth firebaseAuth;
  late MockAnalyticsBackend backend;
  late _MockFirebaseUser firebaseUser;

  final fakeUser = UserModel(
    id: 'u1',
    phoneNumber: '+33600000000',
    roles: ['SENDER'],
    kycStatus: 'NOT_STARTED',
    status: 'ACTIVE',
  );

  setUp(() {
    repo = _MockAuthRepo();
    localAuth = _MockLocalAuth();
    firebaseAuth = _MockFirebaseAuth();
    backend = MockAnalyticsBackend();
    firebaseUser = _MockFirebaseUser();

    when(() => firebaseAuth.currentUser).thenReturn(firebaseUser);
    when(() => firebaseUser.phoneNumber).thenReturn('+33600000000');
  });

  AuthBloc makeBloc({bool analyticsEnabled = true}) {
    final analytics = analyticsEnabled
        ? makeEnabledAnalytics(backend)
        : makeDisabledAnalytics(backend);
    analytics.onConfigured();
    return AuthBloc(
      repo,
      localAuth,
      firebaseAuth: firebaseAuth,
      analytics: analytics,
    );
  }

  group('login_success', () {
    test('fires on AuthCheckRequested when profile exists', () async {
      when(() => repo.getProfile()).thenAnswer((_) async => fakeUser);
      final bloc = makeBloc();
      bloc.add(const AuthCheckRequested());
      await bloc.stream.firstWhere((s) => s is AuthAuthenticated);
      await Future<void>.delayed(Duration.zero);
      verify(() => backend.capture(
        AnalyticsEvents.loginSuccess,
        {'method': 'check'},
      )).called(1);
    });
  });

  group('login_failed', () {
    test('fires on AuthCheckRequested when server error', () async {
      when(() => repo.getProfile()).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 500,
          ),
          type: DioExceptionType.badResponse,
        ),
      );
      final bloc = makeBloc();
      bloc.add(const AuthCheckRequested());
      await bloc.stream.firstWhere((s) => s is AuthError);
      await Future<void>.delayed(Duration.zero);
      verify(() => backend.capture(
        AnalyticsEvents.loginFailed,
        any(),
      )).called(1);
    });
  });

  group('consent off', () {
    test('no event fires when analytics disabled', () async {
      when(() => repo.getProfile()).thenAnswer((_) async => fakeUser);
      final bloc = makeBloc(analyticsEnabled: false);
      bloc.add(const AuthCheckRequested());
      await bloc.stream.firstWhere((s) => s is AuthAuthenticated);
      await Future<void>.delayed(Duration.zero);
      verifyNever(() => backend.capture(any(), any()));
    });
  });
}
