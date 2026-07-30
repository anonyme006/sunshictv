# ox_garage

Garage moderne **ox_lib** + **ox_target** pour ESX — public, privés payants, entreprise, fourrières.

## Garages

| Type | Blip | Accès |
|------|------|--------|
| **Public** (1) | Jaune | Gratuit — Legion |
| **Privé** | Bleu | Achat d'accès + places (prix selon le lieu) |
| **Entreprise** | Orange | Job requis — Job Creator ou `/addjobgarage` |

### Garage privé

1. Approche un garage privé → menu d'achat (`price` + places incluses)
2. Range / sors tes véhicules (limité au nombre de places)
3. Achète des places supplémentaires (`pricePerSlot`, plafond `maxSlots`)

Config exemple :

```lua
{
    id = 'mirror',
    kind = 'private',
    label = 'Garage Privé — Mirror Park',
    price = 22000,        -- accès
    pricePerSlot = 7000,  -- place en plus
    slots = 1,            -- places à l'achat
    maxSlots = 5,
    blip = { enabled = true, sprite = 357, color = 3, scale = 0.7 },
    -- coords / target / store / spawns ...
}
```

### Garages entreprise (commande)

Place-toi à l'emplacement voulu (admin) :

```
/addjobgarage          → formulaire job + label + grade + rayon
/listjobgarages        → liste des IDs
/deljobgarage [id]     → suppression
```

Export serveur :

```lua
exports.ox_garage:AddJobGarage({
    job = 'police',
    label = 'Garage LSPD',
    x = 450.0, y = -980.0, z = 30.0,
    heading = 90.0,
    min_grade = 0,
})

exports.ox_garage:RemoveJobGarage('job_police_123456')
exports.ox_garage:GetJobGarages()
```

Les véhicules de flotte restent gérés via Job Creator (`ox_garage_job_vehicles`).

Les employés peuvent aussi **ranger leurs véhicules perso** dans un garage entreprise
(`Config.JobCreator.allowPersonalVehicles = true`) : stockés dans `owned_vehicles` avec
`parking` = id du garage job.

## Fourrières

| | Générale | Mécano |
|--|----------|--------|
| ID | `impound_public` | `impound_mechanic` |
| Mise en fourrière | `police` / `sheriff` | `mechanic` |
| Récupération | Propriétaire (payant) + police | Propriétaire (payant) + mécano (gratuit staff) |
| Prix défaut | 1500$ | 800$ |

```lua
exports.ox_garage:ImpoundVehicle(plate, 'impound_public', props)
exports.ox_garage:OpenImpound('impound_mechanic')
```

### Remise fourrière (bug / déco) — admin

```
/impoundfix [plaque] [fourrière?]   → 1 véhicule sorti → fourrière
/impoundfixall [fourrière?]         → tous les stored=0 → fourrière
```

Défaut : `impound_public`. Supprime aussi l’entité monde si encore spawnée.

```lua
exports.ox_garage:ForceImpoundPlate('ABC123', 'impound_public')
exports.ox_garage:ForceImpoundAllOut('impound_public')
```

## Installation

```cfg
ensure ox_lib
ensure ox_target
ensure oxmysql
ensure es_extended
ensure ox_garage
```

Tables créées / mises à jour auto au démarrage :

- `owned_vehicles` (+ colonne `parking`) — véhicules **perso** (public / privé / perso en entreprise)
- `ox_garage_private_access` — achats garages privés
- `ox_garage_job_garages` — emplacements garage entreprise (`/addjobgarage`)
- `ox_garage_job_vehicles` — flotte entreprise

SQL manuel (si besoin) : `ox_garage/sql/owned_vehicles.sql`
