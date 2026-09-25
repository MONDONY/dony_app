import 'package:dony/features/corridor_alerts/data/models/alert_notify_mode.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_model.dart';
import 'package:dony/features/corridor_alerts/presentation/corridor_alert_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

CorridorAlertModel _alert({
  DateTime? dateFrom,
  DateTime? dateTo,
  double? minWeightKg,
}) => CorridorAlertModel(
  id: 'a1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  active: true,
  createdAt: DateTime(2026, 6, 20),
  dateFrom: dateFrom,
  dateTo: dateTo,
  minWeightKg: minWeightKg,
);

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
  });

  group('AlertNotifyModeL10n', () {
    const frLabels = {
      AlertNotifyMode.instant: 'Instantanée',
      AlertNotifyMode.daily: 'Quotidienne',
      AlertNotifyMode.muted: 'Silencieuse',
    };
    const enLabels = {
      AlertNotifyMode.instant: 'Instant',
      AlertNotifyMode.daily: 'Daily',
      AlertNotifyMode.muted: 'Silent',
    };
    const frDescriptions = {
      AlertNotifyMode.instant: 'Push instantané, digest à 9 h',
      AlertNotifyMode.daily: 'Digest quotidien à 9 h',
      AlertNotifyMode.muted: 'Sans notification, compteur seulement',
    };
    const enDescriptions = {
      AlertNotifyMode.instant: 'Instant push, 9 AM digest',
      AlertNotifyMode.daily: 'Daily digest at 9 AM',
      AlertNotifyMode.muted: 'No notifications, counter only',
    };

    for (final mode in AlertNotifyMode.values) {
      test('${mode.name} — label fr égale l\'ancien', () {
        expect(mode.label(fr), frLabels[mode]);
      });
      test('${mode.name} — label en', () {
        expect(mode.label(en), enLabels[mode]);
      });
      test('${mode.name} — description fr égale l\'ancienne', () {
        expect(mode.description(fr), frDescriptions[mode]);
      });
      test('${mode.name} — description en', () {
        expect(mode.description(en), enDescriptions[mode]);
      });
    }
  });

  group('corridorAlertDateLabel', () {
    test('même mois — fr égal à l\'ancien texte', () {
      expect(
        corridorAlertDateLabel(
          fr,
          _alert(
            dateFrom: DateTime(2026, 9, 15),
            dateTo: DateTime(2026, 9, 30),
          ),
        ),
        '15 au 30 sept.',
      );
    });

    test('même mois — en (mois sur la première date)', () {
      expect(
        corridorAlertDateLabel(
          en,
          _alert(
            dateFrom: DateTime(2026, 9, 15),
            dateTo: DateTime(2026, 9, 30),
          ),
        ),
        'Sep 15 to Sep 30',
      );
    });

    test('deux mois — fr égal à l\'ancien texte', () {
      expect(
        corridorAlertDateLabel(
          fr,
          _alert(
            dateFrom: DateTime(2026, 9, 28),
            dateTo: DateTime(2026, 10, 3),
          ),
        ),
        '28 sept. au 3 oct.',
      );
    });

    test('deux mois — en', () {
      expect(
        corridorAlertDateLabel(
          en,
          _alert(
            dateFrom: DateTime(2026, 9, 28),
            dateTo: DateTime(2026, 10, 3),
          ),
        ),
        'Sep 28 to Oct 3',
      );
    });

    test('début seul — fr égal à l\'ancien texte', () {
      expect(
        corridorAlertDateLabel(fr, _alert(dateFrom: DateTime(2026, 9, 15))),
        'À partir du 15 sept.',
      );
    });

    test('début seul — en', () {
      expect(
        corridorAlertDateLabel(en, _alert(dateFrom: DateTime(2026, 9, 15))),
        'From Sep 15',
      );
    });

    test('fin seule — fr égal à l\'ancien texte', () {
      expect(
        corridorAlertDateLabel(fr, _alert(dateTo: DateTime(2026, 9, 30))),
        'Jusqu\'au 30 sept.',
      );
    });

    test('fin seule — en', () {
      expect(
        corridorAlertDateLabel(en, _alert(dateTo: DateTime(2026, 9, 30))),
        'Until Sep 30',
      );
    });

    test('aucune borne — fr égal à l\'ancien texte', () {
      expect(corridorAlertDateLabel(fr, _alert()), 'Toute date');
    });

    test('aucune borne — en', () {
      expect(corridorAlertDateLabel(en, _alert()), 'Any date');
    });
  });

  group('corridorAlertWeightLabel', () {
    test('aucun minimum — fr égal à l\'ancien texte', () {
      expect(corridorAlertWeightLabel(fr, _alert()), 'Tout poids');
    });

    test('aucun minimum — en', () {
      expect(corridorAlertWeightLabel(en, _alert()), 'Any weight');
    });

    test('poids entier — fr égal à l\'ancien texte', () {
      expect(corridorAlertWeightLabel(fr, _alert(minWeightKg: 3)), '≥ 3 kg');
    });

    test('poids entier — en', () {
      expect(corridorAlertWeightLabel(en, _alert(minWeightKg: 3)), '≥ 3 kg');
    });

    test(
      'poids fractionnaire — fr : virgule (correction R46 ; ancien rendu bogué « ≥ 2.5 kg »)',
      () {
        expect(
          corridorAlertWeightLabel(fr, _alert(minWeightKg: 2.5)),
          '≥ 2,5 kg',
        );
      },
    );

    test('poids fractionnaire — en : point', () {
      expect(
        corridorAlertWeightLabel(en, _alert(minWeightKg: 2.5)),
        '≥ 2.5 kg',
      );
    });
  });

  group('pluriels trajets/colis — 1 et 3, fr et en', () {
    test('corridorAlertNewTrips', () {
      expect(fr.corridorAlertNewTrips(1), '1 nouveau trajet');
      expect(fr.corridorAlertNewTrips(3), '3 nouveaux trajets');
      expect(en.corridorAlertNewTrips(1), '1 new trip');
      expect(en.corridorAlertNewTrips(3), '3 new trips');
    });

    test('corridorAlertNewParcels', () {
      expect(fr.corridorAlertNewParcels(1), '1 nouveau colis');
      expect(fr.corridorAlertNewParcels(3), '3 nouveaux colis');
      expect(en.corridorAlertNewParcels(1), '1 new parcel');
      expect(en.corridorAlertNewParcels(3), '3 new parcels');
    });

    test('corridorAlertTripCount', () {
      expect(fr.corridorAlertTripCount(1), '1 trajet');
      expect(fr.corridorAlertTripCount(3), '3 trajets');
      expect(en.corridorAlertTripCount(1), '1 trip');
      expect(en.corridorAlertTripCount(3), '3 trips');
    });

    test('corridorAlertParcelCount', () {
      expect(fr.corridorAlertParcelCount(1), '1 colis');
      expect(fr.corridorAlertParcelCount(3), '3 colis');
      expect(en.corridorAlertParcelCount(1), '1 parcel');
      expect(en.corridorAlertParcelCount(3), '3 parcels');
    });

    test('corridorAlertNothingNewTrips', () {
      expect(
        fr.corridorAlertNothingNewTrips(1),
        'Rien de neuf · 1 trajet au total',
      );
      expect(
        fr.corridorAlertNothingNewTrips(3),
        'Rien de neuf · 3 trajets au total',
      );
      expect(
        en.corridorAlertNothingNewTrips(1),
        'Nothing new · 1 trip in total',
      );
      expect(
        en.corridorAlertNothingNewTrips(3),
        'Nothing new · 3 trips in total',
      );
    });

    test('corridorAlertNothingNewParcels', () {
      expect(
        fr.corridorAlertNothingNewParcels(1),
        'Rien de neuf · 1 colis au total',
      );
      expect(
        fr.corridorAlertNothingNewParcels(3),
        'Rien de neuf · 3 colis au total',
      );
      expect(
        en.corridorAlertNothingNewParcels(1),
        'Nothing new · 1 parcel in total',
      );
      expect(
        en.corridorAlertNothingNewParcels(3),
        'Nothing new · 3 parcels in total',
      );
    });
  });
}
