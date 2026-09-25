import 'dart:convert';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/incident_report/bloc/incident_photo_upload.dart';
import 'package:dony/features/incident_report/bloc/incident_photos_cubit.dart';
import 'package:dony/features/incident_report/presentation/widgets/incident_photo_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';

class MockPhotosCubit extends MockCubit<List<IncidentPhotoUpload>>
    implements IncidentPhotosCubit {}

// PNG 1×1 valide (transparent) : évite un échec de décodage dans
// _PhotoThumb (Image.file) quand une capture prête est affichée.
const _tinyPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

Widget _pump(MockPhotosCubit cubit) => MaterialApp(
  home: Scaffold(
    body: BlocProvider<IncidentPhotosCubit>.value(
      value: cubit,
      child: const IncidentPhotoSection(),
    ),
  ),
);

void main() {
  late MockPhotosCubit cubit;
  late File tempPhoto;

  setUp(() {
    cubit = MockPhotosCubit();
  });

  setUpAll(() {
    tempPhoto = File(
      '${Directory.systemTemp.path}/incident_photo_section_test.png',
    )..writeAsBytesSync(base64Decode(_tinyPngBase64));
  });

  tearDownAll(() {
    if (tempPhoto.existsSync()) tempPhoto.deleteSync();
  });

  testWidgets(
    'aucune photo : bouton d\'ajout accessible « Ajouter une photo »',
    (tester) async {
      when(() => cubit.state).thenReturn(const []);
      await tester.pumpWidget(_pump(cubit));

      expect(find.bySemanticsLabel('Ajouter une photo'), findsOneWidget);
    },
  );

  testWidgets('une photo prête : bouton de retrait « Supprimer cette photo »', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn([
      IncidentPhotoUpload(
        localId: 'p0',
        localPath: tempPhoto.path,
        status: IncidentPhotoUploadStatus.ready,
        remoteKey: 'k',
      ),
    ]);
    await tester.pumpWidget(_pump(cubit));
    await tester.pump();

    expect(find.bySemanticsLabel('Supprimer cette photo'), findsOneWidget);
    // Toujours possible d'ajouter (1 < maxPhotos).
    expect(find.bySemanticsLabel('Ajouter une photo'), findsOneWidget);
  });

  testWidgets('4 photos : plus de bouton d\'ajout', (tester) async {
    when(() => cubit.state).thenReturn(
      List.generate(
        4,
        (i) => IncidentPhotoUpload(
          localId: 'p$i',
          localPath: tempPhoto.path,
          status: IncidentPhotoUploadStatus.ready,
          remoteKey: 'k$i',
        ),
      ),
    );
    await tester.pumpWidget(_pump(cubit));
    await tester.pump();

    expect(find.bySemanticsLabel('Ajouter une photo'), findsNothing);
  });

  testWidgets('anglais : libellés d\'accessibilité traduits', (tester) async {
    useEnglish();
    when(() => cubit.state).thenReturn([
      IncidentPhotoUpload(
        localId: 'p0',
        localPath: tempPhoto.path,
        status: IncidentPhotoUploadStatus.ready,
        remoteKey: 'k',
      ),
    ]);
    await tester.pumpWidget(_pump(cubit));
    await tester.pump();

    expect(find.bySemanticsLabel('Add a photo'), findsOneWidget);
    expect(find.bySemanticsLabel('Remove this photo'), findsOneWidget);
  });
}
