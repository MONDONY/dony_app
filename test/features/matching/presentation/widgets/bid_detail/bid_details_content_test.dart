// Tests ciblés sur BidDetailsContent, contenu du sheet « Plus de détails » de
// la fiche colis (K3) : la date de départ du trajet (motif fixe branché par
// langue, la locale 'fr_FR' codée en dur est devenue `locale`), la date limite
// de dépôt (squelette yMd, non-régression), les sections et les adresses.
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/bid_details_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

BidModel _bid({
  DateTime? handoverDeadline,
  DateTime? departureDate,
  String? trackingNumber,
}) => BidModel(
  id: 'bid-001',
  announcementId: 'ann-001',
  senderId: 'sender-001',
  status: 'ACCEPTED',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  handoverDeadline: handoverDeadline,
  departureDate: departureDate,
  trackingNumber: trackingNumber,
);

Widget _host(BidModel bid) => MaterialApp(
  // Défilant comme le sheet réel : le contenu dépasse la hauteur du test.
  home: Scaffold(
    body: SingleChildScrollView(child: BidDetailsContent(bid: bid)),
  ),
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
  });

  testWidgets(
    'date de départ du trajet fr non-régression (motif EEE dd MMM yyyy '
    'inchangé, locale explicite au lieu de fr_FR)',
    (tester) async {
      final departure = DateTime(2026, 10, 6, 14, 5);
      await tester.pumpWidget(_host(_bid(departureDate: departure)));

      expect(
        find.textContaining(
          DateFormat('EEE dd MMM yyyy', 'fr').format(departure),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('date de départ du trajet en anglais (squelette yMMMEd)', (
    tester,
  ) async {
    useEnglish();
    final departure = DateTime(2026, 10, 6, 14, 5);
    await tester.pumpWidget(_host(_bid(departureDate: departure)));

    expect(
      find.textContaining(DateFormat.yMMMEd('en').format(departure)),
      findsOneWidget,
    );
  });

  testWidgets(
    'date limite de dépôt fr non-régression (squelette yMd inchangé)',
    (tester) async {
      final deadline = DateTime(2026, 10, 6, 14, 5);
      await tester.pumpWidget(_host(_bid(handoverDeadline: deadline)));

      expect(
        find.textContaining(DateFormat.yMd('fr').format(deadline)),
        findsOneWidget,
      );
    },
  );

  testWidgets('date limite de dépôt en anglais (squelette yMd)', (
    tester,
  ) async {
    useEnglish();
    final deadline = DateTime(2026, 10, 6, 14, 5);
    await tester.pumpWidget(_host(_bid(handoverDeadline: deadline)));

    expect(
      find.textContaining(DateFormat.yMd('en').format(deadline)),
      findsOneWidget,
    );
  });

  testWidgets('section DEMANDE et trajet complet : tout ce qui est connu', (
    tester,
  ) async {
    final bid = BidModel(
      id: 'abcdef12-0000-0000-0000-000000000000',
      announcementId: 'ann-001',
      senderId: 'sender-001',
      status: 'PENDING',
      createdAt: DateTime(2026, 9, 30, 9, 15),
      updatedAt: DateTime(2026, 9, 30, 10, 45),
      paymentMethod: BidPaymentMethod.cash,
      promoCode: 'BIENVENUE',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureTime: '14:30:00',
      arrivalTime: '21:05:00',
      arrivalInstructions: 'Marché Sandaga, porte 3',
    );
    await tester.pumpWidget(_host(bid));

    expect(find.text('DEMANDE'), findsOneWidget);
    // Sans numéro de suivi servi : début de l'identifiant.
    expect(find.text('ABCDEF12'), findsOneWidget);
    expect(find.text('Espèces à la remise'), findsOneWidget);
    expect(find.text('BIENVENUE'), findsOneWidget);
    expect(find.text('Paris → Dakar'), findsOneWidget);
    expect(find.text('14:30'), findsOneWidget);
    expect(find.text('21:05'), findsOneWidget);
    expect(find.text('Marché Sandaga, porte 3'), findsOneWidget);
  });

  testWidgets(
    'adresses servies : lieu de dépôt ouvrable et section Récupération à '
    "l'arrivée avec adresse et instructions",
    (tester) async {
      final bid = BidModel(
        id: 'bid-001',
        announcementId: 'ann-001',
        senderId: 'sender-001',
        status: 'ACCEPTED',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        handoverLocation: '22 Rue du Séminaire, Chevilly-Larue',
        handoverAddress: const AddressData(
          label: '22 Rue du Séminaire, Chevilly-Larue',
          lat: 48.7667,
          lng: 2.3508,
        ),
        deliveryAddress: const AddressData(
          label: 'ACI 2000, Bamako',
          lat: 12.6362,
          lng: -8.0121,
        ),
        arrivalInstructions: 'Appeler à l\'arrivée',
      );
      await tester.pumpWidget(_host(bid));

      expect(find.byKey(const Key('details-handover-address')), findsOneWidget);
      expect(find.text("RÉCUPÉRATION À L'ARRIVÉE"), findsOneWidget);
      expect(find.byKey(const Key('details-delivery-address')), findsOneWidget);
      expect(find.text('ACI 2000, Bamako'), findsOneWidget);
      expect(find.text("Appeler à l'arrivée"), findsOneWidget);
    },
  );

  testWidgets('ancien back sans adresses : lieu de dépôt en texte simple', (
    tester,
  ) async {
    final bid = BidModel(
      id: 'bid-001',
      announcementId: 'ann-001',
      senderId: 'sender-001',
      status: 'ACCEPTED',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      handoverLocation: '22 Rue du Séminaire, Chevilly-Larue',
    );
    await tester.pumpWidget(_host(bid));

    expect(find.text('22 Rue du Séminaire, Chevilly-Larue'), findsOneWidget);
    expect(find.byKey(const Key('details-handover-address')), findsNothing);
    expect(find.text("RÉCUPÉRATION À L'ARRIVÉE"), findsNothing);
  });

  testWidgets('numéro de suivi servi : libellé « Numéro de suivi », jamais '
      '« Référence » (FLUTTER-J2)', (tester) async {
    await tester.pumpWidget(_host(_bid(trackingNumber: 'DON-E69EDCSG')));
    expect(find.text('Numéro de suivi'), findsOneWidget);
    expect(find.text('Référence'), findsNothing);
    expect(find.text('DON-E69EDCSG'), findsOneWidget);
  });

  testWidgets('sans numéro de suivi : « Référence » de la demande', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_bid()));
    expect(find.text('Référence'), findsOneWidget);
  });

  testWidgets('BidDetailsContent shows reference and tracking link sections', (
    tester,
  ) async {
    final bid = BidModel(
      id: 'bid-001',
      announcementId: 'ann-001',
      senderId: 'sender-001',
      status: 'ACCEPTED',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      trackingNumber: 'DON-E69EDCSG',
      trackingToken: 'tok-123',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: BidDetailsContent(bid: bid)),
        ),
      ),
    );

    expect(find.text('DON-E69EDCSG'), findsOneWidget);
    expect(find.text('Numéro de suivi'), findsOneWidget);
    expect(find.text('LIEN DE SUIVI'), findsOneWidget);
    expect(find.text('RESPONSABILITÉ LÉGALE'), findsOneWidget);
    // Pas de titre « Plus de détails » : le sheet le porte.
    expect(find.text('Plus de détails'), findsNothing);
  });

  testWidgets('BidDetailsContent hides the tracking link when asked', (
    tester,
  ) async {
    final bid = BidModel(
      id: 'bid-001',
      announcementId: 'ann-001',
      senderId: 'sender-001',
      status: 'ACCEPTED',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      trackingToken: 'tok-123',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BidDetailsContent(bid: bid, showTrackingLink: false),
          ),
        ),
      ),
    );

    expect(find.text('LIEN DE SUIVI'), findsNothing);
  });
}
