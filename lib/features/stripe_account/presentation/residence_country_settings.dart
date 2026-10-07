import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Ouvre le réglage du pays de résidence (Réglages › Préférences), qui seul
/// décide si Stripe permet d'encaisser par carte : le pays où se trouve le
/// voyageur n'entre pas en compte (FLUTTER-EE).
///
/// Le statut Connect dépend de ce pays côté serveur : au retour, on le
/// redemande pour que les écrans reflètent le nouveau pays sans attendre un
/// redémarrage.
Future<void> openResidenceCountrySettings(BuildContext context) {
  final stripeBloc = context.read<StripeAccountBloc>();
  return context.push<void>('/settings/preferences').whenComplete(() {
    if (!stripeBloc.isClosed) {
      stripeBloc.add(const StripeAccountStatusRefreshed());
    }
  });
}
