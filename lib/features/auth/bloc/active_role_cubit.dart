import 'package:dony/core/storage/hive_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum ActiveRole { sender, traveler }

class ActiveRoleCubit extends Cubit<ActiveRole> {
  ActiveRoleCubit({required HiveService hiveService})
      : _hive = hiveService,
        super(_load(hiveService));

  final HiveService _hive;
  static const _key = 'active_role';

  static ActiveRole _load(HiveService hive) {
    final saved = hive.userPrefs.get(_key) as String?;
    if (saved == 'TRAVELER') {
      return ActiveRole.traveler;
    }
    return ActiveRole.sender; // défaut : Expéditeur
  }

  void switchToTraveler() {
    _hive.userPrefs.put(_key, 'TRAVELER');
    emit(ActiveRole.traveler);
  }

  void switchToSender() {
    _hive.userPrefs.put(_key, 'SENDER');
    emit(ActiveRole.sender);
  }

  void reset() {
    _hive.userPrefs.delete(_key);
    emit(ActiveRole.sender); // défaut : Expéditeur
  }

  /// Synchronise l'activeRole avec les rôles réels du compte.
  /// Si l'utilisateur n'a pas le rôle TRAVELER, on force le mode Expéditeur
  /// et on efface le cache Hive pour éviter un état incohérent au prochain démarrage.
  void syncWithRoles(List<String> roles) {
    if (!roles.contains('TRAVELER') && state == ActiveRole.traveler) {
      reset();
    }
  }
}
