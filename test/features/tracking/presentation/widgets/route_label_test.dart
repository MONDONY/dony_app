import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/tracking/presentation/widgets/route_label.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// [RouteLabel] sous le vrai thème de l'app, à la largeur d'un téléphone
/// (390 px) et à la taille de texte demandée.
Future<void> _pump(
  WidgetTester tester, {
  String from = 'Paris',
  String to = 'Dakar',
  TransportMode? mode,
  ThemeMode themeMode = ThemeMode.light,
  double textScale = 1,
  Locale locale = AppL10n.fr,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RouteLabel(
                    from: from,
                    to: to,
                    transportMode: mode,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('deux villes et l\'avion par défaut ($themeMode)', (
      tester,
    ) async {
      await _pump(tester, themeMode: themeMode);
      expect(tester.takeException(), isNull);
      final rich = tester.widget<RichText>(
        find
            .descendant(
              of: find.byType(RouteLabel),
              matching: find.byType(RichText),
            )
            .first,
      );
      final plain = rich.text.toPlainText();
      expect(plain, startsWith('Paris'));
      expect(plain, endsWith('Dakar'));
      expect(plain, isNot(contains('→')));
      expect(find.byIcon(Icons.flight_rounded), findsOneWidget);
      // L'avion pointe dans le sens du trajet.
      expect(
        find.ancestor(
          of: find.byIcon(Icons.flight_rounded),
          matching: find.byType(RotatedBox),
        ),
        findsOneWidget,
      );
      final icon = tester.widget<Icon>(find.byIcon(Icons.flight_rounded));
      expect(
        icon.color,
        Theme.of(tester.element(find.byType(RouteLabel))).colorScheme.primary,
      );
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('noms longs à 390 px, texte x$scale : aucun débordement '
          '($themeMode)', (tester) async {
        await _pump(
          tester,
          from: 'Bobo-Dioulasso',
          to: 'Yaoundé',
          themeMode: themeMode,
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
        final size = tester.getSize(find.byType(RouteLabel));
        expect(size.width, lessThanOrEqualTo(390 - 32));
      });
    }
  }

  // Colonne étroite à côté d'un statut, texte à 200 % (carte « Mes envois ») :
  // le connecteur est rogné, jamais de débordement.
  testWidgets('colonne très étroite, texte x2 : aucun débordement', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: AppL10n.fr,
        home: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 40,
                child: RouteLabel(from: 'Paris', to: 'Dakar'),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('icône selon le mode, jamais de camion', (tester) async {
    for (final mode in TransportMode.values) {
      await _pump(tester, mode: mode);
      expect(tester.takeException(), isNull);
      expect(find.byIcon(mode.icon), findsOneWidget, reason: '$mode');
      expect(find.byIcon(Icons.local_shipping), findsNothing);
      expect(find.byIcon(Icons.local_shipping_rounded), findsNothing);
      expect(find.byIcon(Icons.local_shipping_outlined), findsNothing);
      // Seul l'avion est tourné.
      expect(
        find.byType(RotatedBox),
        mode == TransportMode.plane ? findsOneWidget : findsNothing,
      );
    }
  });

  testWidgets('lu « De … à … », icône exclue', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);
    expect(find.bySemanticsLabel('De Paris à Dakar'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Paris.*Dakar.*Dakar')), findsNothing);
    semantics.dispose();
  });

  testWidgets('en anglais : « From … to … »', (tester) async {
    AppL10n.debugEnglishEnabled = true;
    addTearDown(() => AppL10n.debugEnglishEnabled = null);
    final semantics = tester.ensureSemantics();
    await _pump(tester, locale: AppL10n.en);
    expect(find.bySemanticsLabel('From Paris to Dakar'), findsOneWidget);
    semantics.dispose();
  });
}
