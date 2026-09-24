import 'package:dony/features/package_request/presentation/request_screen_case.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/request_status_pill.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  test('libellés', () {
    expect(requestPillFor(fr, RequestScreenCase.draft).label, 'Brouillon');
    expect(requestPillFor(fr, RequestScreenCase.noOffers).label, 'En ligne');
    expect(
      requestPillFor(fr, RequestScreenCase.noTravelers).tone,
      RequestPillTone.live,
    );
    expect(
      requestPillFor(fr, RequestScreenCase.offersReceived, count: 1).label,
      '1 offre',
    );
    expect(
      requestPillFor(fr, RequestScreenCase.offersReceived, count: 2).label,
      '2 offres',
    );
    expect(
      requestPillFor(fr, RequestScreenCase.firmCandidates, count: 2).label,
      '2 candidats',
    );
    expect(
      requestPillFor(fr, RequestScreenCase.cashCommissionPending).tone,
      RequestPillTone.warning,
    );
    expect(
      requestPillFor(fr, RequestScreenCase.toFinalize).label,
      'À finaliser',
    );
    expect(requestPillFor(fr, RequestScreenCase.accepted).label, 'Confirmée');
    expect(requestPillFor(fr, RequestScreenCase.delivered).label, 'Livrée');
    expect(requestPillFor(fr, RequestScreenCase.expired).label, 'Expirée');
    expect(
      requestPillFor(fr, RequestScreenCase.cancelled).tone,
      RequestPillTone.danger,
    );
  });

  test('libellés en anglais', () {
    expect(requestPillFor(en, RequestScreenCase.draft).label, 'Draft');
    expect(
      requestPillFor(en, RequestScreenCase.offersReceived, count: 1).label,
      '1 offer',
    );
    expect(
      requestPillFor(en, RequestScreenCase.offersReceived, count: 2).label,
      '2 offers',
    );
    expect(
      requestPillFor(en, RequestScreenCase.firmCandidates, count: 1).label,
      '1 interested traveler',
    );
    expect(
      requestPillFor(en, RequestScreenCase.firmCandidates, count: 2).label,
      '2 interested travelers',
    );
    expect(requestPillFor(en, RequestScreenCase.cancelled).label, 'Canceled');
  });
}
