import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/cancellation/data/models/cancellation_model.dart';
import 'package:dony/features/cancellation/data/repositories/cancellation_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCancellationRepository extends Mock
    implements CancellationRepository {}

final _cancellation = CancellationModel(
  announcementId: 'ann-1',
  affectedBidsCount: 2,
  reason: 'TRAVELER_SICK',
  rematchSuggestions: [],
  cancelledAt: DateTime(2024, 1, 15),
);

final _suggestions = [
  RematchSuggestionModel(
    suggestionId: 'sug-1',
    announcementId: 'ann-2',
    departureCity: 'Paris',
    arrivalCity: 'Dakar',
    departureDate: DateTime(2024, 2, 1),
    availableKg: 5.0,
    pricePerKg: 12.0,
  ),
];

void main() {
  late MockCancellationRepository mockRepo;

  setUp(() {
    mockRepo = MockCancellationRepository();
  });

  CancellationBloc buildBloc() => CancellationBloc(mockRepo);

  // ── CancellationTripRequested ───────────────────────────────────────────────

  group('CancellationTripRequested', () {
    blocTest<CancellationBloc, CancellationState>(
      'emits [Loading, Success] when cancelTrip succeeds',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.cancelTrip(
              announcementId: 'ann-1',
              reason: 'TRAVELER_SICK',
            )).thenAnswer((_) async => _cancellation);
      },
      act: (b) => b.add(CancellationTripRequested(
        announcementId: 'ann-1',
        reason: 'TRAVELER_SICK',
      )),
      expect: () => [
        isA<CancellationLoading>(),
        isA<CancellationSuccess>().having(
          (s) => s.cancellation.announcementId,
          'announcementId',
          'ann-1',
        ),
      ],
    );

    blocTest<CancellationBloc, CancellationState>(
      'emits [Loading, Error] when DioException thrown',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.cancelTrip(
              announcementId: any(named: 'announcementId'),
              reason: any(named: 'reason'),
            )).thenThrow(
          DioException(
            requestOptions: RequestOptions(),
            error: const NotFoundException(message: 'Announcement not found'),
            response: Response(
              data: {'detail': 'Announcement not found'},
              statusCode: 404,
              requestOptions: RequestOptions(),
            ),
          ),
        );
      },
      act: (b) => b.add(CancellationTripRequested(
        announcementId: 'bad-id',
        reason: 'OTHER',
      )),
      expect: () => [
        isA<CancellationLoading>(),
        isA<CancellationError>().having(
          (s) => s.error.message,
          'error.message',
          'Announcement not found',
        ),
      ],
    );

    blocTest<CancellationBloc, CancellationState>(
      'emits [Loading, Error] when generic exception thrown',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.cancelTrip(
              announcementId: any(named: 'announcementId'),
              reason: any(named: 'reason'),
            )).thenThrow(Exception('server down'));
      },
      act: (b) => b.add(CancellationTripRequested(
        announcementId: 'ann-1',
        reason: 'OTHER',
      )),
      expect: () => [
        isA<CancellationLoading>(),
        isA<CancellationError>(),
      ],
    );
  });

  // ── RematchSuggestionsRequested ─────────────────────────────────────────────

  group('RematchSuggestionsRequested', () {
    blocTest<CancellationBloc, CancellationState>(
      'emits [Loading, RematchSuggestionsLoaded] on success',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.getRematchSuggestions('canc-1'))
            .thenAnswer((_) async => _suggestions);
      },
      act: (b) => b.add(RematchSuggestionsRequested('canc-1')),
      expect: () => [
        isA<CancellationLoading>(),
        isA<RematchSuggestionsLoaded>().having(
          (s) => s.suggestions,
          'suggestions',
          hasLength(1),
        ),
      ],
    );

    blocTest<CancellationBloc, CancellationState>(
      'emits [Loading, Error] on DioException',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.getRematchSuggestions(any()))
            .thenThrow(DioException(requestOptions: RequestOptions()));
      },
      act: (b) => b.add(RematchSuggestionsRequested('canc-x')),
      expect: () => [
        isA<CancellationLoading>(),
        isA<CancellationError>(),
      ],
    );

    blocTest<CancellationBloc, CancellationState>(
      'emits [Loading, Error] on generic exception',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.getRematchSuggestions(any()))
            .thenThrow(Exception('service unavailable'));
      },
      act: (b) => b.add(RematchSuggestionsRequested('canc-x')),
      expect: () => [
        isA<CancellationLoading>(),
        isA<CancellationError>(),
      ],
    );
  });

  // ── NoShowReportRequested ──────────────────────────────────────────────────

  group('NoShowReportRequested', () {
    blocTest<CancellationBloc, CancellationState>(
      'emits [Loading, NoShowReported] on success',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.reportNoShow('bid-1'))
            .thenAnswer((_) async {});
      },
      act: (b) => b.add(NoShowReportRequested('bid-1')),
      expect: () => [
        isA<CancellationLoading>(),
        isA<NoShowReported>(),
      ],
    );

    blocTest<CancellationBloc, CancellationState>(
      'emits [Loading, Error] on exception',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.reportNoShow(any()))
            .thenThrow(Exception('network error'));
      },
      act: (b) => b.add(NoShowReportRequested('bid-x')),
      expect: () => [
        isA<CancellationLoading>(),
        isA<CancellationError>(),
      ],
    );
  });

  // ── NoShowContestRequested ─────────────────────────────────────────────────

  group('NoShowContestRequested', () {
    blocTest<CancellationBloc, CancellationState>(
      'emits [Loading, NoShowContested] on success',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.contestNoShow('bid-2'))
            .thenAnswer((_) async {});
      },
      act: (b) => b.add(NoShowContestRequested('bid-2')),
      expect: () => [
        isA<CancellationLoading>(),
        isA<NoShowContested>(),
      ],
    );

    blocTest<CancellationBloc, CancellationState>(
      'emits [Loading, Error] on exception',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.contestNoShow(any()))
            .thenThrow(DioException(requestOptions: RequestOptions()));
      },
      act: (b) => b.add(NoShowContestRequested('bid-x')),
      expect: () => [
        isA<CancellationLoading>(),
        isA<CancellationError>(),
      ],
    );
  });

  // ── Model tests ─────────────────────────────────────────────────────────────

  group('CancellationModel.fromJson', () {
    test('parses all fields correctly', () {
      final json = {
        'announcementId': 'ann-99',
        'affectedBidsCount': 3,
        'reason': 'PERSONAL',
        'rematchSuggestions': [
          {
            'suggestionId': 's1',
            'announcementId': 'ann-100',
            'departureCity': 'Lyon',
            'arrivalCity': 'Abidjan',
            'departureDate': '2024-03-01T00:00:00Z',
            'availableKg': 10.0,
            'pricePerKg': 8.5,
          }
        ],
        'cancelledAt': '2024-01-20T00:00:00Z',
      };

      final model = CancellationModel.fromJson(json);
      expect(model.announcementId, 'ann-99');
      expect(model.affectedBidsCount, 3);
      expect(model.reason, 'PERSONAL');
      expect(model.rematchSuggestions, hasLength(1));
      expect(model.rematchSuggestions.first.departureCity, 'Lyon');
    });
  });
}
