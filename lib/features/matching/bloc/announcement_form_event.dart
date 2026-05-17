import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:equatable/equatable.dart';

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

class FormResetRequested extends AnnouncementFormEvent {
  const FormResetRequested();
}
