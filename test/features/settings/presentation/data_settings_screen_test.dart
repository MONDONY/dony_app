import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/settings/bloc/account_deletion_bloc.dart';
import 'package:dony/features/settings/bloc/data_export_bloc.dart';
import 'package:dony/features/settings/presentation/screens/data_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/l10n_test_helpers.dart';

class MockDataExportBloc extends MockBloc<DataExportEvent, DataExportState>
    implements DataExportBloc {}

class MockAccountDeletionBloc
    extends MockBloc<AccountDeletionEvent, AccountDeletionState>
    implements AccountDeletionBloc {}

Widget _wrap(Widget child) => MaterialApp.router(
  routerConfig: GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => child)],
  ),
);

void main() {
  late MockDataExportBloc mockDataExportBloc;
  late MockAccountDeletionBloc mockAccountDeletionBloc;

  setUp(() {
    mockDataExportBloc = MockDataExportBloc();
    mockAccountDeletionBloc = MockAccountDeletionBloc();
    when(() => mockDataExportBloc.state).thenReturn(const DataExportInitial());
    when(
      () => mockAccountDeletionBloc.state,
    ).thenReturn(const AccountDeletionInitial());
  });

  Widget buildScreen() => MultiBlocProvider(
    providers: [
      BlocProvider<DataExportBloc>.value(value: mockDataExportBloc),
      BlocProvider<AccountDeletionBloc>.value(value: mockAccountDeletionBloc),
    ],
    child: _wrap(const DataSettingsScreen()),
  );

  group('DataSettingsScreen', () {
    testWidgets('affiche le titre "Mes données"', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();
      expect(find.text('Mes données'), findsOneWidget);
    });

    testWidgets('affiche la section VOS DONNÉES', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();
      expect(find.text('VOS DONNÉES'), findsOneWidget);
    });

    testWidgets('affiche la tile "Télécharger mes données"', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();
      expect(find.text('Télécharger mes données'), findsOneWidget);
    });

    testWidgets('affiche le sous-titre export RGPD', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();
      expect(find.text('Export RGPD au format JSON'), findsOneWidget);
    });

    // La suppression du compte vit désormais dans la feuille de menu de
    // l'onglet Moi : cet écran ne porte plus que l'export.
    testWidgets('ne porte plus de « Danger zone » ni de suppression', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();
      expect(find.text('DANGER ZONE'), findsNothing);
      expect(find.text('Supprimer mon compte'), findsNothing);
    });

    testWidgets('affiche CircularProgressIndicator quand DataExportLoading', (
      tester,
    ) async {
      when(
        () => mockDataExportBloc.state,
      ).thenReturn(const DataExportLoading());
      whenListen<DataExportState>(
        mockDataExportBloc,
        const Stream.empty(),
        initialState: const DataExportLoading(),
      );

      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('tap sur Télécharger envoie DataExportRequested', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Télécharger mes données'));
      await tester.pump();

      verify(
        () => mockDataExportBloc.add(const DataExportRequested()),
      ).called(1);
    });

    testWidgets('affiche snackbar succès quand DataExportSuccess', (
      tester,
    ) async {
      final stream = Stream<DataExportState>.fromIterable([
        const DataExportSuccess(),
      ]);
      whenListen<DataExportState>(
        mockDataExportBloc,
        stream,
        initialState: const DataExportInitial(),
      );

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Export lancé'), findsOneWidget);
    });

    testWidgets(
      'affiche snackbar erreur quand DataExportError, jamais le message brut '
      '(ErrorPresenter résout un texte générique depuis l\'AppException)',
      (tester) async {
        final stream = Stream<DataExportState>.fromIterable([
          const DataExportError(NetworkException('detail technique brut')),
        ]);
        whenListen<DataExportState>(
          mockDataExportBloc,
          stream,
          initialState: const DataExportInitial(),
        );

        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Une erreur est survenue. Vérifie ta connexion et '
            'réessaie.',
          ),
          findsOneWidget,
        );
        expect(find.text('detail technique brut'), findsNothing);
      },
    );

    testWidgets('anglais : titre, section et tuile traduits', (tester) async {
      useEnglish();
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('My data'), findsOneWidget);
      expect(find.text('YOUR DATA'), findsOneWidget);
      expect(find.text('Download my data'), findsOneWidget);
      expect(find.text('GDPR export in JSON format'), findsOneWidget);
      expect(find.text('Mes données'), findsNothing);
    });
  });
}
