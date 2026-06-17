import 'package:dony/features/matching/bloc/bid_photo_upload.dart';
import 'package:dony/features/matching/bloc/bid_photos_cubit.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class MockBidRepository extends Mock implements BidRepository {}

void main() {
  late MockBidRepository repo;
  late BidPhotosCubit cubit;

  setUp(() {
    repo = MockBidRepository();
    cubit = BidPhotosCubit(repo, makeDisabledAnalytics(MockAnalyticsBackend()));
  });

  test('add uploads and marks ready with key', () async {
    when(() => repo.uploadBidPhoto(any())).thenAnswer((_) async => 'bids/s/1.jpg');
    await cubit.add('/tmp/1.jpg');
    expect(cubit.state.single.status, BidPhotoUploadStatus.ready);
    expect(cubit.readyKeys, ['bids/s/1.jpg']);
  });

  test('add marks failed on error', () async {
    when(() => repo.uploadBidPhoto(any())).thenThrow(Exception('boom'));
    await cubit.add('/tmp/1.jpg');
    expect(cubit.state.single.status, BidPhotoUploadStatus.failed);
    expect(cubit.readyKeys, isEmpty);
  });

  test('caps at 4 photos', () async {
    when(() => repo.uploadBidPhoto(any())).thenAnswer((_) async => 'bids/s/x.jpg');
    for (var i = 0; i < 5; i++) {
      await cubit.add('/tmp/$i.jpg');
    }
    expect(cubit.state.length, 4);
    expect(cubit.canAddMore, isFalse);
  });

  test('remove drops the entry', () async {
    when(() => repo.uploadBidPhoto(any())).thenAnswer((_) async => 'bids/s/1.jpg');
    await cubit.add('/tmp/1.jpg');
    cubit.remove(cubit.state.single.localId);
    expect(cubit.state, isEmpty);
  });
}
