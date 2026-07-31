--[[
    Garages entreprise dynamiques — commande admin + export
]]

local ESX = exports['es_extended']:getSharedObject()

---@type table<string, table>
local JobGarageCache = {}

local function L(key, ...)
    local str = Locales[Config.Locale] and Locales[Config.Locale][key] or key
    if select('#', ...) > 0 then return str:format(...) end
    return str
end

local function isGarageAdmin(xPlayer)
    if not xPlayer then return false end
    local groups = (Config.JobGarages and Config.JobGarages.adminGroups) or { admin = true }
    local group = xPlayer.getGroup and xPlayer.getGroup() or 'user'
    if groups[group] then return true end
    return IsPlayerAceAllowed(xPlayer.source, 'command.addjobgarage')
end

local function decodeSpawns(raw)
    if type(raw) == 'table' then return raw end
    if type(raw) ~= 'string' or raw == '' then return {} end
    local ok, data = pcall(json.decode, raw)
    return (ok and data) or {}
end

local function rowToGarage(row)
    local spawns = decodeSpawns(row.spawns)
    local spawnVecs = {}
    for i, s in ipairs(spawns) do
        if type(s) == 'table' then
            spawnVecs[i] = {
                x = tonumber(s.x) or 0.0,
                y = tonumber(s.y) or 0.0,
                z = tonumber(s.z) or 0.0,
                w = tonumber(s.w or s.h or s.heading) or 0.0,
            }
        end
    end

    return {
        id = row.id,
        job = row.job_name,
        job_name = row.job_name,
        label = row.label,
        min_grade = row.min_grade or 0,
        coords = { x = row.x + 0.0, y = row.y + 0.0, z = row.z + 0.0 },
        heading = row.heading or 0.0,
        store = {
            coords = { x = row.x + 0.0, y = row.y + 0.0, z = row.z + 0.0 },
            radius = row.store_radius or 10.0,
        },
        target = {
            coords = { x = row.x + 0.0, y = row.y + 0.0, z = row.z + 0.0 },
            radius = row.target_radius or 2.2,
        },
        spawns = spawnVecs,
        blip = {
            enabled = row.blip_enabled == true or row.blip_enabled == 1,
            sprite = row.blip_sprite or 357,
            color = row.blip_color or 47,
            scale = row.blip_scale or 0.7,
        },
    }
end

local function broadcastGarages()
    local list = {}
    for _i, g in pairs(JobGarageCache) do
        list[#list + 1] = g
    end
    table.sort(list, function(a, b) return (a.id or '') < (b.id or '') end)
    TriggerClientEvent('ox_garage:syncJobGarages', -1, list)
end

local function loadJobGarages()
    local rows = MySQL.query.await('SELECT * FROM ox_garage_job_garages') or {}
    JobGarageCache = {}
    for _i, row in ipairs(rows) do
        JobGarageCache[row.id] = rowToGarage(row)
    end
    broadcastGarages()
end

MySQL.ready(function()
    local sql = LoadResourceFile(GetCurrentResourceName(), 'sql/job_garages.sql')
    if sql then
        for statement in sql:gmatch('([^;]+);') do
            local trimmed = statement:gsub('^%s+', ''):gsub('%s+$', '')
            if trimmed ~= '' then
                MySQL.query.await(trimmed)
            end
        end
    end
    loadJobGarages()
end)

local function generateSpawns(x, y, z, heading)
    local cfg = Config.JobGarages or {}
    local forward = cfg.spawnForward or 4.0
    local side = cfg.spawnSide or 3.0
    local rad = math.rad(heading or 0.0)
    local fx, fy = -math.sin(rad), math.cos(rad)
    local rx, ry = fy, -fx

    local function point(fOff, sOff)
        return {
            x = x + fx * fOff + rx * sOff,
            y = y + fy * fOff + ry * sOff,
            z = z,
            w = heading or 0.0,
        }
    end

    return {
        point(forward, 0.0),
        point(forward, side),
        point(forward, -side),
    }
end

local function makeId(job)
    local base = ('job_%s_%s'):format(
        (job or 'job'):lower():gsub('[^%w]', ''),
        tostring(os.time()):sub(-6)
    )
    return base:sub(1, 64)
end

---@param data table
---@return table|nil garage, string|nil error
local function createJobGarage(data)
    if type(data) ~= 'table' then return nil, 'error' end
    local job = tostring(data.job or data.job_name or ''):lower():gsub('%s+', '')
    if job == '' then return nil, 'bad_job' end

    local label = data.label or ('Garage ' .. job)
    local x = tonumber(data.x)
    local y = tonumber(data.y)
    local z = tonumber(data.z)
    local heading = tonumber(data.heading) or 0.0
    if not x or not y or not z then return nil, 'bad_coords' end

    local cfg = Config.JobGarages or {}
    local blipDef = cfg.defaultBlip or {}
    local id = data.id or makeId(job)
    local minGrade = tonumber(data.min_grade) or 0
    local storeRadius = tonumber(data.store_radius) or cfg.defaultStoreRadius or 10.0
    local targetRadius = tonumber(data.target_radius) or cfg.defaultTargetRadius or 2.2
    local spawns = data.spawns
    if type(spawns) ~= 'table' or #spawns == 0 then
        spawns = generateSpawns(x, y, z, heading)
    end

    local blipEnabled = data.blip_enabled
    if blipEnabled == nil then blipEnabled = blipDef.enabled ~= false end
    local blipSprite = tonumber(data.blip_sprite) or blipDef.sprite or 357
    local blipColor = tonumber(data.blip_color) or blipDef.color or 47
    local blipScale = tonumber(data.blip_scale) or blipDef.scale or 0.7

    MySQL.insert.await([[
        INSERT INTO ox_garage_job_garages
          (id, job_name, label, min_grade, x, y, z, heading, store_radius, target_radius,
           spawns, blip_enabled, blip_sprite, blip_color, blip_scale, created_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        id, job, label, minGrade, x, y, z, heading, storeRadius, targetRadius,
        json.encode(spawns), blipEnabled and 1 or 0, blipSprite, blipColor, blipScale,
        data.created_by,
    })

    local garage = rowToGarage({
        id = id,
        job_name = job,
        label = label,
        min_grade = minGrade,
        x = x, y = y, z = z,
        heading = heading,
        store_radius = storeRadius,
        target_radius = targetRadius,
        spawns = json.encode(spawns),
        blip_enabled = blipEnabled and 1 or 0,
        blip_sprite = blipSprite,
        blip_color = blipColor,
        blip_scale = blipScale,
    })

    JobGarageCache[id] = garage
    broadcastGarages()
    return garage
end

local function deleteJobGarage(id)
    id = tostring(id or '')
    if id == '' or not JobGarageCache[id] then
        return false, 'not_found'
    end
    MySQL.update.await('DELETE FROM ox_garage_job_garages WHERE id = ?', { id })
    JobGarageCache[id] = nil
    broadcastGarages()
    return true
end

lib.callback.register('ox_garage:getJobGarages', function()
    local list = {}
    for _i, g in pairs(JobGarageCache) do
        list[#list + 1] = g
    end
    return list
end)

--- Création depuis le client (commande)
lib.callback.register('ox_garage:adminCreateJobGarage', function(source, payload)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not isGarageAdmin(xPlayer) then
        return { ok = false, error = 'no_perm' }
    end

    if type(payload) ~= 'table' then
        return { ok = false, error = 'error' }
    end

    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    local garage, err = createJobGarage({
        job = payload.job,
        label = payload.label,
        min_grade = payload.min_grade,
        x = coords.x,
        y = coords.y,
        z = coords.z,
        heading = heading,
        store_radius = payload.store_radius,
        created_by = xPlayer.identifier,
    })

    if not garage then
        return { ok = false, error = err or 'error' }
    end

    return { ok = true, garage = garage }
end)

lib.callback.register('ox_garage:adminDeleteJobGarage', function(source, id)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not isGarageAdmin(xPlayer) then
        return { ok = false, error = 'no_perm' }
    end
    local ok, err = deleteJobGarage(id)
    if not ok then return { ok = false, error = err } end
    return { ok = true }
end)

lib.callback.register('ox_garage:adminListJobGarages', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not isGarageAdmin(xPlayer) then return {} end
    local list = {}
    for _i, g in pairs(JobGarageCache) do
        list[#list + 1] = {
            id = g.id,
            job = g.job,
            label = g.label,
            coords = g.coords,
        }
    end
    table.sort(list, function(a, b) return (a.id or '') < (b.id or '') end)
    return list
end)

AddEventHandler('esx:playerLoaded', function(playerId)
    local list = {}
    for _i, g in pairs(JobGarageCache) do
        list[#list + 1] = g
    end
    TriggerClientEvent('ox_garage:syncJobGarages', playerId, list)
end)

--- Export serveur
---@param data { job: string, label?: string, x: number, y: number, z: number, heading?: number, min_grade?: number, spawns?: table }
exports('AddJobGarage', function(data)
    local garage, err = createJobGarage(data)
    if not garage then return false, err end
    return garage
end)

exports('RemoveJobGarage', function(id)
    return deleteJobGarage(id)
end)

exports('GetJobGarages', function()
    local list = {}
    for _i, g in pairs(JobGarageCache) do
        list[#list + 1] = g
    end
    return list
end)

print('^2[ox_garage]^0 module garages entreprise (commande) chargé.')
