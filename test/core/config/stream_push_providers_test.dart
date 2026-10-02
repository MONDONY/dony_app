import 'package:dony/core/config/stream_push_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hors production : fournisseurs push du Stream de staging', () {
    expect(streamAndroidPushProvider, 'firebase-staging');
    expect(streamIosPushProvider, 'apn-staging');
  });

  test('production : fournisseurs push du Stream de prod', () {
    expect(streamAndroidPushProviderFor('production'), 'firebase-prod');
    expect(streamIosPushProviderFor('production'), 'apn-prod');
    expect(streamAndroidPushProviderFor('staging'), 'firebase-staging');
    expect(streamIosPushProviderFor('development'), 'apn-staging');
  });
}
