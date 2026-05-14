import 'package:dony/features/profile/data/models/profile_public_model.dart';
import 'package:dony/features/ratings/data/models/rating_summary.dart';

abstract class ProfilePublicState {
  const ProfilePublicState();
}

class ProfilePublicInitial extends ProfilePublicState {
  const ProfilePublicInitial();
}

class ProfilePublicLoading extends ProfilePublicState {
  const ProfilePublicLoading();
}

class ProfilePublicLoaded extends ProfilePublicState {
  const ProfilePublicLoaded({
    required this.profile,
    required this.recentRatings,
  });

  final ProfilePublicModel profile;
  final RatingSummary recentRatings;
}

class ProfilePublicError extends ProfilePublicState {
  const ProfilePublicError({required this.message});

  final String message;
}
