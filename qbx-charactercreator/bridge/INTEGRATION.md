# Intégration Qbox / qbx-multicharacter

Cette ressource reprend le **flux** de [qbx-multicharacter](https://github.com/Qbox-project/qbx-multicharacter) (sélection, aperçu ped, création, suppression, spawn) avec les APIs **qbx_core** actuelles et notre NUI.

`qbx-multicharacter` officiel n’est plus maintenu : Qbox a intégré le multichar dans `qbx_core`. Ici, le sélecteur est externe et le créateur d’apparence est inclus.

## Configuration Qbox obligatoire

Dans `qbx_core/config/client.lua` :

```lua
characters = {
    useExternalCharacters = true,
}
```

Sans ça, le menu ox_lib de `qbx_core` **et** notre sélecteur s’ouvriront en même temps.

Ne démarrez **pas** `qbx-multicharacter` / `qb-multicharacter` en parallèle.

## Flux

1. Connexion → écran **Sélection de personnage** (emplacements, infos, aperçu ped)
2. **Entrer en ville** → `exports.qbx_core:Login` puis spawn (appartements / qbx_spawn / spawn par défaut)
3. **Créer un personnage** → notre studio (identité + apparence)
4. Validation → Login Qbox + skins `playerskins` + `character_creator`
5. **Supprimer** → vérification de propriété (license) puis suppression

## Ordre de démarrage

```cfg
ensure oxmysql
ensure ox_lib
ensure qbx_core
ensure qbx-charactercreator
# optionnel
ensure qbx_spawn
ensure qbx_apartments
ensure qbx_weathersync
```

## Compatibilité événements

Les événements historiques de qbx-multicharacter sont écoutés :

- `qb-multicharacter:client:chooseChar`
- `qbx-charactercreator:client:chooseChar`

Après création, le spawn suit la même logique que qbx-multicharacter (`apartments:client:setupSpawnUI` ou spawn par défaut).

## illenium-appearance

L’aperçu des personnages existants lit `playerskins`. Si illenium est démarré, `setPedAppearance` est utilisé quand le skin est au format illenium.

`Config.ClothingSystem = 'illenium-appearance'` reste disponible pour le studio.

## Désactiver le sélecteur

```lua
Config.Multichar.Enabled = false
Config.Multichar.TakeOverSession = false
```

Le créateur reste utilisable via `/charcreator` et le hook `qb-clothes:client:CreateFirstCharacter`.
