import 'package:dony/features/matching/data/models/tools_completion_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> json({
    int addresses = 0,
    int recipients = 0,
    int alerts = 0,
    int templates = 0,
    int grid = 0,
  }) => {
    'total': 5,
    'ready': [
      addresses,
      recipients,
      alerts,
      templates,
      grid,
    ].where((c) => c > 0).length,
    'tools': [
      {'key': 'addresses', 'count': addresses, 'ready': addresses > 0},
      {'key': 'recipients', 'count': recipients, 'ready': recipients > 0},
      {'key': 'alerts', 'count': alerts, 'ready': alerts > 0},
      {'key': 'trip_templates', 'count': templates, 'ready': templates > 0},
      {'key': 'price_grid', 'count': grid, 'ready': grid > 0},
    ],
  };

  group('ToolsCompletionModel.fromJson', () {
    test('lit les 5 outils dans l\'ordre du serveur', () {
      final m = ToolsCompletionModel.fromJson(
        json(addresses: 2, templates: 1, grid: 6),
      );

      expect(m.total, 5);
      expect(m.ready, 3);
      expect(m.tools.map((t) => t.key), [
        ToolKey.addresses,
        ToolKey.recipients,
        ToolKey.alerts,
        ToolKey.tripTemplates,
        ToolKey.priceGrid,
      ]);
      expect(m.countOf(ToolKey.addresses), 2);
      expect(m.countOf(ToolKey.recipients), 0);
    });

    test('ignore une clé inconnue plutôt que de planter', () {
      final raw = json(addresses: 1);
      (raw['tools'] as List).add({
        'key': 'future_tool',
        'count': 3,
        'ready': true,
      });

      final m = ToolsCompletionModel.fromJson(raw);

      expect(m.tools.length, 5);
    });

    test('un outil absent de la réponse compte pour zéro', () {
      final raw = json(addresses: 1);
      (raw['tools'] as List).removeWhere((t) => t['key'] == 'alerts');

      final m = ToolsCompletionModel.fromJson(raw);

      expect(m.countOf(ToolKey.alerts), 0);
      expect(m.tools.length, 5);
    });
  });

  group('nextMissing / missing / isComplete', () {
    test('rien de rempli : le prochain est adresses', () {
      final m = ToolsCompletionModel.fromJson(json());
      expect(m.isComplete, isFalse);
      expect(m.nextMissing, ToolKey.addresses);
      expect(m.missing, ToolKey.values);
    });

    test('partiel : premier manquant dans l\'ordre serveur', () {
      final m = ToolsCompletionModel.fromJson(
        json(addresses: 2, templates: 1, grid: 6),
      );
      expect(m.nextMissing, ToolKey.recipients);
      expect(m.missing, [ToolKey.recipients, ToolKey.alerts]);
    });

    test('tout rempli : complet, aucun manquant', () {
      final m = ToolsCompletionModel.fromJson(
        json(addresses: 1, recipients: 1, alerts: 1, templates: 1, grid: 1),
      );
      expect(m.isComplete, isTrue);
      expect(m.nextMissing, isNull);
      expect(m.missing, isEmpty);
    });
  });
}
