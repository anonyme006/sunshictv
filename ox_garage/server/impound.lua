--[[
    Fourrière générale + fourrière mécano
]]

local ESX = exports['es_extended']:getSharedObject()

local function _(key, ...)
    local str = Locales[Config.Locale] and Locales[Config.Locale][key] or key
    if select('#', ...) > 0 then return str:format(...) end
    return str
end

local function normalizePlate(plate)
    return (plate or ''):gsub('%s+', ''):upper()
end

local function decodeVehicle(raw)
    if type(raw) == 'table' then return raw end
    if type(raw) ~= 'string' or raw == '' then return {} end
    local ok, data = pcall(json.decode, raw)
    return (ok and data) or {}
end

local function healthPercent(value, max)
    max = max or 1000.0
    value = tonumber(value) or max
    return math.max(0, math.min(100, math.floor((value / max) * 100 + 0.5)))
end

local function fuelLevel(props)
    local fuel = tonumber(props.fuelLevel or props.fuel)
    if not fuel then return 100 end
    if fuel > 100 then return healthPercent(fuel, 100.0) end
    return math.floor(fuel + 0.5)
end

function GetImpoundById(id)
    for _, imp in ipairs(Config.Impounds or {}) do
        if imp.id == id then return imp end
    end
end

function IsImpoundGarageId(id)
    if not id or id == '' then return false end
    return GetImpoundById(id) ~= nil
end

--- Liste des ids fourrière (pour exclure des garages normaux)
function GetImpoundIds()
    local ids = {}
    for _, imp in ipairs(Config.Impounds or {}) do
        ids[#ids + 1] = imp.id
    end
    return ids
end

local function jobAllowed(map, xPlayer)
    if not map or not xPlayer or not xPlayer.job then return false end
    local minGrade = map[xPlayer.job.name]
    if minGrade == nil then return false end
    return (xPlayer.job.grade or 0) >= (tonumber(minGrade) or 0)
end

local function canSeize(xPlayer, impound)
    return jobAllowed(impound.jobs, xPlayer)
end

local function canRetrieve(xPlayer, impound, ownerIdentifier)
    if not xPlayer then return false, false end
    local isOwner = xPlayer.identifier == ownerIdentifier
    local asJob = jobAllowed(impound.retrieveJobs, xPlayer)
    local ownerOk = isOwner and impound.ownerCanRetrieve ~= false
    return ownerOk or asJob, isOwner, asJob
end

local function addSocietyMoney(account, amount)
    if not account or account == '' or amount <= 0 then return end
    pcall(function()
        TriggerEvent('esx_addonaccount:getSharedAccount', account, function(acc)
            if acc and acc.addMoney then
                acc.addMoney(amount)
                return
            end
        end)
        MySQL.update.await(
            'UPDATE addon_account_data SET money = money + ? WHERE account_name = ? AND (owner IS NULL OR owner = "")',
            { amount, account }
        )
    end)
end

local function buildImpoundEntry(row, impoundId)
    local props = decodeVehicle(row[Config.Columns.vehicle] or row.vehicle)
    local model = props.model
    if type(model) == 'string' then model = joaat(model) end
    model = tonumber(model) or 0

    return {
        plate = row[Config.Columns.plate] or row.plate,
        model = model,
        props = props,
        stored = true,
        garage = row[Config.Columns.garage] or row.parking,
        owner = row[Config.Columns.owner] or row.owner,
        engine = healthPercent(props.engineHealth, 1000.0),
        body = healthPercent(props.bodyHealth, 1000.0),
        fuel = fuelLevel(props),
        impound = true,
        impoundId = impoundId,
        type = row[Config.Columns.type] or row.type or 'car',
    }
end

lib.callback.register('ox_garage:getImpoundVehicles', function(source, impoundId)
    if not Config.Impound or not Config.Impound.enabled then return {} end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return {} end

    local impound = GetImpoundById(impoundId)
    if not impound then return {} end

    local tbl = Config.Columns.table
    local ownerCol = Config.Columns.owner
    local garageCol = Config.Columns.garage
    local asStaff = jobAllowed(impound.retrieveJobs, xPlayer) or canSeize(xPlayer, impound)

    local rows
    if asStaff then
        -- Staff : tous les véhicules de cette fourrière
        rows = MySQL.query.await(
            ('SELECT * FROM `%s` WHERE `%s` = ? AND `%s` = 1'):format(tbl, garageCol, Config.Columns.stored),
            { impoundId }
        ) or {}
    else
        -- Propriétaire : uniquement les siens
        rows = MySQL.query.await(
            ('SELECT * FROM `%s` WHERE `%s` = ? AND `%s` = ? AND `%s` = 1'):format(
                tbl, ownerCol, garageCol, Config.Columns.stored
            ),
            { xPlayer.identifier, impoundId }
        ) or {}
    end

    local list = {}
    for _, row in ipairs(rows) do
        list[#list + 1] = buildImpoundEntry(row, impoundId)
    end
    table.sort(list, function(a, b) return (a.plate or '') < (b.plate or '') end)
    return list
end)

--- Mettre un véhicule en fourrière (par job)
lib.callback.register('ox_garage:impoundVehicle', function(source, impoundId, props)
    if not Config.Impound or not Config.Impound.enabled then
        return { ok = false, error = 'disabled' }
    end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return { ok = false, error = 'error' } end

    local impound = GetImpoundById(impoundId)
    if not impound then return { ok = false, error = 'error' } end
    if not canSeize(xPlayer, impound) then
        return { ok = false, error = 'job' }
    end

    if type(props) ~= 'table' or not props.plate then
        return { ok = false, error = 'error' }
    end

    -- Distance
    local ped = GetPlayerPed(source)
    local store = impound.store or { coords = impound.coords, radius = 12.0 }
    if #(GetEntityCoords(ped) - store.coords) > ((store.radius or 12.0) + 8.0) then
        return { ok = false, error = 'too_far' }
    end

    local plate = normalizePlate(props.plate)
    local tbl = Config.Columns.table
    local plateCol = Config.Columns.plate
    local storedCol = Config.Columns.stored
    local vehicleCol = Config.Columns.vehicle
    local garageCol = Config.Columns.garage

    local row = MySQL.single.await(
        ('SELECT * FROM `%s` WHERE REPLACE(UPPER(`%s`), " ", "") = ?'):format(tbl, plateCol),
        { plate }
    )
    if not row then
        return { ok = false, error = 'not_yours' } -- véhicule non enregistré
    end

    local currentGarage = row[garageCol]
    if currentGarage and IsImpoundGarageId(currentGarage) and (row[storedCol] == 1 or row[storedCol] == true) then
        return { ok = false, error = 'already' }
    end

    props.plate = row[plateCol]
    local encoded = json.encode(props)

    MySQL.update.await(
        ('UPDATE `%s` SET `%s` = 1, `%s` = ?, `%s` = ? WHERE REPLACE(UPPER(`%s`), " ", "") = ?'):format(
            tbl, storedCol, garageCol, vehicleCol, plateCol
        ),
        { impoundId, encoded, plate }
    )

    return {
        ok = true,
        plate = row[plateCol],
        owner = row[Config.Columns.owner],
    }
end)

--- Récupérer un véhicule de fourrière
lib.callback.register('ox_garage:retrieveImpound', function(source, impoundId, plate)
    if not Config.Impound or not Config.Impound.enabled then
        return { ok = false, error = 'disabled' }
    end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return { ok = false, error = 'error' } end

    local impound = GetImpoundById(impoundId)
    if not impound then return { ok = false, error = 'error' } end

    plate = normalizePlate(plate)
    local tbl = Config.Columns.table
    local plateCol = Config.Columns.plate
    local storedCol = Config.Columns.stored
    local vehicleCol = Config.Columns.vehicle
    local garageCol = Config.Columns.garage
    local ownerCol = Config.Columns.owner

    local row = MySQL.single.await(
        ('SELECT * FROM `%s` WHERE REPLACE(UPPER(`%s`), " ", "") = ?'):format(tbl, plateCol),
        { plate }
    )
    if not row then return { ok = false, error = 'not_yours' } end

    if (row[garageCol] or '') ~= impoundId then
        return { ok = false, error = 'not_impound' }
    end

    local storedRaw = row[storedCol]
    local isStored = storedRaw == true or storedRaw == 1 or storedRaw == '1'
    if not isStored then return { ok = false, error = 'already_out' } end

    local allowed, isOwner, asJob = canRetrieve(xPlayer, impound, row[ownerCol])
    if not allowed then
        return { ok = false, error = 'job' }
    end

    local price = tonumber(impound.price) or 0
    -- Staff job qui sort pour un client : gratuit pour le staff (le script peut facturer autrement)
    local chargeOwner = isOwner and not (asJob and not isOwner)
    if asJob and not isOwner then
        price = 0
    end

    if price > 0 then
        local account = (Config.Impound and Config.Impound.payAccount) or 'bank'
        local bal = 0
        if account == 'bank' then
            local acc = xPlayer.getAccount('bank')
            bal = acc and acc.money or 0
        else
            bal = xPlayer.getMoney()
        end
        if bal < price then
            return { ok = false, error = 'money' }
        end
        if account == 'bank' then
            xPlayer.removeAccountMoney('bank', price)
        else
            xPlayer.removeMoney(price)
        end
        addSocietyMoney(impound.society, price)
    end

    local props = decodeVehicle(row[vehicleCol])
    props.plate = row[plateCol]

    MySQL.update.await(
        ('UPDATE `%s` SET `%s` = 0 WHERE REPLACE(UPPER(`%s`), " ", "") = ?'):format(tbl, storedCol, plateCol),
        { plate }
    )

    return {
        ok = true,
        props = props,
        plate = row[plateCol],
        price = price,
        spawns = impound.spawns,
    }
end)

--- Export pour autres ressources (police job, etc.)
exports('ImpoundVehicle', function(plate, impoundId, props)
    impoundId = impoundId or 'impound_public'
    local impound = GetImpoundById(impoundId)
    if not impound then return false end

    plate = normalizePlate(plate)
    local tbl = Config.Columns.table
    local plateCol = Config.Columns.plate
    local storedCol = Config.Columns.stored
    local vehicleCol = Config.Columns.vehicle
    local garageCol = Config.Columns.garage

    local row = MySQL.single.await(
        ('SELECT * FROM `%s` WHERE REPLACE(UPPER(`%s`), " ", "") = ?'):format(tbl, plateCol),
        { plate }
    )
    if not row then return false end

    local encoded
    if type(props) == 'table' then
        props.plate = row[plateCol]
        encoded = json.encode(props)
    else
        encoded = row[vehicleCol]
    end

    MySQL.update.await(
        ('UPDATE `%s` SET `%s` = 1, `%s` = ?, `%s` = ? WHERE REPLACE(UPPER(`%s`), " ", "") = ?'):format(
            tbl, storedCol, garageCol, vehicleCol, plateCol
        ),
        { impoundId, encoded, plate }
    )
    return true
end)

exports('GetImpoundById', GetImpoundById)
exports('IsImpoundGarageId', IsImpoundGarageId)

print('^2[ox_garage]^0 module fourrière chargé.')
