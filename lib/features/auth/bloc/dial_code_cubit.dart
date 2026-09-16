import 'package:dony/core/phone/phone_country.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Porte l'indicatif choisi dans le sélecteur de l'écran de connexion.
///
/// Il vit hors de `AuthBloc` volontairement. L'indicatif était auparavant un
/// champ de `AuthInitial`, or cet état est réémis nu à chaque échec d'envoi,
/// erreur du serveur, déconnexion ou changement de compte : le pays choisi
/// retombait alors sur la France sans que l'utilisateur touche à rien, et le
/// code partait vers le mauvais destinataire s'il resoumettait.
///
/// Choisir un pays n'est pas un fait d'authentification, c'est une préférence
/// de saisie. Elle mérite son propre cycle de vie.
class DialCodeCubit extends Cubit<PhoneCountry> {
  DialCodeCubit() : super(kDefaultPhoneCountry);

  void select(PhoneCountry country) => emit(country);
}
