import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/request_ticket_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

PackageRequest _req({
  List<String> photos = const [],
  String? description = '3 flacons de parfum emballés',
  Set<PaymentMethod> methods = const {PaymentMethod.stripe, PaymentMethod.cash},
  bool negotiable = true,
  List<String> categories = const ['Cosmétiques & parfums'],
}) => PackageRequest(
  id: 'pr-1',
  senderId: 's',
  departureCity: 'Divo',
  arrivalCity: 'Annemasse',
  desiredDate: DateTime(2026, 9, 27),
  dateToleranceDays: 2,
  weightKg: 2,
  parcelSize: ParcelSize.small,
  transportMode: TransportMode.plane,
  categories: categories,
  description: description,
  targetPriceEur: 29,
  status: PackageRequestStatus.open,
  createdAt: DateTime.utc(2026, 9, 17, 6, 25),
  negotiable: negotiable,
  pickupNeighborhood: 'Commerce',
  deliveryNeighborhood: 'Centre-ville',
  photoUrls: photos,
  photoKeys: [for (var i = 0; i < photos.length; i++) 'k$i'],
  acceptedPaymentMethods: methods,
);

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  testWidgets('route, faits, quartiers et paiements', (tester) async {
    await tester.pumpWidget(
      _wrap(
        RequestTicketCard(
          request: _req(),
          statusPill: const Text('En ligne'),
          metaLabel: '14 vues · publiée il y a 2 h',
        ),
      ),
    );
    expect(find.text('DIV'), findsOneWidget);
    expect(find.text('ANN'), findsOneWidget);
    expect(find.text('Divo'), findsOneWidget);
    expect(find.text('27 sept. ± 2 j'), findsOneWidget);
    expect(find.text('2 kg · Cosmétiques & parfums'), findsOneWidget);
    expect(find.text('3 flacons de parfum emballés'), findsOneWidget);
    expect(find.text('négociable'), findsOneWidget);
    expect(find.text('Commerce → Centre-ville'), findsOneWidget);
    expect(find.byKey(const Key('payment-method-chip-stripe')), findsOneWidget);
    expect(find.text('14 vues · publiée il y a 2 h'), findsOneWidget);
    final semantics = tester.ensureSemantics();
    expect(
      find.bySemanticsLabel(RegExp('Divo vers Annemasse')),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('sans photo : vignette colis ; prix ferme', (tester) async {
    await tester.pumpWidget(
      _wrap(
        RequestTicketCard(
          request: _req(negotiable: false, description: null),
          statusPill: const SizedBox(),
          metaLabel: '',
        ),
      ),
    );
    expect(
      find.byKey(const Key('request-ticket-photo-placeholder')),
      findsOneWidget,
    );
    expect(find.text('prix ferme'), findsOneWidget);
  });

  testWidgets('plusieurs photos : compteur +N', (tester) async {
    await tester.pumpWidget(
      _wrap(
        RequestTicketCard(
          request: _req(
            photos: ['https://x/1.jpg', 'https://x/2.jpg', 'https://x/3.jpg'],
          ),
          statusPill: const SizedBox(),
          metaLabel: '',
        ),
      ),
    );
    expect(find.text('+2'), findsOneWidget);
  });

  testWidgets(
    'sans moyen de paiement ni quartier : pied masqué ; footer affiché',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          RequestTicketCard(
            request: PackageRequest(
              id: 'pr-1',
              senderId: 's',
              departureCity: 'Divo',
              arrivalCity: 'Annemasse',
              desiredDate: DateTime(2026, 9, 27),
              dateToleranceDays: 0,
              weightKg: 2,
              parcelSize: ParcelSize.small,
              transportMode: TransportMode.plane,
              status: PackageRequestStatus.open,
              createdAt: DateTime.utc(2026, 9, 17),
            ),
            statusPill: const SizedBox(),
            metaLabel: '',
            footer: const Text('talon'),
          ),
        ),
      );
      expect(
        find.byKey(const Key('request-ticket-footer-details')),
        findsNothing,
      );
      expect(find.text('27 sept.'), findsOneWidget);
      expect(find.text('Prix à définir'), findsOneWidget);
      expect(find.text('talon'), findsOneWidget);
    },
  );

  testWidgets(
    'catégorie du catalogue traduite en anglais (contentCategoryDisplayName)',
    (tester) async {
      useEnglish();
      await tester.pumpWidget(
        _wrap(
          RequestTicketCard(
            request: _req(categories: const ['Vêtements & tissus']),
            statusPill: const Text('Live'),
            metaLabel: '',
          ),
        ),
      );
      expect(find.text('2 kg · Clothing & fabrics'), findsOneWidget);
      expect(find.textContaining('Vêtements'), findsNothing);
    },
  );

  testWidgets('écran traduit en anglais : prix ferme et prix à définir', (
    tester,
  ) async {
    useEnglish();
    await tester.pumpWidget(
      _wrap(
        RequestTicketCard(
          request: _req(negotiable: false, description: null),
          statusPill: const SizedBox(),
          metaLabel: '',
        ),
      ),
    );
    expect(find.text('fixed price'), findsOneWidget);
    expect(find.text('prix ferme'), findsNothing);
  });

  testWidgets('anglais : tolérance de date sans « j »', (tester) async {
    useEnglish();
    await tester.pumpWidget(
      _wrap(
        RequestTicketCard(
          request: _req(),
          statusPill: const Text('Live'),
          metaLabel: '',
        ),
      ),
    );
    expect(find.text('Sep 27 ± 2 d'), findsOneWidget);
    expect(find.textContaining('± 2 j'), findsNothing);
  });
}
