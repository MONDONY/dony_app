import 'package:dony/features/activation/bloc/activation_cubit.dart';
import 'package:dony/features/activation/data/models/activation_status.dart';
import 'package:dony/features/auth/presentation/screens/first_steps_screen.dart';
import 'package:dony/features/kyc/presentation/kyc_return_route.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const notDone = ActivationLoaded(
    ActivationStatus(intent: UserIntent.sender, firstActionDone: false),
  );
  const done = ActivationLoaded(ActivationStatus(intent: UserIntent.sender));

  test('vérifié avec next : retour à l\'action', () {
    expect(
      kycExitRoute(
        returnTo: '/trips/publish-intro',
        justVerified: true,
        activation: notDone,
      ),
      '/trips/publish-intro',
    );
  });

  test('vérifié sans next, rien fait : premiers pas', () {
    expect(
      kycExitRoute(returnTo: null, justVerified: true, activation: notDone),
      firstStepsRoute,
    );
  });

  test('vérifié sans next, déjà actif ou statut inconnu : accueil', () {
    expect(
      kycExitRoute(returnTo: null, justVerified: true, activation: done),
      '/home',
    );
    expect(
      kycExitRoute(
        returnTo: null,
        justVerified: true,
        activation: const ActivationUnavailable(),
      ),
      '/home',
    );
  });

  test('pas encore vérifié : accueil', () {
    expect(
      kycExitRoute(returnTo: null, justVerified: false, activation: notDone),
      '/home',
    );
  });
}
