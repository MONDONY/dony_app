import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/data/models/urgency_filter.dart';
import 'package:dony/features/matching/presentation/trip_domain_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  group('TransportModeL10n.label', () {
    const frLabels = {
      TransportMode.plane: 'Avion',
      TransportMode.car: 'Voiture',
      TransportMode.train: 'Train',
      TransportMode.bus: 'Bus',
      TransportMode.boat: 'Bateau',
      TransportMode.other: 'Autre',
    };
    const enLabels = {
      TransportMode.plane: 'Plane',
      TransportMode.car: 'Car',
      TransportMode.train: 'Train',
      TransportMode.bus: 'Bus',
      TransportMode.boat: 'Boat',
      TransportMode.other: 'Other',
    };

    for (final mode in TransportMode.values) {
      test('${mode.name} — fr égale l\'ancien libellé', () {
        expect(mode.label(fr), frLabels[mode]);
      });

      test('${mode.name} — en', () {
        expect(mode.label(en), enLabels[mode]);
      });
    }
  });

  group('UrgencyFilterL10n', () {
    const frLabels = {
      UrgencyFilter.veryUrgent: '< 3j',
      UrgencyFilter.urgent: '3–7j',
      UrgencyFilter.soon: '7–14j',
      UrgencyFilter.later: '14j+',
    };
    const enLabels = {
      UrgencyFilter.veryUrgent: '< 3d',
      UrgencyFilter.urgent: '3–7d',
      UrgencyFilter.soon: '7–14d',
      UrgencyFilter.later: '14d+',
    };
    for (final filter in UrgencyFilter.values) {
      test('${filter.name} — label fr égale l\'ancien', () {
        expect(filter.label(fr), frLabels[filter]);
      });

      test('${filter.name} — label en', () {
        expect(filter.label(en), enLabels[filter]);
      });
    }
  });

  group('CapacityUnitL10n.label', () {
    const frLabels = {
      CapacityUnit.suitcase23kg: '1 valise 23 kg',
      CapacityUnit.suitcase32kg: '1 valise 32 kg',
      CapacityUnit.kgFree: 'Kg libre',
      CapacityUnit.custom: 'Personnalisé',
    };
    const enLabels = {
      CapacityUnit.suitcase23kg: '1 suitcase (23 kg)',
      CapacityUnit.suitcase32kg: '1 suitcase (32 kg)',
      CapacityUnit.kgFree: 'Flexible kg',
      CapacityUnit.custom: 'Custom',
    };

    for (final unit in CapacityUnit.values) {
      test('${unit.name} — fr égale l\'ancien libellé', () {
        expect(unit.label(fr), frLabels[unit]);
      });

      test('${unit.name} — en', () {
        expect(unit.label(en), enLabels[unit]);
      });
    }
  });

  group('AnnouncementTravelerName.travelerName', () {
    test('rend displayName s\'il est non vide', () {
      const traveler = TravelerProfile(id: 't1', displayName: 'Ibrahima D.');
      expect(traveler.travelerName(fr), 'Ibrahima D.');
      expect(traveler.travelerName(en), 'Ibrahima D.');
    });

    test('repli fr sur "Voyageur" si displayName absent', () {
      const traveler = TravelerProfile(id: 't1');
      expect(traveler.travelerName(fr), 'Voyageur');
    });

    test('repli fr sur "Voyageur" si displayName vide', () {
      const traveler = TravelerProfile(id: 't1', displayName: '');
      expect(traveler.travelerName(fr), 'Voyageur');
    });

    test('repli en sur "Traveler" si displayName absent', () {
      const traveler = TravelerProfile(id: 't1');
      expect(traveler.travelerName(en), 'Traveler');
    });
  });
}
