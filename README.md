# Perfect Rentals

Merci d’utiliser cette ressource **FiveM** — système de **location de véhicules** (showroom / NUI, contrats, caution, prolongation, GPS, webhook optionnel).

**Dépendances :** **ox_lib**, **oxmysql**. Framework : **`esx`**, **`qbcore`**, **`qbox`**. Notifications joueur : **`Config.NotificationMode`** (défaut **`framework`** = ESX/QB ; **`ox_lib`** ou **`custom`**). HUD temps location : **`/uiloc`**.

---

## Liens officiels Spectre Scripts

Une fois les fichiers du script sur ta machine (archive, dépôt cloné, etc.), passe par ces liens avant d’installer : la **documentation** détaille chaque étape, options et sécurité.

| Ressource | Lien |
|-----------|------|
| **Documentation Perfect Rentals** (installation, configuration, API, fonctionnalités) | [https://spectre-scripts.reeveriehost.com/documentation/perfect_rentals/index.html](https://spectre-scripts.reeveriehost.com/documentation/perfect_rentals/index.html) |
| **Serveur Discord — support & communauté** | [https://discord.gg/vRjBVYpRjj](https://discord.gg/vRjBVYpRjj) |

En cas de doute après lecture de la doc : ouvre un fil sur le Discord Spectre Scripts avec ta version du script, logs serveur/console et erreur précise.

---

## Installation rapide (rappel)

Pour le détail (SQL, inventaire `contract`, timeouts, administrateur `/rentaladmin`, etc.), utilise la **[documentation](https://spectre-scripts.reeveriehost.com/documentation/perfect_rentals/index.html)**.

1. Placer ce dossier dans ton serveur, par exemple `resources/[addons]/perfect_rentals/` (le nom doit correspondre à celui utilisé avec `ensure` dans `server.cfg`).
2. Importer `sql/install.sql` dans ta base MySQL.
3. Renseigner `config.lua` (framework, locale, cibles `ox_target`, webhooks Discord, etc.).
4. Dans `server.cfg`, après tes dépendances : `ensure ox_lib`, `ensure oxmysql`, puis `ensure perfect_rentals`.

Un guide pas à pas (item inventaire, ordre des `ensure`, réglages minimaux) se trouve dans la doc sous **Installation** → `setup.html` depuis la page d’accueil ci-dessus.

---

## Arborescence utile

| Chemin | Rôle principal |
|--------|----------------|
| `config.lua` | Framework, locale, paiements, thème, admins |
| `sql/install.sql` | Schéma MySQL |
| `client/` / `server/` | Logique jeu, callbacks, NUI |
| `ui/` | Interface NUI (HTML / CSS / JS) |
| `locales/` | Traductions `fr` / `en` |
| `shared/` | Logique partagée, bootstrap NUI |
| `installation/` | Copies HTML de référence (équivalent hébergé sur le site Spectre) |

Licence et crédits : voir `fxmanifest.lua` et les conditions fournies avec ton acquisition du script.



