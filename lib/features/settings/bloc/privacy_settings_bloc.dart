import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/settings/data/models/privacy_settings_model.dart';
import 'package:dony/features/settings/data/repositories/privacy_settings_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';

part 'privacy_settings_event.dart';
part 'privacy_settings_state.dart';

class PrivacySettingsBloc
    extends Bloc<PrivacySettingsEvent, PrivacySettingsState> {
  final PrivacySettingsRepository _repo;
  final Box _box;
  final AnalyticsService? _analytics;

  PrivacySettingsBloc(this._repo, this._box, [this._analytics])
    : super(_initialState(_box)) {
    on<PrivacySettingsLoadRequested>(_onLoad);
    on<ContactKycOnlyToggled>(_onToggleKycOnly);
    on<HidePhoneNumberToggled>(_onToggleHidePhone);
  }

  /// Lit Hive au démarrage : affichage immédiat sans état de chargement.
  static PrivacySettingsState _initialState(Box box) {
    final cached = box.get(HiveService.kContactKycOnly);
    if (cached is bool) {
      return PrivacySettingsLoaded(
        contactKycOnly: cached,
        hidePhoneNumber:
            box.get(HiveService.kHidePhoneNumber, defaultValue: false) as bool,
      );
    }
    return const PrivacySettingsInitial();
  }

  Future<void> _onLoad(
    PrivacySettingsLoadRequested event,
    Emitter<PrivacySettingsState> emit,
  ) async {
    // N'affiche Loading que si aucune valeur Hive n'est disponible.
    if (state is PrivacySettingsInitial) {
      emit(const PrivacySettingsLoading());
    }
    try {
      final settings = await _repo.fetch();
      await _box.put(HiveService.kContactKycOnly, settings.contactKycOnly);
      await _box.put(HiveService.kHidePhoneNumber, settings.hidePhoneNumber);
      emit(
        PrivacySettingsLoaded(
          contactKycOnly: settings.contactKycOnly,
          hidePhoneNumber: settings.hidePhoneNumber,
        ),
      );
    } catch (_) {
      // Si une valeur Hive est déjà affichée, on la conserve sans montrer d'erreur.
      if (state is! PrivacySettingsLoaded) {
        emit(
          const PrivacySettingsError('Impossible de charger les préférences'),
        );
      }
    }
  }

  Future<void> _onToggleKycOnly(
    ContactKycOnlyToggled event,
    Emitter<PrivacySettingsState> emit,
  ) => _push(emit, (current) => current.copyWith(contactKycOnly: event.value));

  Future<void> _onToggleHidePhone(
    HidePhoneNumberToggled event,
    Emitter<PrivacySettingsState> emit,
  ) async {
    final applied = await _push(
      emit,
      (current) => current.copyWith(hidePhoneNumber: event.value),
    );
    // Tracké seulement si le serveur a confirmé : un rollback ne doit pas
    // compter comme un choix de l'utilisateur. Aucune PII, juste le booléen.
    if (applied) {
      unawaited(
        _analytics?.logEvent(
          AnalyticsEvents.phoneVisibilityToggled,
          properties: {'hidden': event.value},
        ),
      );
    }
  }

  /// Applique un changement de préférence en optimiste : l'UI et Hive bougent
  /// d'abord, le serveur ensuite. Si l'appel échoue, les deux reviennent à leur
  /// valeur précédente — l'utilisateur voit son toggle repartir en arrière plutôt
  /// que de croire à un réglage enregistré qui ne l'est pas.
  ///
  /// Retourne true si le serveur a confirmé.
  Future<bool> _push(
    Emitter<PrivacySettingsState> emit,
    PrivacySettingsLoaded Function(PrivacySettingsLoaded current) next,
  ) async {
    // Défaut aligné sur le backend si l'état n'est pas encore chargé — de toute
    // façon les toggles ne sont tapables qu'une fois l'écran rendu.
    final previous = state is PrivacySettingsLoaded
        ? (state as PrivacySettingsLoaded).copyWith(saveFailed: false)
        : const PrivacySettingsLoaded(contactKycOnly: true);
    final updated = next(previous);

    emit(updated);
    await _write(updated);
    try {
      await _repo.update(
        PrivacySettingsModel(
          contactKycOnly: updated.contactKycOnly,
          hidePhoneNumber: updated.hidePhoneNumber,
        ),
      );
      return true;
    } catch (_) {
      await _write(previous);
      // saveFailed distingue ce retour en arrière d'un simple « rien n'a
      // changé » : l'écran s'en sert pour prévenir que l'enregistrement a
      // échoué, sinon l'utilisateur croit que le réglage refuse de bouger.
      emit(previous.copyWith(saveFailed: true));
      return false;
    }
  }

  Future<void> _write(PrivacySettingsLoaded s) async {
    await _box.put(HiveService.kContactKycOnly, s.contactKycOnly);
    await _box.put(HiveService.kHidePhoneNumber, s.hidePhoneNumber);
  }
}
