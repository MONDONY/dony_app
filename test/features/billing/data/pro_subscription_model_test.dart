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

    test(
      'clé active absente ne lève pas et retombe sur false',
      () {
        // Réponse dégradée (bug backend, proxy qui tronque) : la clé
        // `active` manque entièrement, contrairement au cas ci-dessus où
        // elle valait explicitement `false`. `false` est le bon repli :
        // il fait taire le bandeau PRO plutôt que d'affirmer un état non
        // prouvé par le serveur.
        final model = ProSubscriptionModel.fromJson(const {
          'status': 'NONE',
        });

        expect(model.active, isFalse);
        expect(model.status, ProSubscriptionStatus.none);
      },
    );

    test(
      'active provient du JSON même quand le statut vaudrait ACTIVE : '
      'payload volontairement incohérente pour exclure toute dérivation',
      () {
        // Ce payload ne décrit aucun état réel du serveur (status ACTIVE
        // avec active=false n'arrive jamais en pratique). Il sert
        // uniquement à prouver que le modèle transcrit `active` au lieu
        // de le recalculer à partir de `status` (ex. une règle du type
        // "actif si status ∈ {ACTIVE, PAST_DUE, LEGACY_GRACE}", qui
        // passerait à tort le test "impayé" plus haut sans jamais lire
        // le champ JSON). Ne pas "corriger" cette incohérence.
        final model = ProSubscriptionModel.fromJson(const {
          'active': false,
          'status': 'ACTIVE',
          'source': 'STRIPE',
          'billingCycle': 'MONTHLY',
          'currentPeriodEnd': '2026-09-28T00:00:00Z',
          'cancelAtPeriodEnd': false,
          'graceExpiresAt': null,
        });

        expect(model.active, isFalse);
      },
    );

    test(
      'active provient du JSON même quand le statut vaudrait CANCELED : '
      'payload volontairement incohérente pour exclure toute dérivation',
      () {
        // Symétrique du cas ci-dessus : status CANCELED avec active=true
        // ne décrit pas non plus un état réel. Ne pas "corriger".
        final model = ProSubscriptionModel.fromJson(const {
          'active': true,
          'status': 'CANCELED',
          'source': 'STRIPE',
          'billingCycle': 'MONTHLY',
          'currentPeriodEnd': '2026-09-28T00:00:00Z',
          'cancelAtPeriodEnd': false,
          'graceExpiresAt': null,
        });

        expect(model.active, isTrue);
      },
    );
  });

  group('ProSubscriptionModel Equatable', () {
    // Référence commune : chaque test d'inégalité ne fait varier qu'un seul
    // champ par rapport à celle-ci, pour prouver que `props` couvre bien
    // les sept champs un par un (un champ oublié dans `props` resterait
    // invisible à un simple test de réflexivité).
    const reference = ProSubscriptionModel(
      active: true,
      status: ProSubscriptionStatus.active,
      source: ProSubscriptionSource.stripe,
      billingCycle: 'MONTHLY',
      currentPeriodEnd: null,
      cancelAtPeriodEnd: false,
      graceExpiresAt: null,
    );

    test('deux modèles construits des mêmes valeurs sont égaux', () {
      const other = ProSubscriptionModel(
        active: true,
        status: ProSubscriptionStatus.active,
        source: ProSubscriptionSource.stripe,
        billingCycle: 'MONTHLY',
        currentPeriodEnd: null,
        cancelAtPeriodEnd: false,
        graceExpiresAt: null,
      );

      expect(reference, equals(other));
    });

    test('diffère sur active seul → inégaux', () {
      const other = ProSubscriptionModel(
        active: false,
        status: ProSubscriptionStatus.active,
        source: ProSubscriptionSource.stripe,
        billingCycle: 'MONTHLY',
        currentPeriodEnd: null,
        cancelAtPeriodEnd: false,
        graceExpiresAt: null,
      );

      expect(reference, isNot(equals(other)));
    });

    test('diffère sur status seul → inégaux', () {
      const other = ProSubscriptionModel(
        active: true,
        status: ProSubscriptionStatus.canceled,
        source: ProSubscriptionSource.stripe,
        billingCycle: 'MONTHLY',
        currentPeriodEnd: null,
        cancelAtPeriodEnd: false,
        graceExpiresAt: null,
      );

      expect(reference, isNot(equals(other)));
    });

    test('diffère sur source seul → inégaux', () {
      const other = ProSubscriptionModel(
        active: true,
        status: ProSubscriptionStatus.active,
        source: ProSubscriptionSource.adminGrant,
        billingCycle: 'MONTHLY',
        currentPeriodEnd: null,
        cancelAtPeriodEnd: false,
        graceExpiresAt: null,
      );

      expect(reference, isNot(equals(other)));
    });

    test('diffère sur billingCycle seul → inégaux', () {
      const other = ProSubscriptionModel(
        active: true,
        status: ProSubscriptionStatus.active,
        source: ProSubscriptionSource.stripe,
        billingCycle: 'YEARLY',
        currentPeriodEnd: null,
        cancelAtPeriodEnd: false,
        graceExpiresAt: null,
      );

      expect(reference, isNot(equals(other)));
    });

    test('diffère sur currentPeriodEnd seul → inégaux', () {
      final other = ProSubscriptionModel(
        active: true,
        status: ProSubscriptionStatus.active,
        source: ProSubscriptionSource.stripe,
        billingCycle: 'MONTHLY',
        currentPeriodEnd: DateTime.parse('2026-09-28T00:00:00Z'),
        cancelAtPeriodEnd: false,
        graceExpiresAt: null,
      );

      expect(reference, isNot(equals(other)));
    });

    test('diffère sur cancelAtPeriodEnd seul → inégaux', () {
      const other = ProSubscriptionModel(
        active: true,
        status: ProSubscriptionStatus.active,
        source: ProSubscriptionSource.stripe,
        billingCycle: 'MONTHLY',
        currentPeriodEnd: null,
        cancelAtPeriodEnd: true,
        graceExpiresAt: null,
      );

      expect(reference, isNot(equals(other)));
    });

    test('diffère sur graceExpiresAt seul → inégaux', () {
      final other = ProSubscriptionModel(
        active: true,
        status: ProSubscriptionStatus.active,
        source: ProSubscriptionSource.stripe,
        billingCycle: 'MONTHLY',
        currentPeriodEnd: null,
        cancelAtPeriodEnd: false,
        graceExpiresAt: DateTime.parse('2026-09-15T00:00:00Z'),
      );

      expect(reference, isNot(equals(other)));
    });
  });
}
