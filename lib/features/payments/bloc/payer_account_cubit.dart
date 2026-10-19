import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/phone/normalize_payer_phone.dart';
import 'package:dony/core/phone/phone_country.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/payments/bloc/payer_account_state.dart';
import 'package:dony/features/payments/data/models/mobile_money_countries.dart';
import 'package:dony/features/payments/data/payer_phone_memory.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Composant partagé « compte qui paie » : pays, opérateur et numéro mobile
/// money, avec reconnaissance du numéro par pawaPay.
///
/// Réutilisé par la recharge, puis par le paiement d'un colis et le versement.
/// [flow] (`topup`...) étiquette les événements analytics, qui ne portent
/// jamais de numéro.
///
/// Le minuteur de debounce vit ici, jamais côté écran : [close] l'annule, et
/// aucun `emit` n'a lieu après fermeture.
class PayerAccountCubit extends Cubit<PayerAccountState> {
  PayerAccountCubit(
    this._repository,
    this._memory,
    this._analytics, {
    required this.flow,
  }) : super(const PayerAccountState());

  static const debounce = Duration(milliseconds: 500);

  /// Longueur minimale (chiffres locaux) quand le pays n'a pas de `hint`.
  static const _fallbackLocalDigits = 8;

  static const _unrecognizedCodes = {
    'mobile-money-invalid-phone',
    'topup-phone-unsupported',
  };

  final WalletRepository _repository;
  final PayerPhoneMemory _memory;
  final AnalyticsService _analytics;
  final String flow;

  Timer? _debounceTimer;

  /// Incrémenté à chaque changement de saisie ou de choix : une réponse de
  /// reconnaissance qui résout avec un jeton périmé est ignorée.
  int _generation = 0;

  /// Charge le catalogue, puis préremplit pays, opérateur et numéro depuis la
  /// mémoire quand le pays est encore ouvert et l'opérateur encore proposé.
  Future<void> load() async {
    emit(const PayerAccountState());
    final MobileMoneyCountries? countries;
    try {
      countries = await _repository.mobileMoneyCountries();
    } on Object {
      if (isClosed) return;
      emit(const PayerAccountState(status: PayerAccountStatus.error));
      return;
    }
    if (isClosed) return;
    if (countries == null) {
      emit(const PayerAccountState(status: PayerAccountStatus.legacy));
      return;
    }
    emit(
      PayerAccountState(status: PayerAccountStatus.ready, countries: countries),
    );

    final remembered = await _memory.read();
    if (isClosed || remembered == null) return;
    final country = countries.byCode(remembered.country);
    final operator = country == null
        ? null
        : _operatorOf(country, remembered.operatorCode);
    if (country == null || operator == null) return;

    _generation++;
    emit(
      state.copyWith(
        country: country,
        operator: operator,
        localNumber: _localPart(remembered.country, remembered.e164),
        e164: remembered.e164,
      ),
    );
    if (_isComplete(remembered.country, remembered.e164)) {
      unawaited(_recognize());
    }
  }

  /// Choisit un pays servi (vide opérateur et numéro) ou affiche l'état
  /// « Bientôt ». Un pays absent des deux listes est ignoré.
  void selectCountry(String isoCode) {
    final countries = state.countries;
    if (countries == null) return;
    final iso = isoCode.toUpperCase();
    final country = countries.byCode(iso);
    final upcoming = country == null && countries.isUpcoming(iso);
    if (country == null && !upcoming) return;

    _reset();
    emit(
      state.copyWith(
        country: country,
        unavailableCountry: upcoming ? iso : null,
        operator: null,
        localNumber: '',
        e164: null,
        recognition: RecognitionStatus.idle,
        switchedFrom: null,
      ),
    );
    _log(AnalyticsEvents.mobileMoneyCountrySelected, {
      'country': iso,
      'available': country != null,
    });
    if (upcoming) {
      _log(AnalyticsEvents.mobileMoneyCountryUnavailableViewed, {
        'country': iso,
      });
    }
  }

  void clearCountry() {
    _reset();
    emit(
      state.copyWith(
        country: null,
        unavailableCountry: null,
        operator: null,
        localNumber: '',
        e164: null,
        recognition: RecognitionStatus.idle,
        switchedFrom: null,
      ),
    );
  }

  /// Choisit l'opérateur du pays courant ; le numéro est conservé et, s'il
  /// est complet, revérifié sans attendre.
  void selectOperator(String code) {
    final country = state.country;
    if (country == null) return;
    final operator = _operatorOf(country, code);
    if (operator == null) return;

    _reset();
    emit(
      state.copyWith(
        operator: operator,
        recognition: RecognitionStatus.idle,
        switchedFrom: null,
      ),
    );
    final e164 = state.e164;
    if (e164 != null && _isComplete(country.country, e164)) {
      unawaited(_recognize());
    }
  }

  /// Saisie ou collage du numéro. Un indicatif collé (`+225`, `00225`) n'est
  /// jamais doublé. La reconnaissance part 500 ms après la dernière frappe,
  /// quand le numéro a la longueur attendue du pays.
  void phoneChanged(String raw) {
    _reset();
    final country = state.country;
    final normalized = normalizePayerPhone(raw);
    final phone = country == null ? null : phoneCountryForCode(country.country);

    if (normalized == null) {
      emit(
        state.copyWith(
          localNumber: '',
          e164: null,
          recognition: RecognitionStatus.idle,
          switchedFrom: null,
        ),
      );
      return;
    }
    if (country == null || phone == null) {
      emit(
        state.copyWith(
          localNumber: normalized.replaceAll('+', ''),
          e164: null,
          recognition: RecognitionStatus.idle,
          switchedFrom: null,
        ),
      );
      return;
    }

    final composed = _compose(phone, normalized);
    emit(
      state.copyWith(
        localNumber: composed.international
            ? _localPart(country.country, composed.e164)
            : normalized,
        e164: composed.e164,
        recognition: RecognitionStatus.idle,
        switchedFrom: null,
      ),
    );

    if (state.operator != null && _isComplete(country.country, composed.e164)) {
      _debounceTimer = Timer(debounce, () {
        if (!isClosed) unawaited(_recognize());
      });
    }
  }

  /// À appeler à la confirmation d'une recharge : retient pays, opérateur et
  /// numéro pour préremplir la prochaine fois.
  Future<void> rememberSuccess() async {
    final country = state.country;
    final operator = state.operator;
    final e164 = state.e164;
    if (country == null || operator == null || e164 == null) return;
    await _memory.save(
      RememberedPayer(
        country: country.country,
        operatorCode: operator.code,
        e164: e164,
      ),
    );
  }

  /// Bouton « Recharger par carte » touché depuis un pays « Bientôt ».
  void switchToCardTapped() {
    final country = state.unavailableCountry ?? state.country?.country;
    _log(AnalyticsEvents.mobileMoneySwitchToCardTapped, {'country': ?country});
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }

  // ---------------------------------------------------------------------------

  /// Annule la reconnaissance en attente ou en vol.
  void _reset() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _generation++;
  }

  Future<void> _recognize() async {
    final e164 = state.e164;
    final operator = state.operator;
    final country = state.country;
    if (e164 == null || operator == null || country == null) return;

    final generation = ++_generation;
    emit(
      state.copyWith(
        recognition: RecognitionStatus.checking,
        switchedFrom: null,
      ),
    );
    try {
      final catalog = await _repository.topupProviders(e164);
      if (isClosed || generation != _generation) return;

      final detected = catalog.detected;
      if (detected == null || detected == operator.code) {
        emit(state.copyWith(recognition: RecognitionStatus.recognized));
        return;
      }
      final target = _operatorOf(country, detected);
      if (target == null) {
        // Le numéro appartient à un réseau que ce pays ne sert pas.
        _markUnrecognized(logEvent: true);
        return;
      }
      emit(
        state.copyWith(
          operator: target,
          recognition: RecognitionStatus.autoSwitched,
          switchedFrom: operator.code,
        ),
      );
      _log(AnalyticsEvents.mobileMoneyOperatorAutoSwitched, {
        'from': operator.code,
        'to': target.code,
      });
    } on Object catch (e) {
      if (isClosed || generation != _generation) return;
      _markUnrecognized(
        logEvent: e is AppException && _unrecognizedCodes.contains(e.code),
      );
    }
  }

  void _markUnrecognized({required bool logEvent}) {
    emit(state.copyWith(recognition: RecognitionStatus.unrecognized));
    if (logEvent) _log(AnalyticsEvents.mobileMoneyNumberUnrecognized, const {});
  }

  void _log(String name, Map<String, Object> properties) {
    unawaited(
      _analytics.logEvent(name, properties: {...properties, 'flow': flow}),
    );
  }

  static MobileMoneyOperator? _operatorOf(
    MobileMoneyCountry country,
    String code,
  ) {
    for (final o in country.operators) {
      if (o.code == code) return o;
    }
    return null;
  }

  /// Chiffres attendus après l'indicatif, déduits de l'exemple du pays. Le
  /// zéro de tête d'un pays qui le retire n'est pas compté.
  static int _expectedLocalDigits(PhoneCountry phone) {
    final hintDigits = phone.hint.replaceAll(RegExp(r'\D'), '');
    if (hintDigits.isEmpty) return _fallbackLocalDigits;
    final stripped = phone.stripsLeadingZero && hintDigits.startsWith('0');
    return stripped ? hintDigits.length - 1 : hintDigits.length;
  }

  /// Compose l'E.164 sans jamais doubler l'indicatif d'un numéro collé.
  static ({String e164, bool international}) _compose(
    PhoneCountry phone,
    String normalized,
  ) {
    final bare = phone.dialCode.substring(1);
    var e164 = toE164(phone.dialCode, normalized);
    var international =
        normalized.startsWith('+') || normalized.startsWith('00$bare');

    // Indicatif collé sans « + » ni « 00 » : accepté seulement si la longueur
    // correspond à indicatif + numéro complet, pour ne pas confondre avec un
    // numéro local qui commencerait par les mêmes chiffres.
    if (!international &&
        normalized.startsWith(bare) &&
        normalized.length >= bare.length + _expectedLocalDigits(phone)) {
      e164 = '+$normalized';
      international = true;
    }

    // « +33 06... » : le zéro de tête reste un préfixe interurbain à retirer.
    if (international &&
        phone.stripsLeadingZero &&
        e164.startsWith('${phone.dialCode}0')) {
      e164 = phone.dialCode + e164.substring(phone.dialCode.length + 1);
    }
    return (e164: e164, international: international);
  }

  /// Partie locale d'un E.164 pour le pays [iso] ; sans l'indicatif du pays,
  /// le numéro sans son `+`.
  static String _localPart(String iso, String e164) {
    final phone = phoneCountryForCode(iso);
    if (phone != null && e164.startsWith(phone.dialCode)) {
      return e164.substring(phone.dialCode.length);
    }
    return e164.replaceAll('+', '');
  }

  /// Le numéro a-t-il la longueur attendue du pays ?
  static bool _isComplete(String iso, String e164) {
    final phone = phoneCountryForCode(iso);
    if (phone == null || !e164.startsWith(phone.dialCode)) return false;
    return e164.length - phone.dialCode.length >= _expectedLocalDigits(phone);
  }
}
