import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/recipients/data/models/recipient.dart';
import 'package:dony/features/recipients/data/repositories/recipient_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'recipient_event.dart';
part 'recipient_state.dart';

class RecipientBloc extends Bloc<RecipientEvent, RecipientState> {
  final RecipientRepository _repository;
  final AnalyticsService _analytics;

  RecipientBloc(this._repository, this._analytics)
      : super(const RecipientState()) {
    on<RecipientLoaded>(_onLoaded);
    on<RecipientCreated>(_onCreated);
    on<RecipientUpdated>(_onUpdated);
    on<RecipientDeleted>(_onDeleted);
    on<RecipientDefaultSet>(_onDefaultSet);
    on<RecipientPicked>(_onPicked);
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
        if (event.city != null) 'city': event.city,
        'country': event.country,
        if (event.notes != null) 'notes': event.notes,
        'isDefault': event.isDefault,
      });
      final updatedList = [
        ...state.recipients.map(
          (r) => created.isDefault ? r.copyWith(isDefault: false) : r,
        ),
        created,
      ];
      emit(state.copyWith(
        status: RecipientStatus.success,
        recipients: updatedList,
        error: null,
      ));
      unawaited(_analytics.logEvent(AnalyticsEvents.recipientCreated));
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
        if (event.city != null) 'city': event.city,
        'country': event.country,
        if (event.notes != null) 'notes': event.notes,
        'isDefault': event.isDefault,
      });
      final updatedList = state.recipients.map((r) {
        if (r.id == event.id) {
          return updated;
        }
        return updated.isDefault ? r.copyWith(isDefault: false) : r;
      }).toList();
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

  Future<void> _onDefaultSet(
    RecipientDefaultSet event,
    Emitter<RecipientState> emit,
  ) async {
    final target =
        state.recipients.where((r) => r.id == event.id).firstOrNull;
    if (target == null) {
      return;
    }
    try {
      final updated = await _repository.update(event.id, {
        'fullName': target.fullName,
        if (target.relationship != null) 'relationship': target.relationship,
        'phoneE164': target.phoneE164,
        if (target.whatsappE164 != null) 'whatsappE164': target.whatsappE164,
        if (target.street != null) 'street': target.street,
        if (target.city != null) 'city': target.city,
        'country': target.country,
        if (target.notes != null) 'notes': target.notes,
        'isDefault': true,
      });
      emit(state.copyWith(
        status: RecipientStatus.success,
        recipients: state.recipients
            .map((r) => r.id == event.id ? updated : r.copyWith(isDefault: false))
            .toList(),
        error: null,
      ));
      unawaited(_analytics.logEvent(AnalyticsEvents.recipientDefaultSet));
    } catch (e) {
      emit(state.copyWith(status: RecipientStatus.error, error: e.toString()));
    }
  }

  void _onPicked(RecipientPicked event, Emitter<RecipientState> emit) {
    unawaited(_analytics.logEvent(
      AnalyticsEvents.recipientSelected,
      properties: {'source': event.source},
    ));
  }
}
