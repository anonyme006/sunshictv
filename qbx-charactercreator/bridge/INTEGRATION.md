# Intégration Qbox + rCore Clothing

Cette ressource conserve le **flux qbx-multicharacter** (sélection, aperçu, création, suppression, spawn) et **ne gère plus l’apparence physique**.

Parcours :

```
qbx-multicharacter (cette ressource)
        ↓
Création du personnage
        ↓
Informations personnelles (prénom, nom, date, nationalité, taille)
        ↓
CONTINUER
        ↓
rCore Clothing  →  visage, parents, peau, cheveux, vêtements…
        ↓
SAUVEGARDE (rCore)
        ↓
Spawn Qbox
```

`qbx-multicharacter` officiel n’est plus maintenu : Qbox a intégré le multichar dans `qbx_core`. Ici, le sélecteur est externe. **rCore Clothing** n’est pas livré dans ce dépôt (ressource payante).

## Configuration Qbox obligatoire

Dans `qbx_core/config/client.lua` :

```lua
characters = {
    useExternalCharacters = true,
}
```

Sans ça, le menu ox_lib de `qbx_core` **et** notre sélecteur s’ouvriront en même temps.

Ne démarrez **pas** `qbx-multicharacter` / `qb-multicharacter` en parallèle.

## rCore Clothing — API réellement utilisées

Aucune invention. Uniquement la documentation officielle :

| Usage | API documentée | Source |
| --- | --- | --- |
| Ouvrir le créateur **initial** QB/Qbox | `TriggerEvent('qb-clothes:client:CreateFirstCharacter')` | [crm_multichar](https://documentation.rcore.cz/paid-resources/rcore_clothing/integration/crm_multichar.md) |
| Créateur terminé | `AddEventHandler('rcore_clothing:charcreator:done', …)` | [API client](https://documentation.rcore.cz/paid-resources/rcore_clothing/api/client.md) |
| Aperçu d’un personnage | `exports['rcore_clothing']:getSkinByIdentifier(citizenid)` + `setPedSkin(ped, skin)` | [qbox_multichar](https://documentation.rcore.cz/paid-resources/rcore_clothing/integration/qbox_multichar.md) |
| Sauvegarde (laissée à rCore) | rCore enregistre à la validation de son créateur | API client |

Événements **non utilisés** volontairement :

- `rcore_clothing:esx:charcreator` — ESX uniquement
- `rcore_clothing:openCharCreator` — non présent dans l’API client officielle
- `rcore_clothing:qb:multichar` — prévu pour le ped cloné de `qb-multicharacter`, pas pour notre aperçu joueur

Si votre build `rcore_clothing` diverge, vérifiez `fxmanifest.lua` / `config.lua` de **votre** ressource installée avant de changer `Config.Rcore`.

## Identité Qbox

Les champs sont écrits dans `players.charinfo` via `exports.qbx_core:SetCharInfo` / `Login` :

- `firstname`
- `lastname`
- `birthdate` (stocké `YYYY-MM-DD`, affiché `JJ/MM/AAAA`)
- `nationality`
- `height` (centimètres)
- `gender` — **non demandé** dans le formulaire ; rCore choisit le modèle, puis on synchronise 0/1 depuis le ped

Aucune nouvelle table n’est créée pour ces champs. `character_creator` ne sert que de copie locale optionnelle.

## Ordre de démarrage

```cfg
ensure oxmysql
ensure ox_lib
ensure qbx_core
ensure rcore_clothing
ensure qbx-charactercreator
# optionnel
ensure qbx_spawn
ensure qbx_apartments
ensure qbx_weathersync
```

Désactivez `qb-clothing` : rCore le remplace et écoute `qb-clothes:client:CreateFirstCharacter`.

## Compatibilité événements

- `qb-multicharacter:client:chooseChar`
- `qbx-charactercreator:client:chooseChar`

Après rCore `charcreator:done`, le spawn suit qbx-multicharacter (`apartments:client:setupSpawnUI` ou spawn par défaut).

## Désactiver le sélecteur

```lua
Config.Multichar.Enabled = false
Config.Multichar.TakeOverSession = false
```
