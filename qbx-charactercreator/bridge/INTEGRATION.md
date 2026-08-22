# Intégration Qbox

`qbx_core` possède déjà un système de **sélection / création de personnages**. Cette ressource ne le remplace pas.

## Comportement par défaut

Après `Créer un personnage`, `qbx_core` enregistre l’identité puis déclenche :

```lua
TriggerEvent('qb-clothes:client:CreateFirstCharacter')
```

`qbx-charactercreator` écoute cet événement (`Config.Hooks.CreateFirstCharacter = true`) et ouvre le studio d’apparence.

Le menu ox_lib de `qbx_core` n’est pas modifié. Aucun fichier Qbox n’est écrasé.

## Compatibilité illenium-appearance

Si `illenium-appearance` est installé, les deux ressources peuvent ouvrir un créateur en même temps.

Solutions :

1. Désactiver le hook première création d’illenium, **ou**
2. Passer `Config.Hooks.CreateFirstCharacter = false` ici et appeler manuellement :

```lua
exports['qbx-charactercreator']:OpenCreator('create')
```

3. Ou définir `Config.ClothingSystem = 'illenium-appearance'` pour appliquer les skins via leurs exports, tout en gardant notre NUI.

Les skins sont aussi écrits dans `playerskins` (format illenium) pour que l’aperçu multichar de Qbox continue de fonctionner.

## Remplacer le dialogue d’identité Qbox

Si vous voulez que **toute** la création (identité + apparence) passe par cette ressource :

1. Dans `qbx_core/config/client.lua` :

```lua
characters = {
    useExternalCharacters = true,
}
```

2. Dans votre ressource de sélection de personnages, au clic sur « Créer un personnage » :

```lua
exports['qbx-charactercreator']:StartCreator({ mode = 'register', first = true })
```

3. Après validation, le serveur appelle `exports.qbx_core:Login` puis sauvegarde l’apparence.

Ne faites cela que si vous avez déjà une ressource externe de multicharactère, ou si vous assumez de désactiver celle de `qbx_core`.

## Appels utiles

```lua
-- Client
exports['qbx-charactercreator']:OpenCreator('edit')
exports['qbx-charactercreator']:IsOpen()
exports['qbx-charactercreator']:ApplyAppearance(ped, appearance)

-- Serveur
exports['qbx-charactercreator']:OpenCreator(source, 'edit')
exports['qbx-charactercreator']:GetAppearance(citizenid)
exports['qbx-charactercreator']:HasAppearance(citizenid)
exports['qbx-charactercreator']:ResetAppearance(citizenid, gender)
```

Événements :

```lua
TriggerEvent('qbx-charactercreator:client:open', { mode = 'edit' })
AddEventHandler('qbx-charactercreator:client:created', function() end)
```
