# qbx-charactercreator

Sélecteur **qbx-multicharacter** + formulaire d’**identité** + apparence **rCore Clothing** pour **Qbox / qbx_core**.

Cette ressource **n’utilise pas ESX ni QBCore**. Elle ne recrée **pas** le visage, les parents, les vêtements ni les accessoires : tout cela reste dans `rcore_clothing`.

## Parcours

```
Sélection de personnage
        ↓
Créer un personnage
        ↓
Prénom · Nom · Date de naissance · Nationalité · Taille
        ↓
CONTINUER
        ↓
rCore Clothing (apparence)
        ↓
SAUVEGARDE
        ↓
Spawn
```

## Analyse (avant modification)

Le dépôt ne contient pas `qbx-multicharacter` ni `rcore_clothing`. L’implémentation s’appuie sur :

1. Le sélecteur déjà présent dans cette ressource (flux qbx-multicharacter)
2. `players.charinfo` Qbox (`firstname`, `lastname`, `birthdate`, `nationality`, `height`)
3. Les **seuls** événements rCore documentés pour une création initiale QB/Qbox :
   - ouverture : `qb-clothes:client:CreateFirstCharacter`
   - fin : `rcore_clothing:charcreator:done`
   - aperçu : `getSkinByIdentifier` + `setPedSkin`

Fichiers touchés pour ce flux :

| Fichier | Rôle |
| --- | --- |
| `config.lua` | `Config.Nationalities`, `Config.MinHeight` / `MaxHeight`, `Config.Rcore` |
| `web/identity.js` + `web/index.html` + `web/style.css` | Formulaire identité uniquement |
| `client/rcore.lua` | Bridge documenté (aucun export inventé) |
| `client/main.lua` | Validation → Login Qbox → ouverture rCore → spawn |
| `client/multichar.lua` | Création d’emplacement + aperçu rCore |
| `server/main.lua` / `validation.lua` / `database.lua` | Sauvegarde `charinfo` sans studio d’apparence |

## Dépendances

- FiveM (OneSync recommandé)
- [qbx_core](https://github.com/Qbox-project/qbx_core)
- [ox_lib](https://github.com/overextended/ox_lib)
- [oxmysql](https://github.com/overextended/oxmysql)
- [rCore Clothing](https://store.rcore.cz/) (`rcore_clothing`) — **payant, non inclus**

## Preview navigateur

1. Servir le dossier `web/` : `python3 -m http.server 8765 --directory qbx-charactercreator/web`
2. `http://127.0.0.1:8765/preview.html` — sélection
3. `http://127.0.0.1:8765/preview.html#create` — formulaire d’identité
4. `http://127.0.0.1:8765/preview.html#studio` — ancien studio interne (secours)

La silhouette remplace le ped GTA. En jeu, le personnage 3D reste visible derrière le formulaire.

## Installation

1. Copier `qbx-charactercreator` dans `resources`.
2. Installer et démarrer `rcore_clothing` (désactiver `qb-clothing`).
3. Dans `qbx_core/config/client.lua` : `useExternalCharacters = true`.
4. `server.cfg` :

```cfg
ensure oxmysql
ensure ox_lib
ensure qbx_core
ensure rcore_clothing
ensure qbx-charactercreator
```

Détails : `bridge/INTEGRATION.md`.

## Configuration

```lua
Config.MinHeight = 150
Config.MaxHeight = 200

Config.Nationalities = {
    'Française',
    'Américaine',
    'Anglaise',
    -- …
}

Config.ClothingSystem = 'rcore_clothing'
```

Le sexe n’est **pas** demandé dans le formulaire : rCore Clothing le gère.

## Commandes

| Commande | Description |
| --- | --- |
| `/charcreator` | Si rCore est démarré : boutique admin rCore. Sinon : studio interne. |
| `/charcreator [id]` | Idem, ciblé |
| `/charreset [id]` | Réinitialise l’apparence interne (pas les skins rCore) |
| `/logout` | Retour à la sélection |

## Sécurité / performance

- Identité validée côté NUI **et** serveur
- `citizenid` lu depuis Qbox, jamais depuis le client
- Une boucle `Wait(0)` uniquement pendant le formulaire (contrôles). Elle s’arrête avant l’ouverture de rCore
- Aucun spam d’events : un `CreateFirstCharacter`, un listener `charcreator:done`
