import 'package:dony/core/config/sms_auth_flag.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => setSmsAuthEnabled(kSmsAuthEnabledDefault));

  test('defaults to false (masqué) tant que le backend n\'a pas répondu', () {
    expect(smsAuthEnabledListenable.value, kSmsAuthEnabledDefault);
    expect(kSmsAuthEnabledDefault, isFalse);
  });

  test('setSmsAuthEnabled met à jour le flag et notifie les listeners', () {
    var notified = false;
    smsAuthEnabledListenable.addListener(() => notified = true);

    setSmsAuthEnabled(true);

    expect(smsAuthEnabledListenable.value, isTrue);
    expect(notified, isTrue);
  });
}
