import 'dart:convert';
import 'dart:typed_data';

import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/presentation/widgets/video_modal_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// PNG 1x1 transparent.
final Uint8List kPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// Image prête pour les tests de rendu.
VideoModalImage fakeModalImage({double aspectRatio = 2}) =>
    VideoModalImage(provider: MemoryImage(kPng), aspectRatio: aspectRatio);

/// Fournisseur qui n'aboutit jamais.
class _NeverProvider extends ImageProvider<_NeverProvider> {
  @override
  Future<_NeverProvider> obtainKey(ImageConfiguration c) => Future.value(this);

  @override
  ImageStreamCompleter loadImage(
    _NeverProvider key,
    ImageDecoderCallback decode,
  ) => _NeverCompleter();
}

class _NeverCompleter extends ImageStreamCompleter {}

/// Fournisseur en échec.
class _FailingProvider extends ImageProvider<_FailingProvider> {
  @override
  Future<_FailingProvider> obtainKey(ImageConfiguration c) =>
      Future.value(this);

  @override
  ImageStreamCompleter loadImage(
    _FailingProvider key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(Future.error(Exception('404')));
}

class _ThrowingProvider extends ImageProvider<_ThrowingProvider> {
  @override
  Future<_ThrowingProvider> obtainKey(ImageConfiguration c) =>
      throw StateError('boom');
}

void main() {
  testWidgets('image lisible : fournisseur et rapport largeur/hauteur', (
    tester,
  ) async {
    final image = await tester.runAsync(
      () => loadVideoModalImage(
        'https://x/a.png',
        providerFor: (_) => MemoryImage(kPng),
      ),
    );
    expect(image, isNotNull);
    expect(image!.aspectRatio, 1);
  });

  testWidgets('échec de téléchargement : null, sans exception', (tester) async {
    final image = await tester.runAsync(
      () => loadVideoModalImage(
        'https://x/a.png',
        providerFor: (_) => _FailingProvider(),
      ),
    );
    expect(image, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fournisseur qui lève : null', (tester) async {
    final image = await tester.runAsync(
      () => loadVideoModalImage(
        'https://x/a.png',
        providerFor: (_) => _ThrowingProvider(),
      ),
    );
    expect(image, isNull);
  });

  testWidgets('délai dépassé : null', (tester) async {
    final image = await tester.runAsync(
      () => loadVideoModalImage(
        'https://x/a.png',
        timeout: const Duration(milliseconds: 50),
        providerFor: (_) => _NeverProvider(),
      ),
    );
    expect(image, isNull);
  });

  test('le délai par défaut est de 3 secondes', () {
    expect(videoModalImageTimeout, const Duration(seconds: 3));
  });

  testWidgets('bannière : rapport borné, texte alternatif exposé', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    for (final (ratio, expected) in [(0.5, 1.0), (1.6, 1.6), (5.0, 2.4)]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoModalBanner(
              image: fakeModalImage(aspectRatio: ratio),
              fit: VideoModalImageFit.cover,
              semanticLabel: 'Affiche',
            ),
          ),
        ),
      );
      final size = tester.getSize(find.byKey(const Key('video-modal-banner')));
      expect(size.width / size.height, closeTo(expected, 0.01));
    }
    expect(find.bySemanticsLabel('Affiche'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('affiche en hauteur non bornée : garde le rapport, cadrage', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VideoModalPoster(
              image: fakeModalImage(aspectRatio: 0.5),
              fit: VideoModalImageFit.contain,
              semanticLabel: 'a',
            ),
          ),
        ),
      ),
    );
    final size = tester.getSize(find.byKey(const Key('video-modal-poster')));
    expect(size.width / size.height, closeTo(0.5, 0.01));
    expect(
      tester.widget<Image>(find.byKey(const Key('video-modal-image'))).fit,
      BoxFit.contain,
    );
  });

  testWidgets('affiche en hauteur bornée : remplit la place', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 400,
            child: VideoModalPoster(
              image: fakeModalImage(),
              fit: VideoModalImageFit.cover,
              semanticLabel: 'a',
            ),
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byKey(const Key('video-modal-poster'))),
      const Size(200, 400),
    );
    expect(
      tester.widget<Image>(find.byKey(const Key('video-modal-image'))).fit,
      BoxFit.cover,
    );
  });
}
