import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';

/// Statut du compte Stripe Connect : celui du bloc fait foi quand il est
/// chargé ; sinon celui porté par le profil. `StripeAccountBloc` n'est chargé
/// que par `MainShell.initState` : sans ce repli, un écran affiché avant (ou
/// hors du shell) croirait le compte jamais créé.
///
/// Partagé pour que toutes les surfaces du profil tranchent de la même façon :
/// deux règles divergentes afficheraient « paiements à faire » sur un compte
/// déjà actif.
String effectiveStripeStatus(UserModel? user, StripeAccountState stripe) =>
    switch (stripe) {
      StripeAccountReady(:final accountStatus) => accountStatus.status,
      _ => user?.stripeAccountStatus ?? 'NOT_CREATED',
    };
