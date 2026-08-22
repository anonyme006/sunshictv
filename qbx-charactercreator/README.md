# qbx-charactercreator

Système complet de création de personnage pour **Qbox / qbx_core**.

Interface NUI sombre, caméra interpolée, aperçu temps réel, validation serveur, sauvegarde oxmysql, brouillon temporaire et commandes administrateur.

Cette ressource **n’utilise pas ESX ni QBCore**. Elle s’intègre à `qbx_core`, `ox_lib` et `oxmysql`.

## Analyse du dépôt

Le dépôt `sunshictv` ne contenait aucune ressource FiveM existante. Aucun système de personnages n’a donc été supprimé.

`qbx_core` fournit d’origine un multicharactère. **Il n’est pas remplacé.** Le créateur s’y greffe :

- après « Créer un personnage », Qbox déclenche `qb-clothes:client:CreateFirstCharacter`
- cette ressource ouvre alors le studio
- l’identité Qbox déjà saisie est préremplie et reste éditable
- l’apparence est écrite dans `character_creator` **et** `playerskins` (aperçu Qbox / illenium)

Détails : `bridge/INTEGRATION.md`.

## Dépendances

- FiveM (OneSync recommandé)
- [qbx_core](https://github.com/Qbox-project/qbx_core)
- [ox_lib](https://github.com/overextended/ox_lib)
- [oxmysql](https://github.com/overextended/oxmysql)

Optionnel :

- `illenium-appearance` si `Config.ClothingSystem = 'illenium-appearance'`
- `ox_target` / `ox_inventory` (désactivation automatique pendant le studio)

## Installation

1. Copier le dossier `qbx-charactercreator` dans `resources`.
2. Vérifier que `ox_lib`, `oxmysql` et `qbx_core` démarrent avant cette ressource.
3. Ajouter dans `server.cfg` :

```cfg
ensure oxmysql
ensure ox_lib
ensure qbx_core
ensure qbx-charactercreator
```

4. Redémarrer le serveur. Les tables SQL sont créées automatiquement au démarrage.

## Installation SQL

Automatique au start. Fichier manuel : `sql/install.sql`.

Tables :

- `character_creator` — identité + apparence + vêtements
- `character_creator_drafts` — reprise après fermeture accidentelle
- `playerskins` — uniquement si elle n’existe pas déjà (compat Qbox / illenium)

Aucune colonne Qbox n’est dupliquée dans `players`. L’identité officielle reste dans `players.charinfo`.

## Configuration

Fichier principal : `config.lua`.

```lua
Config.Locale = 'fr'
Config.ClothingSystem = 'native' -- native | illenium-appearance | custom
Config.MinimumAge = 18
Config.AllowCancel = true
Config.EnableClothing = true
Config.EnableMakeup = true
Config.EnableAccessories = true
Config.CreatorPosition = vec4(402.91, -996.76, -99.0, 185.17)
Config.Spawn.coords = vec4(-269.4, -955.3, 31.2, 205.8)
```

Autres options utiles :

| Clé | Rôle |
| --- | --- |
| `Config.Creator.IsolateBucket` | Isole le joueur dans un routing bucket OneSync |
| `Config.Draft.timeoutMinutes` | Durée de vie du brouillon |
| `Config.Sound.volume` | Volume des sons NUI |
| `Config.Hooks.CreateFirstCharacter` | Écoute le hook Qbox de première création |
| `Config.Hooks.AutoOpenIfNoAppearance` | Ouvre le studio si aucune apparence n’existe |
| `Config.Admin.ace` | Permission ACE des commandes ciblées |
| `Config.ClothingSystem` | Adaptateur vêtements |

## Configuration Qbox

Aucun fichier `qbx_core` n’est modifié.

Pour remplacer aussi le dialogue d’identité Qbox, voir `bridge/INTEGRATION.md` (`useExternalCharacters`).

## Configuration vêtements

```lua
Config.ClothingSystem = 'native'
```

- `native` : `SetPedComponentVariation` / `SetPedPropIndex`
- `illenium-appearance` : export `setPedAppearance` si la ressource est démarrée
- `custom` : fonctions `Config.CustomClothingApply` / `Config.CustomClothingCollect`

Ajouter un adaptateur plus tard ne nécessite pas de réécrire le créateur.

## Commandes administrateur

| Commande | Description | Permission |
| --- | --- | --- |
| `/charcreator` | Ouvre le créateur sur soi | Joueur connecté |
| `/charcreator [id]` | Ouvre le créateur sur un joueur | ACE `group.admin` ou permission Qbox `admin` |
| `/charreset [id]` | Réinitialise l’apparence | ACE `group.admin` |

## Exports

```lua
-- Client
exports['qbx-charactercreator']:OpenCreator('edit')
exports['qbx-charactercreator']:StartCreator({ mode = 'create', first = true })
exports['qbx-charactercreator']:IsOpen()
exports['qbx-charactercreator']:ApplyAppearance(ped, appearance)

-- Serveur
exports['qbx-charactercreator']:OpenCreator(source, 'edit')
exports['qbx-charactercreator']:GetAppearance(citizenid)
exports['qbx-charactercreator']:HasAppearance(citizenid)
exports['qbx-charactercreator']:ResetAppearance(citizenid, gender)
```

## Sécurité

- Aucune donnée NUI n’est enregistrée sans validation serveur
- `citizenid` toujours lu depuis le joueur Qbox, jamais depuis le client
- Requêtes oxmysql préparées uniquement
- Modèles limités à `mp_m_freemode_01` / `mp_f_freemode_01`
- Morphologie, overlays, vêtements et textures clampés
- Anti-spam sur sauvegarde, brouillon, ouverture et reset
- Le joueur doit être en session créateur (`busy`) pour sauvegarder

## Performance

Une boucle `Wait(0)` n’existe **que pendant** le studio (caméra, lumières, rotation, contrôles). Elle est arrêtée à la fermeture. Caméras, animations, NUI et routing bucket sont nettoyés.

## Dépannage

**L’interface ne s’ouvre pas**
- Vérifier `ensure qbx-charactercreator`
- Le joueur doit avoir un personnage Qbox, sauf en mode `register`
- Regarder F8 / console serveur

**Conflit avec illenium-appearance**
- Désactiver un des deux hooks de première création
- Voir `bridge/INTEGRATION.md`

**Le personnage est invisible / sous la map**
- `Config.CreatorPosition` pointe vers l’intérieur mugshot vanilla
- Changer les coordonnées si votre mapping le masque

**L’aperçu Qbox reste générique**
- Confirmer que `playerskins` se remplit
- Redémarrer `oxmysql` puis la ressource

**SQL**
- La ressource crée les tables au start
- En cas d’échec, importer `sql/install.sql` à la main

**Permissions**
- `/charcreator [id]` et `/charreset` exigent `add_ace group.admin command` / groupe admin Qbox
