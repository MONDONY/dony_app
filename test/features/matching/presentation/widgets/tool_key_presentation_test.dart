import 'package:dony/features/matching/data/models/tools_completion_model.dart';
import 'package:dony/features/matching/presentation/widgets/tool_key_presentation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('routes des cinq outils', () {
    expect(ToolKey.addresses.route, '/profile/addresses');
    expect(ToolKey.recipients.route, '/profile/recipients');
    expect(ToolKey.alerts.route, '/corridor-alerts');
    expect(ToolKey.tripTemplates.route, '/trip-templates');
    expect(ToolKey.priceGrid.route, '/profile/price-grid');
  });

  test('libellés de CTA', () {
    expect(ToolKey.addresses.ctaLabel, 'Ajouter une adresse');
    expect(ToolKey.recipients.ctaLabel, 'Ajouter un destinataire');
    expect(ToolKey.alerts.ctaLabel, 'Créer une alerte');
    expect(ToolKey.tripTemplates.ctaLabel, 'Créer un modèle de trajet');
    expect(ToolKey.priceGrid.ctaLabel, 'Remplir ma grille de prix');
  });

  group('badgeLabel', () {
    test('singulier et pluriel', () {
      expect(ToolKey.addresses.badgeLabel(1), '1 adresse');
      expect(ToolKey.addresses.badgeLabel(2), '2 adresses');
      expect(ToolKey.recipients.badgeLabel(4), '4 destinataires');
      expect(ToolKey.alerts.badgeLabel(1), '1 alerte');
      expect(ToolKey.tripTemplates.badgeLabel(3), '3 modèles');
    });

    test('la grille est « Configurée » quel que soit le nombre de lignes', () {
      expect(ToolKey.priceGrid.badgeLabel(1), 'Configurée');
      expect(ToolKey.priceGrid.badgeLabel(12), 'Configurée');
    });
  });

  group('missingSentence', () {
    test('un seul manquant', () {
      expect(
        missingSentence([ToolKey.recipients]),
        'Il vous manque un destinataire.',
      );
    });

    test('deux manquants joints par « et »', () {
      expect(
        missingSentence([ToolKey.recipients, ToolKey.alerts]),
        'Il vous manque un destinataire et une alerte.',
      );
    });

    test('trois manquants : virgules puis « et »', () {
      expect(
        missingSentence([
          ToolKey.alerts,
          ToolKey.tripTemplates,
          ToolKey.priceGrid,
        ]),
        'Il vous manque une alerte, un modèle de trajet et une grille de prix.',
      );
    });

    test('aucun tiret cadratin nulle part', () {
      for (final k in ToolKey.values) {
        expect(k.ctaLabel.contains('—'), isFalse);
        expect(k.missingPhrase.contains('—'), isFalse);
        expect(k.badgeLabel(2).contains('—'), isFalse);
      }
    });
  });
}
