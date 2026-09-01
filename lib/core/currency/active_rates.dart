import 'package:dony/core/currency/supported_currency.dart';

/// Taux de change courants servis par le backend (`GET /config/exchange-rates`),
/// chargés une fois au démarrage — pattern `/config/reimbursement-cap`.
///
/// Ferme la triplication des taux : le catalogue Dart embarque une copie de
/// `unitsPerEur` figée à la compilation, alors que le serveur pilote les siens
/// (back-office + synchronisation BCE quotidienne). Sans cette source, les
/// bornes de saisie et de filtre du client divergent de ce que l'API accepte
/// dès qu'un taux bouge.
///
/// Les constantes du catalogue restent le REPLI (hors ligne, premier
/// lancement, backend pas encore déployé) : ne jamais les supprimer, elles
/// garantissent qu'un formulaire fonctionne sans réseau.
abstract final class ActiveRates {
  static final Map<String, double> _serverRates = {};

  /// Unités de [currency] pour un euro : taux serveur si chargé, sinon la
  /// constante du catalogue.
  static double unitsPerEurFor(SupportedCurrency currency) =>
      _serverRates[currency.code] ?? currency.unitsPerEur;

  /// Fusionne les taux reçus du backend. Ignore les valeurs non strictement
  /// positives et les codes hors catalogue : un taux corrompu ne doit jamais
  /// remplacer le repli sain.
  static void setServerRates(Map<String, double> rates) {
    rates.forEach((code, rate) {
      final normalized = code.trim().toUpperCase();
      if (rate > 0 && SupportedCurrency.fromCode(normalized) != null) {
        _serverRates[normalized] = rate;
      }
    });
  }

  /// Réservé aux tests : revient au repli constante pur.
  static void resetForTest() => _serverRates.clear();
}
