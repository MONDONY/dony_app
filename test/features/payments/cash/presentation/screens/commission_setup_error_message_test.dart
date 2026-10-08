import 'package:dony/features/payments/cash/presentation/screens/commission_method_screen.dart';
import 'package:dony/features/payments/data/payment_gateway.dart';
import 'package:dony/l10n/generated/app_localizations_en.dart';
import 'package:dony/l10n/generated/app_localizations_fr.dart';
import 'package:flutter_test/flutter_test.dart';

/// FLUTTER-CJ : l'écran de carte de commission affichait le
/// `localizedMessage` brut de Stripe, y compris pour une erreur technique.
void main() {
  final fr = AppLocalizationsFr();
  final en = AppLocalizationsEn();

  const fragmentDestroyed = PaymentConfirmationException.fromStripe(
    null,
    stripeCode: 'Failed',
    stripeMessage: 'FragmentManager has been destroyed',
  );

  test('vrai refus carte → message du fournisseur', () {
    const e = PaymentConfirmationException.fromStripe(
      'Votre carte a été refusée.',
      stripeCode: 'Failed',
      stripeErrorType: 'card_error',
    );
    expect(
      commissionSetupErrorMessage(fr, e, opening: false),
      'Votre carte a été refusée.',
    );
  });

  test('refus carte sans message → libellé d\'ajout de carte', () {
    const e = PaymentConfirmationException.fromStripe(
      null,
      stripeCode: 'Failed',
      stripeErrorType: 'card_error',
    );
    expect(
      commissionSetupErrorMessage(fr, e, opening: false),
      fr.commissionCardAddErrorMessage,
    );
  });

  test('erreur locale du SDK → « n\'a pas pu s\'ouvrir », traduit', () {
    expect(
      commissionSetupErrorMessage(fr, fragmentDestroyed, opening: false),
      "Le paiement n'a pas pu s'ouvrir. Réessayez.",
    );
    expect(
      commissionSetupErrorMessage(en, fragmentDestroyed, opening: true),
      "The payment couldn't open. Please try again.",
    );
  });

  test('erreur typée hors carte après ouverture → libellé générique', () {
    const e = PaymentConfirmationException.fromStripe(
      null,
      stripeCode: 'Failed',
      stripeErrorType: 'api_error',
      stripeMessage: 'An error occurred with our API.',
    );
    expect(
      commissionSetupErrorMessage(fr, e, opening: false),
      fr.commissionCardAddErrorMessage,
    );
    // À l'ouverture, même typée, la feuille n'a pas pu s'ouvrir.
    expect(
      commissionSetupErrorMessage(fr, e, opening: true),
      fr.paymentSheetOpenFailed,
    );
  });

  group('stripeFailureContext', () {
    test('codes fermés et message tronqué à 200 caractères', () {
      final e = PaymentConfirmationException.fromStripe(
        null,
        stripeCode: 'Failed',
        stripeErrorCode: 'card_declined',
        declineCode: 'insufficient_funds',
        stripeErrorType: 'card_error',
        stripeMessage: 'x' * 250,
      );
      final context = stripeFailureContext(e);
      expect(context['stripe_code'], 'Failed');
      expect(context['stripe_error_code'], 'card_declined');
      expect(context['decline_code'], 'insufficient_funds');
      expect(context['stripe_error_type'], 'card_error');
      expect((context['stripe_message']! as String).length, 200);
    });

    test('champs absents omis', () {
      expect(stripeFailureContext(fragmentDestroyed), {
        'stripe_code': 'Failed',
        'stripe_message': 'FragmentManager has been destroyed',
      });
    });
  });
}
