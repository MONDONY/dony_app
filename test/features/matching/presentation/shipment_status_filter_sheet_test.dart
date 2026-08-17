import 'package:dony/features/matching/presentation/widgets/shipment_status_filter_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // La feuille liste 13 statuts : sur une vue par défaut (600x800) les
  // derniers groupes passent sous le pli et ne sont plus tapables.
  void sizeView(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('coche un statut et applique -> retourne le Set', (tester) async {
    sizeView(tester);
    Set<String>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await ShipmentStatusFilterSheet.show(
                  context,
                  const {},
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Filtrer par statut'), findsOneWidget);
    await tester.tap(find.text('Livré'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Appliquer'));
    await tester.pumpAndSettle();

    expect(result, contains('COMPLETED'));
  });

  testWidgets('pré-coche depuis initial + libellé Appliquer (n)', (
    tester,
  ) async {
    sizeView(tester);
    Set<String>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await ShipmentStatusFilterSheet.show(context, const {
                  'COMPLETED',
                  'ACCEPTED',
                });
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 2 statuts pré-sélectionnés -> le bouton affiche le compteur
    expect(find.text('Appliquer (2)'), findsOneWidget);

    // Décoche « Livré » -> le set retourné ne contient plus COMPLETED
    await tester.tap(find.text('Livré'));
    await tester.pumpAndSettle();
    expect(find.text('Appliquer (1)'), findsOneWidget);
    await tester.tap(find.text('Appliquer (1)'));
    await tester.pumpAndSettle();

    expect(result, contains('ACCEPTED'));
    expect(result, isNot(contains('COMPLETED')));
  });

  testWidgets('expose le statut PARCEL_REFUSED (Colis refusé)', (tester) async {
    sizeView(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  ShipmentStatusFilterSheet.show(context, const {}),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Colis refusé'), findsOneWidget);
  });

  testWidgets('expose le statut ARRIVED dans le groupe En cours', (
    tester,
  ) async {
    sizeView(tester);
    Set<String>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await ShipmentStatusFilterSheet.show(
                  context,
                  const {},
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Arrivé'), findsOneWidget);
    await tester.tap(find.text('Arrivé'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Appliquer'));
    await tester.pumpAndSettle();

    expect(result, contains('ARRIVED'));
  });
}
