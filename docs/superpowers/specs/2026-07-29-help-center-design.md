# Centre d’aide Yadony — conception

## Objectif

Rendre la FAQ et le support faciles à trouver depuis le Profil et le hub
Activités, permettre de rechercher une réponse, corriger les informations
devenues inexactes et fiabiliser l’ouverture du client mail.

## Périmètre retenu

- Ajouter « FAQ & aide » dans la section « AIDE & RÉGLAGES » du Profil.
- Conserver « Aide & support » dans le hub Activités.
- Transformer la FAQ existante en Centre d’aide avec :
  - une recherche locale insensible à la casse et aux accents ;
  - les catégories existantes filtrées par question et réponse ;
  - un état vide clair ;
  - une carte finale « Contacter le support ».
- Corriger les réponses relatives aux moyens de paiement, remboursements,
  litiges, protection des données et suppression du compte.
- Conserver l’envoi par `mailto:` : aucun endpoint backend de création de
  ticket n’est présent dans le dépôt. L’interface doit dire explicitement
  qu’elle ouvre l’application Mail et ne doit jamais prétendre que l’email a
  été envoyé.
- Afficher l’adresse de support avec une action de copie comme solution de
  repli.
- Ajouter les événements analytics nécessaires sans sujet, message, adresse
  email ni autre PII.

## Architecture

### FAQ

`FaqBloc` porte la requête de recherche et les intentions analytics. Il reçoit
`AnalyticsService` par injection GetIt. `FaqScreen` reste responsable de la
présentation et filtre ses données statiques à partir de `FaqState.query`.

Événements :

- `FaqSearchChanged(query)` met à jour la recherche ;
- `FaqQuestionOpened(categoryId, questionId)` trace l’ouverture ;
- `FaqContactRequested()` trace le passage vers le support.

Propriétés autorisées : identifiants stables de catégorie et de question.
Aucun texte libre n’est envoyé.

### Support

`SupportContactBloc` conserve la validation du formulaire et reçoit
`AnalyticsService`. Le widget lance le schéma `mailto:` puis signale le
résultat au BLoC :

1. `SupportSubmitRequested` produit `submitting` ;
2. `SupportEmailComposerOpened` produit `success` et trace l’ouverture ;
3. `SupportEmailComposerFailed` produit `error` et trace un code d’échec.

L’écran reste affiché après ouverture du client mail afin de ne pas perdre la
saisie si l’utilisateur revient sans envoyer son brouillon.

## Interface

Le Centre d’aide utilise le design system existant :

- `DonyPageScaffold` et son espacement responsive ;
- `DonyTextField` avec icône de recherche ;
- cartes de catégories avec rayons et couleurs du thème ;
- `ExpansionTile` avec cible tactile Material ;
- animation d’entrée `fadeIn` + `slideY` ;
- carte de contact et `DonyButton` en fin de page.

Le formulaire support emploie les champs du design system, marque les champs
obligatoires et présente « Continuer dans l’app Mail » comme action.

## Contenu

- Distinguer carte, espèces, Wave et Orange Money.
- Ne pas employer « assurance » sans produit d’assurance démontré.
- Expliquer que les protections et remboursements dépendent du moyen de
  paiement et des conditions applicables.
- Éviter les garanties juridiques ou techniques absolues non vérifiables.
- Distinguer la pause de 30 jours et la suppression immédiate.
- Présenter les délais de support comme indicatifs.

## Tests

- Tests BLoC : recherche, analytics FAQ, succès et erreur du composeur mail,
  analytics support, validation inchangée.
- Tests widget FAQ : recherche, état vide, restauration et navigation support.
- Tests widget support : nouveau libellé, adresse copiable et absence de
  fermeture automatique après succès.
- Test Profil : navigation depuis « FAQ & aide ».
- Vérification finale : format Dart, tests ciblés puis `flutter analyze` sur
  les fichiers modifiés.

## Hors périmètre

- Création d’un endpoint backend de ticket support.
- Téléversement de pièces jointes ou journaux de diagnostic.
- CMS distant pour le contenu de la FAQ.
- Traduction anglaise complète de l’application.
