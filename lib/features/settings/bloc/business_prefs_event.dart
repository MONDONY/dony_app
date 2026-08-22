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

/// La devise choisie est envoyée au serveur, verrouillée par le seul solde
/// du portefeuille (`currencyLocked`, `CurrencyLockService` côté backend) —
/// indépendamment du verrou pays (`countryLocked`, compte Connect créé).
class CurrencyChanged extends BusinessPrefsEvent {
  final String code;
  const CurrencyChanged(this.code);
  @override
  List<Object?> get props => [code];
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

/// Reconstruit l'état depuis Hive, comme au tout premier `BusinessPrefsBloc`.
///
/// `BusinessPrefsBloc` est un `lazySingleton` GetIt : `AuthBloc` ne le
/// recrée jamais. Sans cet event, le bloc continuerait de porter le pays
/// (et les autres préférences) du compte précédent après une déconnexion,
/// un changement de compte ou une nouvelle inscription — alors même que
/// `AuthBloc._clearHiveAccountData` a déjà vidé la case Hive dont ce bloc
/// dérive son état. Dispatché depuis `app.dart`
/// (`AccountResetGuard.shouldResetAccountScopedBlocs`), jamais depuis un
/// autre bloc (cf. `lib/features/auth/account_reset_guard.dart`).
class BusinessPrefsReset extends BusinessPrefsEvent {
  const BusinessPrefsReset();
}
