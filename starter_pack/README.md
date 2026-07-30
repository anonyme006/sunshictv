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

## Carte Chance

1. Utilise l'item `carte_chance` dans l'inventaire.
2. Une fenêtre NUI s'ouvre avec une roue.
3. Clique sur **Tourner** (une seule fois — la carte est consommée).
4. Selon le **taux de réussite** (`Config.ChanceCard.successRate`) et les poids de la roue, tu gagnes entre **10 000 $** et **35 000 $** versés sur le compte **bank**.

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
- `Config.SpawnBmxVehicle` — spawne un vrai BMX à côté du joueur
- `Config.ChanceCard.successRate` — ex. `0.75` = 75 % de chance de gagner
- `Config.ChanceCard.wheel` — montants + poids (plus le poids est haut, plus le lot est fréquent)
- `Config.ChanceCard.minReward` / `maxReward` — bornes affichées

## Commande admin

```
/givekit
```

Donne le kit immédiatement (groupe `admin`).

## Dépendances

- `es_extended` (ESX Legacy)
- `oxmysql`
