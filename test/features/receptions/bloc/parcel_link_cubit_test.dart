import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/receptions/bloc/parcel_link_cubit.dart';
import 'package:dony/features/receptions/data/models/parcel_role.dart';
import 'package:dony/features/receptions/data/repositories/reception_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockReceptionRepository extends Mock implements ReceptionRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  const bidId = '3f2504e0-4f89-41d3-9a0c-0305e82c3301';
  late MockReceptionRepository repository;
  late MockAnalyticsService analytics;

  setUp(() {
    repository = MockReceptionRepository();
    analytics = MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  for (final role in ParcelRole.values) {
    blocTest<ParcelLinkCubit, ParcelLinkState>(
      'rôle ${role.name} : résolu et mesuré',
      build: () {
        when(
          () => repository.getParcelRole(bidId),
        ).thenAnswer((_) async => role);
        return ParcelLinkCubit(repository, analytics);
      },
      act: (cubit) => cubit.load(bidId),
      expect: () => [
        isA<ParcelLinkResolved>().having((s) => s.role, 'role', role),
      ],
      verify: (_) => verify(
        () => analytics.logEvent(
          AnalyticsEvents.parcelDeepLinkResolved,
          properties: {'role': role.name},
        ),
      ).called(1),
    );
  }

  blocTest<ParcelLinkCubit, ParcelLinkState>(
    'erreur réseau : état erreur, rien de mesuré',
    build: () {
      when(() => repository.getParcelRole(bidId)).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/receptions/role/$bidId'),
          type: DioExceptionType.connectionError,
        ),
      );
      return ParcelLinkCubit(repository, analytics);
    },
    act: (cubit) => cubit.load(bidId),
    expect: () => [isA<ParcelLinkError>()],
    verify: (_) => verifyNever(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ),
  );

  blocTest<ParcelLinkCubit, ParcelLinkState>(
    'réessayer après une erreur repasse par le chargement',
    build: () {
      when(
        () => repository.getParcelRole(bidId),
      ).thenAnswer((_) async => ParcelRole.none);
      return ParcelLinkCubit(repository, analytics);
    },
    seed: () => const ParcelLinkError(NetworkException('offline')),
    act: (cubit) => cubit.load(bidId),
    expect: () => [isA<ParcelLinkLoading>(), isA<ParcelLinkResolved>()],
  );
}
