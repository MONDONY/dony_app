import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/profile/data/profile_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

part 'upgrade_to_pro_event.dart';
part 'upgrade_to_pro_state.dart';

class UpgradeToProBloc extends Bloc<UpgradeToProEvent, UpgradeToProState> {
  final ProfileRepository _repository;

  UpgradeToProBloc(this._repository) : super(UpgradeToProInitial()) {
    on<UpgradeToProSubmitted>(_onSubmitted);
    on<DowngradeRequested>(_onDowngrade);
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
    } on AppException catch (e) {
      final isConflict = e.code == '409';
      emit(
        UpgradeToProError(
          isConflict
              ? 'Un compte Stripe Connect existe déjà. Contactez le support.'
              : 'Une erreur est survenue. Veuillez réessayer.',
        ),
      );
    } catch (e) {
      emit(const UpgradeToProError('Une erreur est survenue. Veuillez réessayer.'));
    }
  }

  Future<void> _onDowngrade(
    DowngradeRequested event,
    Emitter<UpgradeToProState> emit,
  ) async {
    emit(UpgradeToProLoading());
    try {
      await _repository.downgradePro();
      emit(DowngradeSuccess());
    } catch (e) {
      emit(const DowngradeError('Une erreur est survenue. Veuillez réessayer.'));
    }
  }
}
