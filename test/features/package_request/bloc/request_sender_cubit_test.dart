import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/package_request/bloc/request_sender_cubit.dart';
import 'package:dony/features/profile/data/models/profile_public_model.dart';
import 'package:dony/features/profile/data/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

const _profile = ProfilePublicModel(
  userId: 'u-1',
  displayName: 'Awa Diop',
  avatarUrl: 'https://cdn.example/a.jpg',
  kycVerified: true,
  isProAccount: false,
  isKiloPro: false,
  completedBidsCount: 3,
  averageRating: 4.5,
  ratingCount: 8,
  memberSince: '2025-01-01',
  badges: [],
  senderIncidentCount: 1,
);

void main() {
  late _MockProfileRepository repo;
  late _MockAnalyticsService analytics;

  setUp(() {
    repo = _MockProfileRepository();
    analytics = _MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  RequestSenderCubit build() => RequestSenderCubit(repo, analytics);

  test('état initial : chargement', () {
    expect(build().state, isA<RequestSenderLoading>());
  });

  blocTest<RequestSenderCubit, RequestSenderState>(
    'profil chargé → résumé au format de la carte de liste',
    setUp: () => when(
      () => repo.getProfilePublic('u-1'),
    ).thenAnswer((_) async => _profile),
    build: build,
    act: (c) => c.load('u-1', canRead: true),
    expect: () => [
      isA<RequestSenderLoading>(),
      isA<RequestSenderLoaded>()
          .having((s) => s.sender.id, 'id', 'u-1')
          .having((s) => s.sender.displayName, 'name', 'Awa Diop')
          .having((s) => s.sender.averageRating, 'note', 4.5)
          .having((s) => s.sender.totalRatings, 'avis', 8)
          .having((s) => s.sender.kycVerified, 'kyc', isTrue)
          .having((s) => s.sender.avatarUrl, 'avatar', isNotNull)
          .having((s) => s.sender.incidentCount, 'incidents', 1),
    ],
  );

  blocTest<RequestSenderCubit, RequestSenderState>(
    '404 (profil masqué) → ligne absente',
    setUp: () => when(
      () => repo.getProfilePublic(any()),
    ).thenThrow(const NotFoundException()),
    build: build,
    act: (c) => c.load('u-1', canRead: true),
    expect: () => [isA<RequestSenderLoading>(), isA<RequestSenderHidden>()],
  );

  blocTest<RequestSenderCubit, RequestSenderState>(
    'visiteur sans compte → ligne absente, aucun appel',
    build: build,
    act: (c) => c.load('u-1', canRead: false),
    expect: () => [isA<RequestSenderHidden>()],
    verify: (_) => verifyNever(() => repo.getProfilePublic(any())),
  );

  blocTest<RequestSenderCubit, RequestSenderState>(
    'expéditeur sans identifiant → ligne absente, aucun appel',
    build: build,
    act: (c) => c.load('', canRead: true),
    expect: () => [isA<RequestSenderHidden>()],
    verify: (_) => verifyNever(() => repo.getProfilePublic(any())),
  );

  test('trackOpened → événement analytics sans propriété', () {
    build().trackOpened();
    verify(() => analytics.logEvent('package_request_sender_opened')).called(1);
  });
}
