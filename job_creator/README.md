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
- **`ox_garage`** + `ox_lib` / `ox_target` si `Config.UseOxGarage = true`

## Utilisation rapide

1. `/jobcreator` (admin)
2. Crée un job (ex: `mechanic` / Mécano)
3. Ajoute des grades + permissions
4. Place-toi au bon endroit → **Markers** → « Position joueur » → type (boss, garage…)
5. Onglet **ox_garage** : vois les garages dispo → « Utiliser dans marker »
6. Pour un garage flotte : ajoute des véhicules liés au job
7. Active les actions F6 dans l’onglet Job
8. Attribue le job via **Outils** ou menu patron

## ox_garage dans le panel

| Champ marker | Effet |
|--------------|--------|
| **Mode** `job_fleet` | Ouvre la flotte entreprise ox_garage |
| **Mode** `ox_garage` | Ouvre un garage perso/public/privé ox_garage (`legion`, `pinkcage`…) |
| **Garage ox_garage** | ID du garage lié (liste auto) |
| **Créer emplacement ox_garage job** | Appelle `AddJobGarage` à la position du marker |

```cfg
ensure ox_lib
ensure ox_target
ensure ox_garage
ensure job_creator
```

## Types de markers & data

- **harvest** : `item`, `count`
- **process** : `need_item`, `need_count`, `give_item`, `give_count`
- **sell** : `item`, `price`, `society_percent`, `black_money`
- **teleport** : `destination` (x,y,z,w)
- **garage** : `ox_mode`, `ox_garage_id`, `register_job_garage`, `spawn`, `radius`
- **garage_store** : `ox_mode`, `ox_garage_id`, `radius`
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

## Garages entreprise (ox_garage)

Si `Config.UseOxGarage = true` et que `ox_garage` est démarré :

- Les markers **garage** / **garage_store** ouvrent les menus **ox_lib** (pas le NUI basique)
- Chaque véhicule ajouté dans l’onglet **Véhicules** devient une unité de flotte (plaque unique, états moteur/carrosserie/essence)
- Même UX que le garage personnel : Rangé/Sorti, progress bar, notifs

Ordre `server.cfg` recommandé :

```cfg
ensure ox_lib
ensure ox_garage
ensure job_creator
```

