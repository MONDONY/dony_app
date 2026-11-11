import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/app_log.dart';
import 'package:dony/features/tax_info/bloc/tax_info_signal.dart';
import 'package:dony/features/tax_info/bloc/tax_info_state.dart';
import 'package:dony/features/tax_info/data/models/tax_info.dart';
import 'package:dony/features/tax_info/data/repositories/tax_info_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Écran « Informations fiscales » (`/profile/tax-info`) : lecture, saisie et
/// enregistrement du numéro fiscal. Jamais bloquant : rien dans l'app ne dépend
/// de cet écran.
///
/// Le numéro et la TVA saisis ne partent que dans le `PUT`. Ni les journaux ni
/// l'analytique n'en reçoivent la valeur ou la longueur : seulement des codes.
class TaxInfoCubit extends Cubit<TaxInfoState> {
  TaxInfoCubit(this._repository, this._analytics) : super(const TaxInfoState());

  final TaxInfoRepository _repository;
  final AnalyticsService _analytics;

  bool _loadInFlight = false;
  bool _reloadQueued = false;
  bool _openedLogged = false;

  /// Une lecture à la fois ; un appel pendant une lecture est mis en file (un
  /// seul rejeu, quel que soit le nombre de demandes).
  Future<void> load() async {
    if (isClosed) return;
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
      // Ni fourni ni demandé : rien à montrer (ex. lien d'une ancienne
      // notification pour un voyageur qui n'est plus concerné).
      final concerned =
          info.provided || info.solicitation == TaxInfoSolicitation.solliciter;
      emit(
        state.copyWith(
          load: concerned
              ? TaxInfoLoadStatus.ready
              : TaxInfoLoadStatus.unavailable,
          info: info,
          // Pays d'émission proposé d'après la résidence, modifiable.
          taxCountry:
              state.taxCountry ?? info.taxCountry ?? info.residenceCountry,
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

  /// Saisie du formulaire. Modifier le numéro efface l'erreur « numéro refusé »
  /// du serveur : elle portait sur la valeur précédente.
  void updateForm({String? taxNumber, String? vatNumber, String? taxCountry}) {
    if (isClosed || state.submitting) return;
    emit(
      state.copyWith(
        taxNumber: taxNumber,
        vatNumber: vatNumber,
        taxCountry: taxCountry,
        // Effacée dès que le champ désigné par le serveur change : l'erreur
        // portait sur la valeur précédente.
        clearError:
            (taxNumber != null && state.serverRejectedTaxNumber) ||
            (vatNumber != null && state.serverRejectedVat),
      ),
    );
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
    final edit = state.info?.provided ?? false;
    final country = state.taxCountry!;
    emit(state.copyWith(submitting: true, clearError: true));
    try {
      final info = await _repository.save(
        taxIdentificationNumber: state.taxNumber,
        taxCountry: country,
        vatNumber: state.vatNumber,
      );
      notifyTaxInfoChanged();
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.taxInfoSaved,
          properties: {'edit': edit},
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
