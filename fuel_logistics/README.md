# Fuel Logistics

Entreprise **Fuel Logistics** pour ESX Legacy 1.12.4 — approvisionnement carburant de toute la ville.

Compatible : **ox_lib**, **ox_target**, **ox_inventory**, **oxmysql**, **ox_fuel** (stations indépendantes du script fuel), Lua 5.4.

## Cycle de gameplay

1. **Récolte** — 3 points (raffineries / dépôt) → `crude_oil`
2. **Raffinage** — usine → `fuel_barrel` (rendement configurable)
3. **Stock** — stash ox_inventory entrepôt
4. **Chargement** — camion-citerne + flexible
5. **Livraison** — stations & cuves entreprises → argent **société ESX**
6. **Export** — surplus → société
7. **Commandes auto** — seuil 20% → mission accept/refuse

## Installation

1. Copie `fuel_logistics` dans `resources`
2. Ajoute les items (`sql/items.lua` → `ox_inventory/data/items.lua`)
3. `server.cfg` :

```cfg
ensure ox_lib
ensure ox_target
ensure ox_inventory
ensure oxmysql
ensure es_extended
ensure esx_addonaccount
ensure fuel_logistics
```

4. Tables créées automatiquement au démarrage (ou `sql/install.sql`)
5. Job `fuel_logistics` + grades synchronisés ESX
6. Compte `society_fuel_logistics` créé si besoin

## Commandes

| Commande | Accès | Description |
|----------|-------|-------------|
| `/fuelboss` | Patron | Menu boss ox_lib |
| `/fladmin` | Admin | Créer / éditer stations & cuves |
| `/florders` | Employés | Commandes automatiques |

## Admin in-game

`/fladmin` à la position voulue :
- Créer station (nom, capacité, prix/L, conso, owner job)
- Enregistrer cuve entreprise (job, capacité)
- Éditer / supprimer sans restart

## Items ox_inventory

- `crude_oil` — pétrole brut
- `fuel_barrel` — baril (50 L par défaut)
- `fuel_can` — bidon
- `fuel_hose` — flexible (requis pour charger)
- `delivery_doc` — bon de livraison
- `fuel_invoice` — facture

## Config clé

`config.lua` : job, grades/permissions, points, prix, temps, conso stations, auto-orders, camion, export.

## Sécurité

- Checks job / grade / permission
- Distance check serveur
- Busy lock anti-spam
- Callbacks ox_lib
- Historique + transactions SQL
- Pas de duplication items (remove avant add)

## Structure

```
fuel_logistics/
  config.lua
  client/   harvest, refine, delivery, export, boss, admin, orders
  server/   db, society, harvest, refine, stations, companies, delivery, export, orders, boss, admin
  locales/  fr, en
  sql/      install.sql, items.lua
```
