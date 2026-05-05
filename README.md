# Perfect Rentals

Merci d’utiliser cette ressource **FiveM** — système de **location de véhicules** (showroom / NUI, contrats, caution, prolongation, GPS, webhook optionnel).

**Dépendances :** **ox_lib**, **oxmysql**. Framework : **`esx`**, **`qbcore`**, **`qbox`**. Notifications joueur : **`Config.NotificationMode`** (défaut **`framework`** = ESX/QB ; **`ox_lib`** ou **`custom`**). HUD temps location : **`/uiloc`**.

**Installation :** suis en priorité la documentation présente dans le dossier **`installation/`** du script (ouvre `installation/index.html` dans ton navigateur). La doc publiée sur le site officiel peut ne pas être synchronisée à chaque mise à jour — le dossier **`installation/`** correspond à la version livrée ici.

---

## Liens officiels Spectre Scripts

Une fois les fichiers du script sur ta machine (archive, dépôt cloné, etc.), les liens ci-dessous restent utiles pour le Discord et un aperçu **en ligne** ; pour l’install **pas à pas**, reste sur le dossier **`installation/`**.

| Ressource | Lien |
|-----------|------|
| **Documentation Perfect Rentals** (installation, configuration, API, fonctionnalités) | [https://spectre-scripts.reeveriehost.com/documentation/perfect_rentals/index.html](https://spectre-scripts.reeveriehost.com/documentation/perfect_rentals/index.html) |
| **Serveur Discord — support & communauté** | [https://discord.gg/vRjBVYpRjj](https://discord.gg/vRjBVYpRjj) |

En cas de doute après lecture de la doc : ouvre un fil sur le Discord Spectre Scripts avec ta version du script, logs serveur/console et erreur précise.

---

## Installation rapide (rappel)

Pour le détail (SQL, inventaire `contract`, timeouts, administrateur `/rentaladmin`, etc.), ouvre **`installation/setup.html`** (et **`installation/config.html`**) depuis le dossier du script ; le site reflète ce contenu lorsqu’il est à jour.

1. Placer ce dossier dans ton serveur, par exemple `resources/[addons]/perfect_rentals/` (le nom doit correspondre à celui utilisé avec `ensure` dans `server.cfg`).
2. Importer `sql/install.sql` dans ta base MySQL.
3. Renseigner `config.lua` (framework, locale, cibles `ox_target`, webhooks Discord, etc.).
4. Dans `server.cfg`, après tes dépendances : `ensure ox_lib`, `ensure oxmysql`, puis `ensure perfect_rentals`.

Le guide pas à pas (item inventaire, ordre des `ensure`, réglages minimaux) est le même que dans **`installation/setup.html`**.

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
| `installation/` | **Guide d’installation et config** inclus avec la release (prioritaire si le site a du retard) |

Licence et crédits : voir `fxmanifest.lua` et les conditions fournies avec ton acquisition du script.



