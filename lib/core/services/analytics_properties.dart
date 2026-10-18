// Propriétés analytics partagées entre features, sans PII.

/// Tranche de montant pour l'analytics, **sans symbole monétaire**.
///
/// Les bornes s'entendaient auparavant en euros et portaient le « € » dans leur
/// libellé, alors qu'elles s'appliquaient au montant brut quelle que soit la
/// devise : une proposition de 5 000 XOF, soit environ 7,60 €, atterrissait
/// dans « >100€ » et faussait toute lecture des données. La tranche est donc
/// neutre et la devise est envoyée à côté (`currency`), ce qui permet de
/// segmenter correctement sans jamais convertir de montant ni envoyer le
/// montant exact.
String analyticsAmountBracket(double amount) {
  if (amount < 20) return '<20';
  if (amount < 50) return '20-50';
  if (amount < 100) return '50-100';
  return '>100';
}
