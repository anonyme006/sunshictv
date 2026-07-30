local ESX = exports['es_extended']:getSharedObject()

---@type table<number, boolean>
local spinning = {}

--- BMX sortis : src -> { [netId] = true }
---@type table<number, table<number, boolean>>
local spawnedBmx = {}

---@type table<number, boolean>
local storing = {}

---@param identifier string
---@return boolean
local function hasReceivedKit(identifier)
    local row = MySQL.single.await(
        'SELECT 1 AS ok FROM starter_pack_claims WHERE identifier = ? LIMIT 1',
        { identifier }
    )
    return row ~= nil
end

---@param identifier string
local function markKitReceived(identifier)
    MySQL.insert.await(
        'INSERT INTO starter_pack_claims (identifier, claimed_at) VALUES (?, NOW())',
        { identifier }
    )
end

---@param src number
---@param msg string
local function notify(src, msg)
    TriggerClientEvent('esx:showNotification', src, msg)
end

local function addInventoryItem(xPlayer, src, item, count)
    if Config.Inventory == 'ox' and GetResourceState('ox_inventory') == 'started' then
        if exports.ox_inventory:CanCarryItem(src, item, count) == false then
            return false
        end
        return exports.ox_inventory:AddItem(src, item, count) and true or false
    end

    if xPlayer.canCarryItem and not xPlayer.canCarryItem(item, count) then
        return false
    end
    xPlayer.addInventoryItem(item, count)
    return true
end

local function removeInventoryItem(xPlayer, src, item, count)
    if Config.Inventory == 'ox' and GetResourceState('ox_inventory') == 'started' then
        local have = exports.ox_inventory:GetItemCount(src, item) or 0
        if have < count then return false end
        return exports.ox_inventory:RemoveItem(src, item, count) and true or false
    end
    local inv = xPlayer.getInventoryItem(item)
    if not inv or (inv.count or 0) < count then
        return false
    end
    xPlayer.removeInventoryItem(item, count)
    return true
end

---@param xPlayer table
local function giveStarterItems(xPlayer)
    for _, item in ipairs(Config.StarterItems) do
        xPlayer.addInventoryItem(item.name, item.count)
    end
end

---@return string
local function generatePlate()
    local cfg = Config.GarageVehicle or {}
    local prefix = tostring(cfg.platePrefix or 'ST'):upper():gsub('%s+', '')
    if #prefix > 4 then
        prefix = prefix:sub(1, 4)
    end

    local charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local remain = math.max(1, 8 - #prefix)
    local suffix = ''
    for _ = 1, remain do
        local i = math.random(1, #charset)
        suffix = suffix .. charset:sub(i, i)
    end

    return (prefix .. suffix):sub(1, 8)
end

---@param plate string
---@return boolean
local function plateExists(plate)
    local cfg = Config.GarageVehicle
    local tbl = cfg.table or 'owned_vehicles'
    local plateCol = (cfg.columns and cfg.columns.plate) or 'plate'
    local row = MySQL.single.await(
        ('SELECT 1 AS ok FROM `%s` WHERE REPLACE(UPPER(`%s`), " ", "") = ? LIMIT 1'):format(tbl, plateCol),
        { (plate or ''):gsub('%s+', ''):upper() }
    )
    return row ~= nil
end

--- Ajoute un véhicule aléatoire rangé dans le garage du joueur (owned_vehicles).
---@param xPlayer table
---@return string|nil modelName, string|nil plate
local function giveStarterGarageVehicle(xPlayer)
    local cfg = Config.GarageVehicle
    if not cfg or not cfg.enabled then
        return nil, nil
    end

    local models = cfg.models
    if type(models) ~= 'table' or #models == 0 then
        return nil, nil
    end

    local modelName = models[math.random(1, #models)]
    if type(modelName) ~= 'string' or modelName == '' then
        return nil, nil
    end

    local modelHash = joaat(modelName)
    local plate
    for _ = 1, 30 do
        local candidate = generatePlate()
        if not plateExists(candidate) then
            plate = candidate
            break
        end
    end

    if not plate then
        print(('^1[starter_pack]^0 impossible de générer une plaque unique pour %s'):format(xPlayer.identifier))
        return nil, nil
    end

    local props = {
        model = modelHash,
        plate = plate,
        engineHealth = 1000.0,
        bodyHealth = 1000.0,
        fuelLevel = 100.0,
    }

    local cols = cfg.columns or {}
    local tbl = cfg.table or 'owned_vehicles'
    local ownerCol = cols.owner or 'owner'
    local plateCol = cols.plate or 'plate'
    local vehicleCol = cols.vehicle or 'vehicle'
    local storedCol = cols.stored or 'stored'
    local typeCol = cols.type or 'type'
    local parkingCol = cols.parking
    local useParking = parkingCol and parkingCol ~= false
    local stored = cfg.stored
    if stored == nil then stored = 1 end
    local vehicleType = cfg.vehicleType or 'car'
    local garageId = cfg.garageId or 'legion'
    local vehicleJson = json.encode(props)

    local ok, err = pcall(function()
        if useParking then
            MySQL.insert.await(
                ('INSERT INTO `%s` (`%s`, `%s`, `%s`, `%s`, `%s`, `%s`) VALUES (?, ?, ?, ?, ?, ?)'):format(
                    tbl, ownerCol, plateCol, vehicleCol, storedCol, parkingCol, typeCol
                ),
                { xPlayer.identifier, plate, vehicleJson, stored, garageId, vehicleType }
            )
        else
            MySQL.insert.await(
                ('INSERT INTO `%s` (`%s`, `%s`, `%s`, `%s`, `%s`) VALUES (?, ?, ?, ?, ?)'):format(
                    tbl, ownerCol, plateCol, vehicleCol, storedCol, typeCol
                ),
                { xPlayer.identifier, plate, vehicleJson, stored, vehicleType }
            )
        end
    end)

    if not ok then
        print(('^1[starter_pack]^0 insert véhicule échoué: %s'):format(tostring(err)))
        return nil, nil
    end

    return modelName, plate
end

---@param src number
---@param xPlayer table
---@param withVehicle boolean|nil
local function deliverKit(src, xPlayer, withVehicle)
    giveStarterItems(xPlayer)

    if withVehicle ~= false then
        local modelName, plate = giveStarterGarageVehicle(xPlayer)
        if modelName and plate then
            notify(src, (Config.Locale.vehicle_received):format(modelName, plate))
        elseif Config.GarageVehicle and Config.GarageVehicle.enabled then
            notify(src, Config.Locale.vehicle_failed)
        end
    end
end

---@return number reward amount (0 if fail)
local function rollReward()
    local cfg = Config.ChanceCard

    if math.random() > cfg.successRate then
        return 0
    end

    local totalWeight = 0
    for _, seg in ipairs(cfg.wheel) do
        totalWeight = totalWeight + seg.weight
    end

    local roll = math.random() * totalWeight
    local cumulative = 0

    for _, seg in ipairs(cfg.wheel) do
        cumulative = cumulative + seg.weight
        if roll <= cumulative then
            return seg.amount
        end
    end

    return cfg.minReward
end

---@param src number
---@param xPlayer table
local function tryGiveKit(src, xPlayer)
    if not xPlayer then return end

    local identifier = xPlayer.identifier

    CreateThread(function()
        Wait(Config.GiveDelay)

        xPlayer = ESX.GetPlayerFromId(src)
        if not xPlayer then return end

        if Config.GiveOnlyOnce and hasReceivedKit(identifier) then
            return
        end

        deliverKit(src, xPlayer, true)

        if Config.GiveOnlyOnce then
            markKitReceived(identifier)
        end

        if Config.NotifyOnReceive then
            notify(src, Config.Locale.kit_received)
        end

        if Config.SpawnBmxVehicle then
            TriggerClientEvent('starter_pack:spawnBmx', src)
        end
    end)
end

MySQL.ready(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS starter_pack_claims (
            identifier VARCHAR(60) NOT NULL PRIMARY KEY,
            claimed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
    ]])
end)

--- Kit d'arrivée (ESX Legacy)
AddEventHandler('esx:playerLoaded', function(playerId, xPlayer, _isNew)
    local src = playerId
    if type(xPlayer) ~= 'table' then
        xPlayer = ESX.GetPlayerFromId(src)
    end
    tryGiveKit(src, xPlayer)
end)

CreateThread(function()
    Wait(500)

    --- Carte Chance
    ESX.RegisterUsableItem(Config.ChanceCard.item, function(source)
        local src = source
        local xPlayer = ESX.GetPlayerFromId(src)
        if not xPlayer then return end

        if spinning[src] then
            notify(src, Config.Locale.already_spinning)
            return
        end

        local item = xPlayer.getInventoryItem(Config.ChanceCard.item)
        if Config.Inventory == 'ox' and GetResourceState('ox_inventory') == 'started' then
            local count = exports.ox_inventory:GetItemCount(src, Config.ChanceCard.item) or 0
            if count < 1 then
                notify(src, Config.Locale.no_card)
                return
            end
        elseif not item or (item.count or 0) < 1 then
            notify(src, Config.Locale.no_card)
            return
        end

        spinning[src] = true
        TriggerClientEvent('starter_pack:openChanceCard', src, Config.ChanceCard.wheel)
    end)

    --- Item BMX → spawn véhicule
    local bmxItem = Config.BmxItem or 'bmx'
    ESX.RegisterUsableItem(bmxItem, function(source)
        local src = source
        local xPlayer = ESX.GetPlayerFromId(src)
        if not xPlayer then return end

        if not removeInventoryItem(xPlayer, src, bmxItem, 1) then
            return
        end

        TriggerClientEvent('starter_pack:spawnBmx', src)
    end)
end)

--- Enregistre un BMX spawné (anti-dupe au rangement)
RegisterNetEvent('starter_pack:registerBmx', function(netId)
    local src = source
    netId = tonumber(netId)
    if not netId then return end
    spawnedBmx[src] = spawnedBmx[src] or {}
    spawnedBmx[src][netId] = true
end)

--- Ranger le BMX → item inventaire
RegisterNetEvent('starter_pack:storeBmx', function(netId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    netId = tonumber(netId)

    local function respond(payload)
        TriggerClientEvent('starter_pack:storeBmxResult', src, payload, netId)
    end

    if not xPlayer or not netId then
        return respond({ ok = false, error = 'invalid' })
    end

    if storing[src] then
        return respond({ ok = false, error = 'busy' })
    end

    -- Vérifie que ce BMX vient du starter_pack
    local owned = spawnedBmx[src] and spawnedBmx[src][netId]
    local entity = NetworkGetEntityFromNetworkId(netId)
    local stateOk = false

    if entity and entity ~= 0 and DoesEntityExist(entity) then
        local ped = GetPlayerPed(src)
        local dist = #(GetEntityCoords(ped) - GetEntityCoords(entity))
        local maxDist = (Config.BmxTarget and Config.BmxTarget.distance or 2.5) + 3.0
        if dist > maxDist then
            return respond({ ok = false, error = 'distance' })
        end

        if GetEntityModel(entity) ~= Config.BmxModel then
            return respond({ ok = false, error = 'invalid' })
        end

        local st = Entity(entity).state
        stateOk = st and st.starter_pack_bmx == true
    end

    if not owned and not stateOk then
        return respond({ ok = false, error = 'invalid' })
    end

    storing[src] = true

    local item = Config.BmxItem or 'bmx'
    local added = addInventoryItem(xPlayer, src, item, 1)
    if not added then
        storing[src] = nil
        return respond({ ok = false, error = 'inventory' })
    end

    if spawnedBmx[src] then
        spawnedBmx[src][netId] = nil
    end

    -- Supprime l'entité côté serveur si possible
    if entity and entity ~= 0 and DoesEntityExist(entity) then
        DeleteEntity(entity)
    end

    storing[src] = nil
    respond({ ok = true })
end)

--- Résultat du spin (validé côté serveur)
RegisterNetEvent('starter_pack:claimSpin', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    if not spinning[src] then
        return
    end

    local cardItem = Config.ChanceCard.item
    local hasCard = false
    if Config.Inventory == 'ox' and GetResourceState('ox_inventory') == 'started' then
        hasCard = (exports.ox_inventory:GetItemCount(src, cardItem) or 0) >= 1
    else
        local item = xPlayer.getInventoryItem(cardItem)
        hasCard = item and (item.count or 0) >= 1
    end

    if not hasCard then
        spinning[src] = nil
        notify(src, Config.Locale.no_card)
        TriggerClientEvent('starter_pack:spinResult', src, { success = false, amount = 0, error = true })
        return
    end

    removeInventoryItem(xPlayer, src, cardItem, 1)

    local amount = rollReward()
    local success = amount > 0

    if success then
        xPlayer.addAccountMoney(Config.ChanceCard.account, amount, 'Carte Chance')
        local digits = amount
        if ESX.Math and ESX.Math.GroupDigits then
            digits = ESX.Math.GroupDigits(amount)
        end
        notify(src, (Config.Locale.spin_success):format(digits))
    else
        notify(src, Config.Locale.spin_fail)
    end

    spinning[src] = nil
    TriggerClientEvent('starter_pack:spinResult', src, {
        success = success,
        amount = amount,
    })
end)

RegisterNetEvent('starter_pack:cancelSpin', function()
    spinning[source] = nil
end)

AddEventHandler('playerDropped', function()
    local src = source
    spinning[src] = nil
    storing[src] = nil
    spawnedBmx[src] = nil
end)

ESX.RegisterCommand('givekit', 'admin', function(xPlayer)
    local src = xPlayer.source
    local giveVehicle = Config.GarageVehicle
        and Config.GarageVehicle.enabled
        and Config.GarageVehicle.giveOnAdminKit ~= false
    deliverKit(src, xPlayer, giveVehicle)
    if Config.SpawnBmxVehicle then
        TriggerClientEvent('starter_pack:spawnBmx', src)
    end
    notify(src, Config.Locale.kit_received)
end, false, { help = 'Donner le kit d\'arrivée (admin)' })

print('^2[starter_pack]^0 ressource chargée.')
