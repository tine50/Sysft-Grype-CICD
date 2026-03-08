# Cas pratique : Syft – Gestion des dépendances et SBOM

Ce dépôt permet de **mettre en pratique Syft** (générateur de SBOM) et de rédiger un **rapport** dans le cadre du cours Security M2.

## Contenu

| Fichier / Dossier | Description |
|-------------------|-------------|
| **app-exemple/** | Projet Node.js minimal (express, lodash, axios, etc.) utilisé comme cible du scan |
| **GUIDE_SYFT.md** | Guide d’installation (Windows) et d’utilisation de Syft |
| **generer-sbom.ps1** | Script PowerShell pour générer les SBOM (CycloneDX, SPDX, Syft JSON) |
| **SYFT_CAS_COMPLET.md** | Cas de figure complet : config, Grype, pipeline, CI/CD (rendre Syft vraiment utile) |
| **syft-grype-pipeline.ps1** | Pipeline Syft + Grype (SBOM → vulnérabilités → option fail-on critical) |
| **.syft.yaml** | Configuration Syft (exclusions, scope) pour des scans plus utiles |
| **RAPPORT_SBOM_TEMPLATE.md** | Modèle de rapport à compléter après les manipulations |
| **rapports/** | Dossier où sont enregistrés les fichiers SBOM générés |
| **app-exemple/Dockerfile** | Image Docker de l’app exemple (pour SBOM sur conteneur) |
| **generer-sbom-docker.ps1** | Script pour générer le SBOM d’une image Docker |

## Démarrage rapide

1. **Installer Syft** (si besoin) :
   - **Winget :** `winget install Anchore.syft`
   - **Docker :** `docker build -t syft-local -f syft/Dockerfile syft` puis utiliser `docker run --rm -v "${PWD}:/workspace" syft-local ...` (voir GUIDE_SYFT.md, option D).

2. **Installer les dépendances du projet exemple** (optionnel, pour un inventaire plus riche) :
   ```powershell
   cd app-exemple
   npm install
   cd ..
   ```

3. **Générer les SBOM** :
   ```powershell
   .\generer-sbom.ps1
   ```
   Les fichiers seront créés dans `rapports/`.

4. **Rédiger le rapport** en s’appuyant sur `RAPPORT_SBOM_TEMPLATE.md` et les SBOM générés.

## SBOM avec Docker

Syft peut générer un SBOM **à partir d’une image Docker** (tout ce qui est dans l’image : OS, paquets, runtime, app).

```powershell
# Image déjà disponible (ex. node:20-alpine)
syft node:20-alpine -o cyclonedx-json=rapports/sbom-docker-node.json

# Construire notre image puis scanner
docker build -t app-exemple-sbom:1.0 -f app-exemple/Dockerfile app-exemple
syft app-exemple-sbom:1.0 -o cyclonedx-json=rapports/sbom-docker-app-exemple.json

# Ou utiliser le script
.\generer-sbom-docker.ps1 -ConstruireAppExemple
.\generer-sbom-docker.ps1 -Image "nginx:alpine"
```

Voir **GUIDE_SYFT.md** section 4 pour le détail.

## Vérification rapide sans script

```powershell
syft app-exemple
syft app-exemple -o cyclonedx-json=rapports/sbom-cyclonedx.json
```

## Suite possible

- Utiliser **Grype** pour scanner les vulnérabilités à partir du SBOM.
- Intégrer Syft dans un pipeline CI/CD.
- **Cas complet** : voir **SYFT_CAS_COMPLET.md** et lancer `.\syft-grype-pipeline.ps1` pour SBOM + scan vulnérabilités en une commande.

Voir **GUIDE_SYFT.md** pour plus de détails et **RAPPORT_SBOM_TEMPLATE.md** pour la structure du rapport.
