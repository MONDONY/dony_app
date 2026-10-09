import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/billet/billet_route.dart';
import 'package:dony/features/matching/presentation/widgets/billet/colis_billet.dart';
import 'package:dony/features/matching/presentation/widgets/billet_perforation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

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

void main() {
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
}
