import 'package:dony/features/payments/data/models/connect_account_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConnectAccountModel', () {
    test('fromJson parses stripeAccountId and derives stripeOnboarded', () {
      final json = {
        'stripeAccountId': 'acct_123',
        'stripeAccountStatus': 'ONBOARDING_COMPLETE',
      };
      final m = ConnectAccountModel.fromJson(json);
      expect(m.stripeAccountId, 'acct_123');
      expect(m.stripeOnboarded, isTrue);
    });

    test('stripeOnboarded is false for any non-complete status', () {
      final json = {
        'stripeAccountId': 'acct_123',
        'stripeAccountStatus': 'PENDING_ONBOARDING',
      };
      final m = ConnectAccountModel.fromJson(json);
      expect(m.stripeOnboarded, isFalse);
    });

    test('fromJson parses requirementsCurrentlyDue', () {
      final json = {
        'stripeAccountId': 'acct_123',
        'stripeAccountStatus': 'PENDING_ONBOARDING',
        'requirementsCurrentlyDue': ['external_account'],
      };
      final m = ConnectAccountModel.fromJson(json);
      expect(m.requirementsCurrentlyDue, {'external_account'});
    });

    test('fromJson defaults requirementsCurrentlyDue to empty set when absent', () {
      final json = {
        'stripeAccountId': 'acct_123',
        'stripeAccountStatus': 'ONBOARDING_COMPLETE',
      };
      final m = ConnectAccountModel.fromJson(json);
      expect(m.requirementsCurrentlyDue, isEmpty);
    });
  });
}
