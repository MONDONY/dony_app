// Blocs de la réponse directe aux demandes de l'écran du trajet
// (`TripBidAnswerScope`), que l'écran du propriétaire crée par getIt : des
// doubles inertes pour les tests d'écran qui ne répondent à aucune demande.
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_bloc.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_event.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _InertBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _InertAcceptanceBloc
    extends MockBloc<BidAcceptanceEvent, BidAcceptanceState>
    implements BidAcceptanceBloc {}

/// Enregistre dans getIt un `BidBloc` et un `BidAcceptanceBloc` inertes
/// (jamais d'état après le premier), retirés à la fin du test.
void registerInertTripAnswerBlocs() {
  unregisterTripAnswerBlocs();
  getIt
    ..registerFactory<BidBloc>(() {
      final bloc = _InertBidBloc();
      whenListen(
        bloc,
        const Stream<BidState>.empty(),
        initialState: BidInitial(),
      );
      return bloc;
    })
    ..registerFactory<BidAcceptanceBloc>(() {
      final bloc = _InertAcceptanceBloc();
      whenListen(
        bloc,
        const Stream<BidAcceptanceState>.empty(),
        initialState: BidAcceptanceInitial(),
      );
      return bloc;
    });
  addTearDown(unregisterTripAnswerBlocs);
}

/// Retire de getIt le `BidBloc` et le `BidAcceptanceBloc` de la réponse.
void unregisterTripAnswerBlocs() {
  if (getIt.isRegistered<BidBloc>()) getIt.unregister<BidBloc>();
  if (getIt.isRegistered<BidAcceptanceBloc>()) {
    getIt.unregister<BidAcceptanceBloc>();
  }
}
