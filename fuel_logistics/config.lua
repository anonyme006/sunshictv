Config = {}

Config.Locale = 'fr'
Config.Debug = false

--[[--------------------------------------------------------------------------
    Job / Société
--------------------------------------------------------------------------]]
Config.JobName = 'fuel_logistics'
Config.JobLabel = 'Fuel Logistics'
Config.SocietyAccount = 'society_fuel_logistics' -- addon_account

Config.Grades = {
    { grade = 0, name = 'trainee',   label = 'Stagiaire',     salary = 150, permissions = { harvest = true, refine = true, deliver = true } },
    { grade = 1, name = 'employee',  label = 'Employé',       salary = 250, permissions = { harvest = true, refine = true, deliver = true, export = true, stash = true } },
    { grade = 2, name = 'senior',    label = 'Confirmé',      salary = 350, permissions = { harvest = true, refine = true, deliver = true, export = true, stash = true, orders = true } },
    { grade = 3, name = 'manager',   label = 'Manager',       salary = 450, permissions = { ['*'] = true } },
    { grade = 4, name = 'boss',      label = 'Patron',        salary = 550, permissions = { ['*'] = true } },
}

Config.AdminGroups = { admin = true, superadmin = true, god = true }

--[[--------------------------------------------------------------------------
    Items (ox_inventory)
--------------------------------------------------------------------------]]
Config.Items = {
    crudeOil      = 'crude_oil',       -- pétrole brut
    fuelBarrel    = 'fuel_barrel',     -- baril de carburant
    fuelCan       = 'fuel_can',        -- bidon
    hose          = 'fuel_hose',       -- flexible
    deliveryDoc   = 'delivery_doc',    -- documents livraison
    invoice       = 'fuel_invoice',    -- facture
}

-- Quantités / conversion
Config.Harvest = {
    rewardItem = 'crude_oil',
    rewardMin = 1,
    rewardMax = 3,
    duration = 6000,
    anim = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer', flag = 1 },
    cooldown = 2000,
}

Config.Refine = {
    inputItem = 'crude_oil',
    inputCount = 5,
    outputItem = 'fuel_barrel',
    outputCount = 1,          -- rendement (configurable)
    duration = 10000,
    anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 1 },
}

-- 1 fuel_barrel = X litres livrables
Config.BarrelLiters = 50

--[[--------------------------------------------------------------------------
    Points de récolte
--------------------------------------------------------------------------]]
Config.HarvestPoints = {
    {
        id = 'refinery_north',
        label = 'Raffinerie Nord',
        coords = vec3(2736.95, 1417.82, 24.49),
        radius = 2.0,
        blip = { enabled = true, sprite = 436, color = 5, scale = 0.7 },
    },
    {
        id = 'refinery_south',
        label = 'Raffinerie Sud',
        coords = vec3(2763.45, 1481.12, 30.79),
        radius = 2.0,
        blip = { enabled = true, sprite = 436, color = 5, scale = 0.7 },
    },
    {
        id = 'oil_depot',
        label = 'Dépôt pétrolier',
        coords = vec3(558.93, -2310.55, 5.88),
        radius = 2.2,
        blip = { enabled = true, sprite = 436, color = 5, scale = 0.7 },
    },
}

--[[--------------------------------------------------------------------------
    Raffinerie / HQ
--------------------------------------------------------------------------]]
Config.RefinePoint = {
    label = 'Usine de raffinage',
    coords = vec3(2772.55, 1488.20, 24.52),
    radius = 2.0,
    blip = { enabled = true, sprite = 365, color = 17, scale = 0.8 },
}

Config.BossMenu = {
    coords = vec3(2764.20, 1492.80, 24.52),
    radius = 1.5,
}

Config.Stash = {
    id = 'fuel_logistics_warehouse',
    label = 'Entrepôt Fuel Logistics',
    slots = 80,
    weight = 500000,
    coords = vec3(2768.10, 1490.50, 24.52),
    radius = 1.5,
}

Config.Cloakroom = {
    coords = vec3(2760.50, 1490.10, 24.52),
    radius = 1.5,
}

--[[--------------------------------------------------------------------------
    Camion citerne / livraison
--------------------------------------------------------------------------]]
Config.Delivery = {
    truckModel = `packer`,          -- ou `phantom` / custom tanker
    trailerModel = `tanker`,
    truckSpawn = vec4(2778.40, 1500.20, 24.50, 250.0),
    maxLoadBarrels = 10,            -- barils max par tournée
    deliverDuration = 8000,
    anim = { dict = 'timetable@gardener@filling_can', clip = 'gar_ig_5_filling_can', flag = 1 },
    requireHose = true,
    requireDoc = false,
    paymentPerLiter = 8,            -- $ versés à la société par litre livré
    companyPaymentPerLiter = 12,    -- livraison cuve entreprise privée
}

Config.Garage = {
    coords = vec3(2775.80, 1498.00, 24.50),
    radius = 2.0,
    label = 'Garage citerne',
}

--[[--------------------------------------------------------------------------
    Export
--------------------------------------------------------------------------]]
Config.Export = {
    coords = vec3(1207.35, -3115.85, 5.54),
    radius = 2.5,
    blip = { enabled = true, sprite = 478, color = 2, scale = 0.75 },
    item = 'fuel_barrel',
    minBarrels = 1,
    pricePerBarrel = 450,
    duration = 7000,
    anim = { dict = 'mp_common', clip = 'givetake1_a', flag = 1 },
}

--[[--------------------------------------------------------------------------
    Stations (seed initial — aussi créables in-game)
--------------------------------------------------------------------------]]
Config.DefaultStations = {
    {
        name = 'Station Grove Street',
        coords = vec3(-70.95, -1761.80, 29.53),
        capacity = 5000,
        level = 2500,
        buyPrice = 6,           -- prix d'achat litre (station → FL)
        consumption = 2.5,      -- litres consommés / minute (serveur)
        owner_job = nil,
    },
    {
        name = 'Station Route 68',
        coords = vec3(1039.30, 2671.20, 39.55),
        capacity = 6000,
        level = 3000,
        buyPrice = 6,
        consumption = 2.0,
        owner_job = nil,
    },
    {
        name = 'Station Mirror Park',
        coords = vec3(1181.40, -330.75, 69.18),
        capacity = 4500,
        level = 2000,
        buyPrice = 7,
        consumption = 2.2,
        owner_job = nil,
    },
}

--[[--------------------------------------------------------------------------
    Cuves entreprises (achetables)
--------------------------------------------------------------------------]]
Config.CompanyTanks = {
    purchasePrice = 25000,          -- prix d'achat cuve
    defaultCapacity = 2000,
    minGradeToBuy = 0,              -- grade boss de l'autre job (géré via menu boss FL ou commande)
}

-- Jobs pouvant avoir une cuve (seed / exemples)
Config.AllowedCompanyJobs = {
    'mechanic', 'cardealer', 'taxi', 'police', 'ambulance', 'airport',
}

--[[--------------------------------------------------------------------------
    Commandes automatiques
--------------------------------------------------------------------------]]
Config.AutoOrders = {
    enabled = true,
    thresholdPercent = 20,          -- sous 20% → commande auto
    checkInterval = 120000,         -- ms
    defaultLiters = 800,
    notifyEmployees = true,
    expireMinutes = 45,
    bonusPayment = 500,             -- bonus société à la clôture
}

--[[--------------------------------------------------------------------------
    Consommation stations (tick serveur)
--------------------------------------------------------------------------]]
Config.ConsumptionTick = 60000 -- chaque minute

--[[--------------------------------------------------------------------------
    Blips job
--------------------------------------------------------------------------]]
Config.JobBlip = {
    enabled = true,
    coords = vec3(2764.20, 1492.80, 24.52),
    sprite = 361,
    color = 17,
    scale = 0.9,
    label = 'Fuel Logistics',
}
