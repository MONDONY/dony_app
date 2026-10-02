import 'package:dony/features/activation/bloc/activation_cubit.dart';
import 'package:dony/features/activation/data/models/activation_status.dart';
import 'package:dony/features/activation/presentation/widgets/first_action_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const showing = ActivationLoaded(
    ActivationStatus(intent: UserIntent.sender, firstActionDone: false),
  );
  const done = ActivationLoaded(ActivationStatus(intent: UserIntent.sender));

  test('retour sur l\'accueil avec la carte affichée : rafraîchir', () {
    expect(shouldRefreshActivationOnHome('/home', showing), isTrue);
  });

  test('ailleurs, carte absente ou statut inconnu : ne rien faire', () {
    expect(shouldRefreshActivationOnHome('/trips/create', showing), isFalse);
    expect(shouldRefreshActivationOnHome('/home', done), isFalse);
    expect(
      shouldRefreshActivationOnHome('/home', const ActivationInitial()),
      isFalse,
    );
    expect(
      shouldRefreshActivationOnHome('/home', const ActivationUnavailable()),
      isFalse,
    );
  });
}
