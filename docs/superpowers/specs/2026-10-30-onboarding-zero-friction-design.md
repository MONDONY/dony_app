# Onboarding sans friction : design

Date : 2026-10-30. Statut : brouillon, en attente de validation du propriétaire.
Périmètre : `dony_app` (Flutter) + fiches de l'assistant dans `dony-back`.

## Intention

Aujourd'hui, une personne qui s'inscrit traverse jusqu'à 11 écrans avant d'atteindre l'accueil : carrousel, méthode, téléphone, code, consentement analytics, pays, « Votre projet », nom, parrainage, identité (KYC), « Par quoi commencer ? ». La plupart ne servent pas à entrer dans l'app : ils servent à Yadony.

Principe voulu par le propriétaire : **zéro friction à l'inscription**. Une information ou une action qui n'est pas indispensable pour créer le compte n'est demandée **qu'au moment où l'utilisateur en a besoin pour une action précise**, jamais avant.

## Objectifs

1. Parcours d'inscription réduit à : **carrousel d'1 écran → méthode → téléphone ou e-mail → code → écran final « Par quoi commencer ? »** (puis accueil).
2. Chaque donnée retirée de l'inscription est redemandée **au bon moment** (tableau ci-dessous), sans nouvelle porte inutile.
3. Aucune perte de conformité : CGU mentionnées, consentement analytics respecté, vérification d'identité toujours exigée avant d'envoyer un colis ou de publier un trajet.
4. L'entonnoir reste mesurable dans PostHog (événements remplacés, pas simplement supprimés).

## Non-objectifs

- Ne pas toucher à la connexion d'un compte existant.
- Ne pas toucher à « Parcourir sans compte » (session anonyme).
- Ne pas changer les règles de vérification d'identité ni de paiement (Stripe, mobile money) : seul le **moment** où elles sont proposées bouge, et il est déjà au bon endroit.
- Pas de refonte visuelle des écrans conservés.

## Anti-objectifs (ce qui serait un échec même si ça compile)

- Un utilisateur qui arrive à publier ou envoyer sans que le nom, le pays ou l'identité requis aient été demandés.
- Du suivi PostHog avant qu'une réponse de consentement ne soit donnée en zone RGPD.
- Un code de parrainage venu d'un lien d'invitation qui se perd.
- Des utilisateurs en cours d'inscription au moment de la mise en production bloqués sur une route supprimée.

## Parcours actuel (référence)

| # | Écran | Route |
|---|---|---|
| 1 | Carrousel (4 pages) | `/onboarding` |
| 2 | Méthode | `/auth/method` |
| 3 | Téléphone / e-mail | `/auth/phone`, `/auth/email` |
| 4 | Code | `/auth/otp`, `/auth/email-otp` |
| 5 | Consentement analytics | `/auth/analytics-consent` |
| 6 | Pays | `/auth/country-selection` |
| 7 | Votre projet (intention, pays visé, case GP Pro) | `intentStepRoute` |
| 8 | Nom et prénom | `/auth/personal-info` |
| 9 | Parrainage | `/auth/referral-code` |
| 10 | Identité (Didit) | `/kyc/verify?from=onboarding` |
| 11 | Par quoi commencer ? | `/first-steps` |

La suite est décidée par `resolvePostSignupRoute` + `nextStep` (`lib/features/auth/presentation/post_signup_route.dart`, `onboarding_step.dart`). `POST /auth/register` n'exige que `phoneNumber` ou `email` et `roles` (tous facultatifs côté DTO) : **le backend n'impose ni nom ni pays à l'inscription**, aucune migration n'est nécessaire.

## Parcours cible et décisions

Les décisions marquées **[propriétaire]** viennent de lui ; les autres sont ma proposition, à valider.

| Élément | Décision | Quand ça revient |
|---|---|---|
| Carrousel | **[propriétaire]** Raccourci à **1 écran** (garder la page « sécurité » : identité vérifiée, paiement retenu, QR, preuve de remise, ou la page qui convertit le mieux ; choix laissé au builder). Toujours franchissable en un tap. | — |
| Méthode, téléphone, code | Inchangés. | — |
| CGU | **Inchangées** (mon choix : question juridique, on ne la touche pas dans ce lot). Le back n'enregistre aucune acceptation des CGU (aucun champ ni `audit_log` trouvé), donc rien ne casse ; l'assouplir plus tard reste possible. | — |
| Consentement analytics | Écran supprimé. **Zone RGPD ou pays inconnu** : feuille discrète affichée à la première arrivée sur l'accueil. **Hors RGPD** : accordé automatiquement comme aujourd'hui (`GdprHelper.resolveConsentAction`). Aucun suivi tant que la réponse manque. La feuille est **ignorable** (valeur par défaut : refus) et revient à l'ouverture suivante. `signup_completed` et `first_steps_choice` ne sont émis que si le consentement est accordé : on accepte de les perdre pour qui ne répond pas. `AnalyticsConsentGate` cesse de renvoyer vers `/auth/analytics-consent` à chaque connexion. | À la première arrivée sur l'accueil, puis Réglages › Confidentialité (existant) |
| Pays | Écran supprimé. L'indicatif du téléphone ne vaut pas résidence : **rien n'est écrit sur le serveur automatiquement**. L'indicatif ne sert qu'à **préremplir** l'écran quand il sera demandé. Pays vide tant qu'il n'est pas confirmé. | Demandé à la première action qui en dépend : publier un trajet (redirection existante vers `/auth/country-selection`, qui devient un écran hors parcours), activer les paiements Connect, ajouter un compte de versement mobile money. Aussi Réglages › Préférences. |
| Votre projet (intention) | Écran supprimé, **fusionné** dans « Par quoi commencer ? » : le choix fait à cet écran enregistre l'intention (`intent_declared`, `source: SIGNUP`). « Plus tard » n'enregistre rien. Le pays visé et la case GP Pro quittent l'inscription. | GP Pro : Profil › GP Pro (existant). Pays visé : à la création d'une alerte ou d'une demande. |
| Nom et prénom | Écran supprimé. | Demandé dans une feuille à la **première action qui l'expose aux autres** : première offre, premier message, première publication. Le nom légal arrive aussi de la vérification d'identité. Affichage de repli quand le nom manque (voir questions). |
| Parrainage | Écran supprimé. | Un code issu d'un lien (`PendingReferralCodeStore`) est appliqué automatiquement juste après `register`, via `POST /referral/redeem` (aucune limite de délai côté back). En cas de refus (404 inconnu, 409 `already-referred` ou auto-parrainage), message neutre et le code est oublié. Sinon saisie dans Profil › Parrainage (existant). |
| Identité (KYC) | Retirée de l'inscription. | Le **back fait foi** : publication de trajet (`yadony.kyc.enforce`, vrai par défaut), paiements, et offre quand le voyageur n'accepte que les contacts vérifiés (403 `contact-kyc-required`). Côté app : `KycRequiredBottomSheet` avant d'envoyer un colis (`package_request_actions.dart`) et à l'intro de publication (`publish_intro_screen.dart`). **À faire** : vérifier que le 403 `contact-kyc-required` d'une offre ouvre cette même feuille et non une erreur brute. |
| Paiements (Stripe Connect) | Inchangés (déjà hors inscription depuis le 02/10). | Rappel à l'intro de publication. |
| Par quoi commencer ? | **Gardé** comme écran final unique, une seule question, « Plus tard » toujours visible. Reçoit l'intention (ligne ci-dessus). | — |

### Mon choix (à valider) : bannière de complétion du profil

La bannière « complétez votre profil » (`effectiveStripeStatus` et progression) **reste**, non bloquante, avec deux items seulement : nom et identité. Elle n'est plus une jauge d'inscription. Les étapes du parcours (jauge, `reachedPast`, `routeAfter`) disparaissent.

## Contraintes

- Règles du dépôt : GoRouter uniquement, BLoC, pas de `setState`, textes via ARB en **français et anglais**, nom public **Yadony**, aucun dégradé, boutons selon la règle d'une seule ligne (CLAUDE.md), couverture de tests ≥ 90 %.
- **Analytics** (CLAUDE.md dépôt `dony_app`) : retirer `onboarding_step_viewed`, `onboarding_step_completed`, `onboarding_step_skipped`, `onboarding_completed` du code et de la table ; garder `signup_completed`, `first_steps_choice`, `intent_declared`, `analytics_consent_answered`. Ajouter des événements pour les demandes juste-à-temps (nom, pays) avec propriété `trigger` en énumération fermée, sans PII.
- **Assistant** : les fiches `dony-back/src/main/resources/assistant/kb/{fr,en}/*.md` qui décrivent ces écrans ou leurs routes sont mises à jour **dans la PR back jumelle**, en FR et EN, même `id`. Une route retirée de `router.dart` doit l'être aussi des fiches (liste blanche des boutons « Y aller »).
- **PR jumelles** : back (fiches) d'abord, app ensuite, jamais de fusion avec une CI rouge.
- Branche dédiée, jamais sur `main` ; la fusion de l'app sur `main` déclenche un envoi TestFlight et Play interne (workflow Deploy stores) : aucun build sans accord explicite.
- Les comptes déjà créés mais au milieu de l'ancien parcours (`onboarding_seen_at` nul) doivent atterrir sur l'accueil, sans boucle ni écran mort.

## Ce que je laisse au builder

- Choix de la page conservée du carrousel et son habillage.
- Forme exacte de la feuille de consentement, de la feuille « Votre prénom » et du message de parrainage appliqué.
- Découpage en PR (ordre suggéré : fiches assistant en back, puis app en une ou deux PR).
- Sort du code devenu sans appelant : le supprimer (règle « pas de code mort »), avec ses tests.
- Mécanisme exact de déduction du pays depuis l'indicatif.

## Décisions prises après la relecture (mes choix, à relire)

- **`onboarding_seen_at`** : posé à l'**affichage** de « Par quoi commencer ? » (via `markOnboardingSeen()`). Le back ne fait que le stocker et l'exposer (`AuthService.markOnboardingSeen`, `UserResponse`), aucun autre usage. Les appels des écrans parrainage, KYC et paiements disparaissent avec eux. `nextStep` et la jauge sont supprimés ; la bannière de complétion calcule ses deux items elle-même.
- **Comptes en cours d'ancien parcours** : `/auth/personal-info`, `/auth/referral-code`, `/auth/analytics-consent` et l'étape « Votre projet » redirigent vers `/home`. `/auth/country-selection` et `/kyc/verify` restent (entrées hors parcours) ; le paramètre `?from=onboarding` est ignoré.
- **`signup_completed`** est émis dans `OtpVerificationScreen._continueAfterSignup` (la table du CLAUDE.md citant `PinSetupScreen` est périmée : à corriger).
- **Carrousel** : le choix de la page n'a aucun impact légal ni analytics.

## Mise à jour du 30/10 : décisions du propriétaire (elles priment sur le tableau ci-dessus)

- **Introduction et méthode** : ne changent pas. Le carrousel n'est pas raccourci dans ce lot ; seuls les écrans à partir du code reçu bougent.
- **Un seul écran facultatif « Faisons connaissance »**, juste après le code et avant « Par quoi commencer ? » : prénom, nom et pays ensemble, avec « Continuer » et « Passer pour l'instant ». Rien n'y est obligatoire. Le pays est prérempli d'après l'indicatif (modifiable, jamais écrit sans que la personne continue).
- **Le prénom n'est plus exigé nulle part.** Il n'y a plus de feuille « Comment vous appelez-vous ? » avant la première offre. Il faut donc un affichage de repli côté voyageur et destinataire quand le nom manque.
- **Le pays reste demandé en feuille** à la publication d'un trajet, aux paiements Connect et aux comptes de versement, **uniquement si la personne l'a passé** à « Faisons connaissance ».
- Écrans du parcours : code, « Faisons connaissance », « Par quoi commencer ? ». Maquettes : https://claude.ai/artifact/W8DDaysZuvXQu3zX2bbJag
- `onboarding_seen_at` reste posé à l'affichage de « Par quoi commencer ? ». Événements à prévoir pour « Faisons connaissance » : vue, `completed`, `skipped` (sans PII).
- **Mode d'accueil par défaut** (le sélecteur « J'envoie un colis » / « Je voyage » de l'accueil, `SearchMode.trips` / `SearchMode.parcels`) :
  - « Voyager avec des colis » : l'accueil s'ouvre sur **Je voyage** (`SearchMode.parcels`).
  - « Envoyer un colis », « Je regarde d'abord », « Plus tard » ou aucun choix : l'accueil s'ouvre sur **J'envoie un colis** (`SearchMode.trips`). C'est déjà le défaut codé en dur (`home_screen.dart`, initialisation de `_mode`).
  - Source de vérité : l'intention déclarée côté serveur (`intent`), enregistrée par le choix de « Par quoi commencer ? » (`intent_declared`, `source: SIGNUP`). `TRAVELER` donne `parcels` ; `SENDER`, `BOTH` ou absente donnent `trips`. Pas de nouveau stockage local.
  - Modifiable dans Réglages › « Vous utilisez Yadony pour… » (écran existant `IntentPromptSheet`), dont le sous-titre précise désormais « Choisit aussi l'écran d'accueil ». Cette feuille ne doit plus exiger le pays visé (`IntentFormState.isValid` exige aujourd'hui intention **et** destination : à assouplir, le pays visé quittant l'inscription).
  - La bascule manuelle du sélecteur reste valable pour la session ; à chaque ouverture de l'app, retour au défaut.
  - Ne touche pas à `ActiveRoleCubit` : le rôle voyageur réel (publier, encaisser) reste lié au rôle `TRAVELER` du compte.

## Mesure du succès

- Écrans entre « code validé » et « accueil » : de 6 à 1 (« Par quoi commencer ? »).
- Taux de passage `signup_completed` → première action métier (publication ou demande) : au moins stable, à comparer sur 2 semaines.
- Taux de réussite de la vérification d'identité au moment de l'action : pas de baisse.
