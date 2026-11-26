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

    test('garde les retours qui rouvrent la saisie (resume=kyc)', () {
      expect(kycReturnRouteOrNull(kycResumeTripRoute), kycResumeTripRoute);
      expect(kycReturnRouteOrNull(kycResumeParcelRoute), kycResumeParcelRoute);
      expect(kycResumeTripRoute, '/trips/publish-intro?resume=kyc');
      expect(kycResumeParcelRoute, '/parcels/send-intro?resume=kyc');
    });

    test('kycReturnKeepsDraft : seulement pour les retours resume=kyc', () {
      expect(kycReturnKeepsDraft(kycResumeTripRoute), isTrue);
      expect(kycReturnKeepsDraft(kycResumeParcelRoute), isTrue);
      expect(kycReturnKeepsDraft('/trips/publish-intro'), isFalse);
      expect(kycReturnKeepsDraft(null), isFalse);
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
    test('sans écran de retour : route nue', () {
      expect(kycVerifyLocation(), kKycVerifyRoute);
      expect(kKycVerifyRoute, '/kyc/verify');
    });

    test('écran de retour autorisé : transporté et relisible', () {
      final location = kycVerifyLocation(returnTo: '/parcels/send-intro');
      final uri = Uri.parse(location);
      expect(uri.path, '/kyc/verify');
      expect(uri.queryParameters, {kycReturnParam: '/parcels/send-intro'});
    });

    test('retour resume=kyc : transporté encodé puis relu intact', () {
      final uri = Uri.parse(kycVerifyLocation(returnTo: kycResumeTripRoute));
      expect(
        kycReturnRouteOrNull(uri.queryParameters[kycReturnParam]),
        kycResumeTripRoute,
      );
    });

    test('écran de retour refusé : ignoré', () {
      expect(kycVerifyLocation(returnTo: '/bids/new'), '/kyc/verify');
    });
  });

  test('back : paramètre posé et relu, combiné au retour', () {
    final location = kycVerifyLocation(back: true);
    expect(Uri.parse(location).queryParameters, {kycBackParam: '1'});
    expect(kycBackRequested(Uri.parse(location).queryParameters), isTrue);
    expect(kycBackRequested(const {}), isFalse);
    expect(
      Uri.parse(
        kycVerifyLocation(returnTo: kycResumeTripRoute, back: true),
      ).queryParameters,
      {kycReturnParam: kycResumeTripRoute, kycBackParam: '1'},
    );
    expect(kycVerifyLocation(), kKycVerifyRoute);
  });
}
