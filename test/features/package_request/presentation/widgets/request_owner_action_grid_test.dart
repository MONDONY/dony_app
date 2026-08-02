import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/presentation/widgets/request_owner_action_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pas de fixture partagée `PackageRequest` dans `test/` (vérifié) — construit
/// directement ici avec les champs `required` du modèle, conformément YAGNI.
PackageRequest fixtureRequest({required PackageRequestStatus status}) =>
    PackageRequest(
      id: 'pr-1',
      senderId: 's-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      desiredDate: DateTime(2026, 6, 15),
      dateToleranceDays: 2,
      weightKg: 5,
      parcelSize: ParcelSize.medium,
      transportMode: TransportMode.plane,
      status: status,
      createdAt: DateTime(2026, 5, 10),
    );

void main() {
  Widget wrap(PackageRequest request, {bool hasOffers = false}) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: RequestOwnerActionGrid(
          request: request,
          hasOffers: hasOffers,
          onEdit: () {},
          onPublish: () {},
          onUnpublish: () {},
          onCancel: () {},
        ),
      ),
    );
  }

  testWidgets('brouillon : affiche Publier + Modifier, pas Dépublier ni Annuler',
      (tester) async {
    await tester.pumpWidget(wrap(fixtureRequest(status: PackageRequestStatus.draft)));
    expect(find.text('Publier'), findsOneWidget);
    expect(find.text('Modifier'), findsOneWidget);
    expect(find.text('Dépublier'), findsNothing);
    expect(find.text('Annuler'), findsNothing);
  });

  testWidgets('ouverte sans offre : Dépublier actif', (tester) async {
    await tester.pumpWidget(
      wrap(fixtureRequest(status: PackageRequestStatus.open)),
    );
    final tile = tester.widget<InkWell>(find.ancestor(
      of: find.text('Dépublier'),
      matching: find.byType(InkWell),
    ));
    expect(tile.onTap, isNotNull);
  });

  testWidgets('ouverte avec offre : Dépublier grisé', (tester) async {
    await tester.pumpWidget(
      wrap(fixtureRequest(status: PackageRequestStatus.open), hasOffers: true),
    );
    final tile = tester.widget<InkWell>(find.ancestor(
      of: find.text('Dépublier'),
      matching: find.byType(InkWell),
    ));
    expect(tile.onTap, isNull);
  });

  testWidgets('en négociation : Modifier actif, pas de Dépublier ni Publier',
      (tester) async {
    await tester.pumpWidget(wrap(fixtureRequest(status: PackageRequestStatus.negotiating)));
    expect(find.text('Publier'), findsNothing);
    expect(find.text('Dépublier'), findsNothing);
    final editTile = tester.widget<InkWell>(find.ancestor(
      of: find.text('Modifier'),
      matching: find.byType(InkWell),
    ));
    expect(editTile.onTap, isNotNull);
    final cancelTile = tester.widget<InkWell>(find.ancestor(
      of: find.text('Annuler'),
      matching: find.byType(InkWell),
    ));
    expect(cancelTile.onTap, isNotNull);
  });

  testWidgets('acceptée : ni Publier, ni Dépublier, ni Annuler, Modifier grisé',
      (tester) async {
    await tester.pumpWidget(wrap(fixtureRequest(status: PackageRequestStatus.accepted)));
    expect(find.text('Publier'), findsNothing);
    expect(find.text('Dépublier'), findsNothing);
    expect(find.text('Annuler'), findsNothing);
    final editTile = tester.widget<InkWell>(find.ancestor(
      of: find.text('Modifier'),
      matching: find.byType(InkWell),
    ));
    expect(editTile.onTap, isNull);
  });

  testWidgets('tap sur Publier appelle onPublish', (tester) async {
    var called = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: RequestOwnerActionGrid(
          request: fixtureRequest(status: PackageRequestStatus.draft),
          hasOffers: false,
          onEdit: () {},
          onPublish: () => called = true,
          onUnpublish: () {},
          onCancel: () {},
        ),
      ),
    ));
    await tester.tap(find.text('Publier'));
    expect(called, isTrue);
  });
}
