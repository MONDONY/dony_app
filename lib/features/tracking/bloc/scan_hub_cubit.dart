import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
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
  const ScanHubError(this.error);

  /// Typée, jamais un `toString()` : l'écran passe par `ErrorPresenter`, sinon le
  /// détail brut du back (voire la `DioException` entière) s'affichait tel quel.
  final AppException error;
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

  /// Colis confirmés d'un trajet donné (voir [selectedTripBids]).
  List<BidModel> confirmedBidsOf(String tripId) =>
      confirmedColis(bidsByTrip[tripId] ?? const []);

  /// Au moins un colis, tous trajets confondus, attend encore une étape.
  bool get hasParcelToValidate => trips.any(
    (t) => confirmedBidsOf(t.id).any((b) => nextRequiredStep(b) != null),
  );
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
  final AnalyticsService _analytics;
  final TrackingRepository _trackingRepo;

  /// Un rechargement peut finir après la fermeture de l'onglet (changement
  /// de compte ou de profil) : son résultat est alors ignoré.
  @override
  void emit(ScanHubState state) {
    if (!isClosed) super.emit(state);
  }

  /// Rechargement silencieux en cours : un retour sur l'onglet pendant
  /// l'appel n'en relance pas un second.
  bool _silentLoading = false;

  /// Charge les trajets scannables et leurs colis.
  ///
  /// [silent] : rafraîchissement (étape validée, retour sur l'onglet). L'écran
  /// garde son contenu pendant l'appel (pas d'état de chargement, donc pas de
  /// caméra démontée), et un échec laisse les colis déjà affichés. Un échec
  /// depuis « Rien à valider » s'affiche en erreur : jamais un vide trompeur.
  /// Le trajet sélectionné est conservé tant qu'il reste scannable.
  Future<void> load({bool silent = false}) async {
    if (silent && _silentLoading) return;
    final previous = state;
    final keepTripId = previous is ScanHubLoaded
        ? previous.selectedTripId
        : null;
    final keepContent =
        silent && (previous is ScanHubLoaded || previous is ScanHubEmpty);
    if (!keepContent) emit(const ScanHubLoading());
    _silentLoading = silent;
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

      final selectedTripId = trips.any((t) => t.id == keepTripId)
          ? keepTripId!
          : trips.first.id;
      final scanHistory = await _trackingRepo.getTripScanHistory(
        selectedTripId,
      );

      emit(
        ScanHubLoaded(
          trips: trips,
          selectedTripId: selectedTripId,
          bidsByTrip: bidsByTrip,
          scanHistory: scanHistory,
        ),
      );
    } catch (e) {
      if (silent && previous is ScanHubLoaded) return;
      emit(ScanHubError(unwrapDioError(e)));
    } finally {
      if (silent) _silentLoading = false;
    }
  }

  /// Bascule le trajet affiché — pas de rechargement des trajets/colis (déjà
  /// en mémoire depuis [load]), seul l'historique de scans du nouveau trajet
  /// est refetché (potentiellement volumineux, inutile de le précharger pour
  /// des trajets jamais consultés).
  ///
  /// [source] : `picker` (feuille « Choisir un trajet ») ou `other_trip`
  /// (QR d'un colis d'un autre trajet du voyageur), tracé dans
  /// `suivi_trip_changed`.
  Future<void> selectTrip(String tripId, {String source = 'picker'}) async {
    final current = state;
    if (current is! ScanHubLoaded || current.selectedTripId == tripId) return;
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.suiviTripChanged,
        properties: {'source': source},
      ),
    );

    emit(
      ScanHubLoaded(
        trips: current.trips,
        selectedTripId: tripId,
        bidsByTrip: current.bidsByTrip,
        scanHistory: const [],
      ),
    );

    try {
      final scanHistory = await _trackingRepo.getTripScanHistory(tripId);
      final latest = state;
      if (latest is ScanHubLoaded && latest.selectedTripId == tripId) {
        emit(
          ScanHubLoaded(
            trips: latest.trips,
            selectedTripId: tripId,
            bidsByTrip: latest.bidsByTrip,
            scanHistory: scanHistory,
          ),
        );
      }
    } catch (_) {
      // L'historique reste vide pour ce trajet si le fetch échoue — le
      // reste de l'écran (colis, scan rapide) demeure utilisable.
    }
  }
}
