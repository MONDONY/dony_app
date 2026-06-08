import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';

const _confirmedStatuses = {'ACCEPTED', 'HANDED_OVER', 'IN_TRANSIT', 'COMPLETED'};
const _departedStatuses = {'HANDED_OVER', 'IN_TRANSIT', 'COMPLETED'};

class ScanHubProgress {
  const ScanHubProgress({
    required this.confirmedColis,
    required this.scannedDepart,
  });

  final int confirmedColis;
  final int scannedDepart;
}

/// Trajet à scanner : IN_PROGRESS le plus proche, sinon prochain ACTIVE/FULL, sinon null.
AnnouncementModel? selectScannableTrip(List<AnnouncementModel> trips) {
  int byDate(AnnouncementModel a, AnnouncementModel b) =>
      a.departureDate.compareTo(b.departureDate);

  final inProgress = trips.where((t) => t.status == 'IN_PROGRESS').toList()
    ..sort(byDate);
  if (inProgress.isNotEmpty) return inProgress.first;

  final upcoming = trips
      .where((t) => t.status == 'ACTIVE' || t.status == 'FULL')
      .toList()
    ..sort(byDate);
  return upcoming.isNotEmpty ? upcoming.first : null;
}

ScanHubProgress computeScanProgress(List<BidModel> bids) {
  return ScanHubProgress(
    confirmedColis:
        bids.where((b) => _confirmedStatuses.contains(b.status)).length,
    scannedDepart:
        bids.where((b) => _departedStatuses.contains(b.status)).length,
  );
}
