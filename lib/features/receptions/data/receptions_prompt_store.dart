import 'package:dony/core/storage/hive_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Colis dont le bandeau « Un colis vous attend » a été fermé sur cet
/// appareil : il ne revient pas pour eux. Un stockage illisible (boîte
/// fermée, test sans Hive) vaut « rien de fermé » et n'est jamais bloquant.
class ReceptionsPromptStore {
  ReceptionsPromptStore(this._box);

  final Box<dynamic> Function() _box;

  Set<String> dismissed() {
    try {
      final raw = _box().get(HiveService.kReceptionsPromptDismissed);
      if (raw is! List) return const {};
      return raw.whereType<String>().toSet();
    } catch (_) {
      return const {};
    }
  }

  Future<void> dismiss(Iterable<String> bidIds) async {
    try {
      final next = {...dismissed(), ...bidIds};
      await _box().put(HiveService.kReceptionsPromptDismissed, next.toList());
    } catch (_) {
      // Préférence de confort : un échec d'écriture fera seulement revenir
      // le bandeau à la prochaine ouverture.
    }
  }
}
