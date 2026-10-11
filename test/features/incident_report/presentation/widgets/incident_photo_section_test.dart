import 'dart:convert';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/widgets/dony_snackbar.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/media_service.dart';
import 'package:dony/features/incident_report/bloc/incident_photo_upload.dart';
import 'package:dony/features/incident_report/bloc/incident_photos_cubit.dart';
import 'package:dony/features/incident_report/presentation/widgets/incident_photo_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';

class MockPhotosCubit extends MockCubit<List<IncidentPhotoUpload>>
    implements IncidentPhotosCubit {}

class _MockMediaService extends Mock implements DonyMediaService {}

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

  group('états d\'une capture', () {
    IncidentPhotoUpload photo(IncidentPhotoUploadStatus status) =>
        IncidentPhotoUpload(
          localId: 'p0',
          localPath: tempPhoto.path,
          status: status,
        );

    testWidgets('envoi en cours : indicateur sur la vignette', (tester) async {
      when(
        () => cubit.state,
      ).thenReturn([photo(IncidentPhotoUploadStatus.uploading)]);
      await tester.pumpWidget(_pump(cubit));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
    });

    testWidgets('échec : pastille d\'erreur sur la vignette', (tester) async {
      when(
        () => cubit.state,
      ).thenReturn([photo(IncidentPhotoUploadStatus.failed)]);
      await tester.pumpWidget(_pump(cubit));
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('la croix retire la capture du cubit', (tester) async {
      when(
        () => cubit.state,
      ).thenReturn([photo(IncidentPhotoUploadStatus.failed)]);
      await tester.pumpWidget(_pump(cubit));
      await tester.tap(find.bySemanticsLabel('Supprimer cette photo'));
      verify(() => cubit.remove('p0')).called(1);
    });
  });

  group('ajout d\'une capture', () {
    late _MockMediaService media;

    setUp(() {
      useEnglish();
      DonySnackbar.clearDedup();
      media = _MockMediaService();
      getIt.registerSingleton<DonyMediaService>(media);
      when(() => cubit.state).thenReturn(const []);
      when(() => cubit.add(any())).thenAnswer((_) async {});
    });

    tearDown(() => getIt.unregister<DonyMediaService>());

    Future<void> chooseSource(WidgetTester tester, String label) async {
      await tester.pumpWidget(_pump(cubit));
      await tester.tap(find.bySemanticsLabel('Add a photo'));
      await tester.pumpAndSettle();
      expect(find.text('Take a photo'), findsOneWidget);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    testWidgets('galerie : le fichier choisi part au cubit', (tester) async {
      when(
        () => media.pick(source: ImageSource.gallery),
      ).thenAnswer((_) async => XFile(tempPhoto.path));
      await chooseSource(tester, 'Choose from gallery');
      verify(() => cubit.add(tempPhoto.path)).called(1);
      expect(find.text('Take a photo'), findsNothing);
    });

    testWidgets('appareil photo annulé : rien n\'est ajouté', (tester) async {
      when(
        () => media.pick(source: ImageSource.camera),
      ).thenAnswer((_) async => null);
      await chooseSource(tester, 'Take a photo');
      verify(() => media.pick(source: ImageSource.camera)).called(1);
      verifyNever(() => cubit.add(any()));
    });

    testWidgets('image refusée : avis d\'erreur', (tester) async {
      when(
        () => media.pick(source: ImageSource.camera),
      ).thenThrow(const MediaFileTooLargeException(1, 0));
      await chooseSource(tester, 'Take a photo');
      expect(find.text('Unsupported or too large image'), findsOneWidget);
      verifyNever(() => cubit.add(any()));
      await tester.pump(const Duration(seconds: 10));
    });
  });
}
