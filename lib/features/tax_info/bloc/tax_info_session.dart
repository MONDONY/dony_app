/// Mémoire de session de la bannière « Informations fiscales » : « Plus tard »
/// la masque jusqu'à la fermeture de l'app, sans rien écrire sur le disque ni
/// sur le serveur (la demande reste ouverte, rien n'est refusé).
///
/// Une entrée par compte : un autre compte connecté sur le même appareil revoit
/// la bannière.
class TaxInfoSession {
  final Set<String> _dismissed = {};

  bool isDismissed(String userId) => _dismissed.contains(userId);

  void dismiss(String userId) => _dismissed.add(userId);
}
