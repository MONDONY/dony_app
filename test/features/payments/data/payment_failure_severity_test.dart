import 'package:dony/core/error/report_severity.dart';
import 'package:dony/features/payments/data/payment_gateway.dart';
import 'package:flutter_stripe/flutter_stripe.dart'
    show FailureCode, LocalizedErrorMessage, StripeException;
import 'package:flutter_test/flutter_test.dart';

/// FLUTTER-G5 : un refus de carte, attendu, remontait à Sentry comme un bug.
void main() {
  PaymentConfirmationException sdk({
    String? code,
    String? decline,
    String? type,
  }) => PaymentConfirmationException.fromStripe(
    null,
    stripeCode: 'Failed',
    stripeErrorCode: code,
    declineCode: decline,
    stripeErrorType: type,
  );

  group('refus de carte → attendu, cardDeclined', () {
    for (final code in PaymentConfirmationException.cardDeclineCodes) {
      test('code $code', () {
        final e = sdk(code: code);
        expect(e.isCardError, isTrue);
        expect(e.reportSeverity, ReportSeverity.expected);
        expect(classifyStripeFailure(e), StripeFailureKind.cardDeclined);
      });
      test('decline_code $code', () {
        final e = sdk(decline: code);
        expect(e.reportSeverity, ReportSeverity.expected);
        expect(classifyStripeFailure(e), StripeFailureKind.cardDeclined);
      });
    }

    test('type card_error seul', () {
      final e = sdk(type: 'card_error');
      expect(e.reportSeverity, ReportSeverity.expected);
      expect(classifyStripeFailure(e), StripeFailureKind.cardDeclined);
    });
  });

  group('échec 3-D Secure → attendu, authenticationFailed', () {
    for (final code
        in PaymentConfirmationException.authenticationFailureCodes) {
      test(code, () {
        final e = sdk(code: code, type: 'invalid_request_error');
        expect(e.isAuthenticationFailure, isTrue);
        expect(e.reportSeverity, ReportSeverity.expected);
        expect(
          classifyStripeFailure(e),
          StripeFailureKind.authenticationFailed,
        );
      });
    }

    test('authentication_required en card_error reste un échec 3-D Secure', () {
      final e = sdk(decline: 'authentication_required', type: 'card_error');
      expect(classifyStripeFailure(e), StripeFailureKind.authenticationFailed);
    });
  });

  group('autres échecs → remontés', () {
    for (final type in [
      'api_error',
      'invalid_request_error',
      'rate_limit_error',
      'authentication_error',
    ]) {
      test('type $type → error', () {
        final e = sdk(type: type);
        expect(e.reportSeverity, ReportSeverity.error);
        expect(classifyStripeFailure(e), StripeFailureKind.generic);
      });
    }

    test('code inconnu sans type → error', () {
      expect(
        sdk(code: 'resource_missing').reportSeverity,
        ReportSeverity.error,
      );
    });

    test('Failed sans aucun détail → warning, sheetUnavailable', () {
      final e = sdk();
      expect(e.hasNoStripeDetail, isTrue);
      expect(e.reportSeverity, ReportSeverity.warning);
      expect(classifyStripeFailure(e), StripeFailureKind.sheetUnavailable);
    });

    test('exception construite par l\'app → error, non issue du SDK', () {
      const e = PaymentConfirmationException('refusé');
      expect(e.isFromStripe, isFalse);
      expect(e.reportSeverity, ReportSeverity.error);
    });
  });

  group('stripeFailureContext', () {
    test('Failed nu → stripe_detail none', () {
      expect(stripeFailureContext(sdk()), {
        'stripe_detail': 'none',
        'stripe_code': 'Failed',
      });
    });

    test('codes présents → pas de stripe_detail', () {
      expect(
        stripeFailureContext(
          sdk(type: 'api_error'),
        ).containsKey('stripe_detail'),
        isFalse,
      );
    });
  });

  test('mapStripeException lit code, decline_code et type du SDK', () {
    final mapped =
        mapStripeException(
              const StripeException(
                error: LocalizedErrorMessage(
                  code: FailureCode.Failed,
                  localizedMessage: 'Votre carte a été refusée.',
                  stripeErrorCode: 'card_declined',
                  declineCode: 'do_not_honor',
                  type: 'card_error',
                ),
              ),
            )
            as PaymentConfirmationException;
    expect(mapped.message, isNull);
    expect(mapped.reportSeverity, ReportSeverity.expected);
    expect(stripeFailureContext(mapped), {
      'stripe_code': 'Failed',
      'stripe_error_code': 'card_declined',
      'decline_code': 'do_not_honor',
      'stripe_error_type': 'card_error',
    });
  });
}
