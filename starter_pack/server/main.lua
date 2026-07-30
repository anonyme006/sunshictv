local ESX = exports['es_extended']:getSharedObject()

---@type table<number, boolean>
local spinning = {}

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

---@param xPlayer table
local function giveStarterItems(xPlayer)
    for _, item in ipairs(Config.StarterItems) do
        xPlayer.addInventoryItem(item.name, item.count)
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

        giveStarterItems(xPlayer)

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
        if not item or (item.count or 0) < 1 then
            notify(src, Config.Locale.no_card)
            return
        end

        spinning[src] = true
        TriggerClientEvent('starter_pack:openChanceCard', src, Config.ChanceCard.wheel)
    end)

    --- Item BMX → spawn véhicule
    ESX.RegisterUsableItem('bmx', function(source)
        local src = source
        local xPlayer = ESX.GetPlayerFromId(src)
        if not xPlayer then return end

        local item = xPlayer.getInventoryItem('bmx')
        if not item or (item.count or 0) < 1 then
            return
        end

        xPlayer.removeInventoryItem('bmx', 1)
        TriggerClientEvent('starter_pack:spawnBmx', src)
    end)
end)

--- Résultat du spin (validé côté serveur)
RegisterNetEvent('starter_pack:claimSpin', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    if not spinning[src] then
        return
    end

    local item = xPlayer.getInventoryItem(Config.ChanceCard.item)
    if not item or (item.count or 0) < 1 then
        spinning[src] = nil
        notify(src, Config.Locale.no_card)
        TriggerClientEvent('starter_pack:spinResult', src, { success = false, amount = 0, error = true })
        return
    end

    xPlayer.removeInventoryItem(Config.ChanceCard.item, 1)

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
    spinning[source] = nil
end)

ESX.RegisterCommand('givekit', 'admin', function(xPlayer)
    local src = xPlayer.source
    giveStarterItems(xPlayer)
    if Config.SpawnBmxVehicle then
        TriggerClientEvent('starter_pack:spawnBmx', src)
    end
    notify(src, Config.Locale.kit_received)
end, false, { help = 'Donner le kit d\'arrivée (admin)' })

print('^2[starter_pack]^0 ressource chargée.')
