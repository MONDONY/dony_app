import 'dart:async';

import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';

/// Une personne ouvre le détail d'un trajet (feuille expéditeur) : le back la
/// compte pour l'audience du voyageur, et `announcement_viewed` part vers
/// l'analytics.
///
/// - Le voyageur sur son propre trajet n'est jamais compté.
/// - Un invité (`viewerId` nul, aucun compte côté back) n'est pas compté par le
///   back, mais l'event analytics part : il mesure l'entonnoir visiteur.
/// - Rien n'est attendu ni remonté : l'affichage du trajet ne dépend jamais de
///   ce signalement. Les services absents (tests, points d'entrée isolés) sont
///   simplement sautés, comme dans `confirm_bid_payment.dart`.
void recordTripView(
  AnnouncementModel announcement, {
  required String? viewerId,
}) {
  if (viewerId == announcement.travelerId) {
    return;
  }
  if (getIt.isRegistered<AnalyticsService>()) {
    unawaited(
      getIt<AnalyticsService>().logEvent(
        AnalyticsEvents.announcementViewed,
        properties: {
          'announcement_id': announcement.id,
          'corridor':
              '${announcement.departureCity}→${announcement.arrivalCity}',
        },
      ),
    );
  }
  if (viewerId == null || !getIt.isRegistered<AnnouncementRepository>()) {
    return;
  }
  unawaited(_send(getIt<AnnouncementRepository>(), announcement.id));
}

Future<void> _send(AnnouncementRepository repository, String id) async {
  try {
    await repository.recordView(id);
  } catch (_) {
    // Hors ligne, back ancien sans la route : la vue est perdue, jamais l'écran.
  }
}
