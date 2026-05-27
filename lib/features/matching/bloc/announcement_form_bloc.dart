import 'package:dony/features/matching/bloc/announcement_form_event.dart';
import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:dony/features/matching/data/models/grid_preview_item.dart';
import 'package:dony/features/price_grid/data/repositories/price_grid_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AnnouncementFormBloc
    extends Bloc<AnnouncementFormEvent, AnnouncementFormState> {
  static const double _minReasonablePrice = 5.0;
  static const double _maxReasonablePrice = 15.0;

  final PriceGridRepository? _priceGridRepository;

  AnnouncementFormBloc({PriceGridRepository? priceGridRepository})
      : _priceGridRepository = priceGridRepository,
        super(const AnnouncementFormState()) {
    on<DepartureCityChanged>(_onDepartureCityChanged);
    on<ArrivalCityChanged>(_onArrivalCityChanged);
    on<DepartureDateChanged>(_onDepartureDateChanged);
    on<PriceChanged>(_onPriceChanged);
    on<AvailableKgChanged>(_onAvailableKgChanged);
    on<CapacityUnitChanged>(_onCapacityUnitChanged);
    on<DescriptionChanged>(_onDescriptionChanged);
    on<TransportModeChanged>(_onTransportModeChanged);
    on<PickupAddressChanged>(_onPickupAddressChanged);
    on<DeliveryAddressChanged>(_onDeliveryAddressChanged);
    on<CashAcceptedChanged>(_onCashAcceptedChanged);
    on<AcceptedTypesChanged>(_onAcceptedTypesChanged);
    on<RejectedTypesChanged>(_onRejectedTypesChanged);
    on<FormResetRequested>(_onFormReset);
    on<AnnouncementPricingModeSetRequested>(_onPricingModeSet);
    on<AnnouncementGridPreviewLoadRequested>(_onGridPreviewLoad);
    on<AnnouncementPricePerKgClearedRequested>(_onPricePerKgCleared);
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
    emit(state.copyWith(availableKgGetter: () => event.kg.toDouble()));
  }

  void _onCapacityUnitChanged(
    CapacityUnitChanged event,
    Emitter<AnnouncementFormState> emit,
  ) {
    switch (event.unit) {
      case CapacityUnit.suitcase23kg:
      case CapacityUnit.suitcase32kg:
        emit(state.copyWith(
          capacityUnit: event.unit,
          availableKgGetter: () => event.unit.maxKg,
        ));
      case CapacityUnit.kgFree:
        // « Kg libre » : tarification au kilo, mais le voyageur indique tout de
        // même un poids disponible (le backend exige availableKg ≥ 1). On
        // conserve la valeur courante plutôt que de la remettre à zéro.
        emit(state.copyWith(
          capacityUnit: event.unit,
          availableKgGetter: () => state.availableKg ?? 1.0,
        ));
      case CapacityUnit.custom:
        emit(state.copyWith(
          capacityUnit: event.unit,
          availableKgGetter: () => state.availableKg ?? 1.0,
        ));
    }
  }

  void _onDescriptionChanged(
    DescriptionChanged event,
    Emitter<AnnouncementFormState> emit,
  ) {
    emit(state.copyWith(description: event.description));
  }

  void _onTransportModeChanged(
    TransportModeChanged event,
    Emitter<AnnouncementFormState> emit,
  ) {
    emit(state.copyWith(transportModeGetter: () => event.mode));
  }

  void _onPickupAddressChanged(
    PickupAddressChanged event,
    Emitter<AnnouncementFormState> emit,
  ) {
    emit(state.copyWith(pickupAddressGetter: () => event.address));
  }

  void _onDeliveryAddressChanged(
    DeliveryAddressChanged event,
    Emitter<AnnouncementFormState> emit,
  ) {
    emit(state.copyWith(deliveryAddressGetter: () => event.address));
  }

  void _onCashAcceptedChanged(
    CashAcceptedChanged event,
    Emitter<AnnouncementFormState> emit,
  ) {
    emit(state.copyWith(cashAccepted: event.accepted));
  }

  void _onAcceptedTypesChanged(
    AcceptedTypesChanged event,
    Emitter<AnnouncementFormState> emit,
  ) {
    emit(state.copyWith(acceptedTypes: event.types));
  }

  void _onRejectedTypesChanged(
    RejectedTypesChanged event,
    Emitter<AnnouncementFormState> emit,
  ) {
    emit(state.copyWith(rejectedTypes: event.types));
  }

  void _onFormReset(
    FormResetRequested event,
    Emitter<AnnouncementFormState> emit,
  ) {
    emit(const AnnouncementFormState());
  }

  void _onPricingModeSet(
    AnnouncementPricingModeSetRequested event,
    Emitter<AnnouncementFormState> emit,
  ) {
    final wasAlreadyMixed = state.pricingMode == PricingMode.mixed;
    emit(state.copyWith(pricingMode: event.mode));
    if (event.mode == PricingMode.mixed && !wasAlreadyMixed) {
      add(const AnnouncementGridPreviewLoadRequested());
    }
  }

  Future<void> _onGridPreviewLoad(
    AnnouncementGridPreviewLoadRequested event,
    Emitter<AnnouncementFormState> emit,
  ) async {
    if (_priceGridRepository == null) return;
    try {
      final items = await _priceGridRepository.getItems();
      final previewItems = items
          .map((e) => GridPreviewItem(
                id: e.id,
                label: e.label,
                unitPriceDisplay: e.unitPriceDisplay,
              ))
          .toList();
      emit(state.copyWith(gridPreviewItems: previewItems));
    } catch (_) {
      // silence — preview only, non bloquant
    }
  }

  void _onPricePerKgCleared(
    AnnouncementPricePerKgClearedRequested event,
    Emitter<AnnouncementFormState> emit,
  ) {
    emit(state.copyWith(pricePerKgGetter: () => null));
  }
}
