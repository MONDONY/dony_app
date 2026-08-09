import 'package:dony/core/models/connect_account_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConnectAccountStatus', () {
    test('isComplete returns true for ONBOARDING_COMPLETE', () {
      const s = ConnectAccountStatus(status: 'ONBOARDING_COMPLETE');
      expect(s.isComplete, isTrue);
    });

    test('needsOnboarding returns true for NOT_CREATED', () {
      const s = ConnectAccountStatus(status: 'NOT_CREATED');
      expect(s.needsOnboarding, isTrue);
    });

    test('needsOnboarding returns true for PENDING_ONBOARDING', () {
      const s = ConnectAccountStatus(status: 'PENDING_ONBOARDING');
      expect(s.needsOnboarding, isTrue);
    });

    test('isDisabled returns true for DISABLED', () {
      const s = ConnectAccountStatus(status: 'DISABLED');
      expect(s.isDisabled, isTrue);
    });

    test('isDisabled returns false for ONBOARDING_COMPLETE', () {
      const s = ConnectAccountStatus(status: 'ONBOARDING_COMPLETE');
      expect(s.isDisabled, isFalse);
    });

    test('isRejected returns true for REJECTED', () {
      const s = ConnectAccountStatus(status: 'REJECTED');
      expect(s.isRejected, isTrue);
    });

    test('isRejected returns false for ONBOARDING_COMPLETE', () {
      const s = ConnectAccountStatus(status: 'ONBOARDING_COMPLETE');
      expect(s.isRejected, isFalse);
    });

    test('fromJson parses status and reason', () {
      final json = {
        'stripeAccountId': 'acct_123',
        'stripeAccountStatus': 'REJECTED',
        'country': 'FR',
        'isProAccount': false,
        'reason': 'Documents invalides',
      };
      final s = ConnectAccountStatus.fromJson(json);
      expect(s.status, 'REJECTED');
      expect(s.reason, 'Documents invalides');
      expect(s.isRejected, isTrue);
    });

    test('fromJson defaults status to NOT_CREATED when absent', () {
      final s = ConnectAccountStatus.fromJson({});
      expect(s.status, 'NOT_CREATED');
    });

    test('needsOnboarding returns false for ONBOARDING_COMPLETE', () {
      const s = ConnectAccountStatus(status: 'ONBOARDING_COMPLETE');
      expect(s.needsOnboarding, isFalse);
    });

    test('fromJson parses isProAccount: true', () {
      final json = {'stripeAccountStatus': 'ONBOARDING_COMPLETE', 'isProAccount': true};
      final s = ConnectAccountStatus.fromJson(json);
      expect(s.isProAccount, isTrue);
    });

    test('fromJson handles null optional fields', () {
      final json = {'stripeAccountStatus': 'NOT_CREATED'};
      final s = ConnectAccountStatus.fromJson(json);
      expect(s.accountId, isNull);
      expect(s.country, isNull);
      expect(s.reason, isNull);
      expect(s.isProAccount, isFalse);
    });

    test('fromJson parses requirementsCurrentlyDue', () {
      final json = {
        'stripeAccountStatus': 'PENDING_ONBOARDING',
        'requirementsCurrentlyDue': ['external_account', 'individual.verification.document'],
      };
      final s = ConnectAccountStatus.fromJson(json);
      expect(s.requirementsCurrentlyDue, {
        'external_account',
        'individual.verification.document',
      });
    });

    test('fromJson defaults requirementsCurrentlyDue to empty set when absent', () {
      final s = ConnectAccountStatus.fromJson({'stripeAccountStatus': 'ONBOARDING_COMPLETE'});
      expect(s.requirementsCurrentlyDue, isEmpty);
    });
  });
}
