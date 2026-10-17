import 'package:dony/core/di/injection.dart';
import 'package:dony/core/storage/form_draft_cubit.dart';
import 'package:dony/core/storage/form_draft_store.dart';

import 'ai_form_draft_test_doubles.dart';
import 'mock_analytics_backend.dart';

/// Trousseau en mémoire pour les brouillons locaux. [failWrites] simule un
/// trousseau qui refuse l'écriture.
class InMemoryFormDraftStorage implements FormDraftStorage {
  final Map<String, String> values = {};
  bool failWrites = false;
  bool failReads = false;

  @override
  Future<String?> read(String key) async {
    if (failReads) throw StateError('keychain unavailable');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('keychain unavailable');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

/// Magasin de brouillons du compte [uid], sur un trousseau en mémoire.
FormDraftStore testFormDraftStore({
  InMemoryFormDraftStorage? storage,
  String? uid = 'uid-test',
  DateTime Function()? clock,
}) => FormDraftStore(
  storage: storage ?? InMemoryFormDraftStorage(),
  currentUid: () => uid,
  clock: clock,
);

/// Enregistre `FormDraftCubit` dans GetIt (formulaires de publication), sur
/// [store] ou un trousseau en mémoire. Sans effet s'il l'est déjà. Rend le
/// magasin utilisé, pour lire ou préparer les brouillons du test.
FormDraftStore registerTestFormDraftCubit({FormDraftStore? store}) {
  // Les écrans de publication lisent la disponibilité de « Créer avec l'IA »
  // en création : éteinte par défaut dans les tests.
  registerUnavailableAiFormDraft();
  final effective = store ?? testFormDraftStore();
  if (!getIt.isRegistered<FormDraftCubit>()) {
    getIt.registerFactoryParam<FormDraftCubit, FormDraftKind, void>(
      (kind, _) => FormDraftCubit(
        effective,
        makeDisabledAnalytics(MockAnalyticsBackend()),
        kind,
      ),
    );
  }
  return effective;
}
