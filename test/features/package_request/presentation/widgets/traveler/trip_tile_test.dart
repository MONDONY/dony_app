import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/presentation/widgets/traveler/trip_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

AnnouncementModel _trip({
  Set<BidPaymentMethod> payments = const {BidPaymentMethod.stripe},
}) {
  return AnnouncementModel(
    id: 'ann-1',
    travelerId: 'trav-1',
    departureCity: 'Paris',
    arrivalCity: 'Dakar',
    departureDate: DateTime(2026, 8, 15),
    availableKg: 12,
    totalKg: 23,
    pricePerKg: 7,
    status: 'ACTIVE',
    transportMode: TransportMode.plane,
    pickupAddress: AddressData(label: 'Paris', lat: 48.86, lng: 2.35),
    deliveryAddress: AddressData(label: 'Dakar', lat: 14.74, lng: -17.49),
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    acceptedPaymentMethods: payments,
  );
}

Widget _harness(TripTile tile) =>
    MaterialApp(theme: AppTheme.light, home: Scaffold(body: tile));

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  testWidgets('affiche le bouton Modifier et la pastille liquide',
      (tester) async {
    await tester.pumpWidget(_harness(TripTile(
      announcement: _trip(),
      index: 0,
      isSelected: false,
      onTap: () {},
      onModify: () {},
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trip-tile-modify-button')), findsOneWidget);
    expect(find.text('Modifier le trajet'), findsOneWidget);
    expect(find.text('Liquide désactivé'), findsOneWidget);
  });

  testWidgets('la pastille indique « Liquide activé » quand le cash est accepté',
      (tester) async {
    await tester.pumpWidget(_harness(TripTile(
      announcement:
          _trip(payments: const {BidPaymentMethod.stripe, BidPaymentMethod.cash}),
      index: 0,
      isSelected: false,
      onTap: () {},
      onModify: () {},
    )));
    await tester.pumpAndSettle();
    expect(find.text('Liquide activé'), findsOneWidget);
  });

  testWidgets('tap sur Modifier déclenche onModify', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_harness(TripTile(
      announcement: _trip(),
      index: 0,
      isSelected: false,
      onTap: () {},
      onModify: () => tapped = true,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('trip-tile-modify-button')));
    expect(tapped, isTrue);
  });

  testWidgets('tap sur le corps de la carte déclenche onTap, pas onModify',
      (tester) async {
    var selected = false;
    var modified = false;
    await tester.pumpWidget(_harness(TripTile(
      announcement: _trip(),
      index: 0,
      isSelected: false,
      onTap: () => selected = true,
      onModify: () => modified = true,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('kg dispo'));
    expect(selected, isTrue);
    expect(modified, isFalse);
  });

  testWidgets('le bouton Modifier est désactivé quand onModify est null',
      (tester) async {
    await tester.pumpWidget(_harness(TripTile(
      announcement: _trip(),
      index: 0,
      isSelected: false,
      onTap: () {},
      onModify: null,
    )));
    await tester.pumpAndSettle();
    final inkWell = tester.widget<InkWell>(
        find.byKey(const Key('trip-tile-modify-button')));
    expect(inkWell.onTap, isNull);
  });
}
