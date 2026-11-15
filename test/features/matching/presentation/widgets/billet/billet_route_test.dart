import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/widgets/billet/billet_route.dart';
import 'package:dony/features/matching/presentation/widgets/billet/colis_billet.dart';
import 'package:dony/features/matching/presentation/widgets/billet_perforation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../../helpers/l10n_test_helpers.dart';
import '../../../../../helpers/plane_icon_expectations.dart';
import '../trip_owner/trip_card_harness.dart' show loadAppFonts;

const _longDep = 'Fontenay-le-Fleury-sous-Bois';
const _longArr = 'Saint-Germain-en-Laye-Centre';

Future<void> _pump(WidgetTester tester, Widget child, {double width = 414}) {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(child: child),
        ),
      ),
    ),
  );
}

void _expectNeverTruncated(WidgetTester tester) {
  for (final key in ['billet_departure_city', 'billet_arrival_city']) {
    final f = find.byKey(Key(key));
    final text = tester.widget<Text>(f);
    expect(text.overflow, isNot(TextOverflow.ellipsis), reason: key);
    expect(text.maxLines, isNull, reason: key);
    expect(
      tester.renderObject<RenderParagraph>(f).didExceedMaxLines,
      isFalse,
      reason: key,
    );
  }
  expect(tester.takeException(), isNull);
}

/// Chaque ligne du nom de ville finit sur une coupure de mot (espace, tiret
/// ou fin du texte), jamais au milieu d'un mot.
void _expectBreaksBetweenWords(WidgetTester tester, String key, String city) {
  final paragraph = tester.renderObject<RenderParagraph>(find.byKey(Key(key)));
  double? top(int i) {
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: i, extentOffset: i + 1),
    );
    return boxes.isEmpty ? null : boxes.first.top;
  }

  var previous = top(0);
  for (var i = 1; i < city.length; i++) {
    final current = top(i);
    if (current == null || previous == null) continue;
    if (current > previous + 1) {
      // Retour à la ligne avant le caractère i.
      final before = city[i - 1];
      final after = city[i];
      expect(
        before == '-' || before == ' ' || after == ' ',
        isTrue,
        reason:
            '$key coupé au milieu d\'un mot : '
            '« ${city.substring(0, i)} / ${city.substring(i)} »',
      );
    }
    previous = current;
  }
}

void main() {
  // Vraies polices : la coupure d'un mot dépend de la largeur réelle des
  // glyphes, la police de test (carrés de 1 em) la fausserait.
  setUpAll(loadAppFonts);

  for (final width in [360.0, 414.0]) {
    testWidgets('villes longues jamais tronquées (${width.toInt()} px)', (
      tester,
    ) async {
      await _pump(
        tester,
        BilletRoute(
          departureCity: _longDep,
          arrivalCity: _longArr,
          departureDate: DateTime(2026, 10, 6),
          departureTime: '08:00:00',
          arrivalDate: DateTime(2026, 10, 7),
          arrivalTime: '06:30',
          notchColor: Colors.white,
        ),
        width: width,
      );

      expect(find.text(_longDep), findsOneWidget);
      expect(find.text(_longArr), findsOneWidget);
      _expectNeverTruncated(tester);
    });

    testWidgets(
      'billet de colis : mêmes villes longues (${width.toInt()} px)',
      (tester) async {
        await _pump(
          tester,
          ColisBillet(
            bid: BidModel(
              id: 'b-1',
              announcementId: 'a-1',
              senderId: 's-1',
              weightKg: 2,
              status: 'REJECTED',
              createdAt: DateTime(2026, 5),
              updatedAt: DateTime(2026, 5),
              departureCity: _longDep,
              arrivalCity: _longArr,
            ),
            isSender: false,
          ),
          width: width,
        );
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(BilletRoute), findsOneWidget);
        _expectNeverTruncated(tester);
      },
    );
  }

  // Recette 13/11 (route, 360 dp) : « Yamoussoukro » en grand se coupait au
  // milieu du mot (« Yamouss / oukro »).
  for (final width in [320.0, 360.0]) {
    for (final cities in [
      ('Abidjan', 'Yamoussoukro'),
      ('Ouagadougou', 'Yamoussoukro'),
      (_longDep, _longArr),
    ]) {
      testWidgets('route : ${cities.$2} coupé entre les mots, jamais au '
          'milieu (${width.toInt()} px)', (tester) async {
        await _pump(
          tester,
          BilletRoute(
            departureCity: cities.$1,
            arrivalCity: cities.$2,
            transportMode: TransportMode.car,
          ),
          width: width,
        );
        _expectNeverTruncated(tester);
        _expectBreaksBetweenWords(tester, 'billet_departure_city', cities.$1);
        _expectBreaksBetweenWords(tester, 'billet_arrival_city', cities.$2);
      });
    }
  }

  testWidgets('route : une ville courte garde la grande taille', (
    tester,
  ) async {
    await _pump(
      tester,
      const BilletRoute(
        departureCity: 'Dakar',
        arrivalCity: 'Thiès',
        transportMode: TransportMode.car,
      ),
      width: 360,
    );
    final text = tester.widget<Text>(
      find.byKey(const Key('billet_arrival_city')),
    );
    expect(text.style?.fontSize, 22);
  });

  testWidgets('lecture d\'écran « départ → arrivée » d\'un seul tenant', (
    tester,
  ) async {
    await _pump(
      tester,
      const BilletRoute(departureCity: 'Paris', arrivalCity: 'Dakar'),
    );
    expect(find.bySemanticsLabel('Paris → Dakar'), findsOneWidget);
    expect(find.text('CDG'), findsOneWidget);
    expect(find.text('DSS'), findsOneWidget);
  });

  testWidgets('arrivée un autre jour → sa date ; même jour → heure seule', (
    tester,
  ) async {
    await _pump(
      tester,
      Column(
        children: [
          BilletDates(
            key: const Key('nuit'),
            departureDate: DateTime(2026, 3, 5),
            departureTime: '22:10:00',
            arrivalDate: DateTime(2026, 3, 6),
            arrivalTime: '05:40:00',
          ),
          BilletDates(
            key: const Key('jour'),
            departureDate: DateTime(2026, 3, 5),
            departureTime: '08:00',
            arrivalDate: DateTime(2026, 3, 5),
            arrivalTime: '12:00',
          ),
        ],
      ),
    );

    String value(String scope, String key) => tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(Key(scope)),
            matching: find.byKey(Key(key)),
          ),
        )
        .data!;
    expect(value('nuit', 'billet-departure-value'), '5 mars · 22:10');
    expect(value('nuit', 'billet-arrival-value'), '6 mars · 05:40');
    expect(value('jour', 'billet-arrival-value'), '12:00');
  });

  testWidgets('valeurs inconnues → « - » ; jour de la semaine sur demande', (
    tester,
  ) async {
    useEnglish();
    await _pump(
      tester,
      Column(
        children: [
          const BilletDates(key: Key('vide')),
          BilletDates(
            key: const Key('semaine'),
            departureDate: DateTime(2026, 10, 6),
            showWeekday: true,
          ),
        ],
      ),
    );

    String value(String scope, String key) => tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(Key(scope)),
            matching: find.byKey(Key(key)),
          ),
        )
        .data!;
    expect(value('vide', 'billet-departure-value'), '-');
    expect(value('vide', 'billet-arrival-value'), '-');
    expect(value('semaine', 'billet-departure-value'), 'Tue, Oct 6');
  });

  testWidgets('sans notchColor → pas de perforation', (tester) async {
    await _pump(
      tester,
      const BilletRoute(departureCity: 'Paris', arrivalCity: 'Dakar'),
    );
    expect(find.byType(BilletPerforation), findsNothing);
  });

  group('icône et villes selon le mode', () {
    testWidgets('avion : codes IATA, villes dessous, icône plane', (
      tester,
    ) async {
      await _pump(
        tester,
        const BilletRoute(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          transportMode: TransportMode.plane,
        ),
      );
      expect(find.text('CDG'), findsOneWidget);
      expect(find.text('DSS'), findsOneWidget);
      expect(find.byKey(const Key('billet_departure_city')), findsOneWidget);
      expect(findDonyIcon('plane'), findsOneWidget);
    });

    testWidgets('mode absent (ancien trajet) : comme l\'avion', (tester) async {
      await _pump(
        tester,
        const BilletRoute(departureCity: 'Paris', arrivalCity: 'Dakar'),
      );
      expect(find.text('CDG'), findsOneWidget);
      expect(find.text('DSS'), findsOneWidget);
      expect(findDonyIcon('plane'), findsOneWidget);
    });

    testWidgets('route : nom de ville en grand, ni code ni avion', (
      tester,
    ) async {
      await _pump(
        tester,
        const BilletRoute(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          transportMode: TransportMode.car,
        ),
      );
      expect(find.text('CDG'), findsNothing);
      expect(find.text('DSS'), findsNothing);
      // Un seul texte par ville : pas de ligne secondaire.
      expect(find.text('Paris'), findsOneWidget);
      expect(find.text('Dakar'), findsOneWidget);
      expect(findDonyIcon('car'), findsOneWidget);
      expectNoPlaneIcon(tester);
      expect(find.bySemanticsLabel('Paris → Dakar'), findsOneWidget);
    });

    testWidgets('bateau : icône ship, ni code ni avion', (tester) async {
      await _pump(
        tester,
        const BilletRoute(
          departureCity: 'Marseille',
          arrivalCity: 'Abidjan',
          transportMode: TransportMode.boat,
        ),
      );
      expect(find.text('MRS'), findsNothing);
      expect(find.text('ABJ'), findsNothing);
      expect(findDonyIcon('ship'), findsOneWidget);
      expectNoPlaneIcon(tester);
    });

    testWidgets('bus : affiché comme la route (icône car)', (tester) async {
      await _pump(
        tester,
        const BilletRoute(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          transportMode: TransportMode.bus,
        ),
      );
      expect(findDonyIcon('car'), findsOneWidget);
      expectNoPlaneIcon(tester);
    });

    testWidgets('train : icône neutre route', (tester) async {
      await _pump(
        tester,
        const BilletRoute(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          transportMode: TransportMode.train,
        ),
      );
      expect(findDonyIcon('route'), findsOneWidget);
      expectNoPlaneIcon(tester);
    });

    for (final width in [360.0, 414.0]) {
      testWidgets(
        'route, villes longues jamais tronquées (${width.toInt()} px)',
        (tester) async {
          await _pump(
            tester,
            const BilletRoute(
              departureCity: _longDep,
              arrivalCity: _longArr,
              transportMode: TransportMode.car,
            ),
            width: width,
          );
          expect(find.text(_longDep), findsOneWidget);
          expect(find.text(_longArr), findsOneWidget);
          _expectNeverTruncated(tester);
        },
      );
    }
  });

  testWidgets('FLUTTER-Q1 : encoches de la perforation dessinées et cerclées', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SizedBox(
            width: 300,
            child: BilletPerforation(notchColor: Colors.white),
          ),
        ),
      ),
    );
    expect(
      find.descendant(
        of: find.byType(BilletPerforation),
        matching: find.byType(CustomPaint),
      ),
      findsNWidgets(2),
    );
  });

  // A6 : un trajet bateau annonce une fourchette d'arrivée estimée.
  group('arrivée estimée (bateau)', () {
    final year = DateTime.now().year;
    for (final width in [360.0, 414.0]) {
      testWidgets('« Arrivée estimée » du premier au dernier jour, sans heure '
          '(${width.toInt()} px)', (tester) async {
        await initializeDateFormatting('fr');
        await _pump(
          tester,
          BilletRoute(
            departureCity: 'Le Havre',
            arrivalCity: 'Abidjan',
            transportMode: TransportMode.boat,
            departureDate: DateTime(year, 12, 2),
            departureTime: '18:00',
            arrivalDate: DateTime(year, 12, 11),
            arrivalTime: '06:30',
            arrivalDateMax: DateTime(year, 12, 18),
          ),
          width: width,
        );
        expect(
          tester
              .widget<Text>(find.byKey(const Key('billet-arrival-label')))
              .data,
          'Arrivée estimée',
        );
        expect(
          tester
              .widget<Text>(find.byKey(const Key('billet-arrival-value')))
              .data,
          '11 déc. au 18 déc.',
        );
        expect(find.textContaining('06:30'), findsNothing);
        expect(tester.takeException(), isNull);
        expectNoPlaneIcon(tester);
      });
    }

    testWidgets('en anglais', (tester) async {
      useEnglish();
      await initializeDateFormatting('en');
      await _pump(
        tester,
        BilletRoute(
          departureCity: 'Le Havre',
          arrivalCity: 'Abidjan',
          transportMode: TransportMode.boat,
          departureDate: DateTime(year, 12, 2),
          arrivalDate: DateTime(year, 12, 11),
          arrivalDateMax: DateTime(year, 12, 18),
        ),
        width: 360,
      );
      expect(find.text('Estimated arrival'), findsOneWidget);
      expect(find.text('Dec 11 to Dec 18'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('fourchette d\'un jour : la date seule', (tester) async {
      await initializeDateFormatting('fr');
      await _pump(
        tester,
        BilletRoute(
          departureCity: 'Le Havre',
          arrivalCity: 'Abidjan',
          transportMode: TransportMode.boat,
          departureDate: DateTime(year, 12, 2),
          arrivalDate: DateTime(year, 12, 11),
          arrivalDateMax: DateTime(year, 12, 11),
        ),
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('billet-arrival-value'))).data,
        '11 déc.',
      );
    });

    testWidgets('sans fin de fourchette : libellé et heure habituels', (
      tester,
    ) async {
      await _pump(
        tester,
        BilletRoute(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          departureDate: DateTime(year, 10, 6),
          arrivalDate: DateTime(year, 10, 7),
          arrivalTime: '06:30',
        ),
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('billet-arrival-label'))).data,
        'Arrivée',
      );
      expect(find.textContaining('06:30'), findsOneWidget);
    });
  });
}
