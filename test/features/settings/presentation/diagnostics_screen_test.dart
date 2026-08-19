import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/settings/bloc/diagnostics_bloc.dart';
import 'package:dony/features/settings/presentation/screens/diagnostics_screen.dart';
import 'package:dony/features/settings/presentation/widgets/settings_flat_group.dart';
import 'package:dony/features/settings/presentation/widgets/settings_section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockDiagnosticsBloc extends MockBloc<DiagnosticsEvent, DiagnosticsState>
    implements DiagnosticsBloc {}

class _FakeDiagnosticsEvent extends Fake implements DiagnosticsEvent {}

Widget _wrap({
  String? appVersion = '1.2.3',
  String? buildNumber = '42',
  bool isPinging = false,
  bool? apiOk,
}) {
  final mockBloc = MockDiagnosticsBloc();
  final state = DiagnosticsState(
    appVersion: appVersion,
    buildNumber: buildNumber,
    isPinging: isPinging,
    apiOk: apiOk,
  );
  when(() => mockBloc.state).thenReturn(state);
  whenListen<DiagnosticsState>(
    mockBloc,
    const Stream.empty(),
    initialState: state,
  );

  return MaterialApp(
    home: BlocProvider<DiagnosticsBloc>.value(
      value: mockBloc,
      child: const DiagnosticsScreen(),
    ),
  );
}

// « Signaler un bug » doit naviguer vers l'écran réel de signalement (celui qui
// accepte des captures d'écran), pas ouvrir une boîte de dialogue qui n'envoie
// rien au back. Le routeur du test enregistre la même route que router.dart.
Widget _wrapWithRouter({
  String? appVersion = '1.2.3',
  String? buildNumber = '42',
}) {
  final mockBloc = MockDiagnosticsBloc();
  final state = DiagnosticsState(
    appVersion: appVersion,
    buildNumber: buildNumber,
  );
  when(() => mockBloc.state).thenReturn(state);
  whenListen<DiagnosticsState>(
    mockBloc,
    const Stream.empty(),
    initialState: state,
  );

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => BlocProvider<DiagnosticsBloc>.value(
          value: mockBloc,
          child: const DiagnosticsScreen(),
        ),
      ),
      GoRoute(
        path: '/settings/report-incident',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return Scaffold(
            body: Text('report-incident:${extra?['targetType']}'),
          );
        },
      ),
    ],
  );

  return MaterialApp.router(routerConfig: router);
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeDiagnosticsEvent());
  });

  group('DiagnosticsScreen', () {
    testWidgets('renders section header APPLICATION', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('APPLICATION'), findsOneWidget);
    });

    testWidgets('renders section header CONNECTIVITÉ', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('CONNECTIVITÉ'), findsOneWidget);
    });

    testWidgets('renders section header SUPPORT', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('SUPPORT'), findsOneWidget);
    });

    testWidgets('uses SettingsSectionHeader for all three sections', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.byType(SettingsSectionHeader), findsNWidgets(3));
    });

    testWidgets('uses SettingsFlatGroup containers', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.byType(SettingsFlatGroup), findsNWidgets(3));
    });

    testWidgets('renders version when state has appVersion', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('v1.2.3 (42)'), findsOneWidget);
    });

    testWidgets('renders Statut API tile', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('Statut API'), findsOneWidget);
    });

    testWidgets('renders Signaler un bug tile', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('Signaler un bug'), findsOneWidget);
    });

    testWidgets('renders Copier mon ID utilisateur tile', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('Copier mon ID utilisateur'), findsOneWidget);
    });

    testWidgets(
      'tap Signaler un bug navigue vers le vrai formulaire (avec photos), '
      "n'ouvre pas une boîte de dialogue qui n'envoie rien",
      (tester) async {
        await tester.pumpWidget(_wrapWithRouter());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Signaler un bug'));
        await tester.pumpAndSettle();

        expect(
          find.text('report-incident:IncidentTargetType.app'),
          findsOneWidget,
        );
        expect(find.byType(AlertDialog), findsNothing);
      },
    );
  });
}
