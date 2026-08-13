import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/settings/bloc/accessibility_bloc.dart';
import 'package:dony/features/settings/presentation/screens/accessibility_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAccessibilityBloc
    extends MockBloc<AccessibilityEvent, AccessibilityState>
    implements AccessibilityBloc {}

void main() {
  late MockAccessibilityBloc bloc;

  setUp(() {
    bloc = MockAccessibilityBloc();
    when(() => bloc.state).thenReturn(const AccessibilityState());
  });

  Widget wrap() => MaterialApp(
    theme: AppTheme.light(),
    home: BlocProvider<AccessibilityBloc>.value(
      value: bloc,
      child: const AccessibilitySettingsScreen(),
    ),
  );

  group('AccessibilitySettingsScreen — structure', () {
    testWidgets('affiche les quatre sections', (tester) async {
      await tester.pumpWidget(wrap());
      // La liste s'ouvre sur un fadeIn/slideY : le laisser se stabiliser
      // avant d'inspecter l'arbre, sinon le timer différé de flutter_animate
      // reste programmé et l'invariant de fin de test (aucun timer en
      // attente) échoue.
      await tester.pumpAndSettle();
      expect(find.text('TEXTE'), findsOneWidget);
      expect(find.text('AFFICHAGE'), findsOneWidget);
      expect(find.text('MOUVEMENT'), findsOneWidget);
      expect(find.text('MESSAGES ET ACTIONS'), findsOneWidget);
    });

    testWidgets('affiche l\'aperçu en tête', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.text('Aperçu'), findsOneWidget);
    });

    testWidgets('n\'utilise plus de SegmentedButton', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.byType(SegmentedButton<String>), findsNothing);
    });

    testWidgets('affiche les neuf réglages', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.text('Suivre les réglages du téléphone'), findsOneWidget);
      expect(find.text('Taille du texte'), findsOneWidget);
      expect(find.text('Texte en gras'), findsOneWidget);
      expect(find.text('Contraste élevé'), findsOneWidget);
      expect(find.text('Souligner les liens'), findsOneWidget);
      expect(find.text('Renforcer les étiquettes'), findsOneWidget);
      expect(find.text('Réduire les animations'), findsOneWidget);
      expect(find.text('Garder les messages affichés'), findsOneWidget);
      expect(find.text('Confirmer les actions importantes'), findsOneWidget);
    });
  });

  group('AccessibilitySettingsScreen — interactions', () {
    testWidgets('le curseur est inerte quand le suivi système est actif', (
      tester,
    ) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.onChanged, isNull);
    });

    testWidgets('le curseur est actif quand le suivi système est coupé', (
      tester,
    ) async {
      when(
        () => bloc.state,
      ).thenReturn(const AccessibilityState(followSystemTextScale: false));
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.onChanged, isNotNull);
    });

    testWidgets('basculer le suivi système envoie l\'event', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Suivre les réglages du téléphone'));
      await tester.pump();
      verify(
        () => bloc.add(const FollowSystemTextScaleToggled(false)),
      ).called(1);
    });

    testWidgets('basculer le gras envoie l\'event', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Texte en gras'));
      await tester.pump();
      verify(() => bloc.add(const BoldTextToggled(true))).called(1);
    });

    testWidgets('choisir un mode de contraste envoie l\'event', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      // 'Contraste élevé' est sous la ligne de flottaison par défaut de la
      // surface de test : la faire défiler avant de la taper, comme sur un
      // vrai écran.
      await tester.ensureVisible(find.text('Contraste élevé'));
      await tester.tap(find.text('Contraste élevé'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toujours activé'));
      await tester.pumpAndSettle();
      verify(() => bloc.add(const HighContrastModeChanged('on'))).called(1);
    });

    testWidgets(
      'la réinitialisation demande confirmation puis envoie l\'event',
      (tester) async {
        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Tout réinitialiser'));
        await tester.tap(find.text('Tout réinitialiser'));
        await tester.pumpAndSettle();
        expect(find.text('Confirmer'), findsOneWidget);
        await tester.tap(find.text('Confirmer'));
        await tester.pumpAndSettle();
        verify(() => bloc.add(const AccessibilityResetRequested())).called(1);
      },
    );

    testWidgets('annuler la réinitialisation n\'envoie rien', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Tout réinitialiser'));
      await tester.tap(find.text('Tout réinitialiser'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      verifyNever(() => bloc.add(const AccessibilityResetRequested()));
    });
  });

  group('AccessibilitySettingsScreen — accessibilité de l\'écran lui-même', () {
    testWidgets('respecte les cibles tactiles et le contraste', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('tient à 200 % de taille de texte sans débordement', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: BlocProvider<AccessibilityBloc>.value(
              value: bloc,
              child: const AccessibilitySettingsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
