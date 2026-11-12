import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/item_size.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:equatable/equatable.dart';

// Re-export PricingMode so callers only need to import this file
export 'package:dony/features/matching/bloc/announcement_form_state.dart'
    show PricingMode;

abstract class AnnouncementFormEvent extends Equatable {
  const AnnouncementFormEvent();

  @override
  List<Object?> get props => [];
}

class DepartureCityChanged extends AnnouncementFormEvent {
  final String city;
  final String? countryCode;

  const DepartureCityChanged(this.city, {this.countryCode});

  @override
  List<Object?> get props => [city, countryCode];
}

class ArrivalCityChanged extends AnnouncementFormEvent {
  final String city;
  final String? countryCode;

  const ArrivalCityChanged(this.city, {this.countryCode});

  @override
  List<Object?> get props => [city, countryCode];
}

class DepartureDateChanged extends AnnouncementFormEvent {
  final DateTime date;

  const DepartureDateChanged(this.date);

  @override
  List<Object?> get props => [date];
}

class PriceChanged extends AnnouncementFormEvent {
  final double price;

  /// Devise de l'annonce : la fourchette « prix raisonnable » en dépend
  /// (5 à 15 €/kg, 1 000 à 5 000 F CFA/kg).
  final SupportedCurrency currency;

  const PriceChanged(this.price, {this.currency = SupportedCurrency.eur});

  @override
  List<Object?> get props => [price, currency];
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

/// Mode du trajet. Vers un mode sans valise (route), une capacité en valises
/// passe en « Personnalisé » avec le même total ; vers un mode sans taille
/// (avion, bateau...), taille et poids max par colis sont effacés.
class TransportModeChanged extends AnnouncementFormEvent {
  final TransportMode mode;

  const TransportModeChanged(this.mode);

  @override
  List<Object?> get props => [mode];
}

/// Taille max d'un colis (route), facultative : `null` = aucune.
class MaxItemSizeChanged extends AnnouncementFormEvent {
  final ItemSize? size;

  const MaxItemSizeChanged(this.size);

  @override
  List<Object?> get props => [size];
}

/// Poids max par colis en kilos (route), facultatif : `null` = aucun. Une
/// saisie hors bornes est gardée telle quelle : l'étape la signale
/// (`isMaxParcelWeightValid`) au lieu de la corriger en silence.
class MaxParcelWeightChanged extends AnnouncementFormEvent {
  final double? kg;

  const MaxParcelWeightChanged(this.kg);

  @override
  List<Object?> get props => [kg];
}

/// Le formulaire modifie un trajet publié : sa capacité est le reste à
/// réserver, pas le total (voir `AnnouncementFormState.isEditingTrip`).
class EditingTripStarted extends AnnouncementFormEvent {
  const EditingTripStarted();

  @override
  List<Object?> get props => [];
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

class MobileMoneyAcceptedChanged extends AnnouncementFormEvent {
  final bool accepted;

  const MobileMoneyAcceptedChanged(this.accepted);

  @override
  List<Object?> get props => [accepted];
}

/// Le voyageur ouvre (ou referme) son trajet aux propositions de prix des
/// expéditeurs.
class NegotiableChanged extends AnnouncementFormEvent {
  final bool negotiable;

  const NegotiableChanged(this.negotiable);

  @override
  List<Object?> get props => [negotiable];
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
