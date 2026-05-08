import 'dart:async';
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
    if (phone == null) throw Exception('No phone number on current user');

    final completer = Completer<String>();
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (PhoneAuthCredential credential) async {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          if (!completer.isCompleted) completer.completeError(Exception('No authenticated user'));
          return;
        }
        await user.reauthenticateWithCredential(credential);
        await user.getIdToken(true);
        if (!completer.isCompleted) completer.complete('AUTO');
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      codeSent: (String verificationId, int? _) {
        if (!completer.isCompleted) completer.complete(verificationId);
      },
      codeAutoRetrievalTimeout: (_) {},
    );
    return completer.future;
  }

  @override
  Future<void> reauthenticate(String verificationId, String smsCode) async {
    if (verificationId == 'AUTO') return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('No authenticated user for reauthentication');
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    await user.reauthenticateWithCredential(credential);
    await user.getIdToken(true);
  }
}
