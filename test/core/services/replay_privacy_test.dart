import 'dart:async';

import 'package:dony/core/services/replay_privacy.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeControl implements ReplayRecordingControl {
  int stops = 0;
  int resumes = 0;

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> resume() async => resumes++;
}

void main() {
  group('isReplaySensitivePath', () {
    test('connexion : numéro, code, e-mail, nom', () {
      for (final p in [
        '/auth/phone',
        '/auth/otp',
        '/auth/email',
        '/auth/email-otp',
        '/auth/personal-info',
        '/auth/referral-code',
      ]) {
        expect(isReplaySensitivePath(p), isTrue, reason: p);
      }
    });

    test('identité, paiement et portefeuille', () {
      for (final p in [
        '/kyc/verify',
        '/kyc/status',
        '/payments/wallet',
        '/payments/wallet/topup/amount',
        '/stripe/onboarding/complete',
        '/connect/onboarding/intro',
      ]) {
        expect(isReplaySensitivePath(p), isTrue, reason: p);
      }
    });

    test('messages, assistant, appels, litiges', () {
      for (final p in [
        '/conversations/abc',
        '/messages',
        '/messages/archives',
        '/support',
        '/support/tickets/42',
        '/assistant',
        '/calls/9',
        '/disputes/detail',
      ]) {
        expect(isReplaySensitivePath(p), isTrue, reason: p);
      }
    });

    test('colis en cours et leurs sous-écrans', () {
      for (final p in [
        '/bids/abc',
        '/bids/abc/accepted',
        '/bids/abc/negotiation',
        '/bids/abc/mobile-money/awaiting',
        '/colis/abc',
        '/receptions/abc',
        '/negotiations/abc',
        '/tracking/validate',
        '/tracking/scan/photo',
      ]) {
        expect(isReplaySensitivePath(p), isTrue, reason: p);
      }
    });

    test('compte : profil, coordonnées, adresses, réglages', () {
      for (final p in [
        '/profile',
        '/profile/edit',
        '/profile/edit/phone',
        '/profile/addresses',
        '/profile/addresses/add',
        '/profile/recipients',
        '/settings',
        '/settings/change-pin',
      ]) {
        expect(isReplaySensitivePath(p), isTrue, reason: p);
      }
    });

    test('écrans publics et de navigation : enregistrés', () {
      for (final p in [
        '/home',
        '/auth/method',
        '/auth/analytics-consent',
        '/auth/country-selection',
        '/announcements',
        '/announcements/abc/trip',
        '/bids/new',
        '/package-requests/new',
        '/trips/create',
        '/flights',
        '/favoris',
        '/onboarding',
        '/profile/community',
        '/profile/help/faq',
      ]) {
        expect(isReplaySensitivePath(p), isFalse, reason: p);
      }
    });

    test('un préfixe ne déborde pas sur un chemin voisin', () {
      expect(isReplaySensitivePath('/kycfoo'), isFalse);
      expect(isReplaySensitivePath('/messagesextra'), isFalse);
      expect(isReplaySensitivePath('/profile/communityx'), isFalse);
    });
  });

  group('ReplayPrivacyObserver', () {
    late _FakeControl control;
    late String? path;
    late bool consent;
    late StreamController<void> consentChanges;
    late ReplayPrivacyObserver observer;

    setUp(() {
      control = _FakeControl();
      path = '/home';
      consent = true;
      consentChanges = StreamController<void>.broadcast();
      observer = ReplayPrivacyObserver(
        currentPath: () => path,
        consentGranted: () => consent,
        control: control,
        consentChanges: () => consentChanges.stream,
      );
    });

    tearDown(() async {
      await observer.dispose();
      await consentChanges.close();
    });

    test('écran sensible : met en pause une seule fois', () {
      path = '/payments/wallet';
      observer.evaluate();
      observer.evaluate();
      expect(observer.isPaused, isTrue);
      expect(control.stops, 1);
      expect(control.resumes, 0);
    });

    test('retour sur un écran ordinaire : reprend si consentement', () {
      path = '/kyc/verify';
      observer.evaluate();
      path = '/home';
      observer.evaluate();
      expect(observer.isPaused, isFalse);
      expect(control.resumes, 1);
    });

    test('sans consentement : ne reprend jamais', () {
      path = '/kyc/verify';
      observer.evaluate();
      consent = false;
      path = '/home';
      observer.evaluate();
      expect(observer.isPaused, isFalse);
      expect(control.resumes, 0);
    });

    test('écran ordinaire de départ : rien à faire', () {
      observer.evaluate();
      expect(control.stops, 0);
      expect(control.resumes, 0);
    });

    test('chemin inconnu (null) : jamais de pause', () {
      path = null;
      observer.evaluate();
      expect(control.stops, 0);
    });

    test('un accord donné sur un écran sensible relance l\'arrêt', () async {
      path = '/settings';
      observer.evaluate();
      expect(control.stops, 1);
      consentChanges.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(control.stops, 2);
    });

    test('un accord donné sur un écran ordinaire ne coupe rien', () async {
      consentChanges.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(control.stops, 0);
    });

    test('service d\'analytics indisponible : ne plante pas, réessaie', () {
      var ready = false;
      final lazy = ReplayPrivacyObserver(
        currentPath: () => '/home',
        consentGranted: () => throw StateError('no service'),
        control: control,
        consentChanges: () {
          if (!ready) throw StateError('GetIt: not registered');
          return consentChanges.stream;
        },
      );
      expect(lazy.evaluate, returnsNormally);
      ready = true;
      expect(lazy.evaluate, returnsNormally);
      addTearDown(lazy.dispose);
    });

    test('chemin illisible : aucune pause, aucune exception', () {
      final broken = ReplayPrivacyObserver(
        currentPath: () => throw StateError('router pas prêt'),
        consentGranted: () => true,
        control: control,
      );
      expect(broken.evaluate, returnsNormally);
      expect(broken.isPaused, isFalse);
      expect(control.stops, 0);
    });

    test('reprise : un service qui échoue ne bloque pas l\'état', () {
      path = '/kyc/verify';
      observer.evaluate();
      final failing = ReplayPrivacyObserver(
        currentPath: () => path,
        consentGranted: () => throw StateError('boom'),
        control: control,
      );
      failing.evaluate();
      path = '/home';
      expect(failing.evaluate, returnsNormally);
    });

    testWidgets('navigation : pause à l\'entrée, reprise à la sortie', (
      tester,
    ) async {
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          navigatorKey: nav,
          navigatorObservers: [observer],
          onGenerateRoute: (settings) => PageRouteBuilder<void>(
            settings: settings,
            pageBuilder: (_, _, _) => const SizedBox(),
          ),
        ),
      );
      path = '/kyc/verify';
      unawaited(nav.currentState!.pushNamed('/kyc/verify'));
      await tester.pumpAndSettle();
      expect(control.stops, 1);

      path = '/home';
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      expect(control.resumes, 1);
    });
  });
}
