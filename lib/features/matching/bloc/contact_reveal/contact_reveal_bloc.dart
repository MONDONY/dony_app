import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_event.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_state.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Récupère le numéro de la contrepartie au moment où l'utilisateur veut appeler.
///
/// Le numéro ne fait plus partie des réponses de colis : il vit dans Firebase et le
/// serveur ne le communique que sur cette demande explicite, qu'il journalise. Ce
/// BLoC porte l'état de chargement pour que le bouton d'appel puisse l'afficher.
class ContactRevealBloc extends Bloc<ContactRevealEvent, ContactRevealState> {
  final BidRepository _repository;

  ContactRevealBloc(this._repository) : super(const ContactRevealInitial()) {
    on<ContactRevealRequested>(_onRequested);
  }

  Future<void> _onRequested(
    ContactRevealRequested event,
    Emitter<ContactRevealState> emit,
  ) async {
    if (state is ContactRevealLoading) return;
    emit(const ContactRevealLoading());
    try {
      emit(ContactRevealSuccess(
        await _repository.getCounterpartyPhone(event.bidId),
      ));
    } catch (e) {
      emit(ContactRevealError(unwrapDioError(e)));
    }
  }
}
