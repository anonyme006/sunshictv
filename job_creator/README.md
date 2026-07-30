# Job Creator (style Jaksam)

Ressource FiveM **ESX Legacy** complète pour créer et gérer des jobs in-game via un panneau NUI admin.

## Fonctionnalités

| Module | Détail |
|--------|--------|
| **Jobs** | Création / édition / suppression, type civil/illégal/LEO/EMS, whitelist, blip, sync `jobs` + `job_grades` ESX |
| **Grades** | Salaire, label, permissions granulaires (`boss`, `hire`, `stash`, `billing`, …) |
| **Markers** | Boss, coffre, vestiaire, garage, rangement, boutique, armurerie, duty, récolte, traitement, craft, vente, téléport, blanchiment |
| **Véhicules** | Liste par job / garage, grade min, livery |
| **Boutique / Armurerie** | Items & armes, prix, grade min |
| **Crafts** | Recettes avec ingrédients + durée |
| **Société** | Déposer / retirer (table `jc_society` + `addon_account` optionnel) |
| **Employés** | Recruter, licencier, promouvoir (online + offline) |
| **Actions F6** | Facture, menottes, escorte, véhicule, fouille |
| **Duty** | Prise / fin de service |
| **Stash** | Coffre ESX SQL ou `ox_inventory` |

## Installation

1. Copie `job_creator` dans `resources/[local]/`
2. Importe `sql/install.sql` (ou laisse la ressource créer les tables au démarrage)
3. `server.cfg` :

```cfg
ensure es_extended
ensure oxmysql
ensure job_creator
```

4. Groupes admin dans `config.lua` → `Config.AdminGroups`
5. Commande : **`/jobcreator`**

### Optionnel

- `esx_addonaccount` si `Config.UseAddonAccount = true`
- `esx_skin` / `skinchanger` pour le vestiaire
- `esx_billing` pour les factures société
- `ox_inventory` si `Config.Inventory = 'ox'`

## Utilisation rapide

1. `/jobcreator` (admin)
2. Crée un job (ex: `mechanic` / Mécano)
3. Ajoute des grades + permissions
4. Place-toi au bon endroit → **Markers** → « Position joueur » → type (boss, garage…)
5. Pour un garage : ajoute des véhicules liés au job
6. Active les actions F6 dans l’onglet Job
7. Attribue le job via **Outils** ou menu patron

## Types de markers & data

- **harvest** : `item`, `count`
- **process** : `need_item`, `need_count`, `give_item`, `give_count`
- **sell** : `item`, `price`, `society_percent`, `black_money`
- **teleport** : `destination` (x,y,z,w)
- **garage** : `spawn` (x,y,z,w)
- **wash** : `fee_percent`

## Config importante

```lua
Config.OpenCommand = 'jobcreator'
Config.AdminGroups = { ['admin'] = true, ['superadmin'] = true }
Config.Inventory = 'esx' -- ou 'ox'
Config.UseAddonAccount = true
Config.ActionsKey = 'F6'
Config.Webhook = '' -- logs Discord
```

## Structure

```
job_creator/
  config.lua
  fxmanifest.lua
  client/   (markers, menus, garage, cloakroom, boss, creator)
  server/   (jobs, markers, society, employees, actions)
  html/     (panneau admin + menus joueur)
  sql/install.sql
  locales/fr.lua
```

## Dépendances

- `es_extended` (ESX Legacy)
- `oxmysql`
