import 'package:dony/core/network/api_client.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/ai_form_draft/bloc/ai_form_draft_availability_cubit.dart';
import 'package:dony/features/ai_form_draft/bloc/ai_form_draft_bloc.dart';
import 'package:dony/features/ai_form_draft/data/ai_form_draft_models.dart';
import 'package:dony/features/ai_form_draft/data/ai_form_draft_repository.dart';
import 'package:dony/features/ai_form_draft/data/speech_service.dart';
import 'package:dony/features/ai_form_draft/presentation/ai_form_draft_launcher.dart';
import 'package:get_it/get_it.dart';

/// Formulaires remplis par l'IA (trajet, demande d'envoi). Appelé par
/// `setupDependencies` (`lib/core/di/injection.dart`).
void registerAiFormDraftDependencies(GetIt getIt) {
  getIt
    ..registerLazySingleton<AiFormDraftRepository>(
      () => AiFormDraftRepository(getIt<ApiClient>()),
    )
    // Singleton : la carte d'entrée garde la dernière réponse de la sonde.
    ..registerLazySingleton<AiFormDraftAvailabilityCubit>(
      () => AiFormDraftAvailabilityCubit(getIt<AiFormDraftRepository>()),
    )
    // Singleton : le plugin speech_to_text n'enregistre ses écouteurs qu'au
    // premier initialize réussi (cf. SttSpeechService).
    ..registerLazySingleton<SpeechService>(SttSpeechService.new)
    // Une instance par feuille : le dialogue est perdu à la fermeture.
    ..registerFactoryParam<AiFormDraftBloc, AiFormDraftSession, void>(
      (session, _) => AiFormDraftBloc(
        getIt<AiFormDraftRepository>(),
        getIt<AnalyticsService>(),
        session: session,
      ),
    )
    ..registerLazySingleton<AiFormDraftLauncher>(AiFormDraftLauncher.new);
}
