# ox_garage

Garage moderne **ox_lib** + **ox_target** pour ESX — menus contextuels style RP haut de gamme.

## Fonctionnalités

- Interaction **ox_target** (ouvrir / ranger)
- Menu **`lib.registerContext`** avec :
  - Nom du véhicule
  - Plaque
  - État **Rangé** (vert) / **Sorti** (rouge)
  - Moteur % · Carrosserie % · Carburant %
  - Icône FontAwesome selon la classe
- Second menu : Sortir / Infos / Retour
- Véhicule déjà sorti → bouton grisé « Véhicule déjà sorti »
- Assis dans le véhicule au garage → menu **Ranger / Annuler**
- **Progress circle** au spawn et au rangement
- Notifications **ox_lib**

## Intégration Job Creator (entreprises)

Avec `job_creator` + `Config.UseOxGarage = true` :

1. Dans **/jobcreator** → marqueur **Garage** + véhicules job
2. Les employés ouvrent le **même menu ox_lib** sur le marker
3. Flotte stockée dans `ox_garage_job_vehicles` (plaque, états, props)
4. Sync auto à la sauvegarde / suppression d’un véhicule job

Exports :

```lua
exports.ox_garage:OpenJobGarage({
    job = 'police',
    garageId = '12',
    label = 'Garage Police',
    spawns = { vec4(...) },
    store = { coords = vec3(...), radius = 8.0 },
})
```

## Installation

```cfg
ensure ox_lib
ensure ox_target
ensure oxmysql
ensure es_extended
ensure ox_garage
ensure job_creator
```

Table flotte créée auto (`sql/job_vehicles.sql`).
