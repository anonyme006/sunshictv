local ESX = exports['es_extended']:getSharedObject()

---@type table<string, number> plate -> netId of spawned vehicles
local spawnedByPlate = {}

local function _(key, ...)
    local str = Locales[Config.Locale] and Locales[Config.Locale][key] or key
    if select('#', ...) > 0 then
        return str:format(...)
    end
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

local function getModelHash(props)
    local model = props.model
    if type(model) == 'string' then
        return joaat(model)
    end
    return tonumber(model) or 0
end

local function healthPercent(value, max)
    max = max or 1000.0
    value = tonumber(value) or max
    local pct = math.floor((value / max) * 100 + 0.5)
    if pct < 0 then pct = 0 end
    if pct > 100 then pct = 100 end
    return pct
end

local function fuelLevel(props)
    local fuel = props.fuelLevel
    if fuel == nil then fuel = props.fuel end
    fuel = tonumber(fuel)
    if not fuel then return 100 end
    if fuel > 100 then
        return healthPercent(fuel, 100.0)
    end
    return math.floor(fuel + 0.5)
end

local function buildVehicleEntry(row, garageId)
    local props = decodeVehicle(row[Config.Columns.vehicle] or row.vehicle)
    local model = getModelHash(props)
    local storedRaw = row[Config.Columns.stored]
    if storedRaw == nil then storedRaw = row.stored end
    local isStored = storedRaw == true or storedRaw == 1 or storedRaw == '1'

    -- Si tracké comme spawn vivant → forcer "sorti"
    local plate = row[Config.Columns.plate] or row.plate
    local nPlate = normalizePlate(plate)
    if spawnedByPlate[nPlate] then
        local ent = NetworkGetEntityFromNetworkId(spawnedByPlate[nPlate])
        if ent and ent ~= 0 and DoesEntityExist(ent) then
            isStored = false
        else
            spawnedByPlate[nPlate] = nil
        end
    end

    local garageCol = row[Config.Columns.garage] or row.parking or row.garage
    return {
        plate = plate,
        model = model,
        props = props,
        stored = isStored,
        garage = garageCol,
        engine = healthPercent(props.engineHealth, 1000.0),
        body = healthPercent(props.bodyHealth, 1000.0),
        fuel = fuelLevel(props),
        type = row[Config.Columns.type] or row.type or 'car',
    }
end

---@param identifier string
---@param garage table
local function fetchVehicles(identifier, garage)
    local garageId = garage.id
    local garageType = garage.type or Config.DefaultType
    local tbl = Config.Columns.table
    local ownerCol = Config.Columns.owner
    local typeCol = Config.Columns.type
    local garageCol = Config.Columns.garage
    local isPrivate = IsPrivateGarage and IsPrivateGarage(garage)

    local query, params

    if Config.UseGarageColumn then
        if isPrivate then
            -- Privé : uniquement les véhicules rangés dans CE garage
            query = ([[
                SELECT * FROM `%s`
                WHERE `%s` = ?
                  AND `%s` = ?
                  AND (`%s` = ? OR `%s` IS NULL OR `%s` = 'car')
            ]]):format(tbl, ownerCol, garageCol, typeCol, typeCol, typeCol)
            params = { identifier, garageId, garageType }
        else
            -- Public : ce garage OU sans parking (compat) — hors privés / fourrière
            query = ([[
                SELECT * FROM `%s`
                WHERE `%s` = ?
                  AND (`%s` = ? OR `%s` IS NULL OR `%s` = '')
                  AND (`%s` = ? OR `%s` IS NULL OR `%s` = 'car')
            ]]):format(tbl, ownerCol, garageCol, garageCol, garageCol, typeCol, typeCol, typeCol)
            params = { identifier, garageId, garageType }
        end
    else
        query = ([[
            SELECT * FROM `%s`
            WHERE `%s` = ?
              AND (`%s` = ? OR `%s` IS NULL OR `%s` = 'car')
        ]]):format(tbl, ownerCol, typeCol, typeCol, typeCol)
        params = { identifier, garageType }
    end

    local rows = MySQL.query.await(query, params) or {}
    local privateIds = GetPrivateGarageIds and GetPrivateGarageIds() or {}
    local list = {}
    for _, row in ipairs(rows) do
        local gCol = row[Config.Columns.garage] or row.parking or row.garage
        if IsImpoundGarageId and IsImpoundGarageId(gCol) then
            goto continue
        end
        -- Sur le public, ne pas afficher un véhicule déjà lié à un privé
        if not isPrivate and gCol and gCol ~= '' and gCol ~= garageId and privateIds[gCol] then
            goto continue
        end
        list[#list + 1] = buildVehicleEntry(row, garageId)
        ::continue::
    end

    table.sort(list, function(a, b)
        if a.stored ~= b.stored then
            return a.stored and not b.stored
        end
        return (a.plate or '') < (b.plate or '')
    end)

    return list
end

local function findGarage(garageId)
    for _, g in ipairs(Config.Garages) do
        if g.id == garageId then return g end
    end
end

lib.callback.register('ox_garage:getVehicles', function(source, garageId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return {} end

    local garage = findGarage(garageId)
    if not garage then return {} end

    if IsPrivateGarage and IsPrivateGarage(garage) then
        local access = GetPrivateAccess and GetPrivateAccess(xPlayer.identifier, garage.id)
        if not access then return {} end
    end

    return fetchVehicles(xPlayer.identifier, garage)
end)

lib.callback.register('ox_garage:getVehicle', function(source, plate)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return nil end

    plate = normalizePlate(plate)
    local tbl = Config.Columns.table
    local ownerCol = Config.Columns.owner
    local plateCol = Config.Columns.plate

    local row = MySQL.single.await(
        ('SELECT * FROM `%s` WHERE `%s` = ? AND REPLACE(UPPER(`%s`), " ", "") = ?'):format(tbl, ownerCol, plateCol),
        { xPlayer.identifier, plate }
    )
    if not row then return nil end
    return buildVehicleEntry(row)
end)

--- Spawn validé serveur
lib.callback.register('ox_garage:takeOut', function(source, garageId, plate)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return { ok = false, error = 'error' } end

    local garage = findGarage(garageId)
    if not garage then return { ok = false, error = 'error' } end

    if IsPrivateGarage and IsPrivateGarage(garage) then
        local access = GetPrivateAccess and GetPrivateAccess(xPlayer.identifier, garage.id)
        if not access then
            return { ok = false, error = 'not_owned' }
        end
    end

    plate = normalizePlate(plate)
    local tbl = Config.Columns.table
    local ownerCol = Config.Columns.owner
    local plateCol = Config.Columns.plate
    local storedCol = Config.Columns.stored
    local vehicleCol = Config.Columns.vehicle

    local row = MySQL.single.await(
        ('SELECT * FROM `%s` WHERE `%s` = ? AND REPLACE(UPPER(`%s`), " ", "") = ?'):format(tbl, ownerCol, plateCol),
        { xPlayer.identifier, plate }
    )
    if not row then
        return { ok = false, error = 'not_yours' }
    end

    local storedRaw = row[storedCol]
    local isStored = storedRaw == true or storedRaw == 1 or storedRaw == '1'
    if not isStored then
        return { ok = false, error = 'already_out' }
    end

    if Config.UseGarageColumn then
        local g = row[Config.Columns.garage]
        if g and IsImpoundGarageId and IsImpoundGarageId(g) then
            return { ok = false, error = 'not_stored' }
        end
        if IsPrivateGarage and IsPrivateGarage(garage) then
            if not g or g ~= garageId then
                return { ok = false, error = 'not_stored' }
            end
        elseif g and g ~= '' and g ~= garageId then
            return { ok = false, error = 'not_stored' }
        end
    end

    local props = decodeVehicle(row[vehicleCol])
    props.plate = row[plateCol] or props.plate

    MySQL.update.await(
        ('UPDATE `%s` SET `%s` = 0 WHERE `%s` = ? AND REPLACE(UPPER(`%s`), " ", "") = ?'):format(tbl, storedCol, ownerCol, plateCol),
        { xPlayer.identifier, plate }
    )

    return {
        ok = true,
        props = props,
        plate = row[plateCol],
        spawns = garage.spawns,
    }
end)

--- Enregistre le netId après spawn client
RegisterNetEvent('ox_garage:registerSpawn', function(plate, netId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or type(plate) ~= 'string' then return end
    spawnedByPlate[normalizePlate(plate)] = netId
end)

--- Rollback si spawn annulé / échoué
RegisterNetEvent('ox_garage:forceStore', function(plate, garageId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or type(plate) ~= 'string' then return end

    plate = normalizePlate(plate)
    local tbl = Config.Columns.table
    local ownerCol = Config.Columns.owner
    local plateCol = Config.Columns.plate
    local storedCol = Config.Columns.stored
    local garageCol = Config.Columns.garage

    if Config.UseGarageColumn and type(garageId) == 'string' then
        MySQL.update.await(
            ('UPDATE `%s` SET `%s` = 1, `%s` = ? WHERE `%s` = ? AND REPLACE(UPPER(`%s`), " ", "") = ?'):format(
                tbl, storedCol, garageCol, ownerCol, plateCol
            ),
            { garageId, xPlayer.identifier, plate }
        )
    else
        MySQL.update.await(
            ('UPDATE `%s` SET `%s` = 1 WHERE `%s` = ? AND REPLACE(UPPER(`%s`), " ", "") = ?'):format(
                tbl, storedCol, ownerCol, plateCol
            ),
            { xPlayer.identifier, plate }
        )
    end

    spawnedByPlate[plate] = nil
end)

--- Ranger
lib.callback.register('ox_garage:store', function(source, garageId, netId, props)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return { ok = false, error = 'error' } end

    local garage = findGarage(garageId)
    if not garage then return { ok = false, error = 'error' } end

    if type(props) ~= 'table' or not props.plate then
        return { ok = false, error = 'error' }
    end

    local plate = normalizePlate(props.plate)
    local tbl = Config.Columns.table
    local ownerCol = Config.Columns.owner
    local plateCol = Config.Columns.plate
    local storedCol = Config.Columns.stored
    local vehicleCol = Config.Columns.vehicle
    local garageCol = Config.Columns.garage

    local row = MySQL.single.await(
        ('SELECT * FROM `%s` WHERE `%s` = ? AND REPLACE(UPPER(`%s`), " ", "") = ?'):format(tbl, ownerCol, plateCol),
        { xPlayer.identifier, plate }
    )
    if not row then
        return { ok = false, error = 'not_yours' }
    end

    -- Vérifie distance du joueur au garage
    local ped = GetPlayerPed(source)
    local pCoords = GetEntityCoords(ped)
    local storeCoords = garage.store and garage.store.coords or garage.coords
    local maxDist = (garage.store and garage.store.radius) or Config.StoreDistance
    if #(pCoords - storeCoords) > (maxDist + 5.0) then
        return { ok = false, error = 'too_far' }
    end

    -- Garage privé : accès + places
    if IsPrivateGarage and IsPrivateGarage(garage) then
        local access = GetPrivateAccess and GetPrivateAccess(xPlayer.identifier, garage.id)
        if not access then
            return { ok = false, error = 'not_owned' }
        end

        local currentParking = row[garageCol]
        local alreadyHere = currentParking == garage.id
        if not alreadyHere then
            local used = CountVehiclesInGarage and CountVehiclesInGarage(xPlayer.identifier, garage.id) or 0
            local slots = tonumber(access.slots) or 0
            if used >= slots then
                return { ok = false, error = 'no_slot' }
            end
        end
    end

    -- Nettoie props
    props.plate = row[plateCol]
    local encoded = json.encode(props)

    if Config.UseGarageColumn then
        MySQL.update.await(
            ('UPDATE `%s` SET `%s` = 1, `%s` = ?, `%s` = ? WHERE `%s` = ? AND REPLACE(UPPER(`%s`), " ", "") = ?'):format(
                tbl, storedCol, garageCol, vehicleCol, ownerCol, plateCol
            ),
            { garageId, encoded, xPlayer.identifier, plate }
        )
    else
        MySQL.update.await(
            ('UPDATE `%s` SET `%s` = 1, `%s` = ? WHERE `%s` = ? AND REPLACE(UPPER(`%s`), " ", "") = ?'):format(
                tbl, storedCol, vehicleCol, ownerCol, plateCol
            ),
            { encoded, xPlayer.identifier, plate }
        )
    end

    spawnedByPlate[plate] = nil

    -- Demande au client de supprimer l'entité
    return { ok = true, plate = row[plateCol], netId = netId }
end)

AddEventHandler('entityRemoved', function(entity)
    -- cleanup if needed
end)

AddEventHandler('playerDropped', function()
    -- keep spawnedByPlate — véhicule peut rester en monde
end)

print('^2[ox_garage]^0 serveur chargé.')
