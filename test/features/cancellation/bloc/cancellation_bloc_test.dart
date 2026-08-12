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
import '../../../helpers/mock_analytics_backend.dart';

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
  late MockAnalyticsBackend backend;

  setUp(() {
    mockRepo = MockCancellationRepository();
    backend = MockAnalyticsBackend();
  });

  CancellationBloc buildBloc() {
    final analytics = makeDisabledAnalytics(backend);
    return CancellationBloc(mockRepo, analytics);
  }

  // ── CancellationTripRequested ───────────────────────────────────────────────

  group('CancellationTripRequested', () {
    blocTest<CancellationBloc, CancellationState>(
      'emits [Loading, Success] when cancelTrip succeeds',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.cancelTrip(
            announcementId: 'ann-1',
            reason: 'TRAVELER_SICK',
          ),
        ).thenAnswer((_) async => _cancellation);
      },
      act: (b) => b.add(
        CancellationTripRequested(
          announcementId: 'ann-1',
          reason: 'TRAVELER_SICK',
        ),
      ),
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
        when(
          () => mockRepo.cancelTrip(
            announcementId: any(named: 'announcementId'),
            reason: any(named: 'reason'),
          ),
        ).thenThrow(
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
      act: (b) => b.add(
        CancellationTripRequested(announcementId: 'bad-id', reason: 'OTHER'),
      ),
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
        when(
          () => mockRepo.cancelTrip(
            announcementId: any(named: 'announcementId'),
            reason: any(named: 'reason'),
          ),
        ).thenThrow(Exception('server down'));
      },
      act: (b) => b.add(
        CancellationTripRequested(announcementId: 'ann-1', reason: 'OTHER'),
      ),
      expect: () => [isA<CancellationLoading>(), isA<CancellationError>()],
    );
  });

  // ── RematchSuggestionsRequested ─────────────────────────────────────────────

  group('RematchSuggestionsRequested', () {
    blocTest<CancellationBloc, CancellationState>(
      'emits [Loading, RematchSuggestionsLoaded] on success',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.getRematchSuggestions('canc-1'),
        ).thenAnswer((_) async => _suggestions);
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
        when(
          () => mockRepo.getRematchSuggestions(any()),
        ).thenThrow(DioException(requestOptions: RequestOptions()));
      },
      act: (b) => b.add(RematchSuggestionsRequested('canc-x')),
      expect: () => [isA<CancellationLoading>(), isA<CancellationError>()],
    );

    blocTest<CancellationBloc, CancellationState>(
      'emits [Loading, Error] on generic exception',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.getRematchSuggestions(any()),
        ).thenThrow(Exception('service unavailable'));
      },
      act: (b) => b.add(RematchSuggestionsRequested('canc-x')),
      expect: () => [isA<CancellationLoading>(), isA<CancellationError>()],
    );
  });

  // ── NoShowReportRequested ──────────────────────────────────────────────────

  group('NoShowReportRequested', () {
    blocTest<CancellationBloc, CancellationState>(
      'emits [Loading, NoShowReported] on success',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.reportNoShow('bid-1')).thenAnswer((_) async {});
      },
      act: (b) => b.add(NoShowReportRequested('bid-1')),
      expect: () => [isA<CancellationLoading>(), isA<NoShowReported>()],
    );

    blocTest<CancellationBloc, CancellationState>(
      'emits [Loading, Error] on exception',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.reportNoShow(any()),
        ).thenThrow(Exception('network error'));
      },
      act: (b) => b.add(NoShowReportRequested('bid-x')),
      expect: () => [isA<CancellationLoading>(), isA<CancellationError>()],
    );
  });

  // ── TravelerNoShowReportRequested ──────────────────────────────────────────

  group('TravelerNoShowReportRequested', () {
    blocTest<CancellationBloc, CancellationState>(
      'emits [Loading, NoShowReported] and calls reportTravelerNoShow on success',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.reportTravelerNoShow('bid-1'),
        ).thenAnswer((_) async {});
      },
      act: (b) => b.add(TravelerNoShowReportRequested('bid-1')),
      expect: () => [isA<CancellationLoading>(), isA<NoShowReported>()],
      verify: (_) {
        verify(() => mockRepo.reportTravelerNoShow('bid-1')).called(1);
      },
    );

    blocTest<CancellationBloc, CancellationState>(
      'emits [Loading, Error] on DioException',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.reportTravelerNoShow(any()),
        ).thenThrow(DioException(requestOptions: RequestOptions()));
      },
      act: (b) => b.add(TravelerNoShowReportRequested('bid-x')),
      expect: () => [isA<CancellationLoading>(), isA<CancellationError>()],
    );

    blocTest<CancellationBloc, CancellationState>(
      'emits [Loading, Error] on generic exception',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.reportTravelerNoShow(any()),
        ).thenThrow(Exception('network error'));
      },
      act: (b) => b.add(TravelerNoShowReportRequested('bid-x')),
      expect: () => [isA<CancellationLoading>(), isA<CancellationError>()],
    );
  });

  // ── NoShowContestRequested ─────────────────────────────────────────────────

  group('NoShowContestRequested', () {
    blocTest<CancellationBloc, CancellationState>(
      'emits [Loading, NoShowContested] on success',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.contestNoShow('bid-2')).thenAnswer((_) async {});
      },
      act: (b) => b.add(NoShowContestRequested('bid-2')),
      expect: () => [isA<CancellationLoading>(), isA<NoShowContested>()],
    );

    blocTest<CancellationBloc, CancellationState>(
      'emits [Loading, Error] on exception',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.contestNoShow(any()),
        ).thenThrow(DioException(requestOptions: RequestOptions()));
      },
      act: (b) => b.add(NoShowContestRequested('bid-x')),
      expect: () => [isA<CancellationLoading>(), isA<CancellationError>()],
    );
  });

  // ── DeliveryNoShowReportRequested (arrivée) ─────────────────────────────────

  group('DeliveryNoShowReportRequested', () {
    blocTest<CancellationBloc, CancellationState>(
      'émet Loading puis DeliveryNoShowReported au succès',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.reportDeliveryNoShow('bid-1'),
        ).thenAnswer((_) async {});
      },
      act: (b) => b.add(DeliveryNoShowReportRequested('bid-1')),
      expect: () => [isA<CancellationLoading>(), isA<DeliveryNoShowReported>()],
    );

    blocTest<CancellationBloc, CancellationState>(
      'émet CancellationError sur DioException',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.reportDeliveryNoShow(any()),
        ).thenThrow(DioException(requestOptions: RequestOptions()));
      },
      act: (b) => b.add(DeliveryNoShowReportRequested('bid-x')),
      expect: () => [isA<CancellationLoading>(), isA<CancellationError>()],
    );
  });

  // ── TravelerDeliveryNoShowReportRequested (arrivée) ─────────────────────────

  group('TravelerDeliveryNoShowReportRequested', () {
    blocTest<CancellationBloc, CancellationState>(
      'émet Loading puis DeliveryNoShowReported au succès et appelle reportTravelerDeliveryNoShow',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.reportTravelerDeliveryNoShow('bid-1'),
        ).thenAnswer((_) async {});
      },
      act: (b) => b.add(TravelerDeliveryNoShowReportRequested('bid-1')),
      expect: () => [isA<CancellationLoading>(), isA<DeliveryNoShowReported>()],
      verify: (_) {
        verify(() => mockRepo.reportTravelerDeliveryNoShow('bid-1')).called(1);
      },
    );

    blocTest<CancellationBloc, CancellationState>(
      'émet CancellationError sur DioException',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.reportTravelerDeliveryNoShow(any()),
        ).thenThrow(DioException(requestOptions: RequestOptions()));
      },
      act: (b) => b.add(TravelerDeliveryNoShowReportRequested('bid-x')),
      expect: () => [isA<CancellationLoading>(), isA<CancellationError>()],
    );
  });

  // ── DeliveryNoShowContestRequested (arrivée) ────────────────────────────────

  group('DeliveryNoShowContestRequested', () {
    blocTest<CancellationBloc, CancellationState>(
      'émet Loading puis DeliveryNoShowContested au succès',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.contestDeliveryNoShow('bid-1'),
        ).thenAnswer((_) async {});
      },
      act: (b) => b.add(DeliveryNoShowContestRequested('bid-1')),
      expect: () => [
        isA<CancellationLoading>(),
        isA<DeliveryNoShowContested>(),
      ],
    );

    blocTest<CancellationBloc, CancellationState>(
      'émet CancellationError sur DioException',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.contestDeliveryNoShow(any()),
        ).thenThrow(DioException(requestOptions: RequestOptions()));
      },
      act: (b) => b.add(DeliveryNoShowContestRequested('bid-x')),
      expect: () => [isA<CancellationLoading>(), isA<CancellationError>()],
    );
  });

  // ── NoShowConfirmRequested ─────────────────────────────────────────────────

  group('NoShowConfirmRequested', () {
    blocTest<CancellationBloc, CancellationState>(
      'emits [Loading, NoShowConfirmed] on success',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.confirmNoShow('bid-3')).thenAnswer((_) async {});
      },
      act: (b) => b.add(NoShowConfirmRequested('bid-3')),
      expect: () => [isA<CancellationLoading>(), isA<NoShowConfirmed>()],
    );

    blocTest<CancellationBloc, CancellationState>(
      'emits [Loading, Error] on exception',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.confirmNoShow(any()),
        ).thenThrow(DioException(requestOptions: RequestOptions()));
      },
      act: (b) => b.add(NoShowConfirmRequested('bid-x')),
      expect: () => [isA<CancellationLoading>(), isA<CancellationError>()],
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
          },
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

  // ── CancelAfterHandoverRequested (D5/D6) ────────────────────────────────────

  group('CancelAfterHandoverRequested', () {
    blocTest<CancellationBloc, CancellationState>(
      'emits [Loading, CancelledAfterHandover] on success',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.cancelAfterHandover('bid-1'),
        ).thenAnswer((_) async {});
      },
      act: (b) =>
          b.add(CancelAfterHandoverRequested('bid-1', actor: 'traveler')),
      expect: () => [isA<CancellationLoading>(), isA<CancelledAfterHandover>()],
      verify: (_) {
        verify(() => mockRepo.cancelAfterHandover('bid-1')).called(1);
      },
    );

    blocTest<CancellationBloc, CancellationState>(
      'emits [Loading, Error] when cancel locked (409)',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.cancelAfterHandover(any())).thenThrow(
          DioException(
            requestOptions: RequestOptions(),
            response: Response(
              data: {'detail': 'Annulation verrouillée'},
              statusCode: 409,
              requestOptions: RequestOptions(),
            ),
          ),
        );
      },
      act: (b) => b.add(CancelAfterHandoverRequested('bid-x', actor: 'sender')),
      expect: () => [isA<CancellationLoading>(), isA<CancellationError>()],
    );
  });

  // ── ReturnConfirmRequested (D7 — voyageur saisit le code) ────────────────────

  group('ReturnConfirmRequested', () {
    blocTest<CancellationBloc, CancellationState>(
      'emits [Loading, ReturnConfirmed] on valid code',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.confirmReturn('bid-1', '123456')).thenAnswer(
          (_) async => ReturnCodeModel(returnedAt: DateTime(2024, 6, 1, 10)),
        );
      },
      act: (b) => b.add(ReturnConfirmRequested('bid-1', '123456')),
      expect: () => [
        isA<CancellationLoading>(),
        isA<ReturnConfirmed>().having(
          (s) => s.result.isReturned,
          'isReturned',
          true,
        ),
      ],
    );

    blocTest<CancellationBloc, CancellationState>(
      'emits [Loading, Error] on wrong code',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.confirmReturn(any(), any())).thenThrow(
          DioException(
            requestOptions: RequestOptions(),
            response: Response(
              data: {'detail': 'Code invalide'},
              statusCode: 422,
              requestOptions: RequestOptions(),
            ),
          ),
        );
      },
      act: (b) => b.add(ReturnConfirmRequested('bid-x', '000000')),
      expect: () => [isA<CancellationLoading>(), isA<CancellationError>()],
    );
  });

  // ── ReturnCodeRequested (D7 — expéditeur consulte le code) ───────────────────

  group('ReturnCodeRequested', () {
    blocTest<CancellationBloc, CancellationState>(
      'emits [Loading, ReturnCodeLoaded] with code + deadline',
      build: buildBloc,
      setUp: () {
        when(() => mockRepo.getReturnCode('bid-1')).thenAnswer(
          (_) async => ReturnCodeModel(
            returnCode: '654321',
            returnDeadline: DateTime(2024, 6, 4, 10),
          ),
        );
      },
      act: (b) => b.add(ReturnCodeRequested('bid-1')),
      expect: () => [
        isA<CancellationLoading>(),
        isA<ReturnCodeLoaded>()
            .having((s) => s.result.returnCode, 'returnCode', '654321')
            .having((s) => s.result.isReturned, 'isReturned', false),
      ],
    );

    blocTest<CancellationBloc, CancellationState>(
      'emits [Loading, Error] on exception',
      build: buildBloc,
      setUp: () {
        when(
          () => mockRepo.getReturnCode(any()),
        ).thenThrow(Exception('network error'));
      },
      act: (b) => b.add(ReturnCodeRequested('bid-x')),
      expect: () => [isA<CancellationLoading>(), isA<CancellationError>()],
    );
  });

  // ── ReturnCodeModel.fromJson ─────────────────────────────────────────────────

  group('ReturnCodeModel.fromJson', () {
    test('parses code + deadline, returnedAt null → not returned', () {
      final m = ReturnCodeModel.fromJson({
        'returnCode': '424242',
        'returnDeadline': '2024-06-04T10:00:00Z',
        'returnedAt': null,
      });
      expect(m.returnCode, '424242');
      expect(m.returnDeadline, isNotNull);
      expect(m.isReturned, false);
    });

    test('returnedAt present → isReturned true, code may be null', () {
      final m = ReturnCodeModel.fromJson({
        'returnCode': null,
        'returnDeadline': '2024-06-04T10:00:00Z',
        'returnedAt': '2024-06-02T09:30:00Z',
      });
      expect(m.returnCode, isNull);
      expect(m.isReturned, true);
    });
  });
}
