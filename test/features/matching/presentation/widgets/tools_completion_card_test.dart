import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/tools_completion_model.dart';
import 'package:dony/features/matching/presentation/widgets/tools_completion_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ToolsCompletionModel _model({
  int addresses = 0,
  int recipients = 0,
  int alerts = 0,
  int templates = 0,
  int grid = 0,
}) => ToolsCompletionModel(
  tools: [
    ToolStatus(key: ToolKey.addresses, count: addresses),
    ToolStatus(key: ToolKey.recipients, count: recipients),
    ToolStatus(key: ToolKey.alerts, count: alerts),
    ToolStatus(key: ToolKey.tripTemplates, count: templates),
    ToolStatus(key: ToolKey.priceGrid, count: grid),
  ],
);

Future<List<ToolKey>> _pump(
  WidgetTester tester,
  ToolsCompletionModel model, {
  ThemeData? theme,
}) async {
  final taps = <ToolKey>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: ToolsCompletionCard(model: model, onCtaTap: taps.add),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return taps;
}

void main() {
  testWidgets('0 / 5 : titre de départ, CTA « Commencer par mes adresses »', (
    tester,
  ) async {
    final taps = await _pump(tester, _model());

    expect(find.byKey(const Key('tools-completion-card')), findsOneWidget);
    expect(find.text('Préparez vos outils une fois'), findsOneWidget);
    expect(find.text('0 / 5'), findsOneWidget);
    expect(find.text('Commencer par mes adresses'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);

    await tester.tap(find.byKey(const Key('tools-completion-cta')));
    expect(taps, [ToolKey.addresses]);
  });

  testWidgets(
    'partiel : « Publiez en 3 taps », manquants, CTA vers le premier',
    (tester) async {
      final taps = await _pump(
        tester,
        _model(addresses: 2, templates: 1, grid: 6),
      );

      expect(find.text('Publiez en 3 taps'), findsOneWidget);
      expect(find.text('3 / 5'), findsOneWidget);
      expect(
        find.textContaining('Il vous manque un destinataire et une alerte.'),
        findsOneWidget,
      );
      expect(find.text('Ajouter un destinataire'), findsOneWidget);
      expect(find.byType(DonyOnboardingGauge), findsOneWidget);

      await tester.tap(find.byKey(const Key('tools-completion-cta')));
      expect(taps, [ToolKey.recipients]);
    },
  );

  testWidgets('la jauge a un segment par outil, pleins = prêts', (
    tester,
  ) async {
    await _pump(tester, _model(addresses: 2, templates: 1, grid: 6));

    final gauge = tester.widget<DonyOnboardingGauge>(
      find.byType(DonyOnboardingGauge),
    );
    expect(gauge.segments.length, 5);
    expect(gauge.segments.where((s) => s == DonyGaugeSegment.done).length, 3);
    expect(gauge.segments.contains(DonyGaugeSegment.current), isFalse);
    expect(gauge.semanticsLabel, 'Préparation de vos outils');
  });

  testWidgets('5 / 5 : bandeau compact, ni jauge ni CTA', (tester) async {
    await _pump(
      tester,
      _model(addresses: 1, recipients: 1, alerts: 1, templates: 1, grid: 1),
    );

    expect(find.byKey(const Key('tools-completion-complete')), findsOneWidget);
    expect(find.byKey(const Key('tools-completion-card')), findsNothing);
    expect(find.text('Vos outils sont prêts'), findsOneWidget);
    expect(
      find.text('Publiez un colis ou un trajet en 3 taps'),
      findsOneWidget,
    );
    expect(find.byType(DonyOnboardingGauge), findsNothing);
    expect(find.byKey(const Key('tools-completion-cta')), findsNothing);
  });

  testWidgets('le CTA fait au moins 44 pt de haut', (tester) async {
    await _pump(tester, _model(addresses: 1));

    final size = tester.getSize(find.byKey(const Key('tools-completion-cta')));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('en sombre, le bandeau 5 / 5 prend le success du thème sombre', (
    tester,
  ) async {
    await _pump(
      tester,
      _model(addresses: 1, recipients: 1, alerts: 1, templates: 1, grid: 1),
      theme: AppTheme.dark(),
    );

    final box = tester.widget<Container>(
      find.byKey(const Key('tools-completion-complete')),
    );
    expect(
      (box.decoration! as BoxDecoration).color,
      AppTheme.dark().colorScheme.successLight,
    );
  });
}
