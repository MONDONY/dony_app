/// Copie partagée par les deux hôtes du portail PRO : l'écran « Compte PRO »
/// et le bandeau d'abonnement de l'écran Profil.
///
/// Ces deux écrans ouvrent le même portail et rencontrent les mêmes échecs.
/// Dupliquer leurs messages les fait diverger à la première retouche, et la
/// copie non couverte par un test dérive sans que rien ne le signale.
library;

/// Échec d'ouverture du navigateur.
///
/// N'accuse pas le réseau : ouvrir un navigateur n'en consomme pas, et
/// l'échec vient d'une URL mal configurée ou de l'absence d'application
/// capable de l'ouvrir. Envoyer l'utilisateur vérifier sa connexion
/// l'enverrait chercher là où rien ne cloche.
const String kProPortalOpenFailedMessage =
    "Impossible d'ouvrir la page. Réessayez, ou rendez-vous sur le site "
    'Yadony PRO depuis votre navigateur.';
