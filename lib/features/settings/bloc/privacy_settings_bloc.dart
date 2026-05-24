import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/settings/data/repositories/privacy_settings_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';

part 'privacy_settings_event.dart';
part 'privacy_settings_state.dart';

class PrivacySettingsBloc
    extends Bloc<PrivacySettingsEvent, PrivacySettingsState> {
  final PrivacySettingsRepository _repo;
  final Box _box;

  PrivacySettingsBloc(this._repo, this._box)
      : super(_initialState(_box)) {
    on<PrivacySettingsLoadRequested>(_onLoad);
    on<ContactKycOnlyToggled>(_onToggle);
  }

  /// Lit Hive au démarrage : affichage immédiat sans état de chargement.
  static PrivacySettingsState _initialState(Box box) {
    final cached = box.get(HiveService.kContactKycOnly);
    if (cached is bool) return PrivacySettingsLoaded(contactKycOnly: cached);
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
      final val = await _repo.fetchContactKycOnly();
      await _box.put(HiveService.kContactKycOnly, val);
      emit(PrivacySettingsLoaded(contactKycOnly: val));
    } catch (_) {
      // Si une valeur Hive est déjà affichée, on la conserve sans montrer d'erreur.
      if (state is! PrivacySettingsLoaded) {
        emit(const PrivacySettingsError('Impossible de charger les préférences'));
      }
    }
  }

  Future<void> _onToggle(
    ContactKycOnlyToggled event,
    Emitter<PrivacySettingsState> emit,
  ) async {
    final prev = state is PrivacySettingsLoaded
        ? (state as PrivacySettingsLoaded).contactKycOnly
        : true;
    emit(PrivacySettingsLoaded(contactKycOnly: event.value)); // optimistic
    await _box.put(HiveService.kContactKycOnly, event.value); // persist Hive
    try {
      await _repo.updateContactKycOnly(event.value);
    } catch (_) {
      await _box.put(HiveService.kContactKycOnly, prev); // rollback Hive
      emit(PrivacySettingsLoaded(contactKycOnly: prev));
    }
  }
}
