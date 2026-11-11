import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/app_log.dart';
import 'package:dony/features/tax_info/bloc/tax_info_signal.dart';
import 'package:dony/features/tax_info/bloc/tax_info_state.dart';
import 'package:dony/features/tax_info/data/models/tax_info.dart';
import 'package:dony/features/tax_info/data/models/tax_info_update.dart';
import 'package:dony/features/tax_info/data/repositories/tax_info_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Écran « Informations fiscales » (`/profile/tax-info`) : lecture, saisie et
/// enregistrement des informations fiscales. Jamais bloquant : rien dans l'app
/// ne dépend de cet écran (ni acceptation, ni publication, ni paiement, ni
/// retrait).
///
/// Deux contrats :
/// - ancien (lot 3d, ou DAC7 éteint) : numéro fiscal, pays d'émission, TVA ;
/// - collecte ciblée (yadony-back #730, `collectionStatus` présent) : le pays
///   seul s'il est inconnu, sinon seulement les champs manquants.
///
/// Les valeurs saisies ne partent que dans le `PUT`. Ni les journaux ni
/// l'analytique n'en reçoivent la valeur ou la longueur : seulement des codes.
class TaxInfoCubit extends Cubit<TaxInfoState> {
  TaxInfoCubit(this._repository, this._analytics) : super(const TaxInfoState());

  final TaxInfoRepository _repository;
  final AnalyticsService _analytics;

  bool _loadInFlight = false;
  bool _reloadQueued = false;
  bool _openedLogged = false;

  /// Ouverture depuis une notification « pays seul » (`residence`), pour
  /// l'analytique : le statut lu reste la seule source de vérité.
  String? _scope;

  /// Une lecture à la fois ; un appel pendant une lecture est mis en file (un
  /// seul rejeu, quel que soit le nombre de demandes).
  Future<void> load({String? scope}) async {
    if (isClosed) return;
    _scope ??= scope;
    if (_loadInFlight) {
      _reloadQueued = true;
      return;
    }
    _loadInFlight = true;
    try {
      do {
        _reloadQueued = false;
        await _load();
      } while (_reloadQueued && !isClosed);
    } finally {
      _loadInFlight = false;
      _reloadQueued = false;
    }
  }

  Future<void> _load() async {
    if (state.load != TaxInfoLoadStatus.ready) {
      emit(state.copyWith(load: TaxInfoLoadStatus.loading));
    }
    try {
      final info = await _repository.fetch();
      if (isClosed) return;
      emit(
        state.copyWith(
          load: _concerned(info)
              ? TaxInfoLoadStatus.ready
              : TaxInfoLoadStatus.unavailable,
          info: info,
          // Pays d'émission proposé d'après la résidence, modifiable.
          taxCountry:
              state.taxCountry ?? info.taxCountry ?? info.residenceCountry,
          // Lieu de naissance déjà donné à la place du numéro : la case
          // « Je n'ai pas de numéro fiscal » reste cochée.
          noTaxNumber:
              state.noTaxNumber ||
              (info.identity?.birthPlaceProvided ?? false) &&
                  info.isMissing(TaxInfoField.taxIdentificationNumber),
          clearError: true,
        ),
      );
      if (!_openedLogged) {
        _openedLogged = true;
        unawaited(
          _analytics.logEvent(
            AnalyticsEvents.taxInfoOpened,
            properties: {
              'solicitation': info.solicitation.wire,
              'provided': info.provided,
              'collection_status': info.collectionStatus?.wire ?? 'legacy',
              'scope': ?_scope,
            },
          ),
        );
      }
    } on TaxInfoUnavailableException {
      if (isClosed) return;
      emit(state.copyWith(load: TaxInfoLoadStatus.unavailable));
    } catch (e) {
      if (isClosed) return;
      AppLog.warn('tax_info_load_failed', data: {'code': _code(e)});
      emit(state.copyWith(load: TaxInfoLoadStatus.failure));
    }
  }

  /// L'écran est-il pour ce voyageur ?
  ///
  /// Collecte ciblée : tout sauf `NE_PAS_SOLLICITER` (pays hors périmètre,
  /// l'écran n'est jamais proposé). Ancien contrat : fourni ou demandé ; ni
  /// l'un ni l'autre (ex. lien d'une ancienne notification) : rien à montrer.
  static bool _concerned(TaxInfo info) {
    if (info.usesCollectionContract) {
      return info.collectionStatus != TaxInfoCollectionStatus.nePasSolliciter;
    }
    return info.provided || info.solicitation == TaxInfoSolicitation.solliciter;
  }

  /// Saisie du formulaire. Modifier un champ efface l'erreur du serveur qui
  /// le désignait : elle portait sur la valeur précédente.
  void updateForm({
    String? taxNumber,
    String? vatNumber,
    String? taxCountry,
    String? residenceCountry,
    String? firstName,
    String? lastName,
    DateTime? birthDate,
    String? street,
    String? line2,
    String? postalCode,
    String? city,
    String? birthPlace,
  }) {
    if (isClosed || state.submitting) return;
    final s = state;
    final clear =
        (residenceCountry != null && s.serverRejected(kTaxFieldResidence)) ||
        (taxNumber != null && s.serverRejectedTaxNumber) ||
        (taxCountry != null && s.serverRejected(kTaxFieldCountry)) ||
        (vatNumber != null && s.serverRejectedVat) ||
        (firstName != null && s.serverRejected(kTaxFieldFirstName)) ||
        (lastName != null && s.serverRejected(kTaxFieldLastName)) ||
        (birthDate != null && s.serverRejected(kTaxFieldBirthDate)) ||
        (street != null && s.serverRejected(kTaxFieldStreet)) ||
        (line2 != null && s.serverRejected(kTaxFieldLine2)) ||
        (postalCode != null && s.serverRejected(kTaxFieldPostalCode)) ||
        (city != null && s.serverRejected(kTaxFieldCity)) ||
        (birthPlace != null && s.serverRejected(kTaxFieldBirthPlace));
    emit(
      s.copyWith(
        taxNumber: taxNumber,
        vatNumber: vatNumber,
        taxCountry: taxCountry,
        residenceCountry: residenceCountry,
        firstName: firstName,
        lastName: lastName,
        birthDate: birthDate,
        street: street,
        line2: line2,
        postalCode: postalCode,
        city: city,
        birthPlace: birthPlace,
        clearError: clear,
      ),
    );
  }

  /// « Ce n'est plus mon adresse » : l'adresse reprise de la pièce cède la
  /// place aux champs de saisie (vides).
  void replaceAddress() {
    if (isClosed || state.submitting) return;
    emit(state.copyWith(replacingAddress: true));
  }

  /// Retour à l'adresse reprise de la pièce, sans rien envoyer.
  void keepAddress() {
    if (isClosed || state.submitting) return;
    emit(
      state.copyWith(
        replacingAddress: false,
        street: '',
        line2: '',
        postalCode: '',
        city: '',
      ),
    );
  }

  /// « Je n'ai pas de numéro fiscal » : le lieu de naissance remplace le
  /// numéro (et la TVA).
  void setNoTaxNumber(bool value) {
    if (isClosed || state.submitting || state.noTaxNumber == value) return;
    emit(state.copyWith(noTaxNumber: value, clearError: true));
  }

  /// « Modifier » sur la fiche d'un voyageur qui a déjà fourni ses
  /// informations : le formulaire s'ouvre vide (le numéro n'est jamais renvoyé
  /// en clair, il n'y a rien à préremplir).
  void startEditing() {
    if (isClosed) return;
    emit(
      state.copyWith(
        editing: true,
        taxNumber: '',
        vatNumber: '',
        clearError: true,
      ),
    );
  }

  /// Retour à la fiche sans rien enregistrer.
  void cancelEditing() {
    if (isClosed) return;
    emit(
      state.copyWith(
        editing: false,
        taxNumber: '',
        vatNumber: '',
        clearError: true,
      ),
    );
  }

  /// Enregistre. Un second appel pendant l'envoi est ignoré : l'état
  /// `submitting` est émis avant tout `await`.
  Future<void> submit() async {
    if (isClosed || !state.canSubmit) return;
    if (state.asksResidence) return _submitResidence();
    final edit = state.info?.provided ?? false;
    final country = state.taxCountry;
    final targeted = state.isTargeted;
    final update = state.update;
    emit(state.copyWith(submitting: true, clearError: true));
    try {
      final info = targeted
          ? await _repository.update(update)
          : await _repository.save(
              taxIdentificationNumber: state.taxNumber,
              taxCountry: country!,
              vatNumber: state.vatNumber,
            );
      notifyTaxInfoChanged();
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.taxInfoSaved,
          properties: {
            'edit': edit,
            if (targeted) 'scope': 'tax_info',
            if (targeted) 'fields': update.fieldCodes.join(','),
            if (targeted)
              'collection_status': info.collectionStatus?.wire ?? 'legacy',
          },
        ),
      );
      if (isClosed) return;
      // Les valeurs saisies sont effacées : on n'affiche que la forme masquée
      // de la réponse.
      emit(
        TaxInfoState(
          load: TaxInfoLoadStatus.ready,
          info: info,
          taxCountry: info.taxCountry ?? country,
          saved: true,
        ),
      );
    } on TaxInfoUnavailableException {
      _failSubmit('dac7-disabled', unavailable: true);
    } on TaxInfoException catch (e) {
      _failSubmit(e.code, field: e.field);
    } catch (_) {
      _failSubmit('unknown');
    }
  }

  /// Pays de résidence (statut `RESIDENCE_INCONNUE`), envoyé par le `PUT`
  /// fiscal (`residenceCountry`, yadony-back #730) : le pays du profil et les
  /// paiements n'en dépendent pas. La réponse dit la suite : le voyageur hors
  /// périmètre n'a plus rien à fournir, le résident de l'Union voit aussitôt
  /// ce qui manque.
  Future<void> _submitResidence() async {
    final code = state.residenceCountry!;
    emit(state.copyWith(submitting: true, clearError: true));
    try {
      final info = await _repository.update(
        TaxInfoUpdate(residenceCountry: code),
      );
      notifyTaxInfoChanged();
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.taxInfoSaved,
          properties: {
            'edit': false,
            'scope': 'residence',
            'collection_status': info.collectionStatus?.wire ?? 'legacy',
          },
        ),
      );
      if (isClosed) return;
      emit(
        TaxInfoState(
          load: TaxInfoLoadStatus.ready,
          info: info,
          taxCountry: info.taxCountry ?? info.residenceCountry,
          residenceSaves: state.residenceSaves + 1,
        ),
      );
    } on TaxInfoUnavailableException {
      _failSubmit('dac7-disabled', unavailable: true);
    } on TaxInfoException catch (e) {
      _failSubmit(e.code, field: e.field);
    } catch (_) {
      _failSubmit('unknown');
    }
  }

  /// « Plus tard » : rien n'est enregistré ni refusé, l'écran se ferme.
  void later() {
    if (isClosed) return;
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.taxInfoLater,
        properties: {'source': 'screen'},
      ),
    );
  }

  /// Jamais de donnée saisie : le code d'erreur seul.
  ///
  /// [unavailable] : plus de formulaire à rejouer, la saisie est effacée de
  /// l'état. Réseau et 422 la gardent pour un nouvel essai.
  void _failSubmit(String code, {String? field, bool unavailable = false}) {
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.taxInfoSaveFailed,
        properties: {'error_code': code},
      ),
    );
    if (isClosed) return;
    emit(
      state.copyWith(
        submitting: false,
        errorCode: code,
        errorField: field,
        taxNumber: unavailable ? '' : null,
        vatNumber: unavailable ? '' : null,
        load: unavailable ? TaxInfoLoadStatus.unavailable : null,
      ),
    );
  }

  String _code(Object e) => e is TaxInfoException ? e.code : 'unknown';
}
