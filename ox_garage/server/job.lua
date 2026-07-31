--[[
    Flotte entreprise — liée au Job Creator
]]

local ESX = exports['es_extended']:getSharedObject()
local spawnedJobByPlate = {}

local function L(key, ...)
    local str = Locales[Config.Locale] and Locales[Config.Locale][key] or key
    if select('#', ...) > 0 then return str:format(...) end
    return str
end

local function normalizePlate(plate)
    return (plate or ''):gsub('%s+', ''):upper()
end

local function decodeProps(raw)
    if type(raw) == 'table' then return raw end
    if type(raw) ~= 'string' or raw == '' then return {} end
    local ok, data = pcall(json.decode, raw)
    return (ok and data) or {}
end

local function healthPercent(value, max)
    max = max or 1000.0
    value = tonumber(value) or max
    local pct = math.floor((value / max) * 100 + 0.5)
    return math.max(0, math.min(100, pct))
end

local function fuelLevel(props)
    local fuel = tonumber(props.fuelLevel or props.fuel)
    if not fuel then return 100 end
    if fuel > 100 then return healthPercent(fuel, 100.0) end
    return math.floor(fuel + 0.5)
end

local function generatePlate(jobName)
    local prefix = (jobName or 'JOB'):upper():gsub('[^%w]', '')
    prefix = prefix:sub(1, Config.JobCreator.platePrefixLen or 3)
    if #prefix < 2 then prefix = 'JOB' end

    for _ = 1, 40 do
        local plate = ('%s%03d'):format(prefix, math.random(1, 999))
        local exists = MySQL.single.await('SELECT 1 AS ok FROM ox_garage_job_vehicles WHERE plate = ?', { plate })
        if not exists then return plate end
    end
    return (prefix .. tostring(math.random(1000, 9999))):sub(1, 8)
end

local function defaultProps(model, plate, livery)
    local hash = type(model) == 'string' and joaat(model) or tonumber(model) or 0
    return {
        model = hash,
        plate = plate,
        engineHealth = 1000.0,
        bodyHealth = 1000.0,
        fuelLevel = 100.0,
        dirtLevel = 0.0,
        livery = livery or 0,
    }
end

local function buildEntry(row)
    local props = decodeProps(row.props)
    if not props.model then
        props.model = type(row.model) == 'string' and joaat(row.model) or row.model
    end
    props.plate = row.plate

    local isStored = row.stored == true or row.stored == 1 or row.stored == '1'
    local nPlate = normalizePlate(row.plate)
    if spawnedJobByPlate[nPlate] then
        local ent = NetworkGetEntityFromNetworkId(spawnedJobByPlate[nPlate])
        if ent and ent ~= 0 and DoesEntityExist(ent) then
            isStored = false
        else
            spawnedJobByPlate[nPlate] = nil
        end
    end

    return {
        id = row.id,
        job_name = row.job_name,
        garage_id = row.garage_id,
        template_id = row.template_id,
        plate = row.plate,
        model = props.model or joaat(row.model),
        label = row.label,
        min_grade = row.min_grade or 0,
        livery = row.livery or 0,
        props = props,
        stored = isStored,
        engine = healthPercent(props.engineHealth, 1000.0),
        body = healthPercent(props.bodyHealth, 1000.0),
        fuel = fuelLevel(props),
        isJob = true,
        isPersonal = false,
    }
end

local function personalAllowed()
    return Config.JobCreator and Config.JobCreator.allowPersonalVehicles ~= false
end

--- Véhicules perso rangés dans ce garage entreprise (parking = garageId)
local function fetchPersonalInJobGarage(identifier, garageId)
    if not personalAllowed() or not garageId or garageId == '' then
        return {}
    end
    if not Config.UseGarageColumn then
        return {}
    end

    local tbl = Config.Columns.table
    local ownerCol = Config.Columns.owner
    local garageCol = Config.Columns.garage
    local vehicleCol = Config.Columns.vehicle
    local plateCol = Config.Columns.plate
    local storedCol = Config.Columns.stored

    local rows = MySQL.query.await(
        ('SELECT * FROM `%s` WHERE `%s` = ? AND `%s` = ?'):format(tbl, ownerCol, garageCol),
        { identifier, garageId }
    ) or {}

    local list = {}
    for _i, row in ipairs(rows) do
        local props = decodeProps(row[vehicleCol] or row.vehicle)
        local model = props.model
        if type(model) == 'string' then model = joaat(model) end
        model = tonumber(model) or 0

        local isStored = row[storedCol] == true or row[storedCol] == 1 or row[storedCol] == '1'
        local plate = row[plateCol] or row.plate
        local nPlate = normalizePlate(plate)

        -- Réutilise le tracking spawn perso si exposé via event registerSpawn
        list[#list + 1] = {
            plate = plate,
            model = model,
            label = nil,
            props = props,
            stored = isStored,
            engine = healthPercent(props.engineHealth, 1000.0),
            body = healthPercent(props.bodyHealth, 1000.0),
            fuel = fuelLevel(props),
            garage_id = garageId,
            isJob = false,
            isPersonal = true,
            nPlate = nPlate,
        }
    end
    return list
end

local function getOwnedPersonalRow(identifier, plate)
    local tbl = Config.Columns.table
    local ownerCol = Config.Columns.owner
    local plateCol = Config.Columns.plate
    return MySQL.single.await(
        ('SELECT * FROM `%s` WHERE `%s` = ? AND REPLACE(UPPER(`%s`), " ", "") = ?'):format(tbl, ownerCol, plateCol),
        { identifier, plate }
    )
end

MySQL.ready(function()
    local sql = LoadResourceFile(GetCurrentResourceName(), 'sql/job_vehicles.sql')
    if sql then
        for statement in sql:gmatch('([^;]+);') do
            local trimmed = statement:gsub('^%s+', ''):gsub('%s+$', '')
            if trimmed ~= '' then
                MySQL.query.await(trimmed)
            end
        end
    end

    if Config.JobCreator and Config.JobCreator.resetOutOnRestart then
        MySQL.update.await('UPDATE ox_garage_job_vehicles SET stored = 1 WHERE stored = 0')
    end
end)

--- Upsert flotte depuis un template Job Creator
---@param data table { template_id, job_name, garage_id, model, label, min_grade, livery }
local function upsertFleetFromTemplate(data)
    if not data or not data.job_name or not data.model then return nil end

    local garageId = tostring(data.garage_id or data.marker_id or '')
    local templateId = data.template_id or data.id

    if templateId then
        local existing = MySQL.single.await(
            'SELECT * FROM ox_garage_job_vehicles WHERE template_id = ? LIMIT 1',
            { templateId }
        )
        if existing then
            MySQL.update.await([[
                UPDATE ox_garage_job_vehicles
                SET job_name=?, garage_id=?, model=?, label=?, min_grade=?, livery=?
                WHERE id=?
            ]], {
                data.job_name, garageId, data.model, data.label or data.model,
                data.min_grade or 0, data.livery or 0, existing.id
            })
            return existing.plate
        end
    end

    local plate = generatePlate(data.job_name)
    local props = json.encode(defaultProps(data.model, plate, data.livery or 0))

    MySQL.insert.await([[
        INSERT INTO ox_garage_job_vehicles
          (job_name, garage_id, template_id, plate, model, label, min_grade, livery, props, stored)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1)
    ]], {
        data.job_name, garageId, templateId, plate, data.model,
        data.label or data.model, data.min_grade or 0, data.livery or 0, props
    })

    return plate
end

exports('UpsertJobFleetVehicle', upsertFleetFromTemplate)

exports('DeleteJobFleetByTemplate', function(templateId)
    if not templateId then return end
    MySQL.query.await('DELETE FROM ox_garage_job_vehicles WHERE template_id = ?', { templateId })
end)

exports('DeleteJobFleetByJob', function(jobName)
    if not jobName then return end
    MySQL.query.await('DELETE FROM ox_garage_job_vehicles WHERE job_name = ?', { jobName })
end)

--- Sync complète depuis la liste jc_vehicles (appelée par job_creator)
RegisterNetEvent('ox_garage:syncJobFleet', function(vehicles)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    -- Autoriser aussi trigger serveur interne
    if src > 0 then
        local group = xPlayer and xPlayer.getGroup and xPlayer.getGroup() or 'user'
        -- soft check: only admins from client; job_creator server uses TriggerEvent
    end
end)

AddEventHandler('ox_garage:syncJobFleetInternal', function(vehicles)
    if type(vehicles) ~= 'table' then return end

    local seen = {}
    for _i, v in ipairs(vehicles) do
        local plate = upsertFleetFromTemplate({
            template_id = v.id,
            id = v.id,
            job_name = v.job_name,
            garage_id = v.marker_id,
            marker_id = v.marker_id,
            model = v.model,
            label = v.label,
            min_grade = v.min_grade,
            livery = v.livery,
        })
        if v.id then seen[v.id] = true end
    end

    -- Supprime les entrées orphelines liées à un template qui n'existe plus
    local all = MySQL.query.await('SELECT id, template_id FROM ox_garage_job_vehicles WHERE template_id IS NOT NULL') or {}
    for _i, row in ipairs(all) do
        if row.template_id and not seen[row.template_id] then
            -- Ne pas supprimer si sync partielle — seulement si vehicles est full dump
            -- On laisse job_creator appeler delete explicitement
        end
    end
end)

--- Full replace sync from job_creator LoadAll
AddEventHandler('ox_garage:fullSyncJobFleet', function(vehicles)
    if type(vehicles) ~= 'table' then return end

    local keepTemplates = {}
    for _i, v in ipairs(vehicles) do
        upsertFleetFromTemplate({
            template_id = v.id,
            id = v.id,
            job_name = v.job_name,
            garage_id = v.marker_id,
            marker_id = v.marker_id,
            model = v.model,
            label = v.label,
            min_grade = v.min_grade,
            livery = v.livery,
        })
        if v.id then keepTemplates[v.id] = true end
    end

    local all = MySQL.query.await('SELECT id, template_id FROM ox_garage_job_vehicles WHERE template_id IS NOT NULL') or {}
    for _i, row in ipairs(all) do
        if row.template_id and not keepTemplates[row.template_id] then
            MySQL.query.await('DELETE FROM ox_garage_job_vehicles WHERE id = ?', { row.id })
        end
    end
end)

lib.callback.register('ox_garage:getJobVehicles', function(source, jobName, garageId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or not xPlayer.job or xPlayer.job.name ~= jobName then
        return { ok = false, error = 'wrong_job', vehicles = {} }
    end

    local grade = xPlayer.job.grade or 0
    garageId = tostring(garageId or '')

    local rows
    if garageId ~= '' then
        rows = MySQL.query.await([[
            SELECT * FROM ox_garage_job_vehicles
            WHERE job_name = ? AND (garage_id = ? OR garage_id = '' OR garage_id IS NULL)
            ORDER BY stored DESC, label ASC
        ]], { jobName, garageId }) or {}
    else
        rows = MySQL.query.await([[
            SELECT * FROM ox_garage_job_vehicles
            WHERE job_name = ?
            ORDER BY stored DESC, label ASC
        ]], { jobName }) or {}
    end

    local list = {}
    for _i, row in ipairs(rows) do
        if grade >= (row.min_grade or 0) then
            list[#list + 1] = buildEntry(row)
        end
    end

    -- Véhicules perso rangés ici
    local personal = fetchPersonalInJobGarage(xPlayer.identifier, garageId)
    for _i, entry in ipairs(personal) do
        list[#list + 1] = entry
    end

    table.sort(list, function(a, b)
        if a.stored ~= b.stored then
            return a.stored and not b.stored
        end
        if a.isPersonal ~= b.isPersonal then
            return not a.isPersonal and b.isPersonal -- flotte avant perso
        end
        return (a.plate or '') < (b.plate or '')
    end)

    return { ok = true, vehicles = list, allowPersonal = personalAllowed() }
end)

lib.callback.register('ox_garage:getJobVehicle', function(source, plate)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return nil end

    plate = normalizePlate(plate)
    local row = MySQL.single.await(
        'SELECT * FROM ox_garage_job_vehicles WHERE REPLACE(UPPER(plate), " ", "") = ?',
        { plate }
    )
    if row then
        if xPlayer.job.name ~= row.job_name then return nil end
        if (xPlayer.job.grade or 0) < (row.min_grade or 0) then return nil end
        return buildEntry(row)
    end

    -- Perso appartenant au joueur (pour menus store)
    if not personalAllowed() then return nil end
    local owned = getOwnedPersonalRow(xPlayer.identifier, plate)
    if not owned then return nil end

    local props = decodeProps(owned[Config.Columns.vehicle] or owned.vehicle)
    local model = props.model
    if type(model) == 'string' then model = joaat(model) end
    local storedRaw = owned[Config.Columns.stored]
    return {
        plate = owned[Config.Columns.plate] or owned.plate,
        model = tonumber(model) or 0,
        props = props,
        stored = storedRaw == true or storedRaw == 1 or storedRaw == '1',
        garage_id = owned[Config.Columns.garage],
        engine = healthPercent(props.engineHealth, 1000.0),
        body = healthPercent(props.bodyHealth, 1000.0),
        fuel = fuelLevel(props),
        isJob = false,
        isPersonal = true,
    }
end)

lib.callback.register('ox_garage:takeOutJob', function(source, jobName, garageId, plate, isPersonal)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or xPlayer.job.name ~= jobName then
        return { ok = false, error = 'wrong_job' }
    end

    plate = normalizePlate(plate)
    garageId = tostring(garageId or '')

    -- Perso
    if isPersonal or (personalAllowed() and not MySQL.single.await(
        'SELECT 1 AS ok FROM ox_garage_job_vehicles WHERE REPLACE(UPPER(plate), " ", "") = ? AND job_name = ?',
        { plate, jobName }
    )) then
        if not personalAllowed() then
            return { ok = false, error = 'not_job_vehicle' }
        end

        local row = getOwnedPersonalRow(xPlayer.identifier, plate)
        if not row then return { ok = false, error = 'not_yours' } end

        local parking = row[Config.Columns.garage]
        if Config.UseGarageColumn and garageId ~= '' and parking ~= garageId then
            return { ok = false, error = 'not_stored' }
        end

        local storedRaw = row[Config.Columns.stored]
        local isStored = storedRaw == true or storedRaw == 1 or storedRaw == '1'
        if not isStored then return { ok = false, error = 'already_out' } end

        MySQL.update.await(
            ('UPDATE `%s` SET `%s` = 0 WHERE `%s` = ? AND REPLACE(UPPER(`%s`), " ", "") = ?'):format(
                Config.Columns.table, Config.Columns.stored, Config.Columns.owner, Config.Columns.plate
            ),
            { xPlayer.identifier, plate }
        )

        local props = decodeProps(row[Config.Columns.vehicle] or row.vehicle)
        props.plate = row[Config.Columns.plate] or props.plate

        return {
            ok = true,
            props = props,
            plate = row[Config.Columns.plate],
            label = nil,
            livery = props.livery or 0,
            isPersonal = true,
        }
    end

    local row = MySQL.single.await(
        'SELECT * FROM ox_garage_job_vehicles WHERE REPLACE(UPPER(plate), " ", "") = ? AND job_name = ?',
        { plate, jobName }
    )
    if not row then return { ok = false, error = 'not_job_vehicle' } end
    if (xPlayer.job.grade or 0) < (row.min_grade or 0) then
        return { ok = false, error = 'grade' }
    end

    local isStored = row.stored == true or row.stored == 1 or row.stored == '1'
    if not isStored then return { ok = false, error = 'already_out' } end

    MySQL.update.await(
        'UPDATE ox_garage_job_vehicles SET stored = 0 WHERE id = ?',
        { row.id }
    )

    local props = decodeProps(row.props)
    if not props.model then props.model = joaat(row.model) end
    props.plate = row.plate
    if row.livery and row.livery > 0 then props.livery = row.livery end

    return {
        ok = true,
        props = props,
        plate = row.plate,
        label = row.label,
        livery = row.livery or 0,
        isPersonal = false,
    }
end)

RegisterNetEvent('ox_garage:registerJobSpawn', function(plate, netId)
    local src = source
    if type(plate) ~= 'string' then return end
    spawnedJobByPlate[normalizePlate(plate)] = netId
end)

RegisterNetEvent('ox_garage:forceStoreJob', function(plate, garageId, isPersonal)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or type(plate) ~= 'string' then return end
    plate = normalizePlate(plate)

    if isPersonal or (personalAllowed() and not MySQL.single.await(
        'SELECT 1 AS ok FROM ox_garage_job_vehicles WHERE REPLACE(UPPER(plate), " ", "") = ?',
        { plate }
    )) then
        local tbl = Config.Columns.table
        local ownerCol = Config.Columns.owner
        local plateCol = Config.Columns.plate
        local storedCol = Config.Columns.stored
        local garageCol = Config.Columns.garage

        if Config.UseGarageColumn and type(garageId) == 'string' and garageId ~= '' then
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
        return
    end

    MySQL.update.await(
        'UPDATE ox_garage_job_vehicles SET stored = 1 WHERE REPLACE(UPPER(plate), " ", "") = ? AND job_name = ?',
        { plate, xPlayer.job.name }
    )
    spawnedJobByPlate[plate] = nil
end)

lib.callback.register('ox_garage:storeJob', function(source, jobName, garageId, netId, props)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or xPlayer.job.name ~= jobName then
        return { ok = false, error = 'wrong_job' }
    end
    if type(props) ~= 'table' or not props.plate then
        return { ok = false, error = 'error' }
    end

    local plate = normalizePlate(props.plate)
    garageId = tostring(garageId or '')

    local row = MySQL.single.await(
        'SELECT * FROM ox_garage_job_vehicles WHERE REPLACE(UPPER(plate), " ", "") = ? AND job_name = ?',
        { plate, jobName }
    )

    if row then
        props.plate = row.plate
        local encoded = json.encode(props)
        MySQL.update.await([[
            UPDATE ox_garage_job_vehicles
            SET stored = 1, props = ?, garage_id = CASE WHEN ? = '' THEN garage_id ELSE ? END
            WHERE id = ?
        ]], { encoded, garageId, garageId, row.id })

        spawnedJobByPlate[plate] = nil
        return { ok = true, plate = row.plate, label = row.label, netId = netId, isPersonal = false }
    end

    -- Ranger un véhicule perso ici
    if not personalAllowed() then
        return { ok = false, error = 'not_job_vehicle' }
    end

    local owned = getOwnedPersonalRow(xPlayer.identifier, plate)
    if not owned then
        return { ok = false, error = 'not_yours' }
    end

    if not Config.UseGarageColumn then
        return { ok = false, error = 'error' }
    end

    props.plate = owned[Config.Columns.plate]
    local encoded = json.encode(props)
    local parkingId = garageId ~= '' and garageId or ('job_' .. jobName)

    MySQL.update.await(
        ('UPDATE `%s` SET `%s` = 1, `%s` = ?, `%s` = ? WHERE `%s` = ? AND REPLACE(UPPER(`%s`), " ", "") = ?'):format(
            Config.Columns.table,
            Config.Columns.stored,
            Config.Columns.garage,
            Config.Columns.vehicle,
            Config.Columns.owner,
            Config.Columns.plate
        ),
        { parkingId, encoded, xPlayer.identifier, plate }
    )

    return {
        ok = true,
        plate = owned[Config.Columns.plate],
        label = nil,
        netId = netId,
        isPersonal = true,
    }
end)

print('^2[ox_garage]^0 module entreprise (job_creator) chargé.')
