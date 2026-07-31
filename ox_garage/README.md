# ox_garage v2 — Garage premium

Garage **NUI** + **ox_target** pour ESX Legacy (OneSync Infinity) — véhicules, hélicos, privés, entreprise, fourrières.

## Dépendances

```
ensure ox_lib
ensure ox_target
ensure oxmysql
ensure ox_fuel          # optionnel (Config.FuelResource)
ensure vehiclekeys      # optionnel (Config.VehicleKeys)
ensure ox_garage
```

## Interface NUI

Panneau semi-transparent avec blur, logo, aperçu véhicule (caméra monde), stats (nom, modèle, plaque, moteur, carrosserie, essence, localisation).

```lua
Config.UI = {
    mode = 'nui',              -- 'nui' | 'ox_lib'
    logo = 'img/logo.svg',
    brand = 'OX GARAGE',
    useWorldPreview = true,
    theme = {
        accent = '#d4a017',
        panel = 'rgba(18, 24, 34, 0.88)',
        blur = '18px',
        -- ...
    },
}
```

## Rangement (sans rester dans le véhicule)

1. Entre le véhicule dans la **BoxZone** / zone de rangement
2. Descends (ou reste à côté / devant / derrière)
3. **ox_target** sur le véhicule **ou** sur le marker → « Ranger le véhicule »
4. Sauvegarde props (moteur, carrosserie, essence, coffre) → `stored = 1` → notif « Véhicule rangé. »

```lua
Config.StoreDistance = 4.0
Config.UseTarget = true
```

Exemple BoxZone dans un garage :

```lua
store = {
    coords = vec3(...),
    radius = 4.0,
    box = {
        coords = vec3(...),
        size = vec3(10.0, 8.0, 3.5),
        rotation = 248.0,
        debug = false,
    },
}
```

Si plusieurs véhicules : seul le plus proche **dans la zone** est rangé.

## Sortir

- Point de spawn libre (`Config.CheckSpawnClear`)
- Spawn + props + **clés** (`Config.VehicleKeys`)
- Fermeture auto du menu

## Types

| `type` | Usage |
|--------|--------|
| `car` | Voitures / motos |
| `aircraft` | Hélicos / avions (ex: `heli_pillbox`) |
| `boat` | Bateaux |

## Garages

| Type | Accès |
|------|--------|
| **Public** | Gratuit (Legion + héliport) |
| **Privé** | Achat d'accès + places |
| **Entreprise** | Job Creator / `/addjobgarage` |

### Privé

```lua
price = 22000, pricePerSlot = 7000, slots = 1, maxSlots = 5
```

### Entreprise

```
/addjobgarage
/listjobgarages
/deljobgarage [id]
```

```lua
exports.ox_garage:AddJobGarage({ job = 'police', label = 'Garage LSPD', x=..., y=..., z=..., heading=90.0 })
exports.ox_garage:OpenJobGarage({ job = 'police', garageId = '...', spawns = {...}, store = {...} })
exports.ox_garage:OpenJobStore(data)
```

## Clés & essence

```lua
Config.VehicleKeys = { enabled = true, resource = 'auto' }
Config.FuelResource = 'ox_fuel' -- 'LegacyFuel' | 'none'
```

## Fourrières

Inchangées : `impound_public`, `impound_mechanic`, `/impoundfix`, `/impoundforceall`.

## Exports utiles

```lua
exports.ox_garage:OpenGarage('legion')
exports.ox_garage:OpenGarageStore('legion')
exports.ox_garage:GetGarages()
exports.ox_garage:OpenImpound('impound_public')
```
