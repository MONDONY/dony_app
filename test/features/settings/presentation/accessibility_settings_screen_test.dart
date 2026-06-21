import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/settings/bloc/accessibility_bloc.dart';
import 'package:dony/features/settings/presentation/screens/accessibility_settings_screen.dart';
import 'package:dony/features/settings/presentation/widgets/settings_flat_group.dart';
import 'package:dony/features/settings/presentation/widgets/settings_section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAccessibilityBloc
    extends MockBloc<AccessibilityEvent, AccessibilityState>
    implements AccessibilityBloc {}

class _FakeAccessibilityEvent extends Fake implements AccessibilityEvent {}

Widget _wrap({String textScale = 'normal', bool highContrast = false, bool reduceAnimations = false}) {
  final mockBloc = MockAccessibilityBloc();
  final state = AccessibilityState(
    textScale: textScale,
    highContrast: highContrast,
    reduceAnimations: reduceAnimations,
  );
  when(() => mockBloc.state).thenReturn(state);
  whenListen<AccessibilityState>(mockBloc, const Stream.empty(),
      initialState: state);

  return MaterialApp(
    home: BlocProvider<AccessibilityBloc>.value(
      value: mockBloc,
      child: const AccessibilitySettingsScreen(),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeAccessibilityEvent());
  });

  group('AccessibilitySettingsScreen', () {
    testWidgets('renders section header TEXTE', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('TEXTE'), findsOneWidget);
    });

    testWidgets('renders section header AFFICHAGE', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('AFFICHAGE'), findsOneWidget);
    });

    testWidgets('uses SettingsSectionHeader for section labels', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.byType(SettingsSectionHeader), findsNWidgets(2));
    });

    testWidgets('uses SettingsFlatGroup containers', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.byType(SettingsFlatGroup), findsNWidgets(2));
    });

    testWidgets('renders SegmentedButton for text scale', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.byType(SegmentedButton<String>), findsOneWidget);
    });

    testWidgets('renders two Switch controls', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.byType(Switch), findsNWidgets(2));
    });

    testWidgets('renders label Contraste élevé', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('Contraste élevé'), findsOneWidget);
    });

    testWidgets('renders label Réduire les animations', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('Réduire les animations'), findsOneWidget);
    });
  });
}
