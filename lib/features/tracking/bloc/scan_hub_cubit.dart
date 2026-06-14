import 'package:bloc/bloc.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/tracking/bloc/scan_hub_selectors.dart';

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
  const ScanHubLoaded({required this.trip, required this.progress});

  final AnnouncementModel trip;
  final ScanHubProgress progress;
}

class ScanHubCubit extends Cubit<ScanHubState> {
  ScanHubCubit(this._announcementRepo, this._bidRepo, this._analytics)
      : super(const ScanHubLoading());

  final AnnouncementRepository _announcementRepo;
  final BidRepository _bidRepo;
  // ignore: unused_field
  final AnalyticsService _analytics;

  Future<void> load() async {
    emit(const ScanHubLoading());
    try {
      final result = await _announcementRepo.getMyAnnouncements();
      final trip = selectScannableTrip(result.announcements);
      if (trip == null) {
        emit(const ScanHubEmpty());
        return;
      }
      final bids = await _bidRepo.getBidsForAnnouncement(trip.id);
      emit(ScanHubLoaded(trip: trip, progress: computeScanProgress(bids)));
    } catch (e) {
      emit(ScanHubError(e.toString()));
    }
  }
}
