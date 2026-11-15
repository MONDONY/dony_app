import 'package:dony/features/auth/data/models/user_model.dart';

/// Le fret par bateau est réservé aux professionnels : un compte pro ou un
/// voyageur GP Pro (badge accordé). Miroir de la garde du back (403
/// `boat-carrier-not-verified`), qui reste l'autorité : cette règle évite de
/// proposer au voyageur un parcours qu'il ne pourrait pas finir.
bool canPublishBoat(UserModel user) => user.gpPro || user.isProAccount;
