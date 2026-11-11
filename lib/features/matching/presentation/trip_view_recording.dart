import 'dart:async';

import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/matching/presentation/trip_moment_corridor.dart';
import 'package:dony/features/video_modal/data/video_modal_moments.dart';
import 'package:flutter/widgets.dart';

/// Une personne ouvre le détail d'un trajet (feuille expéditeur) : le back la
/// compte pour l'audience du voyageur, et `announcement_viewed` part vers
/// l'analytics.
///
/// - [origin] : l'écran de détail, pour que le modal « trajet consulté N fois »
///   s'ouvre dessus (et non au retour sur la liste).
/// - Le voyageur sur son propre trajet n'est jamais compté.
/// - Un invité (`viewerId` nul, aucun compte côté back) n'est pas compté par le
///   back, mais l'event analytics part : il mesure l'entonnoir visiteur.
/// - Rien n'est attendu ni remonté : l'affichage du trajet ne dépend jamais de
///   ce signalement. Les services absents (tests, points d'entrée isolés) sont
///   simplement sautés, comme dans `confirm_bid_payment.dart`.
void recordTripView(
  AnnouncementModel announcement, {
  required String? viewerId,
  BuildContext? origin,
}) {
  if (viewerId == announcement.travelerId) {
    return;
  }
  // Compteur local des consultations de ce trajet (moment « trajet consulté
  // N fois » des modals) : invités compris, aucun appel réseau.
  VideoModalMoments.notifyTripViewed(
    tripId: announcement.id,
    corridor: tripMomentCorridor(announcement),
    origin: origin,
  );
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
