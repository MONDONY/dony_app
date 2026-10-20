import 'package:dony/features/payments/bloc/mobile_money_account_state.dart';

/// Le voyageur a-t-il au moins un compte de versement mobile money ?
/// `Initial`, `Loading` ou `Error` sans liste connue valent « non actif ».
///
/// Fonction pure partagée par `create_trip_screen.dart` (formulaire de
/// création/édition), `trip_template_edit_screen.dart` (écran modèle) et
/// l'assistant de demande d'envoi : vit ici, à côté du bloc qu'elle
/// interprète, plutôt que dans l'un des écrans.
bool mobileMoneyAccountActiveFrom(MobileMoneyAccountState state) =>
    state.data?.accounts.isNotEmpty ?? false;

/// Devises (code ISO, ex. `XOF`) reçues par les comptes de versement. Vide
/// sans compte connu. Un trajet peut accepter le mobile money quand sa
/// devise appartient à cet ensemble ; sert aussi à expliquer pourquoi un
/// trajet dans une autre devise ne le peut pas.
Set<String> mobileMoneyAccountCurrenciesFrom(MobileMoneyAccountState state) => {
  for (final account in state.data?.accounts ?? const [])
    if (account.currency.isNotEmpty) account.currency,
};
