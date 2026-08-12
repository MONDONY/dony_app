import 'package:dony/features/cancellation/data/datasources/cancellation_remote_datasource.dart';
import 'package:dony/features/cancellation/data/models/cancellation_model.dart';
import 'package:dony/features/cancellation/data/repositories/cancellation_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCancellationRemoteDatasource extends Mock
    implements CancellationRemoteDatasource {}

CancellationModel _cancellation() => CancellationModel(
  announcementId: 'ann-001',
  affectedBidsCount: 1,
  reason: 'SICK',
  rematchSuggestions: [],
  cancelledAt: DateTime(2024, 1, 15),
);

void main() {
  late MockCancellationRemoteDatasource mockDs;
  late CancellationRepository repo;

  setUp(() {
    mockDs = MockCancellationRemoteDatasource();
    repo = CancellationRepository(mockDs);
  });

  test('cancelTrip delegates to datasource', () async {
    when(
      () => mockDs.cancelTrip(
        announcementId: any(named: 'announcementId'),
        reason: any(named: 'reason'),
      ),
    ).thenAnswer((_) async => _cancellation());

    final result = await repo.cancelTrip(
      announcementId: 'ann-001',
      reason: 'SICK',
    );
    expect(result.announcementId, 'ann-001');
  });

  test('getRematchSuggestions delegates to datasource', () async {
    when(
      () => mockDs.getRematchSuggestions('canc-1'),
    ).thenAnswer((_) async => []);

    final result = await repo.getRematchSuggestions('canc-1');
    expect(result, isEmpty);
  });

  test('reportNoShow delegates to datasource', () async {
    when(() => mockDs.reportNoShow('bid-1')).thenAnswer((_) async {});

    await repo.reportNoShow('bid-1');

    verify(() => mockDs.reportNoShow('bid-1')).called(1);
  });

  test('contestNoShow delegates to datasource', () async {
    when(() => mockDs.contestNoShow('bid-2')).thenAnswer((_) async {});

    await repo.contestNoShow('bid-2');

    verify(() => mockDs.contestNoShow('bid-2')).called(1);
  });

  test('reportDeliveryNoShow delegates to datasource', () async {
    when(() => mockDs.reportDeliveryNoShow('bid-4')).thenAnswer((_) async {});

    await repo.reportDeliveryNoShow('bid-4');

    verify(() => mockDs.reportDeliveryNoShow('bid-4')).called(1);
  });

  test('reportTravelerDeliveryNoShow delegates to datasource', () async {
    when(
      () => mockDs.reportTravelerDeliveryNoShow('bid-5'),
    ).thenAnswer((_) async {});

    await repo.reportTravelerDeliveryNoShow('bid-5');

    verify(() => mockDs.reportTravelerDeliveryNoShow('bid-5')).called(1);
  });

  test('contestDeliveryNoShow delegates to datasource', () async {
    when(() => mockDs.contestDeliveryNoShow('bid-6')).thenAnswer((_) async {});

    await repo.contestDeliveryNoShow('bid-6');

    verify(() => mockDs.contestDeliveryNoShow('bid-6')).called(1);
  });

  test('confirmNoShow delegates to datasource', () async {
    when(() => mockDs.confirmNoShow('bid-3')).thenAnswer((_) async {});

    await repo.confirmNoShow('bid-3');

    verify(() => mockDs.confirmNoShow('bid-3')).called(1);
  });

  test('cancelAfterHandover delegates to datasource', () async {
    when(() => mockDs.cancelAfterHandover('bid-3')).thenAnswer((_) async {});

    await repo.cancelAfterHandover('bid-3');

    verify(() => mockDs.cancelAfterHandover('bid-3')).called(1);
  });

  test('confirmReturn delegates to datasource', () async {
    when(
      () => mockDs.confirmReturn('bid-3', '123456'),
    ).thenAnswer((_) async => const ReturnCodeModel(returnedAt: null));

    await repo.confirmReturn('bid-3', '123456');

    verify(() => mockDs.confirmReturn('bid-3', '123456')).called(1);
  });

  test('getReturnCode delegates to datasource', () async {
    when(
      () => mockDs.getReturnCode('bid-3'),
    ).thenAnswer((_) async => const ReturnCodeModel(returnCode: '654321'));

    final result = await repo.getReturnCode('bid-3');

    expect(result.returnCode, '654321');
    verify(() => mockDs.getReturnCode('bid-3')).called(1);
  });
}
