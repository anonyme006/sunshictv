--[[
    Garages entreprise dynamiques (créés via /addjobgarage)
]]

local jobGarageZones = {} ---@type table<string, number|string>
local jobGarageBlips = {} ---@type table<string, number>

local function clearJobGarage(id)
    if jobGarageZones[id] then
        exports.ox_target:removeZone(jobGarageZones[id])
        jobGarageZones[id] = nil
    end
    if jobGarageBlips[id] then
        RemoveBlip(jobGarageBlips[id])
        jobGarageBlips[id] = nil
    end
end

local function clearAllJobGarages()
    for id in pairs(jobGarageZones) do
        clearJobGarage(id)
    end
    for id in pairs(jobGarageBlips) do
        clearJobGarage(id)
    end
end

local function toVec3(c)
    if not c then return nil end
    if type(c) == 'vector3' then return c end
    return vec3(c.x + 0.0, c.y + 0.0, c.z + 0.0)
end

local function toSpawn(s)
    if not s then return nil end
    return vec4(s.x + 0.0, s.y + 0.0, s.z + 0.0, (s.w or s.h or 0.0) + 0.0)
end

local function registerJobGarage(garage)
    if not garage or not garage.id or not garage.job then return end
    clearJobGarage(garage.id)

    local coords = toVec3(garage.coords or (garage.target and garage.target.coords))
    if not coords then return end

    local storeCoords = toVec3(garage.store and garage.store.coords or coords)
    local storeRadius = (garage.store and garage.store.radius) or Config.StoreDistance
    local targetRadius = (garage.target and garage.target.radius) or 2.2

    local spawns = {}
    for i, s in ipairs(garage.spawns or {}) do
        spawns[i] = toSpawn(s)
    end

    local menuData = {
        job = garage.job,
        garageId = garage.id,
        label = garage.label or ('Garage ' .. garage.job),
        min_grade = garage.min_grade or 0,
        store = { coords = storeCoords, radius = storeRadius },
        spawns = spawns,
    }

    if garage.blip and garage.blip.enabled then
        local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(blip, garage.blip.sprite or 357)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, garage.blip.scale or 0.7)
        SetBlipColour(blip, garage.blip.color or 47)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(menuData.label)
        EndTextCommandSetBlipName(blip)
        jobGarageBlips[garage.id] = blip
    end

    local zoneId = exports.ox_target:addSphereZone({
        coords = coords,
        radius = targetRadius,
        debug = false,
        options = {
            {
                name = 'ox_garage_job_open_' .. garage.id,
                icon = 'fa-solid fa-building',
                label = L('target_open'),
                distance = 2.2,
                canInteract = function()
                    local data = ESX.GetPlayerData and ESX.GetPlayerData() or ESX.PlayerData
                    local job = data and data.job
                    if not job or job.name ~= garage.job then return false end
                    return (job.grade or 0) >= (garage.min_grade or 0)
                end,
                onSelect = function()
                    OpenJobGarageMenu(menuData)
                end,
            },
            {
                name = 'ox_garage_job_store_' .. garage.id,
                icon = 'fa-solid fa-square-parking',
                label = L('target_store'),
                distance = 2.5,
                canInteract = function()
                    local data = ESX.GetPlayerData and ESX.GetPlayerData() or ESX.PlayerData
                    local job = data and data.job
                    if not job or job.name ~= garage.job then return false end
                    if (job.grade or 0) < (garage.min_grade or 0) then return false end
                    local veh = PlayerInOwnedVehicle()
                    if not veh then return false end
                    return #(GetEntityCoords(veh) - storeCoords) <= storeRadius
                end,
                onSelect = function()
                    local veh = PlayerInOwnedVehicle()
                    if not veh then return end
                    local plate = GetVehicleNumberPlateText(veh)
                    local jobVeh = lib.callback.await('ox_garage:getJobVehicle', false, plate)
                    if jobVeh then
                        OpenJobStoreMenu(menuData, veh, jobVeh)
                        return
                    end
                    if Config.JobCreator and Config.JobCreator.allowPersonalVehicles ~= false then
                        local personal = lib.callback.await('ox_garage:getVehicle', false, plate)
                        if personal then
                            OpenJobStoreMenu(menuData, veh, {
                                plate = personal.plate,
                                model = personal.model,
                                isPersonal = true,
                            })
                            return
                        end
                    end
                    Notify(L('job_not_job_vehicle'), 'error')
                end,
            },
        },
    })

    jobGarageZones[garage.id] = zoneId
end

RegisterNetEvent('ox_garage:syncJobGarages', function(list)
    clearAllJobGarages()
    for _, garage in ipairs(list or {}) do
        registerJobGarage(garage)
    end
end)

CreateThread(function()
    Wait(1500)
    local list = lib.callback.await('ox_garage:getJobGarages', false) or {}
    clearAllJobGarages()
    for _, garage in ipairs(list) do
        registerJobGarage(garage)
    end
end)

--- Commande admin : créer un garage entreprise à ta position
RegisterCommand('addjobgarage', function()
    local input = lib.inputDialog(L('jobgarage_create_title'), {
        { type = 'input', label = L('jobgarage_job'), required = true, placeholder = 'police' },
        { type = 'input', label = L('jobgarage_label'), required = true, placeholder = 'Garage LSPD' },
        { type = 'number', label = L('jobgarage_grade'), default = 0, min = 0, max = 20 },
        { type = 'number', label = L('jobgarage_radius'), default = 10, min = 4, max = 40 },
    })

    if not input then return end

    local result = lib.callback.await('ox_garage:adminCreateJobGarage', false, {
        job = input[1],
        label = input[2],
        min_grade = input[3],
        store_radius = input[4],
    })

    if not result or not result.ok then
        local err = result and result.error
        local map = {
            no_perm = L('jobgarage_no_perm'),
            bad_job = L('jobgarage_bad_job'),
        }
        Notify(map[err] or L('notify_error'), 'error')
        return
    end

    Notify(L('jobgarage_created', result.garage.label, result.garage.id), 'success')
end, false)

RegisterCommand('deljobgarage', function(_, args)
    local id = args[1]
    if not id or id == '' then
        Notify(L('jobgarage_need_id'), 'error')
        return
    end

    local result = lib.callback.await('ox_garage:adminDeleteJobGarage', false, id)
    if not result or not result.ok then
        local err = result and result.error
        local map = {
            no_perm = L('jobgarage_no_perm'),
            not_found = L('jobgarage_not_found'),
        }
        Notify(map[err] or L('notify_error'), 'error')
        return
    end

    Notify(L('jobgarage_deleted', id), 'success')
end, false)

RegisterCommand('listjobgarages', function()
    local list = lib.callback.await('ox_garage:adminListJobGarages', false) or {}
    if #list == 0 then
        Notify(L('jobgarage_empty'), 'inform')
        return
    end

    local options = {}
    for _, g in ipairs(list) do
        options[#options + 1] = {
            title = g.label or g.id,
            description = ('%s  ·  %s'):format(g.job or '?', g.id),
            icon = 'building',
            metadata = {
                { label = 'ID', value = g.id },
                { label = 'Job', value = g.job },
            },
        }
    end

    lib.registerContext({
        id = 'ox_garage_job_list',
        title = L('jobgarage_list_title'),
        options = options,
    })
    lib.showContext('ox_garage_job_list')
end, false)

TriggerEvent('chat:addSuggestion', '/addjobgarage', 'Créer un garage entreprise à ta position')
TriggerEvent('chat:addSuggestion', '/deljobgarage', 'Supprimer un garage entreprise', {
    { name = 'id', help = 'ID du garage (voir /listjobgarages)' },
})
TriggerEvent('chat:addSuggestion', '/listjobgarages', 'Lister les garages entreprise dynamiques')
