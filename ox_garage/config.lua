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
    stored = '#3ecf8e', -- vert
    out    = '#f07178', -- rouge
}

-- Labels affichés
Config.StatusLabels = {
    stored = 'Rangé',
    out    = 'Sorti',
}
