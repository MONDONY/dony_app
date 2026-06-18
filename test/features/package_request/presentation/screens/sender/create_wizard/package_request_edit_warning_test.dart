import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/data/models/content_category.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/package_request_create_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PackageRequest _req(PackageRequestStatus status) => PackageRequest(
      id: 'pr-1',
      senderId: 's1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      desiredDate: DateTime(2026, 8, 1),
      dateToleranceDays: 3,
      weightKg: 5,
      parcelSize: ParcelSize.medium,
      transportMode: TransportMode.plane,
      contentCategory: ContentCategory.vetements,
      status: status,
      createdAt: DateTime(2026, 6, 1),
    );

void main() {
  group('requiresEditWarning', () {
    test('NEGOTIATING → true (négos actives à annuler)', () {
      expect(
        PackageRequestCreateWizard.requiresEditWarning(
            _req(PackageRequestStatus.negotiating)),
        isTrue,
      );
    });
    test('OPEN → false (aucune négo en cours)', () {
      expect(
        PackageRequestCreateWizard.requiresEditWarning(
            _req(PackageRequestStatus.open)),
        isFalse,
      );
    });
    test('ACCEPTED → false', () {
      expect(
        PackageRequestCreateWizard.requiresEditWarning(
            _req(PackageRequestStatus.accepted)),
        isFalse,
      );
    });
    test('null (mode création) → false', () {
      expect(PackageRequestCreateWizard.requiresEditWarning(null), isFalse);
    });
  });

  testWidgets(
      'édition demande en négociation → avertissement ; Annuler n\'ouvre pas le wizard',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => PackageRequestCreateWizard.show(
              context,
              initial: _req(PackageRequestStatus.negotiating),
            ),
            child: const Text('go'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Modifier votre demande ?'), findsOneWidget);
    expect(find.textContaining('annulera toutes les offres'), findsOneWidget);

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(find.text('Modifier votre demande ?'), findsNothing);
    // Le wizard ne s'est pas ouvert (pas de bouton de confirmation résiduel).
    expect(find.text('Modifier quand même'), findsNothing);
  });
}
