import 'package:dony/features/profile/bloc/profile_public_event.dart';
import 'package:dony/features/profile/bloc/profile_public_state.dart';
import 'package:dony/features/profile/data/models/profile_public_model.dart';
import 'package:dony/features/profile/data/profile_repository.dart';
import 'package:dony/features/ratings/data/models/rating_summary.dart';
import 'package:dony/features/ratings/data/rating_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProfilePublicBloc
    extends Bloc<ProfilePublicEvent, ProfilePublicState> {
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
      final profileFuture =
          _profileRepository.getProfilePublic(event.userId);
      final ratingsFuture =
          _ratingRepository.getUserRatings(event.userId);

      final profile = await profileFuture;
      final ratings = await ratingsFuture;

      emit(ProfilePublicLoaded(
        profile: profile,
        recentRatings: ratings,
      ));
    } catch (e) {
      emit(ProfilePublicError(message: e.toString()));
    }
  }
}
