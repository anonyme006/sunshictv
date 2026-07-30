# ox_garage

Garage moderne **ox_lib** + **ox_target** pour ESX — perso, entreprise, **fourrières**.

## Fonctionnalités

- Garages personnels (menus ox_lib, états, spawn/store)
- Garages entreprise (Job Creator)
- **Fourrière Générale** (police) + **Fourrière Mécano**

## Fourrières

| | Générale | Mécano |
|--|----------|--------|
| ID | `impound_public` | `impound_mechanic` |
| Mise en fourrière | `police` / `sheriff` | `mechanic` |
| Récupération | Propriétaire (payant) + police | Propriétaire (payant) + mécano (gratuit staff) |
| Prix défaut | 1500$ | 800$ |
| Société | `society_police` | `society_mechanic` |

### Utilisation in-game

1. Approche la zone ox_target de la fourrière
2. **Ouvrir la fourrière** → liste des véhicules (plaque, états, tarif)
3. Jobs autorisés : **Mettre en fourrière** (véhicule proche / actuel)
4. Propriétaire : **Récupérer** → paiement bank/cash → spawn

### Export

```lua
exports.ox_garage:ImpoundVehicle(plate, 'impound_public', props)
exports.ox_garage:OpenImpound('impound_mechanic')
```

Config : `Config.Impounds` dans `config.lua` (coords, jobs, prix, society).

Les véhicules en fourrière n’apparaissent **plus** dans les garages normaux (`parking` = id fourrière).

## Installation

```cfg
ensure ox_lib
ensure ox_target
ensure oxmysql
ensure es_extended
ensure ox_garage
```

Nécessite la colonne `parking` (ou `Config.Columns.garage`) sur `owned_vehicles`.
