import 'package:dony/features/matching/bloc/announcement_form_event.dart';
import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AnnouncementFormBloc
    extends Bloc<AnnouncementFormEvent, AnnouncementFormState> {
  static const double _minReasonablePrice = 5.0;
  static const double _maxReasonablePrice = 15.0;

  AnnouncementFormBloc() : super(const AnnouncementFormState()) {
    on<DepartureCityChanged>(_onDepartureCityChanged);
    on<ArrivalCityChanged>(_onArrivalCityChanged);
    on<DepartureDateChanged>(_onDepartureDateChanged);
    on<PriceChanged>(_onPriceChanged);
    on<AvailableKgChanged>(_onAvailableKgChanged);
    on<CapacityUnitChanged>(_onCapacityUnitChanged);
    on<DescriptionChanged>(_onDescriptionChanged);
    on<FormResetRequested>(_onFormReset);
  }

  void _onDepartureCityChanged(
    DepartureCityChanged event,
    Emitter<AnnouncementFormState> emit,
  ) {
    emit(state.copyWith(departureCity: event.city));
  }

  void _onArrivalCityChanged(
    ArrivalCityChanged event,
    Emitter<AnnouncementFormState> emit,
  ) {
    emit(state.copyWith(arrivalCity: event.city));
  }

  void _onDepartureDateChanged(
    DepartureDateChanged event,
    Emitter<AnnouncementFormState> emit,
  ) {
    emit(state.copyWith(departureDate: event.date));
  }

  void _onPriceChanged(
    PriceChanged event,
    Emitter<AnnouncementFormState> emit,
  ) {
    PriceWarning? warning;
    if (event.price < _minReasonablePrice) {
      warning = PriceWarning.tooLow;
    } else if (event.price > _maxReasonablePrice) {
      warning = PriceWarning.tooHigh;
    }
    emit(state.copyWith(
      pricePerKg: event.price,
      priceWarningGetter: () => warning,
    ));
  }

  void _onAvailableKgChanged(
    AvailableKgChanged event,
    Emitter<AnnouncementFormState> emit,
  ) {
    emit(state.copyWith(availableKg: event.kg));
  }

  void _onCapacityUnitChanged(
    CapacityUnitChanged event,
    Emitter<AnnouncementFormState> emit,
  ) {
    emit(state.copyWith(capacityUnit: event.unit));
  }

  void _onDescriptionChanged(
    DescriptionChanged event,
    Emitter<AnnouncementFormState> emit,
  ) {
    emit(state.copyWith(description: event.description));
  }

  void _onFormReset(
    FormResetRequested event,
    Emitter<AnnouncementFormState> emit,
  ) {
    emit(const AnnouncementFormState());
  }
}
