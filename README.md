# Perfect Rentals

Ressource **FiveM** — location de véhicules (showroom/NUI, contrats, caution, prolongation, GPS, webhook optionnel).

Dépendances : **ox_lib**, **oxmysql**, framework via `config.lua` (ESX / QBCore).

## Installation rapide

1. Copier ce dossier dans `resources/[addons]/perfect_rentals` (ou le nom adapté après `ensure` dans ton `server.cfg`).
2. Importer `sql/install.sql` dans ta base MySQL (ou garder uniquement les migrations automatiques selon ta version déjà créée).
3. Configurer `config.lua` (framework, locale, paiements, webhooks, etc.).
4. Dans `server.cfg` : `ensure ox_lib`, `ensure oxmysql`, puis `ensure perfect_rentals`.

## Publier sur ton dépôt Git (nouveau repo vide)

Ton dépôt GitHub/GitLab doit contenir **le contenu de ce dossier** à la racine (`fxmanifest.lua` visible tout en haut du repo).

À faire **sur ta machine**, dans une copie de ce dossier (ou après `git init` dans ce dossier si c’est bien la racine de ton projet dédié) :

```powershell
cd chemin\vers\perfect_rentals
git init
git checkout -b main
git add -A
git commit -m "Initial import: Perfect Rentals addon"
git remote add origin https://github.com/TON_UTILISATEUR/TON_REPO.git
git push -u origin main
```

**Alternative** sans dupliquer : créer un dépôt vide, clone ailleurs, copier tous les fichiers de `perfect_rentals` dedans, puis commit + push.

## Mettre à jour le dépôt après des changements

```powershell
cd chemin\vers\perfect_rentals
git add -A
git status
git commit -m "Résumé clair du changement (ex: fix paiement au retour, i18n NUI)."
git push
```

Utilise des messages de commit courts et explicites ; un tag de version peut suivre celui dans `fxmanifest.lua` lors des releases :

```powershell
git tag -a v1.2.0 -m "v1.2.0"
git push origin v1.2.0
```

## Arborescence utile

| Chemin           | Rôle principal                          |
|------------------|-----------------------------------------|
| `config.lua`     | Framework, locale, paiements, thème     |
| `sql/install.sql`| Schéma MySQL                             |
| `client/` / `server/` | Logique jeu + callbacks + NUI     |
| `ui/`            | Interface NUI (HTML/CSS/JS)             |
| `locales/`       | Traductions `fr` / `en`                 |
| `shared/`        | Calculs prix, bootstrap NUI             |

Licence et crédits : voir métadonnées dans `fxmanifest.lua` et ton usage serveur habituel.
