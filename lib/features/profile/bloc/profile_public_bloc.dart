import 'package:dony/features/profile/bloc/profile_public_event.dart';
import 'package:dony/features/profile/bloc/profile_public_state.dart';
import 'package:dony/features/profile/data/models/profile_public_model.dart';
import 'package:dony/features/profile/data/profile_repository.dart';
import 'package:dony/features/ratings/data/models/rating_summary.dart';
import 'package:dony/features/ratings/data/rating_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProfilePublicBloc extends Bloc<ProfilePublicEvent, ProfilePublicState> {
  ProfilePublicBloc(this._profileRepository, this._ratingRepository)
    : super(const ProfilePublicInitial()) {
    on<ProfilePublicRequested>(_onRequested);
  }

  final ProfileRepository _profileRepository;
  final RatingRepository _ratingRepository;

  Future<void> _onRequested(
    ProfilePublicRequested event,
    Emitter<ProfilePublicState> emit,
  ) async {
    emit(const ProfilePublicLoading());
    try {
      final results = await Future.wait([
        _profileRepository.getProfilePublic(event.userId),
        _ratingRepository.getUserRatings(event.userId),
      ]);
      emit(
        ProfilePublicLoaded(
          profile: results[0] as ProfilePublicModel,
          recentRatings: results[1] as RatingSummary,
        ),
      );
    } catch (e) {
      emit(ProfilePublicError(message: e.toString()));
    }
  }
}
