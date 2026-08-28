# qbx-charactercreator

Système complet de **sélection + création de personnage** pour **Qbox / qbx_core**, calqué sur le flux de [qbx-multicharacter](https://github.com/Qbox-project/qbx-multicharacter).

Interface NUI sombre, sélecteur multi-personnages, studio d’apparence, caméra interpolée, aperçu temps réel, validation serveur, sauvegarde oxmysql.

Cette ressource **n’utilise pas ESX ni QBCore**. Elle s’intègre à `qbx_core`, `ox_lib` et `oxmysql`.

## Analyse du dépôt

Le dépôt ne contenait aucune ressource FiveM. `qbx-multicharacter` officiel n’est plus maintenu (Qbox a intégré le multichar dans `qbx_core`).

Cette ressource **ne supprime pas** `qbx_core`. Elle le remplace **uniquement** si vous activez le sélecteur externe :

```lua
-- qbx_core/config/client.lua
useExternalCharacters = true
```

Détails : `bridge/INTEGRATION.md`.

## Dépendances

- FiveM (OneSync recommandé)
- [qbx_core](https://github.com/Qbox-project/qbx_core)
- [ox_lib](https://github.com/overextended/ox_lib)
- [oxmysql](https://github.com/overextended/oxmysql)

Optionnel :

- `illenium-appearance` si `Config.ClothingSystem = 'illenium-appearance'`
- `ox_target` / `ox_inventory` (désactivation automatique pendant le studio)

## Preview navigateur

Une preview hors FiveM est incluse pour visualiser l’interface :

1. Ouvrir `qbx-charactercreator/web/preview.html` dans un navigateur
   (ou servir le dossier `web/` : `python3 -m http.server 8765 --directory qbx-charactercreator/web`)
2. Aller sur `http://127.0.0.1:8765/preview.html` (sélection) ou `http://127.0.0.1:8765/preview.html#create` (studio)

La silhouette remplace le ped GTA. En jeu, le vrai personnage s’affiche en temps réel derrière la NUI.

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

4. Dans `qbx_core/config/client.lua`, mettre `useExternalCharacters = true`.
5. Ne pas démarrer `qbx-multicharacter` / `qb-multicharacter` en même temps.
6. Redémarrer le serveur. Les tables SQL sont créées automatiquement au démarrage.

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
| `Config.Multichar.Enabled` | Sélecteur multi-personnages (flux qbx-multicharacter) |
| `Config.Multichar.DefaultNumberOfCharacters` | Nombre d’emplacements par défaut |
| `Config.Hooks.CreateFirstCharacter` | Écoute le hook Qbox de première création |
| `Config.Hooks.AutoOpenIfNoAppearance` | Ouvre le studio si aucune apparence n’existe |
| `Config.Admin.ace` | Permission ACE des commandes ciblées |
| `Config.ClothingSystem` | Adaptateur vêtements |

## Configuration Qbox

Dans `qbx_core/config/client.lua` :

```lua
useExternalCharacters = true
```

Aucun fichier `qbx_core` n’est modifié par cette ressource. Voir `bridge/INTEGRATION.md`.

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
| `/logout` | Déconnecte le personnage et rouvre la sélection | ACE `group.admin` |

## Exports

```lua
-- Client
exports['qbx-charactercreator']:OpenCreator('edit')
exports['qbx-charactercreator']:StartCreator({ mode = 'create', first = true })
exports['qbx-charactercreator']:IsOpen()
exports['qbx-charactercreator']:OpenCharacterSelect()
exports['qbx-charactercreator']:IsSelectOpen()
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

**Deux menus de personnages s’affichent**
- Mettre `useExternalCharacters = true` dans `qbx_core`
- Arrêter `qbx-multicharacter` / `qb-multicharacter`

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
