import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/design/widgets/dony_skeleton.dart';
import 'package:dony/features/profile/presentation/widgets/profile_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _build({bool hasError = false, VoidCallback? onRetry}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: ProfileScreenSkeleton(hasError: hasError, onRetry: onRetry),
    ),
  );
}

void main() {
  group('ProfileScreenSkeleton', () {
    testWidgets(
      'chargement : reflet animé, aucune valeur de repli, pas de « Réessayer »',
      (tester) async {
        // Libéré à la main en fin de corps : la vérification de fin de test
        // passe avant les tearDown, et exige qu'aucun handle ne soit actif.
        final semantics = tester.ensureSemantics();

        await tester.pumpWidget(_build());
        await tester.pump();

        expect(find.byType(DonyShimmer), findsOneWidget);
        expect(find.text('Réessayer'), findsNothing);
        expect(find.text('Profil indisponible'), findsNothing);
        expect(find.text('Utilisateur'), findsNothing);
        expect(find.bySemanticsLabel('Chargement du profil'), findsOneWidget);

        semantics.dispose();
      },
    );

    testWidgets(
      'erreur : silhouette sans reflet, carte « Profil indisponible »',
      (tester) async {
        await tester.pumpWidget(_build(hasError: true));
        await tester.pump();

        expect(find.byType(DonyShimmer), findsNothing);
        expect(find.text('Profil indisponible'), findsOneWidget);
        expect(find.text('Réessayer'), findsOneWidget);
      },
    );

    testWidgets('« Réessayer » appelle onRetry', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_build(hasError: true, onRetry: () => taps++));
      await tester.pump();

      await tester.tap(find.text('Réessayer'));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('ne déborde pas sur un écran court', (tester) async {
      tester.view.physicalSize = const Size(360, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_build(hasError: true));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
