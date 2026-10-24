import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/widgets/dony_snackbar.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/media_service.dart';
import 'package:dony/features/support/bloc/support_bloc.dart';
import 'package:dony/features/support/data/support_attachment.dart';
import 'package:dony/features/support/presentation/widgets/support_attachment_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';

class MockSupportBloc extends MockBloc<SupportEvent, SupportState>
    implements SupportBloc {}

class _MockMediaService extends Mock implements DonyMediaService {}

Widget _harness(SupportBloc bloc) => MaterialApp(
  home: Scaffold(
    body: BlocProvider<SupportBloc>.value(
      value: bloc,
      child: Column(
        children: [
          Builder(
            builder: (context) => TextButton(
              key: const Key('open-source-sheet'),
              onPressed: () =>
                  SupportAttachmentActions.showSourceSheet(context),
              child: const Text('ouvrir'),
            ),
          ),
          const SupportAttachmentStrip(),
        ],
      ),
    ),
  ),
);

void main() {
  late MockSupportBloc bloc;

  setUp(() {
    bloc = MockSupportBloc();
    whenListen(
      bloc,
      const Stream<SupportState>.empty(),
      initialState: const SupportState(),
    );
  });

  testWidgets('feuille de sélection en français', (tester) async {
    await tester.pumpWidget(_harness(bloc));

    await tester.tap(find.byKey(const Key('open-source-sheet')));
    await tester.pumpAndSettle();

    expect(find.text('Prendre une photo'), findsOneWidget);
    expect(find.text('Choisir dans la galerie'), findsOneWidget);
  });

  testWidgets('anglais : feuille de sélection traduite', (tester) async {
    useEnglish();
    await tester.pumpWidget(_harness(bloc));

    await tester.tap(find.byKey(const Key('open-source-sheet')));
    await tester.pumpAndSettle();

    expect(find.text('Take a photo'), findsOneWidget);
    expect(find.text('Choose from gallery'), findsOneWidget);
  });

  testWidgets('sans image en attente : le bandeau ne prend aucune place', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(bloc));
    expect(
      tester.getSize(find.byType(SupportAttachmentStrip)),
      const Size(0, 0),
    );
  });

  testWidgets('anglais : libellé de retrait d\'une vignette traduit', (
    tester,
  ) async {
    useEnglish();
    whenListen(
      bloc,
      const Stream<SupportState>.empty(),
      initialState: const SupportState(
        pendingAttachments: [
          SupportAttachmentUpload(
            localId: 'local-1',
            localPath: '/tmp/a.jpg',
            status: SupportUploadStatus.ready,
            remoteKey: 'remote/a.jpg',
          ),
        ],
      ),
    );

    await tester.pumpWidget(_harness(bloc));

    expect(find.bySemanticsLabel('Remove this image'), findsOneWidget);
  });

  group('choix et retrait des images', () {
    late _MockMediaService media;

    setUp(() {
      useEnglish();
      DonySnackbar.clearDedup();
      media = _MockMediaService();
      getIt.registerSingleton<DonyMediaService>(media);
    });

    tearDown(() => getIt.unregister<DonyMediaService>());

    Future<void> choose(WidgetTester tester, String source) async {
      await tester.tap(find.byKey(const Key('open-source-sheet')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(source));
      await tester.pumpAndSettle();
    }

    testWidgets('appareil photo : l\'image part au BLoC', (tester) async {
      when(
        () => media.pick(source: ImageSource.camera),
      ).thenAnswer((_) async => XFile('/tmp/support.jpg'));
      await tester.pumpWidget(_harness(bloc));
      await choose(tester, 'Take a photo');
      verify(
        () =>
            bloc.add(const SupportAttachmentPickRequested('/tmp/support.jpg')),
      ).called(1);
    });

    testWidgets('deux demandes rapides : une seule prise de photo', (
      tester,
    ) async {
      final gate = Completer<XFile?>();
      when(
        () => media.pick(source: ImageSource.camera),
      ).thenAnswer((_) => gate.future);
      await tester.pumpWidget(_harness(bloc));
      final context = tester.element(
        find.byKey(const Key('open-source-sheet')),
      );

      unawaited(SupportAttachmentActions.pick(context, ImageSource.camera));
      unawaited(SupportAttachmentActions.pick(context, ImageSource.camera));
      gate.complete(XFile('/tmp/support.jpg'));
      await tester.pumpAndSettle();

      verify(() => media.pick(source: ImageSource.camera)).called(1);
      verify(
        () =>
            bloc.add(const SupportAttachmentPickRequested('/tmp/support.jpg')),
      ).called(1);
    });

    testWidgets('galerie annulée : aucun événement', (tester) async {
      when(
        () => media.pick(source: ImageSource.gallery),
      ).thenAnswer((_) async => null);
      await tester.pumpWidget(_harness(bloc));
      await choose(tester, 'Choose from gallery');
      verify(() => media.pick(source: ImageSource.gallery)).called(1);
      verifyNever(
        () =>
            bloc.add(const SupportAttachmentPickRequested('/tmp/support.jpg')),
      );
    });

    testWidgets('image refusée : avis d\'erreur', (tester) async {
      when(
        () => media.pick(source: ImageSource.camera),
      ).thenThrow(const MediaFileTooLargeException(1, 0));
      await tester.pumpWidget(_harness(bloc));
      await choose(tester, 'Take a photo');
      expect(find.text('Unsupported or too large image'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('vignettes : retrait, choix après coup et image illisible', (
      tester,
    ) async {
      whenListen(
        bloc,
        const Stream<SupportState>.empty(),
        initialState: const SupportState(
          pendingAttachments: [
            SupportAttachmentUpload(
              localId: 'local-9',
              localPath: '/tmp/absente-support.jpg',
              status: SupportUploadStatus.ready,
              remoteKey: 'k',
            ),
          ],
        ),
      );
      when(
        () => media.pick(source: ImageSource.gallery),
      ).thenAnswer((_) async => XFile('/tmp/autre.jpg'));
      await tester.pumpWidget(_harness(bloc));

      // Fichier absent : l'image retombe sur l'icône de remplacement.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Remove this image'));
      verify(
        () => bloc.add(const SupportAttachmentRemoved('local-9')),
      ).called(1);

      await choose(tester, 'Choose from gallery');
      verify(
        () => bloc.add(const SupportAttachmentPickRequested('/tmp/autre.jpg')),
      ).called(1);
    });
  });
}
