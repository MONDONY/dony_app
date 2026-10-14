import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/flights/data/models/flight_passengers.dart';
import 'package:dony/features/flights/presentation/widgets/flight_passengers_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/l10n_test_helpers.dart';

void main() {
  FlightPassengers? choice;

  Future<void> open(
    WidgetTester tester, {
    FlightPassengers initial = FlightPassengers.single,
  }) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    choice = null;
    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => choice = await FlightPassengersSheet.show(
              context,
              initial: initial,
            ),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
  }

  Finder button(FlightPassengerKind kind, String sign) =>
      find.byKey(Key('flight-passengers-${kind.name}-$sign'));

  bool enabled(WidgetTester tester, FlightPassengerKind kind, String sign) =>
      tester
          .widget<InkWell>(
            find.descendant(
              of: button(kind, sign),
              matching: find.byType(InkWell),
            ),
          )
          .onTap !=
      null;

  String count(WidgetTester tester, FlightPassengerKind kind) => tester
      .widget<Text>(find.byKey(Key('flight-passengers-${kind.name}-count')))
      .data!;

  Future<void> tap(
    WidgetTester tester,
    FlightPassengerKind kind,
    String sign,
  ) async {
    await tester.tap(button(kind, sign));
    await tester.pump();
  }

  testWidgets('un adulte : tous les « − » désactivés, cibles de 44 points', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Qui voyage ?'), findsOneWidget);
    expect(find.text('12 ans et plus'), findsOneWidget);
    expect(find.text('De 2 à 11 ans'), findsOneWidget);
    expect(find.text('Moins de 2 ans'), findsOneWidget);
    for (final kind in FlightPassengerKind.values) {
      expect(enabled(tester, kind, 'minus'), isFalse);
      expect(enabled(tester, kind, 'plus'), isTrue);
      expect(
        tester.getSize(button(kind, 'plus')).width,
        greaterThanOrEqualTo(kDonyMinTapTarget),
      );
    }
    expect(count(tester, FlightPassengerKind.adults), '1');
    // Le bouton Valider est dans la zone fixe de la feuille.
    expect(find.byKey(const Key('flight-passengers-validate')), findsOneWidget);
  });

  testWidgets('un bébé par adulte au plus', (tester) async {
    await open(tester);
    await tap(tester, FlightPassengerKind.infants, 'plus');
    expect(count(tester, FlightPassengerKind.infants), '1');
    expect(enabled(tester, FlightPassengerKind.infants, 'plus'), isFalse);

    await tap(tester, FlightPassengerKind.adults, 'plus');
    await tap(tester, FlightPassengerKind.infants, 'plus');
    expect(count(tester, FlightPassengerKind.infants), '2');
    // Deux adultes, deux bébés : un adulte ne peut plus être retiré.
    expect(enabled(tester, FlightPassengerKind.adults, 'minus'), isFalse);

    await tap(tester, FlightPassengerKind.infants, 'minus');
    expect(enabled(tester, FlightPassengerKind.adults, 'minus'), isTrue);
    await tap(tester, FlightPassengerKind.adults, 'minus');

    await tester.tap(find.byKey(const Key('flight-passengers-validate')));
    await tester.pumpAndSettle();
    expect(choice, const FlightPassengers(infants: 1));
  });

  testWidgets('neuf passagers au plus : tous les « + » désactivés', (
    tester,
  ) async {
    await open(tester, initial: const FlightPassengers(adults: 4));
    for (var i = 0; i < 5; i++) {
      await tap(tester, FlightPassengerKind.children, 'plus');
    }
    expect(count(tester, FlightPassengerKind.children), '5');
    for (final kind in FlightPassengerKind.values) {
      expect(enabled(tester, kind, 'plus'), isFalse);
    }
    await tap(tester, FlightPassengerKind.children, 'plus');
    expect(count(tester, FlightPassengerKind.children), '5');

    await tester.tap(find.byKey(const Key('flight-passengers-validate')));
    await tester.pumpAndSettle();
    expect(choice, const FlightPassengers(adults: 4, children: 5));
    expect(choice!.total, 9);
  });

  testWidgets('fermée sans valider : rien n\'est rendu', (tester) async {
    await open(tester, initial: const FlightPassengers(adults: 2));
    expect(count(tester, FlightPassengerKind.adults), '2');
    await tap(tester, FlightPassengerKind.children, 'plus');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(choice, isNull);
  });

  testWidgets('en anglais', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      localizedApp(
        locale: const Locale('en'),
        Builder(
          builder: (context) => TextButton(
            onPressed: () => FlightPassengersSheet.show(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text("Who's travelling?"), findsOneWidget);
    expect(find.text('Aged 2 to 11'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });
}
