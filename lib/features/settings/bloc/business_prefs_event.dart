part of 'business_prefs_bloc.dart';

abstract class BusinessPrefsEvent extends Equatable {
  const BusinessPrefsEvent();
  @override
  List<Object?> get props => [];
}

// ── Existants ────────────────────────────────────────────────────────────────
class WeightUnitChanged extends BusinessPrefsEvent {
  final String unit;
  const WeightUnitChanged(this.unit);
  @override
  List<Object?> get props => [unit];
}

/// Le pays choisi est envoyé au serveur ; la devise qui en dérive revient
/// dans la réponse (`_onCountry`), jamais recalculée côté client.
class CountryChanged extends BusinessPrefsEvent {
  final String code;
  const CountryChanged(this.code);
  @override
  List<Object?> get props => [code];
}

class PickupRadiusChanged extends BusinessPrefsEvent {
  final int km;
  const PickupRadiusChanged(this.km);
  @override
  List<Object?> get props => [km];
}

// ── Nouveaux ─────────────────────────────────────────────────────────────────
class DefaultWeightChanged extends BusinessPrefsEvent {
  final int kg;
  const DefaultWeightChanged(this.kg);
  @override
  List<Object?> get props => [kg];
}

class MinBidPriceChanged extends BusinessPrefsEvent {
  final int euros;
  const MinBidPriceChanged(this.euros);
  @override
  List<Object?> get props => [euros];
}

class ContactModeChanged extends BusinessPrefsEvent {
  final String? mode; // null = effacer la préférence
  const ContactModeChanged(this.mode);
  @override
  List<Object?> get props => [mode];
}

class ResponseDelayChanged extends BusinessPrefsEvent {
  final int? hours; // null = effacer la préférence
  const ResponseDelayChanged(this.hours);
  @override
  List<Object?> get props => [hours];
}

class BusinessPrefsSyncRequested extends BusinessPrefsEvent {
  const BusinessPrefsSyncRequested();
}
