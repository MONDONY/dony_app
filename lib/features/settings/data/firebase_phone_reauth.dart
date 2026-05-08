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
        await FirebaseAuth.instance.currentUser
            ?.reauthenticateWithCredential(credential);
        await FirebaseAuth.instance.currentUser?.getIdToken(true);
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
    if (verificationId == 'AUTO') return; // auto-retrieved on Android
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    await FirebaseAuth.instance.currentUser
        ?.reauthenticateWithCredential(credential);
    await FirebaseAuth.instance.currentUser?.getIdToken(true);
  }
}
