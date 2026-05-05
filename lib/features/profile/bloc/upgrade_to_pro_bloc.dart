import 'package:dony/features/profile/data/profile_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

part 'upgrade_to_pro_event.dart';
part 'upgrade_to_pro_state.dart';

class UpgradeToProBloc extends Bloc<UpgradeToProEvent, UpgradeToProState> {
  final ProfileRepository _repository;

  UpgradeToProBloc(this._repository) : super(UpgradeToProInitial()) {
    on<UpgradeToProSubmitted>(_onSubmitted);
  }

  Future<void> _onSubmitted(
    UpgradeToProSubmitted event,
    Emitter<UpgradeToProState> emit,
  ) async {
    emit(UpgradeToProLoading());
    try {
      await _repository.upgradeToPro(
        companyName: event.companyName,
        siret: event.siret,
      );
      emit(UpgradeToProSuccess());
    } catch (e) {
      final msg = e.toString();
      final isConflict =
          msg.contains('409') || msg.toLowerCase().contains('already');
      emit(
        UpgradeToProError(
          isConflict
              ? 'Un compte Stripe Connect existe déjà. Contactez le support.'
              : 'Une erreur est survenue. Veuillez réessayer.',
        ),
      );
    }
  }
}
