// Constructeurs appelés à l'exécution : un appel `const` n'est jamais exécuté.
// ignore_for_file: prefer_const_constructors

import 'package:dony/features/ratings/bloc/rating_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notation expéditeur et voyageur : mêmes champs, types distincts', () {
    final sender = RatingSubmitRequested(
      bidId: 'b-1',
      stars: 5,
      comment: 'Top',
    );
    final traveler = TravelerRatingSubmitRequested(bidId: 'b-1', stars: 4);
    expect((sender.bidId, sender.stars, sender.comment), ('b-1', 5, 'Top'));
    expect(
      (traveler.bidId, traveler.stars, traveler.comment),
      ('b-1', 4, null),
    );
    expect(sender.runtimeType, isNot(traveler.runtimeType));
  });

  test('vérification des notations en attente : événement sans champ', () {
    expect(PendingRatingChecked(), isA<RatingEvent>());
  });
}
