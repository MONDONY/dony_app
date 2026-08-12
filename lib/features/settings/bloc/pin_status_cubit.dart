import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// État du verrouillage par code PIN.
///
/// Le verrouillage est actif **si et seulement si** un PIN est enregistré dans
/// le secure storage : pas de drapeau séparé à tenir synchronisé, donc pas de
/// réglage qui prétend protéger l'app sans PIN derrière (ni l'inverse).
///
/// [configured] est nul le temps de la première lecture, le secure storage
/// étant asynchrone. L'écran affiche alors l'interrupteur éteint, qui est le
/// défaut d'un compte neuf.
class PinStatusState {
  const PinStatusState({this.configured, this.isBusy = false});

  final bool? configured;

  /// Une création ou une suppression de PIN est en cours.
  final bool isBusy;

  PinStatusState copyWith({bool? configured, bool? isBusy}) => PinStatusState(
        configured: configured ?? this.configured,
        isBusy: isBusy ?? this.isBusy,
      );

  @override
  bool operator ==(Object other) =>
      other is PinStatusState &&
      other.configured == configured &&
      other.isBusy == isBusy;

  @override
  int get hashCode => Object.hash(configured, isBusy);
}

class PinStatusCubit extends Cubit<PinStatusState> {
  PinStatusCubit(this._service) : super(const PinStatusState());

  final LocalAuthService _service;

  Future<void> refresh() async {
    final configured = await _service.isPinSet();
    if (!isClosed) {
      emit(PinStatusState(configured: configured));
    }
  }

  /// Retire le PIN : l'app s'ouvrira sans rien demander.
  Future<void> disable() async {
    if (!isClosed) {
      emit(state.copyWith(isBusy: true));
    }
    await _service.clearPin();
    if (!isClosed) {
      emit(const PinStatusState(configured: false));
    }
  }
}
