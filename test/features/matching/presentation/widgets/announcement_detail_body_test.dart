// Widget tests pour le corps partagé du détail de trajet
// (AnnouncementDetailBody) — utilisé par le bottom sheet et le futur écran
// plein écran du propriétaire.
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/announcement_detail_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

AnnouncementModel _full() => AnnouncementModel(
      id: 'ann-1',
      travelerId: 'trav-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime(2026, 8, 12),
      availableKg: 10,
      totalKg: 10,
      pricePerKg: 7,
      status: 'ACTIVE',
      bidsCount: 5,
      confirmedParcelCount: 3,
      createdAt: DateTime(2026, 7),
      updatedAt: DateTime(2026, 7),
      pickupAddress: const AddressData(
        label: '12 rue de Paris, 75001',
        lat: 48.85,
        lng: 2.35,
      ),
      deliveryAddress: const AddressData(
        label: 'Marché Sandaga, Dakar',
        lat: 14.67,
        lng: -17.43,
      ),
      handoverWindowStart: DateTime(2026, 8, 5, 9),
      handoverWindowEnd: DateTime(2026, 8, 10, 18),
      acceptedPaymentMethods: const {
        BidPaymentMethod.cash,
        BidPaymentMethod.stripe,
      },
      acceptedContentTypes: const ['Vêtements', 'Documents'],
      refusedTypes: const ['Liquides'],
      description: 'Pas de produits fragiles svp.',
    );

AnnouncementModel _minimal() => AnnouncementModel(
      id: 'ann-2',
      travelerId: 'trav-1',
      departureCity: 'Lyon',
      arrivalCity: 'Bamako',
      departureDate: DateTime(2026, 9, 2),
      availableKg: 5,
      totalKg: 5,
      pricePerKg: 6,
      status: 'ACTIVE',
      createdAt: DateTime(2026, 7),
      updatedAt: DateTime(2026, 7),
      acceptedPaymentMethods: const <BidPaymentMethod>{},
    );

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
  });

  Widget host(AnnouncementModel a) => MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('fr', 'FR'), Locale('en')],
        home: Scaffold(
          body: SingleChildScrollView(child: AnnouncementDetailBody(a: a)),
        ),
      );

  testWidgets('modèle complet ACTIVE → corridor + badge + sections présentes',
      (tester) async {
    await tester.pumpWidget(host(_full()));
    await tester.pumpAndSettle();

    // Corridor
    expect(find.text('Paris → Dakar'), findsOneWidget);
    // Status badge ACTIF
    expect(find.text('● ACTIF'), findsOneWidget);
    // Sections
    expect(find.text('LIEUX DE REMISE'), findsOneWidget);
    expect(find.text('12 rue de Paris, 75001'), findsOneWidget);
    expect(find.text('Marché Sandaga, Dakar'), findsOneWidget);
    expect(find.text('FENÊTRE DE REMISE'), findsOneWidget);
    expect(find.text('PAIEMENTS ACCEPTÉS'), findsOneWidget);
    expect(find.text('💵 Espèces'), findsOneWidget);
    expect(find.text('💳 Carte'), findsOneWidget);
    expect(find.text('CE QUE J\'ACCEPTE'), findsOneWidget);
    expect(find.text('Vêtements'), findsOneWidget);
    expect(find.text('CE QUE JE REFUSE'), findsOneWidget);
    expect(find.text('Liquides'), findsOneWidget);
    expect(find.text('NOTE AUX EXPÉDITEURS'), findsOneWidget);
    expect(find.text('Pas de produits fragiles svp.'), findsOneWidget);
    // Compteurs colis
    expect(find.text('colis acceptés'), findsOneWidget);
    expect(find.text('en attente'), findsOneWidget);
  });

  testWidgets(
      'modèle minimal → corridor présent, sections optionnelles absentes',
      (tester) async {
    await tester.pumpWidget(host(_minimal()));
    await tester.pumpAndSettle();

    expect(find.text('Lyon → Bamako'), findsOneWidget);
    expect(find.text('● ACTIF'), findsOneWidget);
    // Sections optionnelles absentes
    expect(find.text('LIEUX DE REMISE'), findsNothing);
    expect(find.text('FENÊTRE DE REMISE'), findsNothing);
    expect(find.text('PAIEMENTS ACCEPTÉS'), findsNothing);
    expect(find.text('CE QUE J\'ACCEPTE'), findsNothing);
    expect(find.text('CE QUE JE REFUSE'), findsNothing);
    expect(find.text('NOTE AUX EXPÉDITEURS'), findsNothing);
  });
}
