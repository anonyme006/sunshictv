Config = {}

Config.Locale = 'fr'

-- Distance max pour ranger (joueur dans son véhicule près du point)
Config.StoreDistance = 8.0

-- Durées progress bar (ms)
Config.ProgressSpawn = 2500
Config.ProgressStore = 2000

-- Colonnes SQL owned_vehicles (adapte si besoin)
Config.Columns = {
    table = 'owned_vehicles',
    owner = 'owner',
    plate = 'plate',
    vehicle = 'vehicle',
    stored = 'stored',   -- 1 = rangé, 0 = sorti
    garage = 'parking',  -- nom du garage (nullable sur certains bases)
    type = 'type',       -- car / boat / aircraft
}

-- Si ta table n'a pas de colonne parking, mets false
Config.UseGarageColumn = true

-- Types acceptés par défaut pour un garage "car"
Config.DefaultType = 'car'

-- Carburant : lit fuelLevel des props, sinon LegacyFuel / ox_fuel state bag
Config.FuelResource = 'none' -- 'ox_fuel' | 'LegacyFuel' | 'none'

-- Spawn : vérifie qu'aucune collision n'occupe le point
Config.CheckSpawnClear = true

--[[
    Intégration Job Creator (garages entreprise)
    Les markers "garage" / "garage_store" du job_creator ouvrent
    les mêmes menus ox_lib que le garage perso.
]]
Config.JobCreator = {
    enabled = true,
    -- Préfixe plaques flotte (ex: POL + 001 → POL001)
    platePrefixLen = 3,
    -- Remettre stored=1 au restart serveur pour toute la flotte sortie
    resetOutOnRestart = false,
}

--[[
    Liste des garages
    target = zone ox_target (sphere / box)
    spawns = points de sortie (vector4)
]]
Config.Garages = {
    {
        id = 'legion',
        label = 'Garage Legion Square',
        type = 'car',
        blip = { enabled = true, sprite = 357, color = 3, scale = 0.75 },
        coords = vec3(215.83, -810.14, 30.73),
        target = {
            coords = vec3(215.83, -810.14, 30.73),
            radius = 2.0,
            debug = false,
        },
        store = {
            coords = vec3(215.83, -810.14, 30.73),
            radius = 8.0,
        },
        spawns = {
            vec4(222.25, -804.13, 30.58, 248.0),
            vec4(223.85, -799.12, 30.58, 248.0),
            vec4(225.45, -794.10, 30.58, 248.0),
        },
    },
    {
        id = 'pinkcage',
        label = 'Garage Pink Cage',
        type = 'car',
        blip = { enabled = true, sprite = 357, color = 3, scale = 0.75 },
        coords = vec3(273.0, -343.85, 44.92),
        target = {
            coords = vec3(273.0, -343.85, 44.92),
            radius = 2.0,
            debug = false,
        },
        store = {
            coords = vec3(273.0, -343.85, 44.92),
            radius = 8.0,
        },
        spawns = {
            vec4(270.94, -340.83, 44.58, 340.0),
            vec4(276.54, -342.76, 44.58, 340.0),
        },
    },
    {
        id = 'airport',
        label = 'Garage Aéroport',
        type = 'car',
        blip = { enabled = true, sprite = 357, color = 3, scale = 0.75 },
        coords = vec3(-1030.0, -2730.0, 20.1),
        target = {
            coords = vec3(-1030.0, -2730.0, 20.1),
            radius = 2.2,
            debug = false,
        },
        store = {
            coords = vec3(-1030.0, -2730.0, 20.1),
            radius = 10.0,
        },
        spawns = {
            vec4(-1024.5, -2728.8, 19.7, 240.0),
            vec4(-1020.2, -2731.5, 19.7, 240.0),
        },
    },
}

-- Icônes FontAwesome selon la classe véhicule
Config.ClassIcons = {
    [0]  = 'car',           -- Compacts
    [1]  = 'car',           -- Sedans
    [2]  = 'car-side',      -- SUVs
    [3]  = 'car',           -- Coupes
    [4]  = 'car',           -- Muscle
    [5]  = 'car',           -- Sports Classics
    [6]  = 'gauge-high',    -- Sports
    [7]  = 'rocket',        -- Super
    [8]  = 'motorcycle',    -- Motorcycles
    [9]  = 'truck-monster', -- Off-road
    [10] = 'truck',         -- Industrial
    [11] = 'truck',         -- Utility
    [12] = 'van-shuttle',   -- Vans
    [13] = 'bicycle',       -- Cycles
    [14] = 'ship',          -- Boats
    [15] = 'helicopter',    -- Helicopters
    [16] = 'plane',         -- Planes
    [17] = 'bus',           -- Service
    [18] = 'truck-medical', -- Emergency
    [19] = 'tank',          -- Military
    [20] = 'truck',         -- Commercial
    [21] = 'train',         -- Trains
}

-- Couleurs statut (ox_lib iconColor)
Config.StatusColors = {
    stored  = '#3ecf8e', -- vert
    out     = '#f07178', -- rouge
    impound = '#e6b35a', -- orange / fourrière
}

-- Labels affichés
Config.StatusLabels = {
    stored  = 'Rangé',
    out     = 'Sorti',
    impound = 'Fourrière',
}

--[[--------------------------------------------------------------------------
    Fourrières
    - public   : fourrière générale (police / ville) — le propriétaire récupère contre paiement
    - mechanic : fourrière mécano — mise en fourrière par le job mechanic
--------------------------------------------------------------------------]]
Config.Impound = {
    enabled = true,
    progressDuration = 3500,
    -- Compte pour payer : 'money' (cash) ou 'bank'
    payAccount = 'bank',
}

Config.Impounds = {
    {
        id = 'impound_public',
        label = 'Fourrière Générale',
        kind = 'public', -- public | mechanic
        -- Jobs autorisés à METTRE un véhicule en fourrière
        jobs = { ['police'] = 0, ['sheriff'] = 0 },
        -- Le propriétaire peut récupérer lui-même
        ownerCanRetrieve = true,
        -- Jobs qui peuvent aussi sortir n'importe quel véhicule (ex: police)
        retrieveJobs = { ['police'] = 0 },
        price = 1500,
        society = 'society_police', -- nil = argent disparu / caisse ville
        blip = { enabled = true, sprite = 67, color = 1, scale = 0.75 },
        coords = vec3(409.32, -1622.94, 29.29),
        target = {
            coords = vec3(409.32, -1622.94, 29.29),
            radius = 2.2,
            debug = false,
        },
        store = {
            coords = vec3(409.32, -1622.94, 29.29),
            radius = 10.0,
        },
        spawns = {
            vec4(401.45, -1631.70, 29.29, 320.0),
            vec4(404.80, -1642.15, 29.29, 320.0),
            vec4(416.10, -1628.40, 29.29, 140.0),
        },
    },
    {
        id = 'impound_mechanic',
        label = 'Fourrière Mécano',
        kind = 'mechanic',
        jobs = { ['mechanic'] = 0 },
        ownerCanRetrieve = true,
        retrieveJobs = { ['mechanic'] = 0 },
        price = 800,
        society = 'society_mechanic',
        blip = { enabled = true, sprite = 446, color = 5, scale = 0.75 },
        coords = vec3(-182.55, -1306.80, 31.30),
        target = {
            coords = vec3(-182.55, -1306.80, 31.30),
            radius = 2.2,
            debug = false,
        },
        store = {
            coords = vec3(-182.55, -1306.80, 31.30),
            radius = 12.0,
        },
        spawns = {
            vec4(-178.20, -1300.40, 31.30, 270.0),
            vec4(-178.20, -1295.10, 31.30, 270.0),
            vec4(-189.50, -1302.80, 31.30, 90.0),
        },
    },
}

