import 'package:dony/core/di/injection.dart';
import 'package:dony/features/ai_form_draft/bloc/ai_form_draft_availability_cubit.dart';
import 'package:dony/features/ai_form_draft/data/ai_form_draft_models.dart';
import 'package:dony/features/ai_form_draft/data/ai_form_draft_repository.dart';
import 'package:dony/features/ai_form_draft/data/speech_service.dart';
import 'package:dony/features/ai_form_draft/presentation/ai_form_draft_launcher.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dictée simulée : [emit] et [finish] jouent le rôle du plugin.
class FakeSpeechService implements SpeechService {
  FakeSpeechService({this.available = true});

  bool available;
  int startCount = 0;
  int stopCount = 0;
  int cancelCount = 0;
  String? lastLocaleId;
  SpeechResultCallback? _onResult;
  void Function()? _onDone;

  @override
  Future<bool> initialize() async => available;

  @override
  Future<void> start({
    required String localeId,
    required SpeechResultCallback onResult,
    required void Function() onDone,
  }) async {
    startCount++;
    lastLocaleId = localeId;
    _onResult = onResult;
    _onDone = onDone;
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
    _onDone = null;
  }

  void emit(String text, {bool isFinal = false}) =>
      _onResult?.call(text, isFinal: isFinal);

  void finish() => _onDone?.call();
}

/// Sonde de disponibilité réglable ; un tour de dialogue échoue toujours.
class FakeAiFormDraftRepository implements AiFormDraftRepository {
  FakeAiFormDraftRepository({this.enabled = false});

  bool enabled;

  @override
  Future<bool> formDraftEnabled() async => enabled;

  @override
  Future<AiFormDraftReply> send({
    required AiFormKind kind,
    required List<AiChatMessage> messages,
    required Map<String, Object?> draft,
    required String locale,
    required DateTime now,
    String? defaultCurrency,
  }) async => throw const AiFormDraftNetworkException();
}

/// Enregistre une disponibilité « éteinte » pour les écrans de publication.
/// Sans effet si elle l'est déjà.
void registerUnavailableAiFormDraft() {
  if (!getIt.isRegistered<AiFormDraftAvailabilityCubit>()) {
    getIt.registerSingleton<AiFormDraftAvailabilityCubit>(
      AiFormDraftAvailabilityCubit(FakeAiFormDraftRepository()),
    );
  }
}

/// Lanceur qui ne monte pas la feuille : rend [outcome] tout de suite.
class FakeAiFormDraftLauncher implements AiFormDraftLauncher {
  FakeAiFormDraftLauncher(this.outcome);

  AiResolvedDraft? outcome;
  final calls = <({AiFormKind kind, String? defaultCurrency})>[];

  @override
  Future<AiResolvedDraft?> open(
    BuildContext context, {
    required AiFormKind kind,
    required String? defaultCurrency,
    bool Function()? isCardReady,
  }) async {
    calls.add((kind: kind, defaultCurrency: defaultCurrency));
    return outcome;
  }
}

/// Allume (ou éteint) « Créer avec l'IA » pour un test d'écran et remplace le
/// lanceur ; tout est rétabli à la fin du test.
FakeAiFormDraftLauncher useAiFormDraft({
  required bool enabled,
  AiResolvedDraft? outcome,
}) {
  if (getIt.isRegistered<AiFormDraftAvailabilityCubit>()) {
    getIt.unregister<AiFormDraftAvailabilityCubit>();
  }
  getIt.registerSingleton<AiFormDraftAvailabilityCubit>(
    AiFormDraftAvailabilityCubit(FakeAiFormDraftRepository(enabled: enabled)),
  );
  if (getIt.isRegistered<AiFormDraftLauncher>()) {
    getIt.unregister<AiFormDraftLauncher>();
  }
  final launcher = FakeAiFormDraftLauncher(outcome);
  getIt.registerSingleton<AiFormDraftLauncher>(launcher);
  addTearDown(() {
    getIt.unregister<AiFormDraftLauncher>();
    getIt.unregister<AiFormDraftAvailabilityCubit>();
    registerUnavailableAiFormDraft();
  });
  return launcher;
}
