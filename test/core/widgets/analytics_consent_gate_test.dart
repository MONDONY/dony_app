// Vérifiez le garde-fou anonymat de AnalyticsConsentGate (correction ronde 1,
// Task 3) : une session Firebase invitée ("Parcourir sans compte") ne doit
// JAMAIS déclencher `identify()` (UID Firebase anonyme -> utilisateur
// identifié fantôme dans PostHog), ni `syncFromBackend()` (appelle
// `/auth/me/analytics-consent`, 404 pour un visiteur sans ligne backend),
// ni surtout une demande de consentement RGPD (aujourd'hui la feuille de
// l'accueil, autrefois un écran d'inscription) : sans ce dernier verrou, un
// visiteur en zone RGPD (Paris/Lyon/Marseille) est interrompu au moment même
// où il choisit "Parcourir sans compte". C'est ce risque de navigation, pas seulement le tracking, que ce
// fichier verrouille en priorité (la demande `ConsentPrompt` reste éteinte).
//
// Utilise un vrai Hive (comme `auth_bloc_test.dart`) car `.listenable()` est
// une extension sur `Box` que `Fake`/`Mock` ne peuvent pas reproduire
// fidèlement — plus simple et plus fidèle qu'un faux Box partiel.

import 'dart:async';
import 'dart:io';

import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/consent_prompt.dart';
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
  late ConsentPrompt consentPrompt;

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
    consentPrompt = ConsentPrompt();
    getIt.registerSingleton<ConsentPrompt>(consentPrompt);
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

  MockUser realUser() {
    final user = MockUser();
    when(() => user.isAnonymous).thenReturn(false);
    when(() => user.uid).thenReturn('uid-1');
    return user;
  }

  Future<void> logIn(
    WidgetTester tester,
    String country, {
    bool hasAnswered = false,
    bool alreadyPending = false,
  }) async {
    if (alreadyPending) consentPrompt.request();
    when(() => mockFirebaseAuth.currentUser).thenReturn(null);
    when(() => mockAnalytics.identify(any())).thenAnswer((_) async {});
    when(() => mockAnalytics.syncFromBackend()).thenAnswer((_) async {});
    when(() => mockAnalytics.isConfigured).thenReturn(true);
    when(() => mockAnalytics.hasAnswered).thenReturn(hasAnswered);
    when(
      () => mockAnalytics.setConsent(
        granted: any(named: 'granted'),
        source: any(named: 'source'),
      ),
    ).thenAnswer((_) async {});
    await tester.runAsync(
      () =>
          hiveService.userPrefs.put(HiveService.kDetectedCountryCode, country),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AnalyticsConsentGate(
          firebaseAuth: mockFirebaseAuth,
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pump();
    authChanges.add(realUser());
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  testWidgets('askConsent appelle ConsentPrompt.request et ne navigue plus', (
    tester,
  ) async {
    await logIn(tester, 'FR');

    expect(consentPrompt.wanted.value, isTrue);
    verifyNever(
      () => mockAnalytics.setConsent(
        granted: any(named: 'granted'),
        source: any(named: 'source'),
      ),
    );
  });

  testWidgets(
    'un compte qui a déjà répondu lève la demande laissée par un autre compte',
    (tester) async {
      await logIn(tester, 'FR', hasAnswered: true, alreadyPending: true);

      expect(consentPrompt.wanted.value, isFalse);
    },
  );

  testWidgets('la déconnexion lève la demande en attente', (tester) async {
    await logIn(tester, 'FR');
    expect(consentPrompt.wanted.value, isTrue);
    when(() => mockAnalytics.reset()).thenAnswer((_) async {});

    authChanges.add(null);
    await tester.pump();
    await tester.pump();

    expect(consentPrompt.wanted.value, isFalse);
    verify(() => mockAnalytics.reset()).called(1);
  });

  testWidgets('hors RGPD accorde automatiquement sans feuille', (tester) async {
    await logIn(tester, 'SN');

    expect(consentPrompt.wanted.value, isFalse);
    verify(
      () => mockAnalytics.setConsent(granted: true, source: 'auto_non_gdpr'),
    ).called(1);
  });

  testWidgets(
    'CRITIQUE : session invitee ne navigue JAMAIS vers l\'entonnoir '
    'consentement/inscription, et ne touche jamais AnalyticsService '
    '(ni identify, ni syncFromBackend, ni resolution de consentement, ni reset)',
    (tester) async {
      when(() => mockFirebaseAuth.currentUser).thenReturn(null);

      await tester.pumpWidget(
        MaterialApp(
          home: AnalyticsConsentGate(
            firebaseAuth: mockFirebaseAuth,
            child: const SizedBox(),
          ),
        ),
      );
      await tester.pump();

      authChanges.add(anonymousUser());
      await tester.pump();
      await tester.pump();

      // Le vrai dégât produit, avant tout tracking : un visiteur en zone
      // RGPD interrompu par une demande de consentement au moment où il
      // choisit "Parcourir sans compte".

      // Aucune interaction avec AnalyticsService : ni identify(uid anonyme),
      // ni syncFromBackend() (donc aucun appel /auth/me/analytics-consent),
      // ni setConsent() (l'auto-octroi RGPD hors-zone ne doit pas non plus se
      // déclencher pour un visiteur), ni reset() (la transition est
      // null -> utilisateur anonyme, donc _onAuthChanged prend la branche
      // "login" et non la branche "logout" : reset() ne doit pas fuiter ici
      // non plus).
      verifyZeroInteractions(mockAnalytics);
      expect(consentPrompt.wanted.value, isFalse);
    },
  );

  testWidgets('consentement modifie en session invitee : _onConsentChanged '
      "n'identifie jamais l'UID anonyme (second chemin du meme fichier)", (
    tester,
  ) async {
    final guest = anonymousUser();
    when(() => mockFirebaseAuth.currentUser).thenReturn(guest);

    await tester.pumpWidget(
      MaterialApp(
        home: AnalyticsConsentGate(
          firebaseAuth: mockFirebaseAuth,
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
