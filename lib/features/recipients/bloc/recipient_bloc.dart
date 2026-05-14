import 'package:dony/features/recipients/data/models/recipient.dart';
import 'package:dony/features/recipients/data/repositories/recipient_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'recipient_event.dart';
part 'recipient_state.dart';

class RecipientBloc extends Bloc<RecipientEvent, RecipientState> {
  final RecipientRepository _repository;

  RecipientBloc(this._repository) : super(const RecipientState()) {
    on<RecipientLoaded>(_onLoaded);
    on<RecipientCreated>(_onCreated);
    on<RecipientUpdated>(_onUpdated);
    on<RecipientDeleted>(_onDeleted);
  }

  Future<void> _onLoaded(
    RecipientLoaded event,
    Emitter<RecipientState> emit,
  ) async {
    emit(state.copyWith(status: RecipientStatus.loading));
    try {
      final recipients = await _repository.getAll();
      emit(state.copyWith(
        status: RecipientStatus.success,
        recipients: recipients,
        error: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: RecipientStatus.error,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onCreated(
    RecipientCreated event,
    Emitter<RecipientState> emit,
  ) async {
    emit(state.copyWith(status: RecipientStatus.loading));
    try {
      final created = await _repository.create({
        'fullName': event.fullName,
        if (event.relationship != null) 'relationship': event.relationship,
        'phoneE164': event.phoneE164,
        if (event.whatsappE164 != null) 'whatsappE164': event.whatsappE164,
        if (event.street != null) 'street': event.street,
        'city': event.city,
        'country': event.country,
        if (event.notes != null) 'notes': event.notes,
      });
      final updatedList = [...state.recipients, created];
      emit(state.copyWith(
        status: RecipientStatus.success,
        recipients: updatedList,
        error: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: RecipientStatus.error,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onUpdated(
    RecipientUpdated event,
    Emitter<RecipientState> emit,
  ) async {
    emit(state.copyWith(status: RecipientStatus.loading));
    try {
      final updated = await _repository.update(event.id, {
        'fullName': event.fullName,
        if (event.relationship != null) 'relationship': event.relationship,
        'phoneE164': event.phoneE164,
        if (event.whatsappE164 != null) 'whatsappE164': event.whatsappE164,
        if (event.street != null) 'street': event.street,
        'city': event.city,
        'country': event.country,
        if (event.notes != null) 'notes': event.notes,
      });
      final updatedList = state.recipients
          .map((r) => r.id == event.id ? updated : r)
          .toList();
      emit(state.copyWith(
        status: RecipientStatus.success,
        recipients: updatedList,
        error: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: RecipientStatus.error,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onDeleted(
    RecipientDeleted event,
    Emitter<RecipientState> emit,
  ) async {
    try {
      await _repository.delete(event.id);
      final updatedList =
          state.recipients.where((r) => r.id != event.id).toList();
      emit(state.copyWith(
        status: RecipientStatus.success,
        recipients: updatedList,
        error: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: RecipientStatus.error,
        error: e.toString(),
      ));
    }
  }
}
