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

-- Compte pour acheter un garage privé / places
Config.PrivatePayAccount = 'bank' -- 'bank' | 'money'

--[[
    Intégration Job Creator (garages entreprise)
    Les markers "garage" / "garage_store" du job_creator ouvrent
    les mêmes menus ox_lib que le garage perso.
]]
Config.JobCreator = {
    enabled = true,
    platePrefixLen = 3,
    resetOutOnRestart = false,
    -- Autoriser aussi les véhicules perso (owned_vehicles) dans les garages entreprise
    allowPersonalVehicles = true,
}

--[[
    Garages entreprise créés via commande / export
    /addjobgarage  — admin, à ta position
    /deljobgarage [id]
    /listjobgarages
]]
Config.JobGarages = {
    -- Groupe ESX autorisé pour les commandes (en plus de ace)
    adminGroups = { admin = true, superadmin = true, god = true },
    -- Blip défaut des garages entreprise dynamiques
    defaultBlip = { enabled = true, sprite = 357, color = 47, scale = 0.7 },
    defaultStoreRadius = 10.0,
    defaultTargetRadius = 2.2,
    -- Offset des points de spawn générés devant le joueur
    spawnForward = 4.0,
    spawnSide = 3.0,
}

--[[
    Garages personnels
    kind = 'public'  → 1 seul garage gratuit (blip jaune)
    kind = 'private' → payant selon la place (prix + places)
]]
Config.Garages = {
    -- ═══════════════════════════════════════════
    -- GARAGE PUBLIC (gratuit) — blip jaune
    -- ═══════════════════════════════════════════
    {
        id = 'legion',
        kind = 'public',
        label = 'Garage Public — Legion',
        type = 'car',
        blip = { enabled = true, sprite = 357, color = 5, scale = 0.85 }, -- 5 = jaune
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

    -- ═══════════════════════════════════════════
    -- GARAGES PRIVÉS (payants selon la place)
    -- price        = accès + places incluses
    -- pricePerSlot = place supplémentaire
    -- slots        = places à l'achat
    -- maxSlots     = plafond achetable
    -- ═══════════════════════════════════════════
    {
        id = 'pinkcage',
        kind = 'private',
        label = 'Garage Privé — Pink Cage',
        type = 'car',
        price = 15000,
        pricePerSlot = 5000,
        slots = 1,
        maxSlots = 4,
        blip = { enabled = true, sprite = 357, color = 3, scale = 0.7 },
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
        kind = 'private',
        label = 'Garage Privé — Aéroport',
        type = 'car',
        price = 35000,
        pricePerSlot = 10000,
        slots = 2,
        maxSlots = 6,
        blip = { enabled = true, sprite = 357, color = 3, scale = 0.7 },
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
    {
        id = 'mirror',
        kind = 'private',
        label = 'Garage Privé — Mirror Park',
        type = 'car',
        price = 22000,
        pricePerSlot = 7000,
        slots = 1,
        maxSlots = 5,
        blip = { enabled = true, sprite = 357, color = 3, scale = 0.7 },
        coords = vec3(1036.25, -763.18, 57.99),
        target = {
            coords = vec3(1036.25, -763.18, 57.99),
            radius = 2.0,
            debug = false,
        },
        store = {
            coords = vec3(1036.25, -763.18, 57.99),
            radius = 8.0,
        },
        spawns = {
            vec4(1029.70, -763.90, 57.90, 145.0),
            vec4(1026.40, -761.20, 57.90, 145.0),
        },
    },
    {
        id = 'sandy',
        kind = 'private',
        label = 'Garage Privé — Sandy Shores',
        type = 'car',
        price = 12000,
        pricePerSlot = 4000,
        slots = 1,
        maxSlots = 3,
        blip = { enabled = true, sprite = 357, color = 3, scale = 0.7 },
        coords = vec3(1737.59, 3710.20, 34.14),
        target = {
            coords = vec3(1737.59, 3710.20, 34.14),
            radius = 2.2,
            debug = false,
        },
        store = {
            coords = vec3(1737.59, 3710.20, 34.14),
            radius = 10.0,
        },
        spawns = {
            vec4(1732.80, 3714.50, 34.00, 20.0),
            vec4(1728.50, 3716.10, 34.00, 20.0),
        },
    },
    {
        id = 'paleto',
        kind = 'private',
        label = 'Garage Privé — Paleto Bay',
        type = 'car',
        price = 18000,
        pricePerSlot = 6000,
        slots = 1,
        maxSlots = 4,
        blip = { enabled = true, sprite = 357, color = 3, scale = 0.7 },
        coords = vec3(107.87, 6613.27, 31.98),
        target = {
            coords = vec3(107.87, 6613.27, 31.98),
            radius = 2.2,
            debug = false,
        },
        store = {
            coords = vec3(107.87, 6613.27, 31.98),
            radius = 10.0,
        },
        spawns = {
            vec4(114.20, 6608.50, 31.85, 225.0),
            vec4(118.10, 6605.40, 31.85, 225.0),
        },
    },
}

-- Icônes FontAwesome selon la classe véhicule
Config.ClassIcons = {
    [0]  = 'car',
    [1]  = 'car',
    [2]  = 'car-side',
    [3]  = 'car',
    [4]  = 'car',
    [5]  = 'car',
    [6]  = 'gauge-high',
    [7]  = 'rocket',
    [8]  = 'motorcycle',
    [9]  = 'truck-monster',
    [10] = 'truck',
    [11] = 'truck',
    [12] = 'van-shuttle',
    [13] = 'bicycle',
    [14] = 'ship',
    [15] = 'helicopter',
    [16] = 'plane',
    [17] = 'bus',
    [18] = 'truck-medical',
    [19] = 'tank',
    [20] = 'truck',
    [21] = 'train',
}

Config.StatusColors = {
    stored  = '#3ecf8e',
    out     = '#f07178',
    impound = '#e6b35a',
}

Config.StatusLabels = {
    stored  = 'Rangé',
    out     = 'Sorti',
    impound = 'Fourrière',
}

--[[--------------------------------------------------------------------------
    Fourrières
--------------------------------------------------------------------------]]
Config.Impound = {
    enabled = true,
    progressDuration = 3500,
    payAccount = 'bank',
}

Config.Impounds = {
    {
        id = 'impound_public',
        label = 'Fourrière Générale',
        kind = 'public',
        jobs = { ['police'] = 0, ['sheriff'] = 0 },
        ownerCanRetrieve = true,
        retrieveJobs = { ['police'] = 0 },
        price = 1500,
        society = 'society_police',
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
