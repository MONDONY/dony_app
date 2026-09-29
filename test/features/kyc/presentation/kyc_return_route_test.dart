import 'package:dony/features/kyc/presentation/kyc_return_route.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('kycReturnRouteOrNull', () {
    test('garde les écrans de publication', () {
      expect(
        kycReturnRouteOrNull('/trips/publish-intro'),
        '/trips/publish-intro',
      );
      expect(
        kycReturnRouteOrNull('/parcels/send-intro'),
        '/parcels/send-intro',
      );
    });

    test('refuse tout le reste (extra requis, lien forgé, externe)', () {
      expect(kycReturnRouteOrNull(null), isNull);
      expect(kycReturnRouteOrNull('/bids/new'), isNull);
      expect(kycReturnRouteOrNull('https://evil.example'), isNull);
      expect(kycReturnRouteOrNull('//evil.example'), isNull);
      expect(kycReturnRouteOrNull('/trips/publish-intro?x=1'), isNull);
    });
  });

  group('kycVerifyLocation', () {
    test('sans marqueur : route nue, comme avant', () {
      expect(kycVerifyLocation(fromOnboarding: false), '/kyc/verify');
    });

    test('onboarding seul : même query qu\'onboardingEntrySuffix', () {
      expect(
        kycVerifyLocation(fromOnboarding: true),
        '/kyc/verify?from=onboarding',
      );
    });

    test('écran de retour autorisé : transporté et relisible', () {
      final location = kycVerifyLocation(
        fromOnboarding: false,
        returnTo: '/parcels/send-intro',
      );
      final uri = Uri.parse(location);
      expect(uri.path, '/kyc/verify');
      expect(uri.queryParameters[kycReturnParam], '/parcels/send-intro');
    });

    test('écran de retour refusé : ignoré', () {
      expect(
        kycVerifyLocation(fromOnboarding: false, returnTo: '/bids/new'),
        '/kyc/verify',
      );
    });
  });
}
