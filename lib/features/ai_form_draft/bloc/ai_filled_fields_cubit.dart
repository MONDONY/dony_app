import 'package:flutter_bloc/flutter_bloc.dart';

/// Clés du brouillon remplies par l'IA dans le formulaire ouvert : la marque
/// « IA » de chaque champ et le bandeau « Rempli par l'IA » les lisent.
/// Une instance par écran de publication.
class AiFilledFieldsCubit extends Cubit<Set<String>> {
  AiFilledFieldsCubit() : super(const {});

  void markFilled(Set<String> fields) => emit(Set.unmodifiable(fields));

  void clear() => emit(const {});

  /// Propriété `from_ai` des événements de publication.
  bool get isFromAi => state.isNotEmpty;
}
