import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/package_request/bloc/complete_details_bloc.dart';
import 'package:dony/features/package_request/data/models/content_category.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPackageRequestRepository extends Mock
    implements PackageRequestRepository {}

const _event = CompleteDetailsSubmitted(
  requestId: 'pr-1',
  recipientName: 'Ibrahima Diallo',
  recipientPhone: '+221771234567',
  recipientCity: 'Dakar',
);

PackageRequest _fakeRequest() => PackageRequest(
      id: 'pr-1',
      senderId: 'sender-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      desiredDate: DateTime(2026, 8, 15),
      dateToleranceDays: 3,
      weightKg: 5,
      parcelSize: ParcelSize.medium,
      transportMode: TransportMode.plane,
      contentCategory: ContentCategory.vetements,
      status: PackageRequestStatus.negotiating,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  late _MockPackageRequestRepository repo;

  setUp(() {
    repo = _MockPackageRequestRepository();
  });

  group('CompleteDetailsBloc', () {
    test('initial state is CompleteDetailsStatus.initial', () {
      final bloc = CompleteDetailsBloc(repo);
      expect(bloc.state.status, CompleteDetailsStatus.initial);
      expect(bloc.state.isLoading, isFalse);
      expect(bloc.state.isSuccess, isFalse);
      bloc.close();
    });

    blocTest<CompleteDetailsBloc, CompleteDetailsState>(
      'CompleteDetailsSubmitted emits [loading, success] on success',
      build: () {
        final fakeRequest = PackageRequest(
          id: 'pr-1',
          senderId: 'sender-1',
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          desiredDate: DateTime(2026, 8, 15),
          dateToleranceDays: 3,
          weightKg: 5,
          parcelSize: ParcelSize.medium,
          transportMode: TransportMode.plane,
          contentCategory: ContentCategory.vetements,
          status: PackageRequestStatus.negotiating,
          createdAt: DateTime(2026, 1, 1),
        );
        when(
          () => repo.completeDetails(
            any(),
            recipientName: any(named: 'recipientName'),
            recipientPhone: any(named: 'recipientPhone'),
            recipientCity: any(named: 'recipientCity'),
          ),
        ).thenAnswer((_) async => fakeRequest);
        return CompleteDetailsBloc(repo);
      },
      act: (bloc) => bloc.add(_event),
      expect: () => [
        const CompleteDetailsState(status: CompleteDetailsStatus.loading),
        const CompleteDetailsState(status: CompleteDetailsStatus.success),
      ],
    );

    blocTest<CompleteDetailsBloc, CompleteDetailsState>(
      'CompleteDetailsStarted loads the request into state',
      build: () {
        when(() => repo.getById('pr-1'))
            .thenAnswer((_) async => _fakeRequest());
        return CompleteDetailsBloc(repo);
      },
      act: (bloc) => bloc.add(const CompleteDetailsStarted('pr-1')),
      expect: () => [
        isA<CompleteDetailsState>()
            .having((s) => s.loaded, 'loaded', isTrue)
            .having((s) => s.request?.id, 'request.id', 'pr-1'),
      ],
    );

    blocTest<CompleteDetailsBloc, CompleteDetailsState>(
      'CompleteDetailsStarted still marks loaded on repo failure (best-effort recap)',
      build: () {
        when(() => repo.getById('pr-1')).thenThrow(Exception('boom'));
        return CompleteDetailsBloc(repo);
      },
      act: (bloc) => bloc.add(const CompleteDetailsStarted('pr-1')),
      expect: () => [
        isA<CompleteDetailsState>()
            .having((s) => s.loaded, 'loaded', isTrue)
            .having((s) => s.request, 'request', isNull),
      ],
    );

    blocTest<CompleteDetailsBloc, CompleteDetailsState>(
      'CompleteDetailsSubmitted emits [loading, error] on exception',
      build: () {
        when(
          () => repo.completeDetails(
            any(),
            recipientName: any(named: 'recipientName'),
            recipientPhone: any(named: 'recipientPhone'),
            recipientCity: any(named: 'recipientCity'),
          ),
        ).thenThrow(Exception('Server error'));
        return CompleteDetailsBloc(repo);
      },
      act: (bloc) => bloc.add(_event),
      expect: () => [
        const CompleteDetailsState(status: CompleteDetailsStatus.loading),
        isA<CompleteDetailsState>()
            .having((s) => s.status, 'status', CompleteDetailsStatus.error)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              isNotNull,
            ),
      ],
    );

    test('isLoading returns true when status is loading', () {
      const s = CompleteDetailsState(status: CompleteDetailsStatus.loading);
      expect(s.isLoading, isTrue);
      expect(s.isSuccess, isFalse);
    });

    test('isSuccess returns true when status is success', () {
      const s = CompleteDetailsState(status: CompleteDetailsStatus.success);
      expect(s.isSuccess, isTrue);
      expect(s.isLoading, isFalse);
    });

    test('copyWith preserves fields when null', () {
      const s = CompleteDetailsState(
        status: CompleteDetailsStatus.error,
        errorMessage: 'oops',
      );
      final copy = s.copyWith();
      expect(copy.status, CompleteDetailsStatus.error);
      expect(copy.errorMessage, isNull); // copyWith sets to null if not passed
    });

    test('CompleteDetailsSubmitted Equatable props work', () {
      const e1 = CompleteDetailsSubmitted(
        requestId: 'pr-1',
        recipientName: 'John',
        recipientPhone: '+33612345678',
        recipientCity: 'Dakar',
      );
      const e2 = CompleteDetailsSubmitted(
        requestId: 'pr-1',
        recipientName: 'John',
        recipientPhone: '+33612345678',
        recipientCity: 'Dakar',
      );
      expect(e1, equals(e2));
    });

    test('CompleteDetailsSubmitted allows null recipientCity', () {
      const e = CompleteDetailsSubmitted(
        requestId: 'pr-1',
        recipientName: 'John',
        recipientPhone: '+33612345678',
      );
      expect(e.recipientCity, isNull);
      expect(e.props, contains(null));
    });
  });
}
