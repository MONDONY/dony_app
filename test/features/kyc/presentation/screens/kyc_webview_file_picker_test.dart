import 'package:dony/core/services/media_service.dart';
import 'package:dony/features/kyc/presentation/screens/kyc_webview_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class _MockMediaService extends Mock implements DonyMediaService {}

/// Sans sélecteur de fichier, la WebView Android ignorait « Importer une
/// photo » de la page Didit : rien ne s'ouvrait. Le rappel passe par
/// `DonyMediaService`, seul chemin d'import d'images de l'app.
void main() {
  late _MockMediaService media;
  late List<(String, String)> outcomes;
  late int rejections;

  setUpAll(() => registerFallbackValue(ImageSource.gallery));

  setUp(() {
    media = _MockMediaService();
    outcomes = [];
    rejections = 0;
  });

  Future<List<String>> run({bool capture = false}) => pickKycWebviewFile(
    FileSelectorParams(
      isCaptureEnabled: capture,
      acceptTypes: const ['image/*'],
      mode: FileSelectorMode.open,
    ),
    media: media,
    onOutcome: (source, outcome) => outcomes.add((source, outcome)),
    onRejected: () => rejections++,
  );

  test('galerie : rend l\'URI du fichier choisi', () async {
    when(
      () => media.pick(source: ImageSource.gallery),
    ).thenAnswer((_) async => XFile('/cache/photo.jpg'));

    expect(await run(), ['file:///cache/photo.jpg']);
    expect(outcomes, [('gallery', 'selected')]);
    expect(rejections, 0);
  });

  test('page qui demande la capture : appareil photo', () async {
    when(
      () => media.pick(source: ImageSource.camera),
    ).thenAnswer((_) async => XFile('/cache/selfie.jpg'));

    expect(await run(capture: true), ['file:///cache/selfie.jpg']);
    expect(outcomes, [('camera', 'selected')]);
    verifyNever(() => media.pick(source: ImageSource.gallery));
  });

  test('chemin avec espaces : URI correctement encodée', () async {
    when(
      () => media.pick(source: ImageSource.gallery),
    ).thenAnswer((_) async => XFile('/cache/ma photo.jpg'));

    expect(await run(), ['file:///cache/ma%20photo.jpg']);
  });

  test('annulation : liste vide, sans avis à l\'utilisateur', () async {
    when(
      () => media.pick(source: ImageSource.gallery),
    ).thenAnswer((_) async => null);

    expect(await run(), isEmpty);
    expect(outcomes, [('gallery', 'cancelled')]);
    expect(rejections, 0);
  });

  test('fichier qui n\'est pas une image : refusé avec avis', () async {
    when(
      () => media.pick(source: ImageSource.gallery),
    ).thenThrow(const UnsupportedMediaTypeException('clip.mp4'));

    expect(await run(), isEmpty);
    expect(outcomes, [('gallery', 'rejected')]);
    expect(rejections, 1);
  });

  test('fichier démesuré : refusé avec avis', () async {
    when(() => media.pick(source: ImageSource.gallery)).thenThrow(
      const MediaFileTooLargeException(60 * 1024 * 1024, 50 * 1024 * 1024),
    );

    expect(await run(), isEmpty);
    expect(outcomes, [('gallery', 'rejected')]);
    expect(rejections, 1);
  });

  test('erreur inattendue : liste vide, tracée, sans planter', () async {
    when(
      () => media.pick(source: ImageSource.gallery),
    ).thenThrow(StateError('plugin indisponible'));

    expect(await run(), isEmpty);
    expect(outcomes, [('gallery', 'error')]);
    expect(rejections, 0);
  });
}
