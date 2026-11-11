import 'package:dio/dio.dart';
import 'package:dony/features/settings/data/repositories/business_prefs_repository.dart';
import 'package:dony/features/tax_info/data/datasources/tax_info_remote_datasource.dart';
import 'package:dony/features/tax_info/data/models/tax_info.dart';
import 'package:dony/features/tax_info/data/models/tax_info_update.dart';

/// Échec d'un appel « informations fiscales ». [code] est le `type` RFC 7807 du
/// back (dernier segment, ex. `tax-info-invalid`) ou `network` sans réponse.
/// Ne porte jamais la valeur saisie.
class TaxInfoException implements Exception {
  const TaxInfoException(this.code, {this.status, this.field});

  final String code;
  final int? status;

  /// Champ refusé par le back (422 `tax-info-invalid` ou `tax-info-read-only`,
  /// propriété `field` : `taxIdentificationNumber`, `vatNumber`, `firstName`,
  /// `birthDate`, `address.city`…). Le nom du champ seulement, jamais sa
  /// valeur.
  final String? field;

  @override
  String toString() =>
      'TaxInfoException($code, status: $status, field: $field)';
}

/// La fonction est absente pour ce compte : collecte éteinte (404
/// `dac7-disabled`), route inconnue d'un ancien back (404), invité (403) ou
/// session expirée (401). L'app ne montre alors rien du tout.
class TaxInfoUnavailableException extends TaxInfoException {
  const TaxInfoUnavailableException({super.status})
    : super('tax-info-unavailable');
}

/// Codes levés par [TaxInfoRepository.saveResidenceCountry] avant tout envoi :
/// le pays ne se change pas depuis l'écran fiscal (paiements engagés, ou
/// activation des paiements par carte en cours qu'un changement annulerait).
/// Réglages › Préférences reste la porte, avec sa confirmation.
const String kTaxResidenceLockedCode = 'country-locked';
const String kTaxResidenceResetsPayoutCode = 'country-resets-payout';

class TaxInfoRepository {
  TaxInfoRepository(this._datasource, [this._businessPrefs]);

  final TaxInfoRemoteDatasource _datasource;

  /// Préférences du compte (`/users/me/business-preferences`), seule porte
  /// d'écriture du pays de résidence côté back. Facultatif pour les tests qui
  /// ne touchent pas au pays.
  final BusinessPrefsRepository? _businessPrefs;

  Future<TaxInfo> fetch() => _guard(_datasource.fetch);

  /// 422 `tax-info-invalid` : numéro refusé par le back.
  Future<TaxInfo> save({
    required String taxIdentificationNumber,
    required String taxCountry,
    String? vatNumber,
  }) => _guard(
    () => _datasource.save(
      taxIdentificationNumber: taxIdentificationNumber,
      taxCountry: taxCountry,
      vatNumber: vatNumber,
    ),
  );

  /// Collecte ciblée : `PUT` partiel (yadony-back #730).
  Future<TaxInfo> update(TaxInfoUpdate update) =>
      _guard(() => _datasource.update(update));

  /// Pays de résidence inconnu : enregistré par le `PUT` des préférences
  /// (même corps que le `GET`, `country` renseigné), puis relecture des
  /// informations fiscales, qui en dépendent.
  ///
  /// Refuse sans rien envoyer si le pays est verrouillé ou si le changer
  /// annulerait une activation des paiements par carte : Réglages demande
  /// alors confirmation, pas cet écran.
  Future<TaxInfo> saveResidenceCountry(String country) => _guard(() async {
    final prefsRepo = _businessPrefs;
    if (prefsRepo == null) {
      throw const TaxInfoUnavailableException();
    }
    final prefs = await prefsRepo.fetchPrefs();
    if (prefs.country != country) {
      if (prefs.countryLocked) {
        throw const TaxInfoException(kTaxResidenceLockedCode);
      }
      if (prefs.countryChangeResetsPayoutSetup) {
        throw const TaxInfoException(kTaxResidenceResetsPayoutCode);
      }
      await prefsRepo.updatePrefs(prefs.copyWith(country: country));
    }
    return _datasource.fetch();
  });

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  TaxInfoException _map(DioException e) {
    final status = e.response?.statusCode;
    if (e.response == null) return TaxInfoException('network', status: status);
    if (status == 404 || status == 403 || status == 401) {
      return TaxInfoUnavailableException(status: status);
    }
    return TaxInfoException(
      _problemCode(e.response?.data) ?? 'unknown',
      status: status,
      field: _problemField(e.response?.data),
    );
  }

  /// Nom du champ refusé (extension `field` du ProblemDetail), jamais sa valeur.
  static String? _problemField(Object? data) {
    if (data is! Map) return null;
    final field = data['field'];
    return field is String && field.isNotEmpty ? field : null;
  }

  /// Dernier segment du `type` RFC 7807, sinon `code` (champ d'extension).
  static String? _problemCode(Object? data) {
    if (data is! Map) return null;
    final type = data['type'];
    if (type is String && type.isNotEmpty) {
      final segment = type.split('/').last;
      if (segment.isNotEmpty) return segment;
    }
    final code = data['code'];
    return code is String && code.isNotEmpty ? code : null;
  }
}
