import 'package:dony/features/payments/bloc/mobile_money_account_state.dart';
import 'package:dony/features/payments/data/models/mobile_money_account.dart';

/// Dérive si le compte de versement mobile money du voyageur est actif à
/// partir de l'état de `MobileMoneyAccountBloc`.
///
/// `Initial`, `Loading` ou `Error` sans compte connu valent « non actif » —
/// seul un état portant un compte dont `isActive` est vrai (`Loaded`,
/// `Updating`, ou `Error` avec le dernier compte connu conservé) l'active.
///
/// Fonction pure partagée par `create_trip_screen.dart` (formulaire de
/// création/édition) et `trip_template_edit_screen.dart` (écran modèle) :
/// vit ici, à côté du bloc qu'elle interprète, plutôt que dans l'un des deux
/// écrans — un écran ne doit pas importer un autre écran pour une fonction
/// pure sans dépendance sur son état.
bool mobileMoneyAccountActiveFrom(MobileMoneyAccountState state) =>
    _accountFrom(state)?.isActive ?? false;

/// Devise reçue par le compte de versement mobile money actif (code ISO de
/// l'opérateur, ex. `XOF`), `null` si aucun compte actif n'est connu. Sert à
/// expliquer pourquoi un trajet dans une autre devise ne peut pas l'accepter.
String? mobileMoneyAccountCurrencyFrom(MobileMoneyAccountState state) {
  final account = _accountFrom(state);
  return account != null && account.isActive ? account.currency : null;
}

MobileMoneyAccount? _accountFrom(MobileMoneyAccountState state) =>
    switch (state) {
      MobileMoneyAccountLoaded() => state.account,
      MobileMoneyAccountUpdating() => state.account,
      MobileMoneyAccountError() => state.account,
      MobileMoneyAccountPhoneRequired() => state.account,
      MobileMoneyAccountProvidersLoading() => state.account,
      MobileMoneyAccountProvidersLoaded() => state.account,
      MobileMoneyAccountProvidersError() => state.account,
      MobileMoneyAccountProvidersUnavailable() => state.account,
      _ => null,
    };
