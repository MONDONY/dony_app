import 'package:dony/app/initial_location.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mock_analytics_backend.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockUser extends Mock implements User {}

class _MockLocalAuthService extends Mock implements LocalAuthService {}

void main() {
  late _MockFirebaseAuth auth;
  late _MockLocalAuthService localAuth;
  late MockHiveService hive;
  late MockBox prefs;

  setUp(() {
    auth = _MockFirebaseAuth();
    localAuth = _MockLocalAuthService();
    hive = MockHiveService();
    prefs = MockBox();
    when(() => hive.userPrefs).thenReturn(prefs);
    when(
      () => prefs.get('onboarding_done', defaultValue: false),
    ).thenReturn(false);
    when(() => auth.currentUser).thenReturn(null);
    when(localAuth.isPinSet).thenAnswer((_) async => false);
  });

  Future<String> resolve() => resolveInitialLocation(
    firebaseAuth: auth,
    localAuthService: localAuth,
    hiveService: hive,
  );

  test('sans session et sans onboarding vu → /onboarding', () async {
    expect(await resolve(), '/onboarding');
  });

  test('sans session mais onboarding déjà vu → /auth/method', () async {
    when(
      () => prefs.get('onboarding_done', defaultValue: false),
    ).thenReturn(true);
    expect(await resolve(), '/auth/method');
  });

  test('session Firebase + code local → /auth/local', () async {
    when(() => auth.currentUser).thenReturn(_MockUser());
    when(localAuth.isPinSet).thenAnswer((_) async => true);
    expect(await resolve(), '/auth/local');
  });

  test('session Firebase sans code local → /home directement', () async {
    when(() => auth.currentUser).thenReturn(_MockUser());
    expect(await resolve(), '/home');
  });

  test(
    'ne dépend jamais du backend : aucun appel réseau, résolution immédiate',
    () async {
      when(() => auth.currentUser).thenReturn(_MockUser());
      // Le seul await est la lecture du secure storage (mockée) : la
      // résolution ne doit pas attendre un health check.
      expect(await resolve().timeout(const Duration(seconds: 1)), '/home');
    },
  );
}
