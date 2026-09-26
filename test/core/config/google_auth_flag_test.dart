import 'package:dony/core/config/google_auth_flag.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    debugEnvironmentOverride = null;
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'masqué sur Android en staging (clé App Signing Play = projet prod)',
    () {
      expect(
        isGoogleSignInAvailable(
          environment: 'staging',
          platform: TargetPlatform.android,
          isWeb: false,
        ),
        isFalse,
      );
    },
  );

  test('disponible sur iOS en staging', () {
    expect(
      isGoogleSignInAvailable(
        environment: 'staging',
        platform: TargetPlatform.iOS,
        isWeb: false,
      ),
      isTrue,
    );
  });

  test('disponible sur Android hors staging', () {
    for (final env in ['development', 'production']) {
      expect(
        isGoogleSignInAvailable(
          environment: env,
          platform: TargetPlatform.android,
          isWeb: false,
        ),
        isTrue,
        reason: env,
      );
    }
  });

  test('le web n\'est pas concerné, même en staging', () {
    expect(
      isGoogleSignInAvailable(
        environment: 'staging',
        platform: TargetPlatform.android,
        isWeb: true,
      ),
      isTrue,
    );
  });

  test(
    'googleSignInAvailable suit debugEnvironmentOverride et la plateforme',
    () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      debugEnvironmentOverride = 'staging';
      expect(googleSignInAvailable, isFalse);

      debugEnvironmentOverride = 'production';
      expect(googleSignInAvailable, isTrue);
    },
  );
}
