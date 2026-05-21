import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/settings/bloc/account_deletion_bloc.dart';
import 'package:dony/features/settings/bloc/data_export_bloc.dart';
import 'package:dony/features/settings/presentation/screens/data_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockDataExportBloc
    extends MockBloc<DataExportEvent, DataExportState>
    implements DataExportBloc {}

class MockAccountDeletionBloc
    extends MockBloc<AccountDeletionEvent, AccountDeletionState>
    implements AccountDeletionBloc {}

Widget _wrap(Widget child) => MaterialApp.router(
      routerConfig: GoRouter(
        routes: [GoRoute(path: '/', builder: (_, __) => child)],
      ),
    );

void main() {
  late MockDataExportBloc mockDataExportBloc;
  late MockAccountDeletionBloc mockAccountDeletionBloc;

  setUp(() {
    mockDataExportBloc = MockDataExportBloc();
    mockAccountDeletionBloc = MockAccountDeletionBloc();
    when(() => mockDataExportBloc.state).thenReturn(const DataExportInitial());
    when(() => mockAccountDeletionBloc.state)
        .thenReturn(const AccountDeletionInitial());
  });

  Widget buildScreen() => MultiBlocProvider(
        providers: [
          BlocProvider<DataExportBloc>.value(value: mockDataExportBloc),
          BlocProvider<AccountDeletionBloc>.value(
              value: mockAccountDeletionBloc),
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

    testWidgets('affiche la section DANGER ZONE', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();
      expect(find.text('DANGER ZONE'), findsOneWidget);
    });

    testWidgets('affiche "Supprimer mon compte"', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();
      expect(find.text('Supprimer mon compte'), findsOneWidget);
    });

    testWidgets('affiche "Action irréversible" comme sous-titre',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();
      expect(find.text('Action irréversible'), findsOneWidget);
    });

    testWidgets('affiche CircularProgressIndicator quand DataExportLoading',
        (tester) async {
      when(() => mockDataExportBloc.state)
          .thenReturn(const DataExportLoading());
      whenListen<DataExportState>(
        mockDataExportBloc,
        const Stream.empty(),
        initialState: const DataExportLoading(),
      );

      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('tap sur Télécharger envoie DataExportRequested',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Télécharger mes données'));
      await tester.pump();

      verify(() => mockDataExportBloc.add(const DataExportRequested()))
          .called(1);
    });

    testWidgets('affiche snackbar succès quand DataExportSuccess',
        (tester) async {
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

    testWidgets('affiche snackbar erreur quand DataExportError',
        (tester) async {
      const errorMessage = 'Erreur réseau';
      final stream = Stream<DataExportState>.fromIterable([
        const DataExportError(errorMessage),
      ]);
      whenListen<DataExportState>(
        mockDataExportBloc,
        stream,
        initialState: const DataExportInitial(),
      );

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text(errorMessage), findsOneWidget);
    });
  });
}
