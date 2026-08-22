import 'package:dony/core/services/firebase_session_probe.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockUser extends Mock implements User {}

void main() {
  late _MockFirebaseAuth auth;

  setUp(() => auth = _MockFirebaseAuth());

  test('aucune session : rien n\'est vrai', () {
    when(() => auth.currentUser).thenReturn(null);
    final probe = FirebaseSessionProbe(auth: auth);

    expect(probe.hasSession, isFalse);
    expect(probe.isAnonymous, isFalse);
    expect(probe.hasRealSession, isFalse);
  });

  test('session anonyme : session presente, invite, pas de session reelle', () {
    final user = _MockUser();
    when(() => user.isAnonymous).thenReturn(true);
    when(() => auth.currentUser).thenReturn(user);
    final probe = FirebaseSessionProbe(auth: auth);

    expect(probe.hasSession, isTrue);
    expect(probe.isAnonymous, isTrue);
    expect(probe.hasRealSession, isFalse);
  });

  test('session reelle : session presente, pas invite', () {
    final user = _MockUser();
    when(() => user.isAnonymous).thenReturn(false);
    when(() => auth.currentUser).thenReturn(user);
    final probe = FirebaseSessionProbe(auth: auth);

    expect(probe.hasSession, isTrue);
    expect(probe.isAnonymous, isFalse);
    expect(probe.hasRealSession, isTrue);
  });
}
