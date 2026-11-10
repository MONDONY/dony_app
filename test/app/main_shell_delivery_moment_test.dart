import 'package:dony/app/main_shell.dart';
import 'package:dony/features/ratings/bloc/rating_state.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/video_modal/moment_test_support.dart';

/// Livraison confirmée côté expéditeur : l'invite de note du shell émet le
/// moment ; côté voyageur, l'écran de succès de la livraison l'a déjà émis.
void main() {
  PendingRatingFound found({required bool isTravelerRating}) =>
      PendingRatingFound(
        bidId: 'b1',
        otherPartyName: 'Awa',
        otherPartyId: 'u2',
        isTravelerRating: isTravelerRating,
      );

  test(
    'note de l\'expéditeur en attente : un moment « livraison confirmée »',
    () {
      final moments = useRecordingMoments();
      notifyDeliveryMomentForRatingPrompt(found(isTravelerRating: false));
      expect(moments.triggers, [VideoModalTrigger.deliveryConfirmed]);
      expect(moments.origins.single, isNull);
    },
  );

  test('note du voyageur en attente : aucun moment (pas de doublon)', () {
    final moments = useRecordingMoments();
    notifyDeliveryMomentForRatingPrompt(found(isTravelerRating: true));
    expect(moments.emitted, isEmpty);
  });
}
