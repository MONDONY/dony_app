# Spec — Refonte écran chat + règles de messages
**Date:** 2026-06-20 | **Direction validée:** messagerie moderne épurée (variante A) + footer texte F1

## A. Refonte visuelle (`chat_screen.dart`)
- **Bulles** : reçue = `cs.surface` + ombre douce, **sans bordure** (supprime le double bordure+ombre actuel) ; envoyée = `cs.primary`. Rayon 20, coin « queue » 7 sur le dernier d'un groupe.
- **Groupage** : messages consécutifs du même expéditeur resserrés (gap 2-3 px), gap 9 px entre groupes ; queue + horodatage seulement sur le dernier du groupe.
- **Header** : avatar + nom + **présence** (« En ligne » / rôle) + pastille ; **bouton 📞 appel** (style WhatsApp) visible si numéro révélé (deal actif) ; menu ⋯.
- **Trajet lié** + **bandeau statut** conservés (affinés). **Séparateur date** en pastille centrée. **Messages système** en pill.
- **Footer F1** : une seule pill = champ multiligne + bouton envoi **à l'intérieur** (bleu dès qu'il y a du texte, scale-on-press). **Plus de bouton image ni position.**
- **Micro-animations** (make-interfaces) : fade/slide entrée bulles, scale 0.96 on press envoi, transition clavier douce, horodatage `tabular-nums`.

## B. Texte uniquement
Suppression de l'envoi **image** (`_pickAndSendImage`) et **position** (`_sendLocation`) : boutons + events `ChatImageSendRequested`/`ChatLocationSendRequested` non déclenchés depuis l'UI. Rendu des anciens messages image/position conservé (historique).

## C. Règles de contenu — **bloque + avertit** — client (Flutter) + firestore.rules
Validateur pur `ChatMessageValidator` (testable), appelé dans `_sendText` avant envoi.

| Famille | Règle | Couche |
|---|---|---|
| Longueur/vide | 1–**500** car., trim, pas de vide | client + Rules |
| Anti-contournement | tél **8+ chiffres** (séparateurs tolérés), email, `wa.me`/`t.me`/whatsapp/telegram/signal/snap/insta(gram), « appelle/numéro + chiffres » | client + Rules (tél/email) |
| Anti-spam | **5 msg / 15 s** glissant + anti-doublon (même texte trim < **30 s**) | client (timestamps en mémoire) |
| Contenu interdit | insultes (liste FR), IBAN (FR..), CB (13–16 chiffres), URL (http/https/www/domaine.tld) | client (+ Rules IBAN/CB) |

Message bloquant unique : « Pour ta sécurité, garde les échanges et le paiement sur dony. Le partage de coordonnées est interdit. » (variantes courtes par famille possibles). **Pas de Cloud Function.**

## Répartition repos
- **dony_app** : refonte UI, footer F1, 📞 header, `ChatMessageValidator` + câblage, `ParticipantModel.phone`.
- **dony-back** : DTO conversation expose `otherParticipant.phone` (révélé même gating que `BidResponse.phoneForStatus` — deal actif).
- **dony-functions** : `firestore.rules` durcies sur `conversations/{id}/messages` (longueur ≤ 500, non vide, type texte, reject regex tél/email/IBAN/CB).

## Décisions
- Footer F1 (envoi dans la pill) ; bulles A ; permission appel = **numéro révélé** (pas de consentement opt-in séparé).
- Enforcement client + Rules (pas de CF). Seuils : 500 / 5 par 15 s / doublon 30 s / tél 8+.
