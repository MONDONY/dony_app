import 'package:dony/features/ai_form_draft/data/ai_form_draft_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// La carte « Créer avec l'IA » s'affiche-t-elle ? Singleton : la dernière
/// réponse de `/assistant/status` sert d'emblée à l'ouverture suivante, puis
/// [refresh] la confirme.
class AiFormDraftAvailabilityCubit extends Cubit<bool> {
  AiFormDraftAvailabilityCubit(this._repository) : super(false);

  final AiFormDraftRepository _repository;

  Future<void> refresh() async {
    final enabled = await _repository.formDraftEnabled();
    if (!isClosed) emit(enabled);
  }
}
