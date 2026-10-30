import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/stripe_account/presentation/effective_stripe_status.dart';
import 'package:flutter_test/flutter_test.dart';

UserModel _user(String stripeAccountStatus) => UserModel(
  id: 'u1',
  roles: const [],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
  stripeAccountStatus: stripeAccountStatus,
);

void main() {
  group('effectiveStripeStatus', () {
    test('bloc chargé : son statut fait foi', () {
      expect(
        effectiveStripeStatus(
          _user('NOT_CREATED'),
          const StripeAccountReady(
            ConnectAccountStatus(status: 'ONBOARDING_COMPLETE'),
          ),
        ),
        'ONBOARDING_COMPLETE',
      );
    });

    test('bloc pas encore chargé : repli sur le profil', () {
      expect(
        effectiveStripeStatus(
          _user('ONBOARDING_COMPLETE'),
          const StripeAccountInitial(),
        ),
        'ONBOARDING_COMPLETE',
      );
    });

    test('ni bloc ni profil : compte jamais créé', () {
      expect(
        effectiveStripeStatus(null, const StripeAccountInitial()),
        'NOT_CREATED',
      );
    });
  });
}
