import 'package:dony/features/traveler_status/data/publishing_eligibility.dart';
import 'package:dony/features/traveler_status/data/traveler_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PublishingReason', () {
    test('lit les quatre valeurs du contrat', () {
      expect(PublishingReason.fromWire('OK'), PublishingReason.ok);
      expect(
        PublishingReason.fromWire('STATUS_REQUIRED'),
        PublishingReason.statusRequired,
      );
      expect(
        PublishingReason.fromWire('LIMIT_REACHED'),
        PublishingReason.limitReached,
      );
      expect(
        PublishingReason.fromWire('GP_PRO_PENDING'),
        PublishingReason.gpProPending,
      );
    });

    test('valeur inconnue ou absente : OK, jamais de blocage', () {
      expect(PublishingReason.fromWire('FUTURE_REASON'), PublishingReason.ok);
      expect(PublishingReason.fromWire(null), PublishingReason.ok);
      expect(PublishingReason.fromWire(''), PublishingReason.ok);
    });

    test('les trois codes 403 de publication donnent leur raison', () {
      expect(
        PublishingReason.fromErrorCode('traveler-status-required'),
        PublishingReason.statusRequired,
      );
      expect(
        PublishingReason.fromErrorCode('monthly-limit-reached'),
        PublishingReason.limitReached,
      );
      expect(
        PublishingReason.fromErrorCode('gp-pro-pending'),
        PublishingReason.gpProPending,
      );
    });

    test('un autre code n\'est pas un blocage de publication', () {
      expect(PublishingReason.fromErrorCode('pro-limit-reached'), isNull);
      expect(PublishingReason.fromErrorCode(null), isNull);
    });
  });

  group('PublishingEligibility.fromJson', () {
    test('limite atteinte, particulier', () {
      final e = PublishingEligibility.fromJson(const {
        'allowed': false,
        'reason': 'LIMIT_REACHED',
        'limit': 4,
        'used': 4,
        'resetsOn': '2026-12-01',
        'travelerStatus': 'INDIVIDUAL',
      });
      expect(e.allowed, isFalse);
      expect(e.reason, PublishingReason.limitReached);
      expect(e.limit, 4);
      expect(e.used, 4);
      expect(e.resetsOn, DateTime(2026, 12));
      expect(e.travelerStatus, TravelerStatus.individual);
    });

    test('OK : limite nulle, statut nul', () {
      final e = PublishingEligibility.fromJson(const {
        'allowed': true,
        'reason': 'OK',
        'limit': null,
        'used': 2,
        'resetsOn': '2026-12-01',
        'travelerStatus': null,
      });
      expect(e.allowed, isTrue);
      expect(e.limit, isNull);
      expect(e.travelerStatus, isNull);
    });

    test('allowed suit la raison, pas le champ allowed', () {
      final e = PublishingEligibility.fromJson(const {
        'allowed': true,
        'reason': 'STATUS_REQUIRED',
      });
      expect(e.allowed, isFalse);
      final ok = PublishingEligibility.fromJson(const {
        'allowed': false,
        'reason': 'OK',
      });
      expect(ok.allowed, isTrue);
    });

    test('réponse vide ou champs illisibles : OK sans exception', () {
      final e = PublishingEligibility.fromJson(const {});
      expect(e.allowed, isTrue);
      expect(e.reason, PublishingReason.ok);
      expect(e.used, 0);
      expect(e.resetsOn, isNull);

      final bad = PublishingEligibility.fromJson(const {
        'reason': 'LIMIT_REACHED',
        'limit': 'beaucoup',
        'used': null,
        'resetsOn': 'demain',
        'travelerStatus': 'ROBOT',
      });
      expect(bad.reason, PublishingReason.limitReached);
      expect(bad.limit, isNull);
      expect(bad.resetsOn, isNull);
      expect(bad.travelerStatus, isNull);
    });
  });

  group('PublishingEligibility.blockedBy', () {
    test('construit depuis un code 403, reprise le 1er du mois suivant', () {
      final e = PublishingEligibility.blockedBy(
        PublishingReason.limitReached,
        now: DateTime(2026, 11, 10),
      );
      expect(e.allowed, isFalse);
      expect(e.reason, PublishingReason.limitReached);
      expect(e.limit, isNull);
      expect(e.resetsOn, DateTime(2026, 12));
    });

    test('décembre : reprise en janvier de l\'année suivante', () {
      final e = PublishingEligibility.blockedBy(
        PublishingReason.statusRequired,
        now: DateTime(2026, 12, 20),
      );
      expect(e.resetsOn, DateTime(2027));
    });
  });

  test('PublishingEligibility.ok est autorisé', () {
    expect(PublishingEligibility.ok.allowed, isTrue);
    expect(PublishingEligibility.ok.reason, PublishingReason.ok);
  });
}
