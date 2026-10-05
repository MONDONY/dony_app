// Carte « Lieux » de la fiche colis (vue expéditeur) : la mini-carte montre le
// lieu de remise avant la remise au voyageur, puis le lieu de récupération par
// le destinataire ; les deux adresses restent listées et ouvrables.
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/external_url_launcher.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/address_location_row.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/parcel_locations_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockExternalUrlLauncher extends Mock implements ExternalUrlLauncher {}

class _FakeUri extends Fake implements Uri {}

const _handover = AddressData(
  label: '22 Rue du Séminaire, 94550 Chevilly-Larue, France',
  lat: 48.7667,
  lng: 2.3508,
);
const _delivery = AddressData(
  label: 'ACI 2000, Bamako, Mali',
  lat: 12.6362,
  lng: -8.0121,
);

BidModel _bid(
  String status, {
  AddressData? handover = _handover,
  AddressData? delivery = _delivery,
}) => BidModel(
  id: 'bid-001',
  announcementId: 'ann-001',
  senderId: 'sender-001',
  status: status,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  handoverAddress: handover,
  deliveryAddress: delivery,
);

Widget _host(BidModel bid) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(child: ParcelLocationsCard(bid: bid)),
  ),
);

AddressData _mapped(WidgetTester tester) => tester
    .widget<AddressPointMiniMap>(find.byType(AddressPointMiniMap))
    .address;

void main() {
  setUpAll(() => registerFallbackValue(_FakeUri()));

  testWidgets('avant la remise : carte sur le lieu de remise, deux adresses', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_bid('ACCEPTED')));

    expect(_mapped(tester), _handover);
    expect(find.text(_handover.label), findsOneWidget);
    expect(find.text(_delivery.label), findsOneWidget);
    expect(find.text('Étape en cours'), findsOneWidget);
    expect(find.text("À l'arrivée"), findsOneWidget);
  });

  testWidgets('après la remise : carte sur le lieu de récupération', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_bid('IN_TRANSIT')));

    expect(_mapped(tester), _delivery);
    expect(find.text(_handover.label), findsOneWidget);
    expect(find.text('Remis'), findsOneWidget);
    expect(find.text('Étape en cours'), findsOneWidget);
  });

  testWidgets('colis récupéré : pastille Livré, carte sur la récupération', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_bid('COMPLETED')));

    expect(_mapped(tester), _delivery);
    expect(find.text('Livré'), findsOneWidget);
    expect(find.text('Étape en cours'), findsNothing);
  });

  testWidgets('sans adresse de récupération : seule la remise apparaît', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_bid('HANDED_OVER', delivery: null)));

    expect(_mapped(tester), _handover);
    expect(find.text(_delivery.label), findsNothing);
  });

  test('masquée pour une demande morte ou sans adresse (ancien back)', () {
    expect(ParcelLocationsCard.shouldShow(_bid('ACCEPTED')), isTrue);
    expect(ParcelLocationsCard.shouldShow(_bid('REJECTED')), isFalse);
    expect(ParcelLocationsCard.shouldShow(_bid('CANCELLED')), isFalse);
    expect(
      ParcelLocationsCard.shouldShow(
        _bid('ACCEPTED', handover: null, delivery: null),
      ),
      isFalse,
    );
  });

  testWidgets('tap sur la récupération → ouvre la carte native', (
    tester,
  ) async {
    final launcher = _MockExternalUrlLauncher();
    when(() => launcher.open(any())).thenAnswer((_) async => true);
    if (getIt.isRegistered<ExternalUrlLauncher>()) {
      getIt.unregister<ExternalUrlLauncher>();
    }
    getIt.registerSingleton<ExternalUrlLauncher>(launcher);
    addTearDown(() => getIt.unregister<ExternalUrlLauncher>());

    await tester.pumpWidget(_host(_bid('ACCEPTED')));
    await tester.tap(find.byKey(const Key('parcel-location-delivery')));
    await tester.pump();

    final uri =
        verify(() => launcher.open(captureAny())).captured.single as Uri;
    expect(uri.scheme, 'https');
    expect(uri.query, contains('12.6362'));
  });
}
