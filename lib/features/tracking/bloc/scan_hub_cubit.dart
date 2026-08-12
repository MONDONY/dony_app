import 'package:bloc/bloc.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/tracking/bloc/scan_hub_selectors.dart';
import 'package:dony/features/tracking/data/models/trip_scan_history_entry_model.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';

sealed class ScanHubState {
  const ScanHubState();
}

class ScanHubLoading extends ScanHubState {
  const ScanHubLoading();
}

class ScanHubEmpty extends ScanHubState {
  const ScanHubEmpty();
}

class ScanHubError extends ScanHubState {
  const ScanHubError(this.message);

  final String message;
}

class ScanHubLoaded extends ScanHubState {
  const ScanHubLoaded({
    required this.trips,
    required this.selectedTripId,
    required this.bidsByTrip,
    required this.scanHistory,
  });

  final List<AnnouncementModel> trips;
  final String selectedTripId;
  final Map<String, List<BidModel>> bidsByTrip;
  final List<TripScanHistoryEntryModel> scanHistory;

  AnnouncementModel get selectedTrip =>
      trips.firstWhere((t) => t.id == selectedTripId);

  /// Colis confirmés/scannables du trajet sélectionné — filtre
  /// [bidsByTrip] via [confirmedColis] pour que tout consommateur (liste,
  /// bandeau synchro, résolution du champ numéro) ignore les bids
  /// `PENDING`/`REJECTED`/`CANCELLED`. [bidsByTrip] lui-même reste brut.
  List<BidModel> get selectedTripBids =>
      confirmedColis(bidsByTrip[selectedTripId] ?? const []);

  ScanHubProgress get progress => computeScanProgress(selectedTripBids);
}

class ScanHubCubit extends Cubit<ScanHubState> {
  ScanHubCubit(
    this._announcementRepo,
    this._bidRepo,
    this._analytics,
    this._trackingRepo,
  ) : super(const ScanHubLoading());

  final AnnouncementRepository _announcementRepo;
  final BidRepository _bidRepo;
  // ignore: unused_field
  final AnalyticsService _analytics;
  final TrackingRepository _trackingRepo;

  Future<void> load() async {
    emit(const ScanHubLoading());
    try {
      final result = await _announcementRepo.getMyAnnouncements();
      final trips = selectScannableTrips(result.announcements);
      if (trips.isEmpty) {
        emit(const ScanHubEmpty());
        return;
      }

      final bidsByTrip = <String, List<BidModel>>{};
      for (final trip in trips) {
        bidsByTrip[trip.id] = await _bidRepo.getBidsForAnnouncement(trip.id);
      }

      final selectedTripId = trips.first.id;
      final scanHistory =
          await _trackingRepo.getTripScanHistory(selectedTripId);

      emit(ScanHubLoaded(
        trips: trips,
        selectedTripId: selectedTripId,
        bidsByTrip: bidsByTrip,
        scanHistory: scanHistory,
      ));
    } catch (e) {
      emit(ScanHubError(e.toString()));
    }
  }

  /// Bascule le trajet affiché — pas de rechargement des trajets/colis (déjà
  /// en mémoire depuis [load]), seul l'historique de scans du nouveau trajet
  /// est refetché (potentiellement volumineux, inutile de le précharger pour
  /// des trajets jamais consultés).
  Future<void> selectTrip(String tripId) async {
    final current = state;
    if (current is! ScanHubLoaded || current.selectedTripId == tripId) return;

    emit(ScanHubLoaded(
      trips: current.trips,
      selectedTripId: tripId,
      bidsByTrip: current.bidsByTrip,
      scanHistory: const [],
    ));

    try {
      final scanHistory = await _trackingRepo.getTripScanHistory(tripId);
      final latest = state;
      if (latest is ScanHubLoaded && latest.selectedTripId == tripId) {
        emit(ScanHubLoaded(
          trips: latest.trips,
          selectedTripId: tripId,
          bidsByTrip: latest.bidsByTrip,
          scanHistory: scanHistory,
        ));
      }
    } catch (_) {
      // L'historique reste vide pour ce trajet si le fetch échoue — le
      // reste de l'écran (colis, scan rapide) demeure utilisable.
    }
  }
}
