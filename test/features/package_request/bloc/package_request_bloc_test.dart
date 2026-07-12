import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/bloc/package_request_bloc.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements PackageRequestRepository {}

PackageRequest _fakeRequest(String id) => PackageRequest(
  id: id,
  senderId: 's-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  desiredDate: DateTime(2026, 6, 15),
  dateToleranceDays: 2,
  weightKg: 5,
  parcelSize: ParcelSize.small,
  transportMode: TransportMode.plane,
  categories: const ['Vêtements'],
  status: PackageRequestStatus.open,
  createdAt: DateTime(2026, 5, 10),
);

void main() {
  late _MockRepo repo;

  setUp(() => repo = _MockRepo());

  // ─── FetchMyRequests — happy path ─────────────────────────────────────────────

  blocTest<PackageRequestBloc, PackageRequestState>(
    'FetchMyRequests emits loading then loaded with requests',
    build: () {
      when(() => repo.findMine()).thenAnswer(
        (_) async => PackageRequestPage(
          content: [_fakeRequest('r-1'), _fakeRequest('r-2')],
          totalElements: 2,
          page: 0,
          size: 20,
        ),
      );
      return PackageRequestBloc(repo);
    },
    act: (bloc) => bloc.add(const FetchMyRequests()),
    expect: () => [
      isA<PackageRequestState>().having(
        (s) => s.status,
        'status',
        PackageRequestListStatus.loading,
      ),
      isA<PackageRequestState>()
          .having((s) => s.status, 'status', PackageRequestListStatus.loaded)
          .having((s) => s.requests.length, 'requests.length', 2),
    ],
  );

  // ─── FetchMyRequests — error ──────────────────────────────────────────────────

  blocTest<PackageRequestBloc, PackageRequestState>(
    'FetchMyRequests emits error when repo throws',
    build: () {
      when(() => repo.findMine()).thenThrow(Exception('network error'));
      return PackageRequestBloc(repo);
    },
    act: (bloc) => bloc.add(const FetchMyRequests()),
    expect: () => [
      isA<PackageRequestState>().having(
        (s) => s.status,
        'status',
        PackageRequestListStatus.loading,
      ),
      isA<PackageRequestState>()
          .having((s) => s.status, 'status', PackageRequestListStatus.error)
          .having((s) => s.errorMessage, 'errorMessage', isNotNull),
    ],
  );

  // ─── CancelRequest — calls repo.cancel then refetches ─────────────────────────

  blocTest<PackageRequestBloc, PackageRequestState>(
    'CancelRequest calls repo.cancel then refetches',
    build: () {
      when(() => repo.cancel('r-1')).thenAnswer((_) async {});
      when(() => repo.findMine()).thenAnswer(
        (_) async => PackageRequestPage(
          content: [_fakeRequest('r-2')],
          totalElements: 1,
          page: 0,
          size: 20,
        ),
      );
      return PackageRequestBloc(repo);
    },
    seed: () => PackageRequestState(
      status: PackageRequestListStatus.loaded,
      requests: [_fakeRequest('r-1'), _fakeRequest('r-2')],
    ),
    act: (bloc) => bloc.add(const CancelRequest('r-1')),
    expect: () => [
      isA<PackageRequestState>().having(
        (s) => s.status,
        'status',
        PackageRequestListStatus.cancelling,
      ),
      isA<PackageRequestState>()
          .having((s) => s.status, 'status', PackageRequestListStatus.loaded)
          .having((s) => s.requests.length, 'requests.length', 1)
          .having(
            (s) => s.fetchedAt.isAfter(DateTime(2000)),
            'fetchedAt fresh',
            true,
          ),
    ],
    verify: (_) {
      verify(() => repo.cancel('r-1')).called(1);
      verify(() => repo.findMine()).called(1);
    },
  );

  // ─── CancelRequest — error ────────────────────────────────────────────────────

  blocTest<PackageRequestBloc, PackageRequestState>(
    'CancelRequest emits error when repo.cancel throws',
    build: () {
      when(() => repo.cancel(any())).thenThrow(Exception('forbidden'));
      return PackageRequestBloc(repo);
    },
    act: (bloc) => bloc.add(const CancelRequest('r-1')),
    expect: () => [
      isA<PackageRequestState>().having(
        (s) => s.status,
        'status',
        PackageRequestListStatus.cancelling,
      ),
      isA<PackageRequestState>().having(
        (s) => s.status,
        'status',
        PackageRequestListStatus.error,
      ),
    ],
  );

  // ─── RefreshMyRequests — keeps existing data visible ─────────────────────────

  blocTest<PackageRequestBloc, PackageRequestState>(
    'RefreshMyRequests updates requests without showing loading',
    build: () {
      when(() => repo.findMine()).thenAnswer(
        (_) async => PackageRequestPage(
          content: [_fakeRequest('r-fresh')],
          totalElements: 1,
          page: 0,
          size: 20,
        ),
      );
      return PackageRequestBloc(repo);
    },
    seed: () => PackageRequestState(
      status: PackageRequestListStatus.loaded,
      requests: [_fakeRequest('r-old')],
    ),
    act: (bloc) => bloc.add(const RefreshMyRequests()),
    expect: () => [
      isA<PackageRequestState>()
          .having((s) => s.status, 'status', PackageRequestListStatus.loaded)
          .having((s) => s.requests.first.id, 'first.id', 'r-fresh'),
    ],
  );
}
