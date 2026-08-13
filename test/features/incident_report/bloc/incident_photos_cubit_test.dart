import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/incident_report/bloc/incident_photo_upload.dart';
import 'package:dony/features/incident_report/bloc/incident_photos_cubit.dart';
import 'package:dony/features/incident_report/data/repositories/incident_report_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class MockIncidentReportRepository extends Mock
    implements IncidentReportRepository {}

void main() {
  late MockIncidentReportRepository repository;
  late MockAnalyticsBackend analyticsBackend;

  setUp(() {
    repository = MockIncidentReportRepository();
    analyticsBackend = MockAnalyticsBackend();
  });

  IncidentPhotosCubit build() =>
      IncidentPhotosCubit(repository, makeDisabledAnalytics(analyticsBackend));

  group('add', () {
    blocTest<IncidentPhotosCubit, List<IncidentPhotoUpload>>(
      'upload réussi : uploading puis ready avec la clé',
      build: () {
        when(
          () => repository.uploadPhoto('/tmp/a.png'),
        ).thenAnswer((_) async => 'reports/u/a.png');
        return build();
      },
      act: (cubit) => cubit.add('/tmp/a.png'),
      expect: () => [
        [
          isA<IncidentPhotoUpload>().having(
            (p) => p.status,
            'status',
            IncidentPhotoUploadStatus.uploading,
          ),
        ],
        [
          isA<IncidentPhotoUpload>()
              .having(
                (p) => p.status,
                'status',
                IncidentPhotoUploadStatus.ready,
              )
              .having((p) => p.remoteKey, 'remoteKey', 'reports/u/a.png'),
        ],
      ],
    );

    blocTest<IncidentPhotosCubit, List<IncidentPhotoUpload>>(
      'upload échoué : uploading puis failed',
      build: () {
        when(
          () => repository.uploadPhoto(any()),
        ).thenThrow(Exception('réseau'));
        return build();
      },
      act: (cubit) => cubit.add('/tmp/b.png'),
      expect: () => [
        [
          isA<IncidentPhotoUpload>().having(
            (p) => p.status,
            'status',
            IncidentPhotoUploadStatus.uploading,
          ),
        ],
        [
          isA<IncidentPhotoUpload>().having(
            (p) => p.status,
            'status',
            IncidentPhotoUploadStatus.failed,
          ),
        ],
      ],
    );

    test('refuse la 5e photo', () async {
      when(() => repository.uploadPhoto(any())).thenAnswer((_) async => 'k');
      final cubit = build();
      for (var i = 0; i < 5; i++) {
        await cubit.add('/tmp/$i.png');
      }
      expect(cubit.state.length, IncidentPhotosCubit.maxPhotos);
    });
  });

  group('remove / getters', () {
    test(
      'remove retire la photo ; readyKeys et hasUploading cohérents',
      () async {
        when(
          () => repository.uploadPhoto('/tmp/ok.png'),
        ).thenAnswer((_) async => 'reports/u/ok.png');
        when(
          () => repository.uploadPhoto('/tmp/ko.png'),
        ).thenThrow(Exception());
        final cubit = build();

        await cubit.add('/tmp/ok.png');
        await cubit.add('/tmp/ko.png');

        expect(cubit.readyKeys, ['reports/u/ok.png']);
        expect(cubit.hasUploading, isFalse);

        cubit.remove(cubit.state.first.localId);
        expect(cubit.state.length, 1);
        expect(cubit.readyKeys, isEmpty);
      },
    );
  });
}
