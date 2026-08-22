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

  /// Pose la session Firebase courante.
  ///
  /// `isAnonymous` distingue les deux cas que `currentUser != null` confondait :
  /// un utilisateur réel (inscrit) et un visiteur en session anonyme. Le mock
  /// est construit hors du `when` qui le renvoie, sinon mocktail refuse le
  /// stub imbriqué.
  void givenSession({required bool anonymous}) {
    final user = _MockUser();
    when(() => user.isAnonymous).thenReturn(anonymous);
    when(() => auth.currentUser).thenReturn(user);
  }

  test('session Firebase + code local → /auth/local', () async {
    givenSession(anonymous: false);
    when(localAuth.isPinSet).thenAnswer((_) async => true);
    expect(await resolve(), '/auth/local');
  });

  test('session Firebase sans code local → /home directement', () async {
    givenSession(anonymous: false);
    expect(await resolve(), '/home');
  });

  test(
    'ne dépend jamais du backend : aucun appel réseau, résolution immédiate',
    () async {
      givenSession(anonymous: false);
      // Le seul await est la lecture du secure storage (mockée) : la
      // résolution ne doit pas attendre un health check.
      expect(await resolve().timeout(const Duration(seconds: 1)), '/home');
    },
  );

  test('session anonyme : ne compte pas comme un utilisateur connecté', () async {
    givenSession(anonymous: true);

    // Un visiteur qui relance l'application doit revoir l'onboarding ou
    // l'écran de connexion, exactement comme avant sa session anonyme.
    expect(await resolve(), isNot('/home'));
  });

  test('session anonyme sans onboarding vu → /onboarding', () async {
    givenSession(anonymous: true);
    expect(await resolve(), '/onboarding');
  });

  test('session anonyme mais onboarding déjà vu → /auth/method', () async {
    when(
      () => prefs.get('onboarding_done', defaultValue: false),
    ).thenReturn(true);
    givenSession(anonymous: true);
    expect(await resolve(), '/auth/method');
  });

  test(
    'session anonyme + code local : le code local ne rouvre pas la session',
    () async {
      // Un visiteur peut hériter d'un code local posé par un compte
      // précédemment déconnecté sur cet appareil. Ce code ne doit pas servir
      // de laissez-passer : sans compte, il n'y a pas de session à rouvrir.
      givenSession(anonymous: true);
      when(localAuth.isPinSet).thenAnswer((_) async => true);
      expect(await resolve(), '/onboarding');
    },
  );
}
