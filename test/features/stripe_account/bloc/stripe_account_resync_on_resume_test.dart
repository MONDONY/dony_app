import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Au retour au premier plan, `POST /payments/connect/refresh` interroge Stripe
/// (≈ 400 ms côté serveur). Il n'a d'intérêt que pour un compte dont le statut
/// peut encore changer : inscription en cours ou compte suspendu.
void main() {
  StripeAccountState ready(String status, {bool available = true}) =>
      StripeAccountReady(
        ConnectAccountStatus(
          status: status,
          connectAvailableInCountry: available,
        ),
      );

  group('shouldResyncOnResume', () {
    test('inscription en cours : oui', () {
      expect(ready('PENDING_ONBOARDING').shouldResyncOnResume, isTrue);
    });

    test('compte suspendu : oui', () {
      expect(ready('DISABLED').shouldResyncOnResume, isTrue);
    });

    test('compte complet : non, le webhook account.updated suffit', () {
      expect(ready('ONBOARDING_COMPLETE').shouldResyncOnResume, isFalse);
    });

    test('aucun compte : non, le serveur répondrait 409', () {
      expect(ready('NOT_CREATED').shouldResyncOnResume, isFalse);
    });

    test('compte refusé : non', () {
      expect(ready('REJECTED').shouldResyncOnResume, isFalse);
    });

    test('pays sans Connect : non', () {
      expect(
        ready('PENDING_ONBOARDING', available: false).shouldResyncOnResume,
        isFalse,
      );
    });

    test('statut pas encore chargé : non', () {
      expect(const StripeAccountInitial().shouldResyncOnResume, isFalse);
      expect(const StripeAccountLoading().shouldResyncOnResume, isFalse);
    });

    test('chargement en échec : oui, pour retenter', () {
      expect(const StripeAccountLoadError().shouldResyncOnResume, isTrue);
    });
  });
}
