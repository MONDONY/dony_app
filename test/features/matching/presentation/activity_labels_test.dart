import 'package:dony/features/matching/bloc/stats_period_cubit.dart';
import 'package:dony/features/matching/data/models/revenue_details_model.dart';
import 'package:dony/features/matching/data/models/tools_completion_model.dart';
import 'package:dony/features/matching/presentation/activity_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  group('StatsPeriodL10n', () {
    const frLabels = {
      StatsPeriod.sevenDays: '7 jours',
      StatsPeriod.thirtyDays: '30 jours',
      StatsPeriod.twelveMonths: '12 mois',
    };
    const enLabels = {
      StatsPeriod.sevenDays: '7 days',
      StatsPeriod.thirtyDays: '30 days',
      StatsPeriod.twelveMonths: '12 months',
    };
    const frDetailLabels = {
      StatsPeriod.sevenDays: '7 derniers jours',
      StatsPeriod.thirtyDays: '30 derniers jours',
      StatsPeriod.twelveMonths: '12 derniers mois',
    };
    const enDetailLabels = {
      StatsPeriod.sevenDays: 'Last 7 days',
      StatsPeriod.thirtyDays: 'Last 30 days',
      StatsPeriod.twelveMonths: 'Last 12 months',
    };

    for (final period in StatsPeriod.values) {
      test('${period.name} — label fr égale l\'ancien libellé', () {
        expect(period.label(fr), frLabels[period]);
      });
      test('${period.name} — label en', () {
        expect(period.label(en), enLabels[period]);
      });
      test('${period.name} — detailLabel fr égale l\'ancien libellé', () {
        expect(period.detailLabel(fr), frDetailLabels[period]);
      });
      test('${period.name} — detailLabel en', () {
        expect(period.detailLabel(en), enDetailLabels[period]);
      });
    }
  });

  group('RevenueRailL10n.label', () {
    const frLabels = {
      RevenueRail.card: 'Carte',
      RevenueRail.mobileMoney: 'Mobile money',
      RevenueRail.cash: 'Espèces',
      RevenueRail.unknown: 'Paiement',
    };
    const enLabels = {
      RevenueRail.card: 'Card',
      RevenueRail.mobileMoney: 'Mobile money',
      RevenueRail.cash: 'Cash',
      RevenueRail.unknown: 'Payment',
    };

    for (final rail in RevenueRail.values) {
      test('${rail.name} — fr égale l\'ancien libellé', () {
        expect(rail.label(fr), frLabels[rail]);
      });
      test('${rail.name} — en', () {
        expect(rail.label(en), enLabels[rail]);
      });
    }
  });

  group('ToolKeyL10n.missingPhrase', () {
    const frPhrases = {
      ToolKey.addresses: 'une adresse',
      ToolKey.recipients: 'un destinataire',
      ToolKey.alerts: 'une alerte',
      ToolKey.tripTemplates: 'un modèle de trajet',
      ToolKey.priceGrid: 'une grille de prix',
    };
    const enPhrases = {
      ToolKey.addresses: 'an address',
      ToolKey.recipients: 'a recipient',
      ToolKey.alerts: 'an alert',
      ToolKey.tripTemplates: 'a trip template',
      ToolKey.priceGrid: 'a price grid',
    };

    for (final tool in ToolKey.values) {
      test('${tool.name} — fr égale l\'ancien libellé', () {
        expect(tool.missingPhrase(fr), frPhrases[tool]);
      });
      test('${tool.name} — en', () {
        expect(tool.missingPhrase(en), enPhrases[tool]);
      });
    }
  });

  group('ToolKeyL10n.ctaLabel', () {
    test('fr égale les anciens libellés', () {
      expect(ToolKey.addresses.ctaLabel(fr), 'Ajouter une adresse');
      expect(ToolKey.recipients.ctaLabel(fr), 'Ajouter un destinataire');
      expect(ToolKey.alerts.ctaLabel(fr), 'Créer une alerte');
      expect(ToolKey.tripTemplates.ctaLabel(fr), 'Créer un modèle de trajet');
      expect(ToolKey.priceGrid.ctaLabel(fr), 'Remplir ma grille de prix');
    });

    test('en', () {
      expect(ToolKey.addresses.ctaLabel(en), 'Add an address');
      expect(ToolKey.recipients.ctaLabel(en), 'Add a recipient');
      expect(ToolKey.alerts.ctaLabel(en), 'Create an alert');
      expect(ToolKey.tripTemplates.ctaLabel(en), 'Create a trip template');
      expect(ToolKey.priceGrid.ctaLabel(en), 'Fill in my price grid');
    });
  });

  group('ToolKeyL10n.badgeLabel', () {
    test('singulier et pluriel — fr égale les anciens libellés', () {
      expect(ToolKey.addresses.badgeLabel(fr, 1), '1 adresse');
      expect(ToolKey.addresses.badgeLabel(fr, 2), '2 adresses');
      expect(ToolKey.recipients.badgeLabel(fr, 4), '4 destinataires');
      expect(ToolKey.alerts.badgeLabel(fr, 1), '1 alerte');
      expect(ToolKey.tripTemplates.badgeLabel(fr, 3), '3 modèles');
    });

    test('singulier et pluriel — en', () {
      expect(ToolKey.addresses.badgeLabel(en, 1), '1 address');
      expect(ToolKey.addresses.badgeLabel(en, 2), '2 addresses');
      expect(ToolKey.recipients.badgeLabel(en, 4), '4 recipients');
      expect(ToolKey.alerts.badgeLabel(en, 1), '1 alert');
      expect(ToolKey.tripTemplates.badgeLabel(en, 3), '3 templates');
    });

    test('la grille est « Configurée » quel que soit le nombre de lignes', () {
      expect(ToolKey.priceGrid.badgeLabel(fr, 1), 'Configurée');
      expect(ToolKey.priceGrid.badgeLabel(fr, 12), 'Configurée');
      expect(ToolKey.priceGrid.badgeLabel(en, 1), 'Set up');
    });

    test('aucun tiret cadratin nulle part', () {
      for (final k in ToolKey.values) {
        expect(k.ctaLabel(fr).contains('—'), isFalse);
        expect(k.missingPhrase(fr).contains('—'), isFalse);
        expect(k.badgeLabel(fr, 2).contains('—'), isFalse);
      }
    });
  });

  group('missingSentence', () {
    test('aucun manquant : phrase vide', () {
      expect(missingSentence(fr, const []), '');
      expect(missingSentence(en, const []), '');
    });

    test('un seul manquant — fr', () {
      expect(
        missingSentence(fr, [ToolKey.recipients]),
        'Il vous manque un destinataire.',
      );
    });

    test('deux manquants joints par « et » — fr', () {
      expect(
        missingSentence(fr, [ToolKey.addresses, ToolKey.alerts]),
        'Il vous manque une adresse et une alerte.',
      );
    });

    test('deux manquants joints par "and" — en', () {
      expect(
        missingSentence(en, [ToolKey.addresses, ToolKey.alerts]),
        'You still need an address and an alert.',
      );
    });

    test('trois manquants : virgules puis « et » — fr', () {
      expect(
        missingSentence(fr, [
          ToolKey.alerts,
          ToolKey.tripTemplates,
          ToolKey.priceGrid,
        ]),
        'Il vous manque une alerte, un modèle de trajet et une grille de prix.',
      );
    });

    test('trois manquants : virgules puis "and" — en', () {
      expect(
        missingSentence(en, [
          ToolKey.addresses,
          ToolKey.recipients,
          ToolKey.alerts,
        ]),
        'You still need an address, a recipient, and an alert.',
      );
    });
  });

  group('compteurs (pluriels ICU), dans les deux langues', () {
    test('activityKgSoldParcels — fr toujours « colis » invariant', () {
      expect(fr.activityKgSoldParcels(0), '0 colis');
      expect(fr.activityKgSoldParcels(1), '1 colis');
      expect(fr.activityKgSoldParcels(5), '5 colis');
    });

    test('activityKgSoldParcels — en', () {
      expect(en.activityKgSoldParcels(1), '1 parcel');
      expect(en.activityKgSoldParcels(5), '5 parcels');
    });

    test('activityKgSoldTrips — fr singulier/pluriel', () {
      expect(fr.activityKgSoldTrips(1), '1 trajet');
      expect(fr.activityKgSoldTrips(3), '3 trajets');
    });

    test('activityKgSoldTrips — en', () {
      expect(en.activityKgSoldTrips(1), '1 trip');
      expect(en.activityKgSoldTrips(3), '3 trips');
    });

    test('activityDeliveries — fr : « 0 livraison », correction d\'accord', () {
      expect(fr.activityDeliveries(0), '0 livraison');
      expect(fr.activityDeliveries(1), '1 livraison');
      expect(fr.activityDeliveries(2), '2 livraisons');
    });

    test('activityDeliveries — en', () {
      expect(en.activityDeliveries(0), '0 deliveries');
      expect(en.activityDeliveries(1), '1 delivery');
      expect(en.activityDeliveries(2), '2 deliveries');
    });

    test('activityNewCount — fr', () {
      expect(fr.activityNewCount(1), '1 nouveau');
      expect(fr.activityNewCount(3), '3 nouveaux');
    });

    test('activityNewCount — en : deux branches identiques', () {
      expect(en.activityNewCount(1), '1 new');
      expect(en.activityNewCount(3), '3 new');
    });
  });
}
