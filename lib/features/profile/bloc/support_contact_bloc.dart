import 'package:flutter_bloc/flutter_bloc.dart';

part 'support_contact_event.dart';
part 'support_contact_state.dart';

class SupportContactBloc extends Bloc<SupportContactEvent, SupportContactState> {
  SupportContactBloc() : super(const SupportContactState()) {
    on<SupportCategorySelected>(_onCategorySelected);
    on<SupportSubjectChanged>(_onSubjectChanged);
    on<SupportMessageChanged>(_onMessageChanged);
    on<SupportSubmitRequested>(_onSubmitRequested);
  }

  void _onCategorySelected(SupportCategorySelected event, Emitter<SupportContactState> emit) {
    emit(state.copyWith(category: event.category));
  }

  void _onSubjectChanged(SupportSubjectChanged event, Emitter<SupportContactState> emit) {
    emit(state.copyWith(subject: event.subject));
  }

  void _onMessageChanged(SupportMessageChanged event, Emitter<SupportContactState> emit) {
    emit(state.copyWith(message: event.message));
  }

  void _onSubmitRequested(SupportSubmitRequested event, Emitter<SupportContactState> emit) {
    if (!state.isValid) return;
    emit(state.copyWith(submitStatus: SupportSubmitStatus.submitting));
  }
}
