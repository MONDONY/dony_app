import 'package:dony/core/di/ai_form_draft_injection.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/ai_form_draft/bloc/ai_form_draft_availability_cubit.dart';
import 'package:dony/features/ai_form_draft/bloc/ai_form_draft_bloc.dart';
import 'package:dony/features/ai_form_draft/data/ai_form_draft_models.dart';
import 'package:dony/features/ai_form_draft/data/ai_form_draft_repository.dart';
import 'package:dony/features/ai_form_draft/data/speech_service.dart';
import 'package:dony/features/ai_form_draft/presentation/ai_form_draft_launcher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/mock_analytics_backend.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _NoopResolver implements AiDraftResolver {
  @override
  Future<AiResolvedDraft> resolve(Map<String, Object?> draft) async =>
      AiResolvedDraft(draft: draft);
}

void main() {
  test('chaque dépendance de la feature se résout', () async {
    final getIt = GetIt.asNewInstance();
    getIt
      ..registerSingleton<ApiClient>(_MockApiClient())
      ..registerSingleton<AnalyticsService>(
        makeDisabledAnalytics(MockAnalyticsBackend()),
      );
    registerAiFormDraftDependencies(getIt);

    expect(
      getIt<AiFormDraftRepository>(),
      same(getIt<AiFormDraftRepository>()),
    );
    expect(
      getIt<AiFormDraftAvailabilityCubit>(),
      same(getIt<AiFormDraftAvailabilityCubit>()),
    );
    expect(getIt<SpeechService>(), isA<SttSpeechService>());
    expect(getIt<SpeechService>(), same(getIt<SpeechService>()));
    expect(getIt<AiFormDraftLauncher>(), isA<AiFormDraftLauncher>());
    final session = AiFormDraftSession(
      kind: AiFormKind.trip,
      resolver: _NoopResolver(),
    );
    final first = getIt<AiFormDraftBloc>(param1: session);
    final second = getIt<AiFormDraftBloc>(param1: session);
    expect(first, isNot(same(second)));
    expect(first.state.kind, AiFormKind.trip);
    await first.close();
    await second.close();
  });
}
