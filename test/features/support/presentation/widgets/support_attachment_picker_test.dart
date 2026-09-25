import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/support/bloc/support_bloc.dart';
import 'package:dony/features/support/data/support_attachment.dart';
import 'package:dony/features/support/presentation/widgets/support_attachment_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/l10n_test_helpers.dart';

class MockSupportBloc extends MockBloc<SupportEvent, SupportState>
    implements SupportBloc {}

Widget _harness(SupportBloc bloc) => MaterialApp(
  home: Scaffold(
    body: BlocProvider<SupportBloc>.value(
      value: bloc,
      child: const SupportAttachmentPicker(),
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

  testWidgets('trombone : tooltip et sheet de sélection en français', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(bloc));

    expect(find.byTooltip('Joindre une image'), findsOneWidget);

    await tester.tap(find.byTooltip('Joindre une image'));
    await tester.pumpAndSettle();

    expect(find.text('Prendre une photo'), findsOneWidget);
    expect(find.text('Choisir dans la galerie'), findsOneWidget);
  });

  testWidgets('anglais : tooltip et sheet de sélection traduits', (
    tester,
  ) async {
    useEnglish();
    await tester.pumpWidget(_harness(bloc));

    expect(find.byTooltip('Attach an image'), findsOneWidget);

    await tester.tap(find.byTooltip('Attach an image'));
    await tester.pumpAndSettle();

    expect(find.text('Take a photo'), findsOneWidget);
    expect(find.text('Choose from gallery'), findsOneWidget);
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
}
