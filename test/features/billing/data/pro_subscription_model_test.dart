import 'package:dony/features/billing/data/models/pro_subscription_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProSubscriptionModel.fromJson', () {
    test('abonnement mensuel actif complet', () {
      final model = ProSubscriptionModel.fromJson(const {
        'active': true,
        'status': 'ACTIVE',
        'source': 'STRIPE',
        'billingCycle': 'MONTHLY',
        'currentPeriodEnd': '2026-09-28T00:00:00Z',
        'cancelAtPeriodEnd': false,
        'graceExpiresAt': null,
      });

      expect(model.active, isTrue);
      expect(model.status, ProSubscriptionStatus.active);
      expect(model.source, ProSubscriptionSource.stripe);
      expect(model.billingCycle, 'MONTHLY');
      expect(model.currentPeriodEnd, DateTime.parse('2026-09-28T00:00:00Z'));
      expect(model.currentPeriodEnd!.isUtc, isTrue);
      expect(model.cancelAtPeriodEnd, isFalse);
      expect(model.graceExpiresAt, isNull);
    });

    test('absence d\'abonnement', () {
      final model = ProSubscriptionModel.fromJson(const {
        'active': false,
        'status': 'NONE',
        'source': null,
        'billingCycle': null,
        'currentPeriodEnd': null,
        'cancelAtPeriodEnd': false,
        'graceExpiresAt': null,
      });

      expect(model.active, isFalse);
      expect(model.status, ProSubscriptionStatus.none);
      expect(model.source, isNull);
    });

    test('grâce historique', () {
      final model = ProSubscriptionModel.fromJson(const {
        'active': true,
        'status': 'LEGACY_GRACE',
        'source': 'LEGACY_FREE',
        'billingCycle': null,
        'currentPeriodEnd': null,
        'cancelAtPeriodEnd': false,
        'graceExpiresAt': '2026-09-15T00:00:00Z',
      });

      expect(model.status, ProSubscriptionStatus.legacyGrace);
      expect(model.source, ProSubscriptionSource.legacyFree);
      expect(model.billingCycle, isNull);
      expect(model.graceExpiresAt, DateTime.parse('2026-09-15T00:00:00Z'));
    });

    test(
      'impayé : active est lu du JSON, pas dérivé du statut',
      () {
        final model = ProSubscriptionModel.fromJson(const {
          'active': true,
          'status': 'PAST_DUE',
          'source': 'STRIPE',
          'billingCycle': 'MONTHLY',
          'currentPeriodEnd': '2026-09-01T00:00:00Z',
          'cancelAtPeriodEnd': false,
          'graceExpiresAt': null,
        });

        expect(model.status, ProSubscriptionStatus.pastDue);
        expect(model.active, isTrue);
      },
    );

    test('octroi administrateur', () {
      final model = ProSubscriptionModel.fromJson(const {
        'active': true,
        'status': 'ACTIVE',
        'source': 'ADMIN_GRANT',
        'billingCycle': null,
        'currentPeriodEnd': '2026-12-31T00:00:00Z',
        'cancelAtPeriodEnd': false,
        'graceExpiresAt': null,
      });

      expect(model.source, ProSubscriptionSource.adminGrant);
      expect(model.billingCycle, isNull);
    });

    test('statut et source inconnus retombent sur unknown sans exception', () {
      final model = ProSubscriptionModel.fromJson(const {
        'active': false,
        'status': 'SOMETHING_NEW',
        'source': 'SOMETHING_ELSE',
        'billingCycle': null,
        'currentPeriodEnd': null,
        'cancelAtPeriodEnd': false,
        'graceExpiresAt': null,
      });

      expect(model.status, ProSubscriptionStatus.unknown);
      expect(model.source, ProSubscriptionSource.unknown);
    });

    test('champs absents plutôt que nuls ne lève pas', () {
      final model = ProSubscriptionModel.fromJson(const {
        'active': false,
        'status': 'NONE',
      });

      expect(model.active, isFalse);
      expect(model.status, ProSubscriptionStatus.none);
      expect(model.source, isNull);
      expect(model.billingCycle, isNull);
      expect(model.currentPeriodEnd, isNull);
      expect(model.cancelAtPeriodEnd, isFalse);
      expect(model.graceExpiresAt, isNull);
    });
  });

  group('ProSubscriptionModel Equatable', () {
    test('deux modèles construits des mêmes valeurs sont égaux', () {
      const a = ProSubscriptionModel(
        active: true,
        status: ProSubscriptionStatus.active,
        source: ProSubscriptionSource.stripe,
        billingCycle: 'MONTHLY',
        currentPeriodEnd: null,
        cancelAtPeriodEnd: false,
        graceExpiresAt: null,
      );
      const b = ProSubscriptionModel(
        active: true,
        status: ProSubscriptionStatus.active,
        source: ProSubscriptionSource.stripe,
        billingCycle: 'MONTHLY',
        currentPeriodEnd: null,
        cancelAtPeriodEnd: false,
        graceExpiresAt: null,
      );

      expect(a, equals(b));
    });
  });
}
