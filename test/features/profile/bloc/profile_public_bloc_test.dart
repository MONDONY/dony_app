import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/profile/bloc/profile_public_bloc.dart';
import 'package:dony/features/profile/bloc/profile_public_event.dart';
import 'package:dony/features/profile/bloc/profile_public_state.dart';
import 'package:dony/features/profile/data/models/profile_public_model.dart';
import 'package:dony/features/profile/data/profile_repository.dart';
import 'package:dony/features/ratings/data/models/rating_summary.dart';
import 'package:dony/features/ratings/data/rating_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockProfileRepo extends Mock implements ProfileRepository {}

class _MockRatingRepo extends Mock implements RatingRepository {}

const _profile = ProfilePublicModel(
  userId: 'u-1',
  displayName: 'Awa Diop',
  kycVerified: true,
  isProAccount: false,
  gpPro: false,
  completedBidsCount: 3,
  averageRating: 4.5,
  ratingCount: 8,
  memberSince: '2025-01-01',
  badges: [],
);

const _ratings = RatingSummary(
  averageRating: 4.5,
  ratingCount: 8,
  distribution: {5: 8},
  ratings: [],
  page: 0,
  totalPages: 1,
);

void main() {
  late _MockProfileRepo profileRepo;
  late _MockRatingRepo ratingRepo;

  setUp(() {
    profileRepo = _MockProfileRepo();
    ratingRepo = _MockRatingRepo();
  });

  ProfilePublicBloc build() => ProfilePublicBloc(profileRepo, ratingRepo);

  test('état initial', () {
    final bloc = build();
    expect(bloc.state, isA<ProfilePublicInitial>());
    bloc.close();
  });

  blocTest<ProfilePublicBloc, ProfilePublicState>(
    'profil et avis chargés ensemble → Loading puis Loaded',
    build: () {
      when(
        () => profileRepo.getProfilePublic('u-1'),
      ).thenAnswer((_) async => _profile);
      when(
        () => ratingRepo.getUserRatings('u-1'),
      ).thenAnswer((_) async => _ratings);
      return build();
    },
    act: (b) => b.add(const ProfilePublicRequested('u-1')),
    expect: () => [
      isA<ProfilePublicLoading>(),
      isA<ProfilePublicLoaded>()
          .having((s) => s.profile.displayName, 'displayName', 'Awa Diop')
          .having((s) => s.recentRatings.ratingCount, 'ratingCount', 8),
    ],
    verify: (_) {
      verify(() => profileRepo.getProfilePublic('u-1')).called(1);
      verify(() => ratingRepo.getUserRatings('u-1')).called(1);
    },
  );

  blocTest<ProfilePublicBloc, ProfilePublicState>(
    'échec des avis → Error, même si le profil a répondu',
    build: () {
      when(
        () => profileRepo.getProfilePublic(any()),
      ).thenAnswer((_) async => _profile);
      when(
        () => ratingRepo.getUserRatings(any()),
      ).thenThrow(const ServerException());
      return build();
    },
    act: (b) => b.add(const ProfilePublicRequested('u-1')),
    expect: () => [
      isA<ProfilePublicLoading>(),
      isA<ProfilePublicError>().having(
        (s) => s.error,
        'error',
        isA<ServerException>(),
      ),
    ],
  );
}
