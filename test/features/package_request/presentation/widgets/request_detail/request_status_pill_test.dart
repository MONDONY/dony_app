import 'package:dony/features/package_request/presentation/request_screen_case.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/request_status_pill.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('libellés', () {
    expect(requestPillFor(RequestScreenCase.draft).label, 'Brouillon');
    expect(requestPillFor(RequestScreenCase.noOffers).label, 'En ligne');
    expect(
      requestPillFor(RequestScreenCase.noTravelers).tone,
      RequestPillTone.live,
    );
    expect(
      requestPillFor(RequestScreenCase.offersReceived, count: 1).label,
      '1 offre',
    );
    expect(
      requestPillFor(RequestScreenCase.offersReceived, count: 2).label,
      '2 offres',
    );
    expect(
      requestPillFor(RequestScreenCase.firmCandidates, count: 2).label,
      '2 candidats',
    );
    expect(
      requestPillFor(RequestScreenCase.cashCommissionPending).tone,
      RequestPillTone.warning,
    );
    expect(requestPillFor(RequestScreenCase.toFinalize).label, 'À finaliser');
    expect(requestPillFor(RequestScreenCase.accepted).label, 'Confirmée');
    expect(requestPillFor(RequestScreenCase.delivered).label, 'Livrée');
    expect(requestPillFor(RequestScreenCase.expired).label, 'Expirée');
    expect(
      requestPillFor(RequestScreenCase.cancelled).tone,
      RequestPillTone.danger,
    );
  });
}
