import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/features/stripe_account/data/stripe_account_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'stripe_account_event.dart';
part 'stripe_account_state.dart';

class StripeAccountBloc extends Bloc<StripeAccountEvent, StripeAccountState> {
  final IStripeAccountRepository _repository;

  StripeAccountBloc(this._repository) : super(const StripeAccountInitial()) {
    on<StripeAccountStatusLoaded>(_onLoad);
    on<StripeAccountStatusRefreshed>(_onRefresh);
    on<StripeAccountReset>(_onReset);
  }

  Future<void> _onLoad(
    StripeAccountStatusLoaded event,
    Emitter<StripeAccountState> emit,
  ) async {
    emit(const StripeAccountLoading());
    await _fetch(emit);
  }

  /// Resynchronise depuis Stripe, puis retombe sur la lecture simple.
  ///
  /// Les appelants de cet event (retour d'onboarding, reprise de
  /// l'application) veulent savoir si le compte est devenu utilisable — une
  /// relecture du statut stocké ne l'apprend que si un webhook
  /// `account.updated` est bien arrivé entre-temps. Un webhook manqué laissait
  /// donc l'utilisateur bloqué sur un statut périmé, sans aucun moyen de s'en
  /// sortir depuis l'application.
  ///
  /// Le repli sur [_fetch] couvre les échecs attendus : pas encore de compte
  /// Stripe (409), réseau coupé, Stripe indisponible. Sans lui, un simple
  /// retour au premier plan sans compte Connect afficherait une erreur.
  Future<void> _onRefresh(
    StripeAccountStatusRefreshed event,
    Emitter<StripeAccountState> emit,
  ) async {
    try {
      emit(StripeAccountReady(await _repository.refreshAccountStatus()));
      return;
    } catch (_) {
      // Volontairement silencieux : le repli ci-dessous décide de l'état final.
    }
    await _fetch(emit);
  }

  Future<void> _fetch(Emitter<StripeAccountState> emit) async {
    try {
      final status = await _repository.getAccountStatus();
      emit(StripeAccountReady(status));
    } catch (_) {
      emit(const StripeAccountLoadError());
    }
  }

  /// Voir `StripeAccountReset` : purge des données de compte, pas un simple
  /// rechargement — aucun appel réseau ici, juste l'état initial.
  void _onReset(StripeAccountReset event, Emitter<StripeAccountState> emit) {
    emit(const StripeAccountInitial());
  }
}
