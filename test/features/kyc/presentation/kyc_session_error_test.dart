import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/kyc/presentation/kyc_session_error.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  group('isKycServiceUnavailable', () {
    test('503, serveur, hors ligne, délai, réseau : indisponible', () {
      for (final e in <AppException>[
        const ServiceUnavailableException(
          'Impossible de créer la session de vérification',
        ),
        const ServerException(),
        const OfflineException(),
        const TimeoutException(),
        const NetworkException('x'),
      ]) {
        expect(isKycServiceUnavailable(e), isTrue, reason: '$e');
      }
    });

    test('refus métier ou quota : pas une indisponibilité', () {
      expect(isKycServiceUnavailable(const RateLimitException()), isFalse);
      expect(isKycServiceUnavailable(const ForbiddenException('x')), isFalse);
    });
  });

  group('kycErrorMessage', () {
    const unavailable = ServiceUnavailableException(
      'Impossible de créer la session de vérification',
    );

    test('503 : message dédié, jamais le texte technique', () {
      final message = kycErrorMessage(fr, unavailable);
      expect(
        message,
        'La vérification d\'identité est momentanément indisponible. '
        'Réessayez dans quelques minutes.',
      );
      expect(message, isNot(contains('AppException')));
      expect(message, isNot(contains('session')));
    });

    test('saisie gardée en brouillon : le message le dit', () {
      expect(
        kycErrorMessage(fr, unavailable, draftSaved: true),
        'La vérification d\'identité est momentanément indisponible. '
        'Votre saisie est enregistrée : réessayez dans quelques minutes.',
      );
      expect(
        kycErrorMessage(en, const OfflineException(), draftSaved: true),
        'Identity verification is temporarily unavailable. Your entry is '
        'saved: please try again in a few minutes.',
      );
    });

    test('autre erreur : texte du catalogue', () {
      final message = kycErrorMessage(fr, const RateLimitException());
      expect(message, isNotEmpty);
      expect(message, isNot(contains('AppException')));
    });
  });
}
