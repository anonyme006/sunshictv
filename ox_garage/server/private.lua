--[[
    Garages privés — achat d'accès / places
]]

local ESX = exports['es_extended']:getSharedObject()

local function _(key, ...)
    local str = Locales[Config.Locale] and Locales[Config.Locale][key] or key
    if select('#', ...) > 0 then return str:format(...) end
    return str
end

MySQL.ready(function()
    local sql = LoadResourceFile(GetCurrentResourceName(), 'sql/private_access.sql')
    if sql then
        for statement in sql:gmatch('([^;]+);') do
            local trimmed = statement:gsub('^%s+', ''):gsub('%s+$', '')
            if trimmed ~= '' then
                MySQL.query.await(trimmed)
            end
        end
    end
end)

function IsPrivateGarage(garage)
    return garage and garage.kind == 'private'
end

function IsPublicGarage(garage)
    return not garage or not garage.kind or garage.kind == 'public'
end

function GetPrivateGarageIds()
    local ids = {}
    for _, g in ipairs(Config.Garages or {}) do
        if g.kind == 'private' then
            ids[g.id] = true
        end
    end
    return ids
end

---@param identifier string
---@param garageId string
---@return table|nil
function GetPrivateAccess(identifier, garageId)
    return MySQL.single.await(
        'SELECT * FROM ox_garage_private_access WHERE identifier = ? AND garage_id = ? LIMIT 1',
        { identifier, garageId }
    )
end

---@param identifier string
---@param garageId string
---@return number
function CountVehiclesInGarage(identifier, garageId)
    local tbl = Config.Columns.table
    local ownerCol = Config.Columns.owner
    local garageCol = Config.Columns.garage
    local row = MySQL.single.await(
        ('SELECT COUNT(*) AS c FROM `%s` WHERE `%s` = ? AND `%s` = ?'):format(tbl, ownerCol, garageCol),
        { identifier, garageId }
    )
    return (row and tonumber(row.c)) or 0
end

local function formatPrice(n)
    n = tonumber(n) or 0
    if ESX.Math and ESX.Math.GroupDigits then
        return ESX.Math.GroupDigits(n)
    end
    return tostring(n)
end

lib.callback.register('ox_garage:getPrivateInfo', function(source, garageId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return nil end

    local garage
    for _, g in ipairs(Config.Garages) do
        if g.id == garageId then garage = g break end
    end
    if not garage or not IsPrivateGarage(garage) then
        return { kind = garage and garage.kind or 'public', owned = true }
    end

    local access = GetPrivateAccess(xPlayer.identifier, garageId)
    local used = CountVehiclesInGarage(xPlayer.identifier, garageId)
    local slots = access and tonumber(access.slots) or 0

    return {
        kind = 'private',
        owned = access ~= nil,
        slots = slots,
        used = used,
        maxSlots = garage.maxSlots or garage.slots or 1,
        price = garage.price or 0,
        pricePerSlot = garage.pricePerSlot or 0,
        includedSlots = garage.slots or 1,
        label = garage.label,
        account = Config.PrivatePayAccount or 'bank',
    }
end)

lib.callback.register('ox_garage:buyPrivateAccess', function(source, garageId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return { ok = false, error = 'error' } end

    local garage
    for _, g in ipairs(Config.Garages) do
        if g.id == garageId then garage = g break end
    end
    if not garage or not IsPrivateGarage(garage) then
        return { ok = false, error = 'error' }
    end

    if GetPrivateAccess(xPlayer.identifier, garageId) then
        return { ok = false, error = 'already_owned' }
    end

    local price = tonumber(garage.price) or 0
    local account = Config.PrivatePayAccount or 'bank'
    local bal = xPlayer.getAccount(account)
    if not bal or (bal.money or 0) < price then
        return { ok = false, error = 'no_money' }
    end

    xPlayer.removeAccountMoney(account, price, 'Garage privé — ' .. (garage.label or garageId))

    local slots = tonumber(garage.slots) or 1
    MySQL.insert.await(
        'INSERT INTO ox_garage_private_access (identifier, garage_id, slots) VALUES (?, ?, ?)',
        { xPlayer.identifier, garageId, slots }
    )

    return {
        ok = true,
        slots = slots,
        price = price,
        priceLabel = formatPrice(price),
    }
end)

lib.callback.register('ox_garage:buyPrivateSlot', function(source, garageId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return { ok = false, error = 'error' } end

    local garage
    for _, g in ipairs(Config.Garages) do
        if g.id == garageId then garage = g break end
    end
    if not garage or not IsPrivateGarage(garage) then
        return { ok = false, error = 'error' }
    end

    local access = GetPrivateAccess(xPlayer.identifier, garageId)
    if not access then
        return { ok = false, error = 'not_owned' }
    end

    local slots = tonumber(access.slots) or 0
    local maxSlots = tonumber(garage.maxSlots) or slots
    if slots >= maxSlots then
        return { ok = false, error = 'max_slots' }
    end

    local price = tonumber(garage.pricePerSlot) or 0
    local account = Config.PrivatePayAccount or 'bank'
    local bal = xPlayer.getAccount(account)
    if not bal or (bal.money or 0) < price then
        return { ok = false, error = 'no_money' }
    end

    xPlayer.removeAccountMoney(account, price, 'Place garage — ' .. (garage.label or garageId))

    local newSlots = slots + 1
    MySQL.update.await(
        'UPDATE ox_garage_private_access SET slots = ? WHERE identifier = ? AND garage_id = ?',
        { newSlots, xPlayer.identifier, garageId }
    )

    return {
        ok = true,
        slots = newSlots,
        price = price,
        priceLabel = formatPrice(price),
    }
end)

--- Vérifie accès + capacité avant rangement privé
---@return boolean ok, string|nil error
function CanStoreInPrivateGarage(identifier, garage)
    if not IsPrivateGarage(garage) then
        return true
    end

    local access = GetPrivateAccess(identifier, garage.id)
    if not access then
        return false, 'not_owned'
    end

    local slots = tonumber(access.slots) or 0
    local used = CountVehiclesInGarage(identifier, garage.id)
    -- Un véhicule déjà rangé ici ne consomme pas une place en plus
    if used >= slots then
        -- Autoriser si on re-range un véhicule déjà dans ce garage (caller checks)
        return false, 'no_slot'
    end

    return true
end

print('^2[ox_garage]^0 module garages privés chargé.')
