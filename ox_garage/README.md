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
- Fermeture auto après action réussie
- Rafraîchissement des données à chaque ouverture

## Dépendances

```
es_extended
ox_lib
ox_target
oxmysql
```

## Installation

1. Copie `ox_garage` dans `resources`
2. Adapte `Config.Columns` si ta table `owned_vehicles` diffère
3. Si pas de colonne `parking` / garage : `Config.UseGarageColumn = false`
4. `server.cfg` :

```cfg
ensure ox_lib
ensure ox_target
ensure oxmysql
ensure es_extended
ensure ox_garage
```

5. Configure les garages dans `config.lua` (coords, spawns, blips)

## Carburant

```lua
Config.FuelResource = 'none'      -- natif
-- Config.FuelResource = 'ox_fuel'
-- Config.FuelResource = 'LegacyFuel'
```

## Table SQL attendue

Colonnes utilisées sur `owned_vehicles` :

| Colonne | Rôle |
|---------|------|
| `owner` | identifier joueur |
| `plate` | plaque |
| `vehicle` | JSON props |
| `stored` | 1 = rangé, 0 = sorti |
| `parking` | id garage (optionnel) |
| `type` | `car` / `boat` / … |

## Utilisation

1. Approche le point **ox_target** du garage
2. « Ouvrir le garage » → liste des véhicules
3. Sélectionne un véhicule → Sortir / Infos
4. Pour ranger : monte dans ton véhicule près du garage → target « Ranger » ou ouvre le menu
