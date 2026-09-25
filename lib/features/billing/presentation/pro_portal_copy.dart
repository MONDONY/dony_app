/// Copie partagée par les deux hôtes du portail PRO : l'écran « Compte PRO »
/// et le bandeau d'abonnement de l'écran Profil.
///
/// Ces deux écrans ouvrent le même portail et rencontrent les mêmes échecs.
/// Dupliquer leurs messages les fait diverger à la première retouche, et la
/// copie non couverte par un test dérive sans que rien ne le signale.
library;

import 'package:dony/l10n/l10n.dart';

/// Échec d'ouverture du navigateur.
///
/// N'accuse pas le réseau : ouvrir un navigateur n'en consomme pas, et
/// l'échec vient d'une URL mal configurée ou de l'absence d'application
/// capable de l'ouvrir. Envoyer l'utilisateur vérifier sa connexion
/// l'enverrait chercher là où rien ne cloche.
String proPortalOpenFailedMessage(AppLocalizations l) =>
    l.proPortalOpenFailedMessage;
