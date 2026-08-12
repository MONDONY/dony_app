import 'dart:io';

import 'package:dony/features/package_request/bloc/package_request_photo_upload.dart';
import 'package:dony/features/package_request/bloc/package_request_photos_cubit.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class MockPackageRequestRepository extends Mock
    implements PackageRequestRepository {}

void main() {
  setUpAll(() => registerFallbackValue(File('x')));

  late MockPackageRequestRepository repo;
  late PackageRequestPhotosCubit cubit;

  setUp(() {
    repo = MockPackageRequestRepository();
    cubit = PackageRequestPhotosCubit(
      repo,
      makeDisabledAnalytics(MockAnalyticsBackend()),
    );
  });

  test('add uploads and marks ready with key', () async {
    when(
      () => repo.uploadPhotoKey(any()),
    ).thenAnswer((_) async => 'package_requests/s/1.jpg');
    await cubit.add('/tmp/1.jpg');
    expect(cubit.state.single.status, PackageRequestPhotoUploadStatus.ready);
    expect(cubit.readyKeys, ['package_requests/s/1.jpg']);
    expect(cubit.touched, isTrue);
  });

  test('add marks failed on error', () async {
    when(() => repo.uploadPhotoKey(any())).thenThrow(Exception('boom'));
    await cubit.add('/tmp/1.jpg');
    expect(cubit.state.single.status, PackageRequestPhotoUploadStatus.failed);
    expect(cubit.readyKeys, isEmpty);
  });

  test('caps at 4 photos', () async {
    when(
      () => repo.uploadPhotoKey(any()),
    ).thenAnswer((_) async => 'package_requests/s/x.jpg');
    for (var i = 0; i < 5; i++) {
      await cubit.add('/tmp/$i.jpg');
    }
    expect(cubit.state.length, 4);
    expect(cubit.canAddMore, isFalse);
  });

  test('remove drops the entry', () async {
    when(
      () => repo.uploadPhotoKey(any()),
    ).thenAnswer((_) async => 'package_requests/s/1.jpg');
    await cubit.add('/tmp/1.jpg');
    cubit.remove(cubit.state.single.localId);
    expect(cubit.state, isEmpty);
  });

  test('seed charge les photos existantes en ready + readyKeys', () {
    cubit.seed([
      (key: 'package_requests/s/1.jpg', url: 'https://signed/1'),
      (key: 'package_requests/s/2.jpg', url: 'https://signed/2'),
    ]);
    expect(cubit.state.length, 2);
    expect(
      cubit.state.every(
        (p) => p.status == PackageRequestPhotoUploadStatus.ready,
      ),
      isTrue,
    );
    expect(cubit.state.first.remoteUrl, 'https://signed/1');
    expect(cubit.state.first.localPath, isEmpty);
    expect(cubit.readyKeys, [
      'package_requests/s/1.jpg',
      'package_requests/s/2.jpg',
    ]);
    expect(cubit.touched, isTrue);
  });

  test('seed est un no-op si l\'état n\'est pas vide', () async {
    when(
      () => repo.uploadPhotoKey(any()),
    ).thenAnswer((_) async => 'package_requests/s/new.jpg');
    await cubit.add('/tmp/new.jpg');
    cubit.seed([
      (key: 'package_requests/s/old.jpg', url: 'https://signed/old'),
    ]);
    expect(cubit.state.length, 1);
    expect(cubit.readyKeys, ['package_requests/s/new.jpg']);
  });

  test('seed plafonne à 4', () {
    cubit.seed([
      for (var i = 0; i < 6; i++)
        (key: 'package_requests/s/\$i.jpg', url: 'https://signed/\$i'),
    ]);
    expect(cubit.state.length, 4);
  });

  test('retirer une photo seedée la sort de readyKeys', () {
    cubit.seed([
      (key: 'package_requests/s/1.jpg', url: 'https://signed/1'),
      (key: 'package_requests/s/2.jpg', url: 'https://signed/2'),
    ]);
    cubit.remove(cubit.state.first.localId);
    expect(cubit.readyKeys, ['package_requests/s/2.jpg']);
  });
}
