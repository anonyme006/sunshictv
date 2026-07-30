# starter_pack

Ressource FiveM (ESX Legacy) : kit d'arrivée + **Carte Chance** (roue NUI → gain en banque).

## Contenu du kit (première connexion)

| Item | Quantité |
|------|----------|
| Carte d'identité (`id_card`) | 1 |
| Téléphone (`phone`) | 1 |
| BMX (`bmx` + véhicule spawné) | 1 |
| Eau (`water`) | 5 |
| Pain (`bread`) | 5 |
| Carte Chance (`carte_chance`) | 1 |
| Véhicule aléatoire (garage) | 1 |

Au premier join, un modèle est tiré dans `Config.GarageVehicle.models` et inséré dans `owned_vehicles` (**rangé**, `parking` = `Config.GarageVehicle.garageId`, défaut `legion` pour ox_garage).

## Carte Chance

1. Utilise l'item `carte_chance` dans l'inventaire.
2. Une fenêtre NUI s'ouvre avec une roue.
3. Clique sur **Tourner** (une seule fois — la carte est consommée).
4. Selon le **taux de réussite** (`Config.ChanceCard.successRate`) et les poids de la roue, tu gagnes entre **10 000 $** et **35 000 $** versés sur le compte **bank**.

## Lien esx_banque

Le gain est crédité via ESX (`bank`) **et** loggé dans l’historique banque si `esx_banque` / `esx_banking` est démarré.

```cfg
ensure es_extended
ensure esx_banque   # ou esx_banking
ensure starter_pack
```

```lua
Config.Bank = {
    enabled = true,
    resources = { 'esx_banque', 'esx_banking' }, -- ordre de détection
    logType = 'DEPOSIT',
}
Config.ChanceCard.account = 'bank'
Config.ChanceCard.transactionLabel = 'Carte Chance'
```

## Installation

1. Copie le dossier `starter_pack` dans `resources/[local]/` (ou ton dossier resources).
2. Ajoute les items (voir `sql/items.sql`) :
   - **ox_inventory** : colle les définitions dans `ox_inventory/data/items.lua`
   - **ESX items SQL** : exécute les `INSERT` du fichier SQL
3. Dans `server.cfg` :

```cfg
ensure es_extended
ensure oxmysql
ensure starter_pack
```

4. Redémarre le serveur (ou `ensure starter_pack`).

## Configuration

Fichier `config.lua` :

- `Config.StarterItems` — liste / noms des items (adapte-les à ton inventaire)
- `Config.GiveOnlyOnce` — kit une seule fois par joueur
- `Config.SpawnBmxVehicle` — `true` pour spawner un BMX dès l'arrivée (sinon : utiliser l'item `bmx`)
- `Config.GarageVehicle` — véhicule aléatoire au garage (`enabled`, `models`, `garageId`, colonnes SQL)
- `Config.ChanceCard.successRate` — ex. `0.75` = 75 % de chance de gagner
- `Config.ChanceCard.wheel` — montants + poids (plus le poids est haut, plus le lot est fréquent)
- `Config.ChanceCard.minReward` / `maxReward` — bornes affichées

### Véhicule garage (ox_garage)

```lua
Config.GarageVehicle = {
    enabled = true,
    garageId = 'legion', -- doit matcher un Config.Garages[].id d'ox_garage
    models = { 'asbo', 'blista', 'panto', ... },
    -- si pas de colonne parking : columns.parking = false
}
```

L'item **BMX** est utilisable : il spawn un vélo à côté du joueur et se consomme.

### Ranger le BMX (ox_target)

Avec `ox_target` démarré et `Config.BmxTarget.enabled = true` :

1. Utilise l'item `bmx` → le vélo apparaît
2. Vise le BMX → **Ranger dans l'inventaire**
3. Le véhicule est supprimé et l'item `bmx` est rendu

Seuls les BMX spawnés par le starter_pack sont rangeables (state bag `starter_pack_bmx`).

```lua
Config.BmxTarget = {
    enabled = true,
    label = 'Ranger dans l\'inventaire',
    icon = 'fa-solid fa-box',
    distance = 2.5,
    progress = 1500,
}
Config.Inventory = 'esx' -- ou 'ox'
```


## Commande admin

```
/givekit
```

Donne le kit immédiatement (groupe `admin`).

## Dépendances

- `es_extended` (ESX Legacy)
- `oxmysql`
