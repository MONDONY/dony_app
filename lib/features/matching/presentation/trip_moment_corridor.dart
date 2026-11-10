import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/video_modal/data/models/video_modal_corridor.dart';

/// Corridor d'un trajet pour les moments d'action des modals : villes et pays
/// de départ et d'arrivée, comparés aux corridors des campagnes.
VideoModalMomentCorridor tripMomentCorridor(AnnouncementModel trip) =>
    VideoModalMomentCorridor(
      fromCity: trip.departureCity,
      fromCountryCode: trip.departureCountryCode,
      toCity: trip.arrivalCity,
      toCountryCode: trip.arrivalCountryCode,
    );
