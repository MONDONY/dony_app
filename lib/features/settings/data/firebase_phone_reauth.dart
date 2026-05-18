import 'dart:async';
import 'package:dony/core/error/app_exception.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class FirebasePhoneReauth {
  String? get currentUserPhone;
  Future<String> sendVerificationCode();
  Future<void> reauthenticate(String verificationId, String smsCode);
}

class FirebasePhoneReauthImpl implements FirebasePhoneReauth {
  @override
  String? get currentUserPhone =>
      FirebaseAuth.instance.currentUser?.phoneNumber;

  @override
  Future<String> sendVerificationCode() async {
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber;
    if (phone == null) {
      throw const NetworkException(
        'Aucun numéro de téléphone associé à ce compte.',
        code: 'no-phone-number',
      );
    }

    final completer = Completer<String>();
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (PhoneAuthCredential credential) async {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          if (!completer.isCompleted) {
            completer.completeError(
              const NetworkException('Aucun utilisateur authentifié.'),
            );
          }
          return;
        }
        await user.reauthenticateWithCredential(credential);
        await user.getIdToken(true);
        if (!completer.isCompleted) {
          completer.complete('AUTO');
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!completer.isCompleted) {
          completer.completeError(_mapFirebaseError(e));
        }
      },
      codeSent: (String verificationId, int? _) {
        if (!completer.isCompleted) {
          completer.complete(verificationId);
        }
      },
      codeAutoRetrievalTimeout: (_) {},
    );
    return completer.future;
  }

  @override
  Future<void> reauthenticate(String verificationId, String smsCode) async {
    if (verificationId == 'AUTO') {
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const NetworkException('Aucun utilisateur authentifié.');
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    try {
      await user.reauthenticateWithCredential(credential);
      await user.getIdToken(true);
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseError(e);
    }
  }

  static AppException _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return const ValidationException(
          'Numéro de téléphone invalide.',
          code: 'invalid-phone-number',
        );
      case 'too-many-requests':
        return const RateLimitException(
          'Trop de tentatives d\'envoi de SMS. Réessaie dans quelques minutes.',
        );
      case 'quota-exceeded':
        return const RateLimitException(
          'Quota SMS dépassé. Réessaie plus tard.',
        );
      case 'network-request-failed':
        return const OfflineException(
          'Pas de connexion Internet. Vérifie ta connexion et réessaie.',
        );
      case 'invalid-verification-code':
      case 'invalid-verification-id':
        return const UnauthorizedException(
          'Code SMS incorrect. Vérifie le code reçu et réessaie.',
          'reauth-required',
        );
      case 'session-expired':
        return const UnauthorizedException(
          'Session expirée. Recommence la procédure de suppression.',
          'reauth-required',
        );
      default:
        return NetworkException(
          'Impossible d\'envoyer le code SMS. Réessaie dans un instant. (${e.code})',
          code: 'firebase-auth-error',
        );
    }
  }
}
