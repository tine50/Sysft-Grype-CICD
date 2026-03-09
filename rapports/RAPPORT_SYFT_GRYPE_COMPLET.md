# Rapport – Syft, Grype et SBOM : chaîne de confiance et vulnérabilités

**Projet :** Sysft-Grype-CICD – Security M2  
**Contexte :** UADB M2 – Sécurité logicielle  
**Date :** 2026

---

## 1. Contexte et objectifs

### 1.1 Contexte

**Pourquoi c’est important**

- **Traçabilité des dépendances** : savoir *exactement* quelles bibliothèques et quelles versions sont utilisées par une application (directement ou indirectement). Sans cela, on ne peut pas répondre à la question « qu’est-ce qui tourne vraiment dans mon logiciel ? » ni réagir vite en cas de faille connue.
- **Détection des vulnérabilités (CVE)** : les **CVE** (Common Vulnerabilities and Exposures) sont des failles de sécurité publiquement répertoriées. Les détecter sur *vos* dépendances permet de corriger ou de mettre à jour les composants concernés avant qu’ils soient exploités.

**Cadres réglementaires et bonnes pratiques**

Ces attentes sont renforcées par plusieurs textes et recommandations :

| Cadre | En bref |
|-------|--------|
| **NIS2** (Union européenne) | Obligations de cybersécurité pour les acteurs essentiels et importants ; la chaîne d’approvisionnement logicielle et la connaissance des composants sont visées. |
| **ANSSI** (France) | Recommandations sur la gestion des vulnérabilités et la connaissance des dépendances pour les organisations sensibles. |
| **EO 14028** (États-Unis) | Exigence de fourniture d’un SBOM (ou équivalent) pour les logiciels livrés au gouvernement fédéral. |

**Rôle du SBOM**

Un **SBOM** (Software Bill of Materials) est une **liste structurée des composants** d’un projet ou d’une image (nom, version, type). C’est la base pour : (1) savoir ce qui est présent, (2) scanner les vulnérabilités connues sur ces composants, et (3) prouver cette démarche en cas d’audit ou de conformité.

### 1.2 Objectifs du projet

- Mettre en œuvre **Syft** (Anchore) pour générer des SBOM à partir d’un répertoire ou d’une image Docker.
- Utiliser **Grype** pour scanner les vulnérabilités à partir du SBOM.
- Automatiser le pipeline (SBOM + Grype + rapports) en local et en **CI/CD** (GitHub Actions).
- Produire des rapports exploitables (JSON, HTML, présentables) pour une démonstration ou un audit.

---

## 2. Outils utilisés

| Outil | Rôle | Version typique |
|-------|------|-----------------|
| **Syft** | Génération de SBOM (CycloneDX, SPDX, Syft JSON) à partir de répertoires ou d’images | 1.42.x |
| **Grype** | Scan des vulnérabilités à partir d’un SBOM ou d’une cible directe ; base de vulnérabilités (NVD, GitHub Advisory, Alpine SecDB, etc.) | 0.109.x |
| **GitHub Actions** | Exécution du pipeline (Syft + Grype) à chaque push/PR ; artefacts SBOM et rapports | — |

---

## 3. Cible analysée : application exemple

- **Répertoire :** `app-exemple` – application Node.js (Express, Lodash, Axios).
- **Image Docker :** construite à partir de `app-exemple/Dockerfile` (base `node:20-alpine`), image nommée `app-exemple-sbom:1.0`.
- Pour les besoins de la démo, des **versions volontairement vulnérables** ont été utilisées (ex. lodash 4.17.20) afin d’obtenir des résultats dans les rapports Grype.

---

## 4. Méthodologie et pipeline

### 4.1 Chaîne globale

1. **Syft** : scan de la cible (répertoire ou image) → génération d’un SBOM au format CycloneDX (JSON).
2. **Grype** : lecture du SBOM → comparaison avec la base de vulnérabilités → rapport (table, JSON).
3. **Rapport HTML** : génération d’un fichier `rapports/vulns-report.html` à partir du JSON Grype (tableau par sévérité, liens vers les avis).
4. **CI/CD** : le workflow `.github/workflows/sbom-grype.yml` exécute Syft puis Grype à chaque push/PR sur `main`, et publie les artefacts (SBOM, rapport vulns, rapport HTML).

### 4.2 Commandes principales (local)

- Génération SBOM répertoire :  
  `syft app-exemple -o cyclonedx-json=rapports/sbom-cyclonedx.json`
- Scan des vulnérabilités :  
  `grype sbom:rapports/sbom-cyclonedx.json -o table`  
  `grype sbom:rapports/sbom-cyclonedx.json -o json --file rapports/vulns.json`
- Pipeline tout-en-un (script fourni) :  
  `.\syft-grype-pipeline.ps1`  
  `.\generer-rapport-vulns-html.ps1`

### 4.3 Configuration Syft

Le fichier `.syft.yaml` à la racine du projet permet d’exclure des chemins (`.git`, `dist`, `build`, etc.) et de contrôler le scope des scans (ex. `squashed` pour les images), afin d’obtenir des SBOM plus pertinents et plus rapides.

---

## 5. Résultats : SBOM et vulnérabilités

### 5.1 Inventaire (SBOM)

- **Répertoire `app-exemple` :** plusieurs dizaines de paquets npm (dépendances directes et transitives), listés dans `rapports/sbom-cyclonedx.json` et `rapports/sbom-spdx.json`.
- **Image Docker `app-exemple-sbom:1.0` :** paquets de la couche Alpine (apk), runtime Node.js et dépendances npm installées dans l’image.

Les formats CycloneDX et SPDX permettent une réutilisation dans d’autres outils (Dependency-Track, conformité, attestations).

### 5.2 Vulnérabilités détectées (exemple)

Sur la cible `app-exemple` avec lodash 4.17.20 (version volontairement vulnérable pour la démo), Grype signale notamment :

| Paquet | Version | Vulnérabilité | Sévérité | Description type |
|--------|---------|---------------|----------|-------------------|
| lodash | 4.17.20 | GHSA-35jh-r3h4-6jhm | High | Command Injection |
| lodash | 4.17.20 | GHSA-29mw-wpgm-hmr9 | Medium | ReDoS (Regular Expression DoS) |
| lodash | 4.17.20 | GHSA-xxjr-mmjv-4gpg | Medium | Prototype Pollution (`_.unset`, `_.omit`) |

Les identifiants GHSA sont cliquables dans le rapport HTML et renvoient vers les avis GitHub (ex. CVE-2021-23337, version corrigée : lodash 4.17.21).

### 5.3 Source des données Grype

Grype s’appuie sur une base de vulnérabilités (téléchargée et mise en cache localement) alimentée par NVD, GitHub Advisory Database, Alpine SecDB, etc. La commande `grype db status` affiche la base utilisée ; `grype db update` met à jour cette base.

---

## 6. CI/CD (GitHub Actions)

- **Workflow :** `.github/workflows/sbom-grype.yml`
- **Déclenchement :** push et pull_request sur la branche `main`
- **Étapes :** installation de Syft et Grype, génération du SBOM du répertoire `app-exemple`, exécution de Grype (table + JSON), génération du rapport HTML, upload des artefacts (SBOM CycloneDX, rapport vulns, rapport HTML).
- **Option :** une step commentée permet de faire échouer le job en cas de vulnérabilité de sévérité « critical » (`--fail-on critical`).

---

## 7. Aller plus loin (références du projet)

- **Dependency-Track :** import du SBOM CycloneDX pour tableau de bord et politiques (voir `docs/SYFT_CAS_COMPLET.md`).
- **Attestations :** signature du SBOM avec Syft + Cosign pour la chaîne de confiance.
- **Comparaison de SBOM :** script `comparer-sbom.ps1` pour comparer un SBOM de référence et un SBOM actuel (ajouts, suppressions, changements de version).
- **Conformité :** le SBOM et les rapports Grype servent de preuve d’inventaire et de gestion des vulnérabilités (NIS2, ANSSI).

---

## 8. Conclusion

Ce projet démontre une chaîne complète : **SBOM (Syft) → scan des vulnérabilités (Grype) → rapports (JSON, HTML) → CI/CD (GitHub Actions)**. Il fournit une base reproductible pour la traçabilité des dépendances et la détection des CVE, utilisable en local comme en intégration continue, et exploitable pour des présentations ou des démonstrations de conformité.

---

*Rapport généré dans le cadre du projet Syft/Grype – Security M2.*
