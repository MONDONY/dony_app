import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/presentation/widgets/poster/package_request_poster_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

PackageRequest request({
  String departureCity = 'Lyon',
  String arrivalCity = 'Abidjan',
  int tolerance = 3,
  double weightKg = 8,
  double? gross = 45,
  double? target,
  bool negotiable = true,
  List<String> categories = const ['Vêtements', 'Chaussures'],
  Set<PaymentMethod> payments = const {
    PaymentMethod.stripe,
    PaymentMethod.wave,
  },
  String? pickup = 'Guillotière',
  String? delivery = 'Cocody',
  String currency = 'EUR',
}) => PackageRequest(
  id: 'r1',
  senderId: 's1',
  departureCity: departureCity,
  arrivalCity: arrivalCity,
  desiredDate: DateTime(2026, 10, 23),
  dateToleranceDays: tolerance,
  weightKg: weightKg,
  parcelSize: ParcelSize.medium,
  transportMode: TransportMode.plane,
  categories: categories,
  grossPriceEur: gross,
  targetPriceEur: target,
  negotiable: negotiable,
  acceptedPaymentMethods: payments,
  pickupNeighborhood: pickup,
  deliveryNeighborhood: delivery,
  status: PackageRequestStatus.open,
  createdAt: DateTime(2026, 10),
  currency: currency,
);

Future<void> _pump(WidgetTester tester, PackageRequest r, {String? qrData}) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PackageRequestPosterCard(request: r, qrData: qrData),
        ),
      ),
    );

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
  });

  testWidgets('annonce le corridor et la recherche d\'un voyageur', (
    tester,
  ) async {
    await _pump(tester, request());

    expect(find.text('LYON'), findsOneWidget);
    expect(find.text('ABIDJAN'), findsOneWidget);
    expect(find.text('CHERCHE UN VOYAGEUR'), findsOneWidget);
    expect(find.text('COLIS À TRANSPORTER · AVION'), findsOneWidget);
  });

  testWidgets('date souhaitée avec sa tolérance', (tester) async {
    await _pump(tester, request());

    expect(
      find.text('Autour du vendredi 23 octobre, à 3 jours près'),
      findsOneWidget,
    );
  });

  testWidgets('date souhaitée sans tolérance', (tester) async {
    await _pump(tester, request(tolerance: 0));

    expect(find.text('Autour du vendredi 23 octobre'), findsOneWidget);
  });

  testWidgets('poids, format et budget brut négociable', (tester) async {
    await _pump(tester, request());

    expect(find.text('8 kg'), findsOneWidget);
    expect(find.text('Format moyen'), findsOneWidget);
    expect(find.text(formatPriceIn(45, 'EUR')), findsOneWidget);
    expect(find.text('négociable'), findsOneWidget);
  });

  /// Le net seul est un tarif que personne ne paie : le brut prime, le net
  /// n'est qu'un repli pour un ancien payload.
  testWidgets('préfère le brut au net et ne montre jamais les deux', (
    tester,
  ) async {
    await _pump(tester, request(target: 40));

    expect(find.text(formatPriceIn(45, 'EUR')), findsOneWidget);
    expect(find.text(formatPriceIn(40, 'EUR')), findsNothing);
  });

  testWidgets('sans budget, invite à proposer un prix', (tester) async {
    await _pump(tester, request(gross: null, negotiable: false));

    expect(find.text('À proposer'), findsOneWidget);
    expect(find.text('prix ferme'), findsOneWidget);
  });

  testWidgets('budget en franc CFA', (tester) async {
    await _pump(tester, request(gross: 30000, currency: 'XOF'));

    expect(find.text(formatPriceIn(30000, 'XOF')), findsOneWidget);
  });

  testWidgets('moyens de paiement, quartiers et contenu', (tester) async {
    await _pump(tester, request());

    expect(find.text('Carte, Wave'), findsOneWidget);
    expect(find.text('Lyon, Guillotière'), findsOneWidget);
    expect(find.text('Abidjan, Cocody'), findsOneWidget);
    expect(find.text('Vêtements'), findsOneWidget);
    expect(find.text('Chaussures'), findsOneWidget);
  });

  testWidgets('omet paiement et contenu quand ils sont vides', (tester) async {
    await _pump(
      tester,
      request(payments: const {}, categories: const [], pickup: null),
    );

    expect(find.text('PAIEMENT'), findsNothing);
    expect(find.text('CONTENU'), findsNothing);
    expect(find.text('Lyon'), findsOneWidget);
  });

  testWidgets('sans photo, une illustration tient sa place', (tester) async {
    await _pump(tester, request());

    expect(find.byIcon(Icons.inventory_2_rounded), findsOneWidget);
    expect(find.byKey(const Key('request-poster-photo')), findsNothing);
  });

  testWidgets('QR code seulement quand le lien est fourni', (tester) async {
    await _pump(tester, request());
    expect(find.byKey(const Key('poster-qr')), findsNothing);

    await _pump(
      tester,
      request(),
      qrData: 'https://yadony.com/demande/r1?c=qr',
    );
    expect(find.byKey(const Key('poster-qr')), findsOneWidget);
  });

  testWidgets('appel à l\'action adressé aux voyageurs de l\'axe', (
    tester,
  ) async {
    await _pump(tester, request());

    expect(
      find.text('Vous faites Lyon → Abidjan ? Proposez votre trajet'),
      findsOneWidget,
    );
  });

  testWidgets('n\'imprime ni URL ni numéro', (tester) async {
    await _pump(
      tester,
      request(),
      qrData: 'https://yadony.com/demande/r1?c=qr',
    );

    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join(' ');
    expect(texts, isNot(contains('http')));
    expect(texts, isNot(contains('yadony.com')));
    expect(RegExp(r'\+?\d{8,}').hasMatch(texts), isFalse);
  });

  testWidgets('un corridor long passe sur deux lignes sans déborder', (
    tester,
  ) async {
    await _pump(
      tester,
      request(
        departureCity: 'Marseille',
        arrivalCity: 'Ouagadougou',
        categories: const ['Vêtements', 'Chaussures', 'Documents', 'Épices'],
        payments: const {
          PaymentMethod.stripe,
          PaymentMethod.cash,
          PaymentMethod.orangeMoney,
          PaymentMethod.mobileMoney,
        },
      ),
      qrData: 'https://yadony.com/demande/r1?c=qr',
    );

    expect(tester.takeException(), isNull);
    expect(find.text('MARSEILLE'), findsOneWidget);
    expect(find.text('OUAGADOUGOU'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
  });

  testWidgets('se traduit en anglais', (tester) async {
    useEnglish();
    await _pump(tester, request());

    expect(find.text('LOOKING FOR A TRAVELER'), findsOneWidget);
    expect(
      find.text('Around Friday, October 23, give or take 3 days'),
      findsOneWidget,
    );
    expect(find.text('Size medium'), findsOneWidget);
  });

  test('libellé de lieu : quartier facultatif', () {
    expect(PackageRequestPosterCard.placeLabel('Dakar', null), 'Dakar');
    expect(PackageRequestPosterCard.placeLabel('Dakar', '  '), 'Dakar');
    expect(
      PackageRequestPosterCard.placeLabel('Dakar', 'Plateau'),
      'Dakar, Plateau',
    );
  });
}
