# Story : solde unifié Yadony, côté app (lot 2)

Jumelle de la PR back MONDONY/yadony-back#671 (commission multi-portefeuilles) et #672 (origine d'une ligne convertie). À fusionner APRÈS elles ; l'app tolère l'ancien contrat.

## Ce qui change pour l'utilisateur

- Écran Portefeuille : l'historique mixte reste tel quel. Le total est dit « Total estimé (EUR) » dans la devise active, avec un lien discret « Changer ».
- Nouveau bouton dans l'en-tête : feuille « Mes soldes », une carte par devise, montant en grand dans le format de la devise, équivalent au taux du jour. Choisir une autre devise prévient que seul le total change (montant chiffré quand les taux sont connus) et propose « Calculer le total en … » (bouton dans `stickyBottom`).
- Historique : une ligne de commission prélevée sur un autre portefeuille dit « pour 450 F CFA » (jamais le taux, recalculé sur des montants arrondis).
- « Solde insuffisant » (acceptation, négociation, supplément, avenant) : avec le back à jour, le texte dit ce que tous les portefeuilles réunis règlent, ce qui manque encore et les portefeuilles écartés (remboursement en cours, taux indisponible).

## Contrat toléré

`fundingDetail` (corps 200 et extensions 422), `sourceCurrency`/`sourceAmount` sont optionnels : absents, l'écran retombe sur les textes historiques.

## Analytics

Pas de nouvel événement : le changement de devise du total réutilise `wallet_active_currency_switched` (le cubit journalise déjà origine et cible).

## Hors périmètre / suite

- Aperçu de la répartition avant l'acceptation (`GET /bids/{bidId}/commission-allocation`) : endpoint livré côté back, écran non branché ici.
- État « portefeuille gelé » dans la feuille : le DTO back n'expose pas d'indicateur de remboursement en cours.

## Tests

`wallet_screen_test.dart` (feuille, lien, bouton, écouteur, origine d'une ligne), `wallet_balances_total_test.dart`, `commission_funding_detail_test.dart`, `commission_shortfall_text_test.dart`.
