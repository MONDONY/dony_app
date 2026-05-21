import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:equatable/equatable.dart';

// Re-export PricingMode so callers only need to import this file
export 'package:dony/features/matching/bloc/announcement_form_state.dart' show PricingMode;

abstract class AnnouncementFormEvent extends Equatable {
  const AnnouncementFormEvent();

  @override
  List<Object?> get props => [];
}

class DepartureCityChanged extends AnnouncementFormEvent {
  final String city;

  const DepartureCityChanged(this.city);

  @override
  List<Object?> get props => [city];
}

class ArrivalCityChanged extends AnnouncementFormEvent {
  final String city;

  const ArrivalCityChanged(this.city);

  @override
  List<Object?> get props => [city];
}

class DepartureDateChanged extends AnnouncementFormEvent {
  final DateTime date;

  const DepartureDateChanged(this.date);

  @override
  List<Object?> get props => [date];
}

class PriceChanged extends AnnouncementFormEvent {
  final double price;

  const PriceChanged(this.price);

  @override
  List<Object?> get props => [price];
}

class AvailableKgChanged extends AnnouncementFormEvent {
  final double kg;

  const AvailableKgChanged(this.kg);

  @override
  List<Object?> get props => [kg];
}

class CapacityUnitChanged extends AnnouncementFormEvent {
  final CapacityUnit unit;

  const CapacityUnitChanged(this.unit);

  @override
  List<Object?> get props => [unit];
}

class DescriptionChanged extends AnnouncementFormEvent {
  final String description;

  const DescriptionChanged(this.description);

  @override
  List<Object?> get props => [description];
}

class TransportModeChanged extends AnnouncementFormEvent {
  final TransportMode mode;

  const TransportModeChanged(this.mode);

  @override
  List<Object?> get props => [mode];
}

class PickupAddressChanged extends AnnouncementFormEvent {
  final AddressData? address;

  const PickupAddressChanged(this.address);

  @override
  List<Object?> get props => [address];
}

class DeliveryAddressChanged extends AnnouncementFormEvent {
  final AddressData? address;

  const DeliveryAddressChanged(this.address);

  @override
  List<Object?> get props => [address];
}

class CashAcceptedChanged extends AnnouncementFormEvent {
  final bool accepted;

  const CashAcceptedChanged(this.accepted);

  @override
  List<Object?> get props => [accepted];
}

class AcceptedTypesChanged extends AnnouncementFormEvent {
  final List<String> types;

  const AcceptedTypesChanged(this.types);

  @override
  List<Object?> get props => [types];
}

class RejectedTypesChanged extends AnnouncementFormEvent {
  final List<String> types;

  const RejectedTypesChanged(this.types);

  @override
  List<Object?> get props => [types];
}

class FormResetRequested extends AnnouncementFormEvent {
  const FormResetRequested();
}

class AnnouncementPricingModeSetRequested extends AnnouncementFormEvent {
  final PricingMode mode;
  const AnnouncementPricingModeSetRequested(this.mode);

  @override
  List<Object?> get props => [mode];
}

class AnnouncementGridPreviewLoadRequested extends AnnouncementFormEvent {
  const AnnouncementGridPreviewLoadRequested();
}

class AnnouncementPricePerKgClearedRequested extends AnnouncementFormEvent {
  const AnnouncementPricePerKgClearedRequested();
}
