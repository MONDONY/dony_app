// Vérifie le garde-fou anonymat de AnalyticsConsentGate (correction ronde 1,
// Task 3) : une session Firebase invitée ("Parcourir sans compte") ne doit
// JAMAIS déclencher `identify()` (UID Firebase anonyme -> utilisateur
// identifié fantôme dans PostHog), ni `syncFromBackend()` (appelle
// `/auth/me/analytics-consent`, 404 pour un visiteur sans ligne backend),
// ni surtout la NAVIGATION vers l'entonnoir de consentement RGPD /
// inscription (`/auth/analytics-consent` -> country-selection ->
// referral-code) : sans ce dernier verrou, un visiteur en zone RGPD
// (Paris/Lyon/Marseille) est éjecté de l'accueil au moment même où il
// choisit "Parcourir sans compte" — le mode invité ne fonctionne plus du
// tout. C'est ce risque de navigation, pas seulement le tracking, que ce
// fichier verrouille en priorité (`navigate` injectable, cf. widget).
//
// Utilise un vrai Hive (comme `auth_bloc_test.dart`) car `.listenable()` est
// une extension sur `Box` que `Fake`/`Mock` ne peuvent pas reproduire
// fidèlement — plus simple et plus fidèle qu'un faux Box partiel.

import 'dart:async';
import 'dart:io';

import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/core/widgets/analytics_consent_gate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  late Directory tempDir;
  late HiveService hiveService;
  late MockAnalyticsService mockAnalytics;
  late MockFirebaseAuth mockFirebaseAuth;
  late StreamController<User?> authChanges;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'hive_analytics_consent_gate_test',
    );
    // `Hive.init` (pas `initFlutter`/`HiveService.init()`) : ce dernier
    // appelle `path_provider` via platform channel, indisponible en test
    // widget pur — même contournement que `auth_bloc_test.dart`.
    Hive.init(p.join(tempDir.path));
    await Hive.openBox(HiveService.userPrefsBox);
    hiveService = HiveService();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    await hiveService.userPrefs.clear();
    mockAnalytics = MockAnalyticsService();
    mockFirebaseAuth = MockFirebaseAuth();
    authChanges = StreamController<User?>.broadcast();
    when(
      () => mockFirebaseAuth.authStateChanges(),
    ).thenAnswer((_) => authChanges.stream);

    getIt.registerSingleton<AnalyticsService>(mockAnalytics);
    getIt.registerSingleton<HiveService>(hiveService);
  });

  tearDown(() async {
    await authChanges.close();
    await getIt.reset();
  });

  MockUser anonymousUser({String uid = 'anon-uid-1'}) {
    final user = MockUser();
    when(() => user.isAnonymous).thenReturn(true);
    when(() => user.uid).thenReturn(uid);
    return user;
  }

  testWidgets(
    'CRITIQUE : session invitee ne navigue JAMAIS vers l\'entonnoir '
    'consentement/inscription, et ne touche jamais AnalyticsService '
    '(ni identify, ni syncFromBackend, ni resolution de consentement, ni reset)',
    (tester) async {
      when(() => mockFirebaseAuth.currentUser).thenReturn(null);
      final navigated = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: AnalyticsConsentGate(
            firebaseAuth: mockFirebaseAuth,
            navigate: navigated.add,
            child: const SizedBox(),
          ),
        ),
      );
      await tester.pump();

      authChanges.add(anonymousUser());
      await tester.pump();
      await tester.pump();

      // Le vrai dégât produit, avant tout tracking : un visiteur en zone
      // RGPD éjecté vers /auth/analytics-consent (puis country-selection,
      // referral-code) au moment où il choisit "Parcourir sans compte".
      expect(
        navigated,
        isEmpty,
        reason:
            'une session invitee ne doit jamais declencher de navigation '
            '(GdprHelper.resolveConsentAction ne doit meme pas etre appele)',
      );

      // Aucune interaction avec AnalyticsService : ni identify(uid anonyme),
      // ni syncFromBackend() (donc aucun appel /auth/me/analytics-consent),
      // ni setConsent() (l'auto-octroi RGPD hors-zone ne doit pas non plus se
      // déclencher pour un visiteur), ni reset() (la transition est
      // null -> utilisateur anonyme, donc _onAuthChanged prend la branche
      // "login" et non la branche "logout" : reset() ne doit pas fuiter ici
      // non plus).
      verifyZeroInteractions(mockAnalytics);
    },
  );

  testWidgets('consentement modifie en session invitee : _onConsentChanged '
      "n'identifie jamais l'UID anonyme (second chemin du meme fichier)", (
    tester,
  ) async {
    final guest = anonymousUser();
    when(() => mockFirebaseAuth.currentUser).thenReturn(guest);
    final navigated = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: AnalyticsConsentGate(
          firebaseAuth: mockFirebaseAuth,
          navigate: navigated.add,
          child: const SizedBox(),
        ),
      ),
    );
    // Laisse le postFrameCallback exécuter _onAuthChanged(guest) -> _onLogin
    // -> retour anticipé (testé ci-dessus).
    await tester.pump();
    await tester.pump();

    // Simule un autre chemin qui changerait le flag Hive pendant que la
    // session reste anonyme (ex: écran RGPD atteint par erreur, réglages) :
    // même dans ce cas, _onConsentChanged doit refuser d'identifier.
    //
    // `tester.runAsync` est OBLIGATOIRE ici : une écriture Hive réelle est de
    // l'I/O disque véritable, qui n'avance jamais dans la zone FakeAsync
    // utilisée par `testWidgets` — sans ça, `await put(...)` bloque jusqu'au
    // timeout (piège déjà rencontré sur Scan & Suivi).
    when(() => mockAnalytics.isEnabled).thenReturn(true);
    await tester.runAsync(
      () => hiveService.userPrefs.put(HiveService.kAnalyticsConsent, true),
    );
    await tester.pump();
    await tester.pump();

    verifyNever(() => mockAnalytics.identify(any()));
    expect(navigated, isEmpty);
  });

  test('defaut de consentement : un visiteur qui n\'a jamais repondu reste '
      'non-trackable (isEnabled=false), aucun comportement explicite '
      'supplementaire requis', () async {
    // Démontre la réponse à la question du reviewer : `AnalyticsService`
    // considère le consentement `null` (jamais répondu, valeur par défaut
    // Hive) comme `hasAnswered=false` et donc `isEnabled=false` — le seul
    // état dans lequel une session invitée reste, puisque `_onLogin` ne la
    // fait plus jamais transiter par `setConsent`/`syncFromBackend`. Aucun
    // événement ni identify() ne peut donc fuiter, sans qu'il soit
    // nécessaire d'écrire un défaut explicite ailleurs.
    final real = AnalyticsService(hiveService);
    expect(real.consent, isNull);
    expect(real.hasAnswered, isFalse);
    expect(real.isEnabled, isFalse);
  });
}
