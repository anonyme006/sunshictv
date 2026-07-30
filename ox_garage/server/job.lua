--[[
    Flotte entreprise — liée au Job Creator
]]

local ESX = exports['es_extended']:getSharedObject()
local spawnedJobByPlate = {}

local function _(key, ...)
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
    }
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
    for _, v in ipairs(vehicles) do
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
    for _, row in ipairs(all) do
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
    for _, v in ipairs(vehicles) do
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
    for _, row in ipairs(all) do
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
    for _, row in ipairs(rows) do
        if grade >= (row.min_grade or 0) then
            list[#list + 1] = buildEntry(row)
        end
    end

    return { ok = true, vehicles = list }
end)

lib.callback.register('ox_garage:getJobVehicle', function(source, plate)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return nil end

    plate = normalizePlate(plate)
    local row = MySQL.single.await(
        'SELECT * FROM ox_garage_job_vehicles WHERE REPLACE(UPPER(plate), " ", "") = ?',
        { plate }
    )
    if not row then return nil end
    if xPlayer.job.name ~= row.job_name then return nil end
    if (xPlayer.job.grade or 0) < (row.min_grade or 0) then return nil end
    return buildEntry(row)
end)

lib.callback.register('ox_garage:takeOutJob', function(source, jobName, garageId, plate)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or xPlayer.job.name ~= jobName then
        return { ok = false, error = 'wrong_job' }
    end

    plate = normalizePlate(plate)
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
    }
end)

RegisterNetEvent('ox_garage:registerJobSpawn', function(plate, netId)
    local src = source
    if type(plate) ~= 'string' then return end
    spawnedJobByPlate[normalizePlate(plate)] = netId
end)

RegisterNetEvent('ox_garage:forceStoreJob', function(plate)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or type(plate) ~= 'string' then return end
    plate = normalizePlate(plate)

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
    local row = MySQL.single.await(
        'SELECT * FROM ox_garage_job_vehicles WHERE REPLACE(UPPER(plate), " ", "") = ? AND job_name = ?',
        { plate, jobName }
    )
    if not row then return { ok = false, error = 'not_job_vehicle' } end

    props.plate = row.plate
    local encoded = json.encode(props)
    garageId = tostring(garageId or row.garage_id or '')

    MySQL.update.await([[
        UPDATE ox_garage_job_vehicles
        SET stored = 1, props = ?, garage_id = CASE WHEN ? = '' THEN garage_id ELSE ? END
        WHERE id = ?
    ]], { encoded, garageId, garageId, row.id })

    spawnedJobByPlate[plate] = nil
    return { ok = true, plate = row.plate, label = row.label, netId = netId }
end)

print('^2[ox_garage]^0 module entreprise (job_creator) chargé.')
