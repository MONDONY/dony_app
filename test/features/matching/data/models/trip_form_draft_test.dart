import 'dart:convert';

import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/trip_form_draft.dart';
import 'package:dony/features/matching/data/models/trip_leg_draft.dart';
import 'package:dony/features/matching/data/models/trip_stops.dart';
import 'package:flutter_test/flutter_test.dart';

const _pickup = AddressData(label: 'Gare de Lyon', lat: 48.84, lng: 2.37);
const _delivery = AddressData(label: 'Plateau', lat: 14.67, lng: -17.43);

final _leg = TripLegDraft(
  arrivalCity: 'Bamako',
  arrivalCountryCode: 'ML',
  departureDate: DateTime(2026, 11, 5),
  departureTime: '08:30',
  deliveryAddress: _delivery,
  availableKg: 10,
  pricePerKg: 4000,
  stops: TripStops.one,
  currency: 'XOF',
  acceptedPaymentMethods: const ['CASH'],
);

TripFormDraft _full() => TripFormDraft(
  step: 2,
  currency: 'EUR',
  departureCity: 'Paris',
  departureCountryCode: 'FR',
  arrivalCity: 'Dakar',
  arrivalCountryCode: 'SN',
  departureDate: DateTime(2026, 11, 2),
  departureTime: '10:15',
  arrivalTime: '06:00',
  arrivalDayOffset: 1,
  handoverDeadline: DateTime(2026, 11),
  handoverLeadDays: 1,
  transportMode: 'PLANE',
  stops: TripStops.direct,
  pickupAddress: _pickup,
  deliveryAddress: _delivery,
  availableKg: 23,
  capacityUnit: 'SUITCASE_23KG',
  pricingMode: 'KG',
  priceOption: 4,
  customPrice: 9,
  customPriceText: '9',
  acceptedContent: const ['Vêtements'],
  customAccepted: const ['Épices'],
  refusedTypes: const ['Liquides'],
  description: 'Valise rigide',
  cashEnabled: true,
  cardEnabled: false,
  mobileMoneyEnabled: true,
  negotiable: true,
  legs: [_leg],
);

Map<String, dynamic> _viaJson(TripFormDraft d) =>
    jsonDecode(jsonEncode(d.toJson())) as Map<String, dynamic>;

void main() {
  final now = DateTime(2026, 10, 13);

  test('aller-retour JSON : tous les champs, étapes comprises', () {
    final back = TripFormDraft.fromJson(_viaJson(_full()), now: now);
    expect(back, _full());
    expect(back.legs.single.arrivalCity, 'Bamako');
    expect(back.legs.single.deliveryAddress, _delivery);
    expect(back.pickupAddress, _pickup);
  });

  test('brouillon vide : défauts du formulaire vierge', () {
    final back = TripFormDraft.fromJson(const {}, now: now);
    expect(back.step, 0);
    expect(back.priceOption, -1);
    expect(back.kgPriceEnabled, isTrue);
    expect(back.cardEnabled, isTrue);
    expect(back.legs, isEmpty);
    expect(back, const TripFormDraft());
  });

  test('départ passé : date, date limite et étapes retirées, étape 0', () {
    final back = TripFormDraft.fromJson(
      _viaJson(_full()),
      now: DateTime(2026, 12),
    );
    expect(back.departureDate, isNull);
    expect(back.handoverDeadline, isNull);
    expect(back.legs, isEmpty);
    expect(back.step, 0);
    expect(back.departureCity, 'Paris');
  });

  test('lecture tolérante : valeurs illisibles écartées', () {
    final back = TripFormDraft.fromJson(const {
      'step': -3,
      'departureTime': '10h',
      'arrivalDayOffset': 7,
      'pickupAddress': {'label': 'sans coordonnées'},
      'deliveryAddress': 'texte',
      'legs': [
        {'arrivalCity': 'X'},
        'pas une étape',
      ],
      'acceptedContent': ['A', 2],
    }, now: now);
    expect(back.step, 0);
    expect(back.departureTime, isNull);
    expect(back.arrivalDayOffset, 2);
    expect(back.pickupAddress, isNull);
    expect(back.deliveryAddress, isNull);
    expect(back.legs, isEmpty);
    expect(back.acceptedContent, ['A']);
  });

  test('étape sans moyens de paiement mémorisés : null conservé', () {
    final json = _viaJson(_full());
    (json['legs'] as List).first['acceptedPaymentMethods'] = null;
    final back = TripFormDraft.fromJson(json, now: now);
    expect(back.legs.single.acceptedPaymentMethods, isNull);
  });
}
