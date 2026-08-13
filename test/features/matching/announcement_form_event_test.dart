import 'package:dony/features/matching/bloc/announcement_form_event.dart';
import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnnouncementFormEvent equality (Equatable props)', () {
    test('DepartureCityChanged — equal when same city', () {
      expect(
        const DepartureCityChanged('Paris'),
        equals(const DepartureCityChanged('Paris')),
      );
    });

    test('DepartureCityChanged — not equal when different city', () {
      expect(
        const DepartureCityChanged('Paris'),
        isNot(equals(const DepartureCityChanged('Lyon'))),
      );
    });

    test('ArrivalCityChanged — equal when same city', () {
      expect(
        const ArrivalCityChanged('Dakar'),
        equals(const ArrivalCityChanged('Dakar')),
      );
    });

    test('ArrivalCityChanged — not equal when different city', () {
      expect(
        const ArrivalCityChanged('Dakar'),
        isNot(equals(const ArrivalCityChanged('Abidjan'))),
      );
    });

    test('DepartureDateChanged — equal when same date', () {
      final date = DateTime(2025, 6, 15);
      expect(DepartureDateChanged(date), equals(DepartureDateChanged(date)));
    });

    test('DepartureDateChanged — not equal when different date', () {
      expect(
        DepartureDateChanged(DateTime(2025, 6, 15)),
        isNot(equals(DepartureDateChanged(DateTime(2025, 6, 16)))),
      );
    });

    test('PriceChanged — equal when same price', () {
      expect(const PriceChanged(8.0), equals(const PriceChanged(8.0)));
    });

    test('PriceChanged — not equal when different price', () {
      expect(const PriceChanged(8.0), isNot(equals(const PriceChanged(10.0))));
    });

    test('AvailableKgChanged — equal when same kg', () {
      expect(
        const AvailableKgChanged(10.0),
        equals(const AvailableKgChanged(10.0)),
      );
    });

    test('AvailableKgChanged — not equal when different kg', () {
      expect(
        const AvailableKgChanged(10.0),
        isNot(equals(const AvailableKgChanged(20.0))),
      );
    });

    test('CapacityUnitChanged — equal when same unit', () {
      expect(
        const CapacityUnitChanged(CapacityUnit.suitcase23kg),
        equals(const CapacityUnitChanged(CapacityUnit.suitcase23kg)),
      );
    });

    test('CapacityUnitChanged — not equal when different unit', () {
      expect(
        const CapacityUnitChanged(CapacityUnit.suitcase23kg),
        isNot(equals(const CapacityUnitChanged(CapacityUnit.custom))),
      );
    });

    test('DescriptionChanged — equal when same description', () {
      expect(
        const DescriptionChanged('Test desc'),
        equals(const DescriptionChanged('Test desc')),
      );
    });

    test('DescriptionChanged — not equal when different description', () {
      expect(
        const DescriptionChanged('Test'),
        isNot(equals(const DescriptionChanged('Other'))),
      );
    });

    test('TransportModeChanged — equal when same mode', () {
      expect(
        const TransportModeChanged(TransportMode.plane),
        equals(const TransportModeChanged(TransportMode.plane)),
      );
    });

    test('TransportModeChanged — not equal when different mode', () {
      expect(
        const TransportModeChanged(TransportMode.plane),
        isNot(equals(const TransportModeChanged(TransportMode.car))),
      );
    });

    test('PickupAddressChanged — equal when same address', () {
      const addr = AddressData(label: 'Paris 1er', lat: 48.86, lng: 2.35);
      expect(
        const PickupAddressChanged(addr),
        equals(const PickupAddressChanged(addr)),
      );
    });

    test('PickupAddressChanged — equal when both null', () {
      expect(
        const PickupAddressChanged(null),
        equals(const PickupAddressChanged(null)),
      );
    });

    test('DeliveryAddressChanged — equal when same address', () {
      const addr = AddressData(label: 'Dakar Plateau', lat: 14.69, lng: -17.44);
      expect(
        const DeliveryAddressChanged(addr),
        equals(const DeliveryAddressChanged(addr)),
      );
    });

    test('CashAcceptedChanged — equal when same value', () {
      expect(
        const CashAcceptedChanged(true),
        equals(const CashAcceptedChanged(true)),
      );
    });

    test('CashAcceptedChanged — not equal when different value', () {
      expect(
        const CashAcceptedChanged(true),
        isNot(equals(const CashAcceptedChanged(false))),
      );
    });

    test('AcceptedTypesChanged — equal when same list', () {
      expect(
        const AcceptedTypesChanged(['CLOTHING', 'ELECTRONICS']),
        equals(const AcceptedTypesChanged(['CLOTHING', 'ELECTRONICS'])),
      );
    });

    test('AcceptedTypesChanged — not equal when different list', () {
      expect(
        const AcceptedTypesChanged(['CLOTHING']),
        isNot(equals(const AcceptedTypesChanged(['ELECTRONICS']))),
      );
    });

    test('RejectedTypesChanged — equal when same list', () {
      expect(
        const RejectedTypesChanged(['FOOD']),
        equals(const RejectedTypesChanged(['FOOD'])),
      );
    });

    test('RejectedTypesChanged — not equal when different list', () {
      expect(
        const RejectedTypesChanged(['FOOD']),
        isNot(equals(const RejectedTypesChanged(['LIQUIDS']))),
      );
    });

    test('FormResetRequested — two instances are equal', () {
      expect(const FormResetRequested(), equals(const FormResetRequested()));
    });

    test('AnnouncementPricingModeSetRequested — equal when same mode', () {
      expect(
        const AnnouncementPricingModeSetRequested(PricingMode.mixed),
        equals(const AnnouncementPricingModeSetRequested(PricingMode.mixed)),
      );
    });

    test(
      'AnnouncementPricingModeSetRequested — not equal when different mode',
      () {
        expect(
          const AnnouncementPricingModeSetRequested(PricingMode.mixed),
          isNot(
            equals(const AnnouncementPricingModeSetRequested(PricingMode.kg)),
          ),
        );
      },
    );

    test('AnnouncementGridPreviewLoadRequested — two instances are equal', () {
      expect(
        const AnnouncementGridPreviewLoadRequested(),
        equals(const AnnouncementGridPreviewLoadRequested()),
      );
    });

    test(
      'AnnouncementPricePerKgClearedRequested — two instances are equal',
      () {
        expect(
          const AnnouncementPricePerKgClearedRequested(),
          equals(const AnnouncementPricePerKgClearedRequested()),
        );
      },
    );

    test('different event types are not equal', () {
      expect(
        const DepartureCityChanged('Paris'),
        isNot(equals(const ArrivalCityChanged('Paris'))),
      );
    });
  });
}
