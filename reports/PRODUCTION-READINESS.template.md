# Production Readiness — dony app

## Résumé exécutif

**Verdict global:** [À remplir après exécution complète des tests]

Synthèse : [Insérer ici le verdict (✅/⚠️/❌) et 2 lignes de conclusions critiques]

---

## 1. Perf UI (FPS / jank)

Analyse des performances FPS et des gelés lors de la navigation, du rendu des listes et des transitions.

Contenu généré depuis `reports/perf-report.md` :

<!-- SECTION_PERF_START -->
_(non généré — lancer scripts/perf.sh sur un device)_
<!-- SECTION_PERF_END -->

---

## 2. Réseau

Analyse des requêtes HTTP : latence, taille, waterfall et patterns de mise en cache.

### 2.1 Rapport réseau

Contenu généré depuis `reports/network-report.md` :

<!-- SECTION_NETWORK_START -->
_(non généré — lancer scripts/perf.sh sur un device)_
<!-- SECTION_NETWORK_END -->

### 2.2 Waterfall (timeline)

Contenu généré depuis `reports/waterfall-report.md` :

<!-- SECTION_WATERFALL_START -->
_(non généré — lancer scripts/perf.sh sur un device)_
<!-- SECTION_WATERFALL_END -->

---

## 3. Montée en charge backend (k6)

Analyse de la scalabilité du backend sous charge : latence p50/p95/p99, taux d'erreur, throughput.

**Note :** Le rapport k6 est généré côté `dony-back/load-test/reports/load-report.md` (autre repo).  
Référence : `/dony-back/load-test/reports/load-report.md`

---

## 4. Caveats

**Important :** Les résultats proviennent d'un émulateur ou d'un Simulateur, qui ne reflètent pas exactement le comportement d'un vrai device :

- **Perf UI** : L'émulateur / Simulateur ralentit les rendus vidéo et réseau. Seul un **FAIL** est vraiment fiable (il sera reproductible sur device réel). Pour les ✅/⚠️ marginals, **reconfirmer sur un vrai device en production**.

- **Réseau** : Les latences réseau mesurées sont des artefacts de la virtualisation. Les patterns de requête (ordre, taille) sont représentatifs, mais les temps ne le sont pas.

- **Profile vs Release** : Le mode `--profile` utilisé pour la mesure perf est plus proche du Release que du Debug, mais il conserve des informations de symboles. Les optimisations Release (treeshaking, optimisation Dart2native) peuvent différer légèrement.

- **Load test** : Le test de charge k6 s'exécute contre l'environnement **staging**, jamais contre la production. Les résultats sont valides pour validation pré-prod mais pas une garantie de comportement prod.

**Recommandation :** ✅/⚠️ sur émulateur → reconfirmer manuellement sur au moins 1 device réel avant go-live.

---

## 5. Recommandations

[À remplir après exécution des tests et analyse des résultats]

Lister les optimisations à prioriser :
- Critiques (blockers prod)
- Importantes (à faire avant v1.0)
- Optionnelles (futurs sprints)
