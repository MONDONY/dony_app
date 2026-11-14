import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/data/models/urgency_filter.dart';
import 'package:dony/features/matching/presentation/trip_domain_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

AnnouncementModel _trip({TransportMode? transportMode}) => AnnouncementModel(
  id: 'ann-1',
  travelerId: 't1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2026, 10, 6),
  availableKg: 10,
  totalKg: 20,
  pricePerKg: 8,
  status: 'ACTIVE',
  createdAt: DateTime(2026, 9),
  updatedAt: DateTime(2026, 9),
  transportMode: transportMode,
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
  });

  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  group('TransportModeL10n.label', () {
    const frLabels = {
      TransportMode.plane: 'Avion',
      TransportMode.car: 'Route',
      TransportMode.train: 'Train',
      TransportMode.bus: 'Route',
      TransportMode.boat: 'Bateau',
      TransportMode.other: 'Autre',
    };
    const enLabels = {
      TransportMode.plane: 'Plane',
      TransportMode.car: 'Road',
      TransportMode.train: 'Train',
      TransportMode.bus: 'Road',
      TransportMode.boat: 'Boat',
      TransportMode.other: 'Other',
    };

    for (final mode in TransportMode.values) {
      test('${mode.name} — fr', () {
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
      test('${unit.name} — fr', () {
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
  group('tripShareMessage', () {
    const url = 'https://yadony.app/annonce/ann-1';

    test('commence par l\'emoji du mode du trajet', () {
      expect(
        tripShareMessage(fr, _trip(transportMode: TransportMode.car), url),
        startsWith('🚗 Je voyage Paris → Dakar le '),
      );
      expect(
        tripShareMessage(fr, _trip(transportMode: TransportMode.bus), url),
        startsWith('🚗 '),
      );
      expect(
        tripShareMessage(en, _trip(transportMode: TransportMode.boat), url),
        startsWith("🚢 I'm traveling Paris → Dakar on "),
      );
      expect(
        tripShareMessage(fr, _trip(transportMode: TransportMode.plane), url),
        startsWith('✈️ '),
      );
    });

    test('mode absent (anciennes données) : avion', () {
      expect(tripShareMessage(fr, _trip(), url), startsWith('✈️ '));
    });

    test('date du départ et lien en fin de message', () {
      final date = DateFormat.MMMMd('fr').format(DateTime(2026, 10, 6));
      final message = tripShareMessage(fr, _trip(), url);
      expect(message, contains(' le $date avec de la place pour vos colis'));
      expect(message, endsWith('\n$url'));
    });
  });
}
