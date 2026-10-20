import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/phone/normalize_payer_phone.dart';
import 'package:dony/core/phone/phone_country.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/payments/bloc/payer_account_state.dart';
import 'package:dony/features/payments/data/models/mobile_money_countries.dart';
import 'package:dony/features/payments/data/payer_account_source.dart';
import 'package:dony/features/payments/data/payer_phone_memory.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Pays (code ISO) et code opérateur imposés au composant : changement de
/// numéro d'un compte existant.
typedef FixedPayerAccount = ({String country, String operator});

/// Composant partagé « compte qui paie » : pays, opérateur et numéro mobile
/// money, avec reconnaissance du numéro par pawaPay.
///
/// Réutilisé par la recharge, le paiement d'un colis et l'ajout d'un compte
/// de versement : [PayerAccountSource] fournit le catalogue (dépôts ou
/// versements). Sans [PayerPhoneMemory] (versement), rien n'est prérempli ni
/// retenu. [flow] (`topup`, `payout`...) étiquette les événements analytics,
/// qui ne portent jamais de numéro.
///
/// Le minuteur de debounce vit ici, jamais côté écran : [close] l'annule, et
/// aucun `emit` n'a lieu après fermeture.
class PayerAccountCubit extends Cubit<PayerAccountState> {
  PayerAccountCubit(
    this._source,
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

  final PayerAccountSource _source;
  final PayerPhoneMemory? _memory;
  final AnalyticsService _analytics;
  final String flow;

  Timer? _debounceTimer;

  /// Devise imposée au catalogue, opérateurs permis et compte imposé,
  /// retenus par [configure] / [restrictOperators] et rejoués à chaque [load]
  /// (le « Réessayer » d'une erreur de chargement les garde).
  String? _currency;
  Set<String>? _allowed;
  FixedPayerAccount? _fixed;

  /// Incrémenté à chaque changement de saisie ou de choix : une réponse de
  /// reconnaissance qui résout avec un jeton périmé est ignorée.
  int _generation = 0;

  /// Opérateur que pawaPay a prédit pour [_recognizedE164], gardé pour
  /// respecter un choix manuel sans relancer d'appel.
  String? _detectedCode;
  String? _recognizedE164;

  /// Impose la devise du paiement et/ou limite les opérateurs acceptés, puis
  /// charge le catalogue (voir [load]). Sans argument, équivaut à [load]
  /// sans réglage.
  ///
  /// [fixed] : pays et opérateur imposés (changement de numéro d'un compte).
  /// Ils sont posés au chargement, sans préremplissage du numéro, et ne
  /// peuvent plus changer ; un numéro d'un autre opérateur donne
  /// [RecognitionStatus.notAllowed]. Absents du catalogue, le chargement
  /// finit en erreur : on ne laisse pas choisir un autre opérateur à la place.
  Future<void> configure({
    String? currency,
    Set<String>? allowedOperators,
    FixedPayerAccount? fixed,
  }) {
    _currency = currency;
    _allowed = allowedOperators;
    _fixed = fixed;
    return load();
  }

  /// Limite les opérateurs acceptés (`null` = tous). L'opérateur déjà choisi
  /// qui ne l'est plus est retiré, le numéro reste saisi. Si un numéro refusé
  /// pour son opérateur devient acceptable, il est reconnu de nouveau.
  ///
  /// En mode [PayerAccountState.fixed], la restriction est retenue mais
  /// l'opérateur imposé reste en place.
  void restrictOperators(Set<String>? allowed) {
    _allowed = allowed;
    if (state.fixed) {
      emit(state.copyWith(allowedOperators: allowed));
      return;
    }
    final operator = state.operator;
    if (operator != null && !_isAllowedBy(allowed, operator)) {
      _reset();
      _forgetDetection();
      emit(
        state.copyWith(
          allowedOperators: allowed,
          operator: null,
          recognition: RecognitionStatus.idle,
          switchedFrom: null,
        ),
      );
      return;
    }
    final rejected = state.rejectedOperator;
    final nowAccepted =
        state.recognition == RecognitionStatus.notAllowed &&
        rejected != null &&
        _isAllowedBy(allowed, rejected);
    emit(state.copyWith(allowedOperators: allowed));
    final country = state.country;
    final e164 = state.e164;
    if (nowAccepted &&
        operator != null &&
        country != null &&
        e164 != null &&
        _isComplete(country.country, e164)) {
      _reset();
      unawaited(_recognize());
    }
  }

  /// Charge le catalogue, puis préremplit pays, opérateur et numéro depuis la
  /// mémoire quand le pays est encore ouvert (et de la devise imposée) et
  /// l'opérateur encore proposé et permis. En mode imposé ([configure]
  /// `fixed`), pose le pays et l'opérateur imposés sans lire la mémoire.
  ///
  /// Restriction et devise sont relues dans [_allowed] / [_currency] à chaque
  /// `emit` : un [restrictOperators] reçu pendant l'attente du catalogue ou de
  /// la mémoire ne doit pas être écrasé par la valeur du début du chargement.
  Future<void> load() async {
    final generation = _newSession();
    emit(_base(PayerAccountStatus.loading));
    final MobileMoneyCountries? loaded;
    try {
      loaded = await _source.countries();
    } on Object {
      if (isClosed || generation != _generation) return;
      emit(_base(PayerAccountStatus.error));
      return;
    }
    if (isClosed || generation != _generation) return;
    if (loaded == null) {
      emit(_base(PayerAccountStatus.legacy));
      return;
    }
    final currency = _currency;
    final countries = currency == null ? loaded : loaded.restrictedTo(currency);

    final fixed = _fixed;
    if (fixed != null) {
      _emitFixed(countries, fixed);
      return;
    }

    // La mémoire est lue avant d'émettre `ready` : sinon l'utilisateur
    // pourrait choisir un pays pendant la lecture, et le préremplissage
    // écraserait son choix.
    final memory = _memory;
    final remembered = memory == null ? null : await memory.read();
    if (isClosed || generation != _generation) return;
    final country = remembered == null
        ? null
        : countries.byCode(remembered.country);
    final operator = country == null
        ? null
        : _operatorOf(country, remembered!.operatorCode);
    final ready = _base(
      PayerAccountStatus.ready,
    ).copyWith(countries: countries);
    if (remembered == null || country == null || operator == null) {
      emit(ready);
      return;
    }
    if (!_isAllowedBy(_allowed, operator)) {
      // Pays gardé, mais l'opérateur mémorisé n'est pas accepté ici : on
      // laisse choisir, sans reprendre un numéro qui ne servirait pas.
      emit(ready.copyWith(country: country));
      return;
    }

    emit(
      ready.copyWith(
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

  /// Pays et opérateur imposés, numéro vide. Absents du catalogue (fermés au
  /// versement, autre devise) : erreur plutôt qu'un autre choix.
  void _emitFixed(MobileMoneyCountries countries, FixedPayerAccount fixed) {
    final country = countries.byCode(fixed.country);
    final operator = country == null
        ? null
        : _operatorOf(country, fixed.operator);
    if (country == null || operator == null) {
      emit(_base(PayerAccountStatus.error));
      return;
    }
    emit(
      _base(
        PayerAccountStatus.ready,
      ).copyWith(countries: countries, country: country, operator: operator),
    );
  }

  /// État vide qui garde les réglages de [configure] / [restrictOperators].
  PayerAccountState _base(PayerAccountStatus status) => PayerAccountState(
    status: status,
    allowedOperators: _allowed,
    currency: _currency,
    fixed: _fixed != null,
  );

  /// Choisit un pays servi (vide opérateur et numéro) ou affiche l'état
  /// « Bientôt ». Un pays absent des deux listes est ignoré.
  void selectCountry(String isoCode) {
    final countries = state.countries;
    if (countries == null || state.fixed) return;
    final iso = isoCode.toUpperCase();
    final country = countries.byCode(iso);
    final upcoming = country == null && countries.isUpcoming(iso);
    if (country == null && !upcoming) return;

    _reset();
    _forgetDetection();
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

  /// Sans effet en mode [PayerAccountState.fixed].
  void clearCountry() {
    if (state.fixed) return;
    _reset();
    _forgetDetection();
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

  /// Choisit l'opérateur du pays courant ; le numéro est conservé. Sans
  /// effet en mode [PayerAccountState.fixed] (seul l'opérateur imposé y est
  /// permis).
  ///
  /// Re-choisir l'opérateur déjà retenu ne fait rien. Une fois le numéro
  /// reconnu, un autre choix est respecté sans nouvel appel
  /// ([RecognitionStatus.overridden]) : relancer la reconnaissance
  /// rebasculerait aussitôt sur l'opérateur détecté. Sans reconnaissance
  /// aboutie pour ce numéro, un numéro complet est revérifié sans attendre.
  void selectOperator(String code) {
    final country = state.country;
    if (country == null || state.operator?.code == code) return;
    final operator = _operatorOf(country, code);
    if (operator == null || !state.isAllowed(operator)) return;

    _reset();
    final e164 = state.e164;
    final detected = _detectedCode;
    // Un numéro dont l'opérateur est refusé (`notAllowed`) a bien été
    // reconnu : choisir ensuite un opérateur permis est un choix manuel
    // respecté, sans nouvel appel.
    final recognizedBefore =
        detected != null &&
        e164 != null &&
        e164 == _recognizedE164 &&
        (state.canProceed || state.recognition == RecognitionStatus.notAllowed);
    if (recognizedBefore) {
      emit(
        state.copyWith(
          operator: operator,
          recognition: code == detected
              ? RecognitionStatus.recognized
              : RecognitionStatus.overridden,
          switchedFrom: null,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        operator: operator,
        recognition: RecognitionStatus.idle,
        switchedFrom: null,
      ),
    );
    if (e164 != null && _isComplete(country.country, e164)) {
      unawaited(_recognize());
    }
  }

  /// Relance la reconnaissance du numéro courant (après une coupure réseau).
  Future<void> retryRecognition() async {
    final country = state.country;
    final e164 = state.e164;
    if (state.operator == null ||
        country == null ||
        e164 == null ||
        !_isComplete(country.country, e164)) {
      return;
    }
    _reset();
    await _recognize();
  }

  /// Saisie ou collage du numéro. Un indicatif collé (`+225`, `00225`) n'est
  /// jamais doublé. La reconnaissance part 500 ms après la dernière frappe,
  /// quand le numéro a la longueur attendue du pays.
  void phoneChanged(String raw) {
    _reset();
    _forgetDetection();
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
    if (composed.international &&
        phone.dialCode.length > composed.e164.length &&
        phone.dialCode.startsWith(composed.e164)) {
      // Indicatif du pays en cours de frappe (« +2 », « +22 » pour +225) :
      // rien n'est encore faux, pas de « non reconnu » qui clignote.
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
    if (composed.international && !composed.e164.startsWith(phone.dialCode)) {
      // Numéro d'un autre pays que celui choisi : aucun opérateur d'ici ne
      // peut le servir, inutile d'interroger pawaPay.
      emit(
        state.copyWith(
          localNumber: _withoutForeignDialCode(composed.e164),
          e164: composed.e164,
          recognition: RecognitionStatus.unrecognized,
          switchedFrom: null,
        ),
      );
      return;
    }
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
  /// numéro pour préremplir la prochaine fois. Sans mémoire, ne fait rien.
  Future<void> rememberSuccess() async {
    final memory = _memory;
    if (memory == null) return;
    final country = state.country;
    final operator = state.operator;
    final e164 = state.e164;
    if (country == null || operator == null || e164 == null) return;
    await memory.save(
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

  /// Nouvelle session de chargement : invalide tout ce qui est en vol.
  int _newSession() {
    _reset();
    _forgetDetection();
    return _generation;
  }

  void _forgetDetection() {
    _detectedCode = null;
    _recognizedE164 = null;
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
      final catalog = await _source.recognize(e164);
      if (isClosed || generation != _generation) return;

      final detected = catalog.detected;
      if (detected == null) {
        // pawaPay a prédit un opérateur fermé au dépôt ou d'une autre
        // devise : un dépôt partirait sur un mauvais opérateur.
        _markUnrecognized(logEvent: true);
        return;
      }
      final target = _operatorOf(country, detected);
      if (target == null) {
        // Le numéro appartient à un réseau que ce pays ne sert pas.
        _markUnrecognized(logEvent: true);
        return;
      }
      _detectedCode = detected;
      _recognizedE164 = e164;
      if (!state.isAllowed(target)) {
        // L'opérateur du numéro existe ici mais n'est pas accepté (restriction
        // du paiement, ou opérateur imposé d'un changement de numéro) : pas
        // de bascule, le choix de l'utilisateur reste en place.
        emit(
          state.copyWith(
            recognition: RecognitionStatus.notAllowed,
            rejectedOperator: target,
            switchedFrom: null,
          ),
        );
        _log(AnalyticsEvents.mobileMoneyOperatorNotAllowed, {
          'operator': target.code,
        });
        return;
      }
      if (detected == operator.code) {
        emit(state.copyWith(recognition: RecognitionStatus.recognized));
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
      if (e is AppException && _unrecognizedCodes.contains(e.code)) {
        _markUnrecognized(logEvent: true);
      } else {
        // Coupure réseau ou erreur serveur : le numéro n'est pas en cause,
        // l'écran propose de réessayer.
        emit(state.copyWith(recognition: RecognitionStatus.failed));
      }
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

  static bool _isAllowedBy(Set<String>? allowed, MobileMoneyOperator o) =>
      allowed == null || allowed.contains(o.code);

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

  /// E.164 d'un autre pays sans son indicatif (le plus long qui correspond),
  /// pour ne pas l'afficher derrière l'indicatif du pays choisi.
  static String _withoutForeignDialCode(String e164) {
    String? best;
    for (final c in kPhoneCountries) {
      if (e164.startsWith(c.dialCode) &&
          (best == null || c.dialCode.length > best.length)) {
        best = c.dialCode;
      }
    }
    return best == null
        ? e164.replaceAll('+', '')
        : e164.substring(best.length);
  }

  /// Le numéro a-t-il la longueur attendue du pays ?
  static bool _isComplete(String iso, String e164) {
    final phone = phoneCountryForCode(iso);
    if (phone == null || !e164.startsWith(phone.dialCode)) return false;
    return e164.length - phone.dialCode.length >= _expectedLocalDigits(phone);
  }
}
