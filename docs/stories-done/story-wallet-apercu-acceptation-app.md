# Story : aperçu de la répartition de la commission avant l'acceptation (app)

Suite de `story-wallet-solde-unifie-app.md`. Consomme le endpoint back `GET /bids/{bidId}/commission-allocation` (yadony-back #671, fusionné).

## Ce qui change pour le voyageur

Avant d'accepter un colis payé en espèces, si la commission ne vient pas du seul portefeuille de la devise du colis (plusieurs portefeuilles, ou une part convertie), une feuille « Comment vos frais seront réglés » liste un portefeuille par ligne (montant dans sa devise) et, pour une part convertie, la part réglée et le taux du jour. Le bouton « Accepter et régler » (dans `stickyBottom`) poursuit l'acceptation ; fermer la feuille l'annule sans rien débiter.

## Quand rien ne s'affiche

Autre moyen de paiement, un seul portefeuille sans conversion, portefeuilles insuffisants (la feuille « Solde insuffisant » détaillée prend le relais), ou aperçu indisponible (ancien back, hors ligne, erreur) : l'aperçu est indicatif, il ne bloque jamais une acceptation.

## Points d'accroche

`confirmCashCommissionAllocation` (`commission_allocation_sheet.dart`) est appelé avant `dispatchBidAccept` dans `demandes_screen.dart`, `pending_bids_screen.dart` (l'indicateur de traitement n'est posé qu'après confirmation) et `bid_detail_action_bars.dart`.

## Hors périmètre

Le règlement d'un accord négocié (`bid_negotiation_thread_screen.dart`, fil de demande) garde son parcours : il passe déjà par la feuille « Solde insuffisant » détaillée.

## Tests

`commission_allocation_test.dart` (modèle, règles d'affichage, feuille : confirmer, fermer, repli), `bid_repository_test.dart`.
