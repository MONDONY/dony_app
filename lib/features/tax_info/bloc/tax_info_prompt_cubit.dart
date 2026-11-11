import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/app_log.dart';
import 'package:dony/features/tax_info/bloc/tax_info_session.dart';
import 'package:dony/features/tax_info/bloc/tax_info_state.dart';
import 'package:dony/features/tax_info/data/repositories/tax_info_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Bannière et ligne « Informations fiscales » du Profil.
///
/// Une lecture au chargement du Profil et à la reprise de l'app, jamais en
/// boucle : un appel pendant une lecture est mis en file et coalescé. Fonction
/// absente (404, 403, 401, ancien back) : rien n'est affiché, aucune erreur.
class TaxInfoPromptCubit extends Cubit<TaxInfoPromptState> {
  TaxInfoPromptCubit(
    this._repository,
    this._analytics,
    this._session,
    this._userId,
  ) : super(TaxInfoPromptState(dismissed: _session.isDismissed(_userId)));

  final TaxInfoRepository _repository;
  final AnalyticsService _analytics;
  final TaxInfoSession _session;
  final String _userId;

  bool _loadInFlight = false;
  bool _reloadQueued = false;

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
    try {
      final info = await _repository.fetch();
      if (isClosed) return;
      emit(TaxInfoPromptState(info: info, dismissed: state.dismissed));
    } on TaxInfoUnavailableException {
      if (isClosed) return;
      // Fonction absente : on oublie toute lecture précédente.
      emit(TaxInfoPromptState(dismissed: state.dismissed));
    } catch (e) {
      // Réseau ou serveur : la dernière lecture reste affichée, sans bruit.
      AppLog.warn(
        'tax_info_prompt_failed',
        data: {'code': e is TaxInfoException ? e.code : 'unknown'},
      );
    }
  }

  /// « Plus tard » sur la bannière : masquée pour la session, rien n'est
  /// enregistré ni envoyé au serveur.
  void dismiss() {
    if (isClosed || state.dismissed) return;
    _session.dismiss(_userId);
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.taxInfoLater,
        properties: {'source': 'banner'},
      ),
    );
    emit(TaxInfoPromptState(info: state.info, dismissed: true));
  }

  /// Bannière ou ligne touchée (`banner` / `row`).
  void trackTapped(String variant) {
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.profileTaxInfoTapped,
        properties: {'variant': variant},
      ),
    );
  }
}
