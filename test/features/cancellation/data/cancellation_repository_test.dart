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
    when(() => mockDs.cancelTrip(
          announcementId: any(named: 'announcementId'),
          reason: any(named: 'reason'),
        )).thenAnswer((_) async => _cancellation());

    final result = await repo.cancelTrip(
      announcementId: 'ann-001',
      reason: 'SICK',
    );
    expect(result.announcementId, 'ann-001');
  });

  test('getRematchSuggestions delegates to datasource', () async {
    when(() => mockDs.getRematchSuggestions('canc-1'))
        .thenAnswer((_) async => []);

    final result = await repo.getRematchSuggestions('canc-1');
    expect(result, isEmpty);
  });
}
