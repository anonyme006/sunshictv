--[[
    Garage job — ox_garage (panel : mode + garage lié)
]]

local function oxGarageReady()
    if not Config.UseOxGarage then return false end
    return GetResourceState('ox_garage') == 'started'
end

local function markerToOxData(marker)
    local d = marker.data or {}
    local spawn = d.spawn
    local spawns = {}

    if spawn and spawn.x then
        spawns[1] = vec4(spawn.x + 0.0, spawn.y + 0.0, spawn.z + 0.0, (spawn.w or 0.0) + 0.0)
    else
        local c = marker.coords
        spawns[1] = vec4(c.x + 2.0, c.y + 2.0, c.z, 0.0)
    end

    if type(d.spawns) == 'table' then
        for _i, s in ipairs(d.spawns) do
            if s.x then
                spawns[#spawns + 1] = vec4(s.x + 0.0, s.y + 0.0, s.z + 0.0, (s.w or 0.0) + 0.0)
            end
        end
    end

    local radius = tonumber(d.radius) or 8.0
    local c = marker.coords
    local garageId = d.ox_garage_id
    if not garageId or garageId == '' then
        garageId = tostring(marker.id)
    end

    return {
        job = marker.job_name,
        garageId = tostring(garageId),
        label = marker.label or ('Garage ' .. (marker.job_name or '')),
        min_grade = marker.min_grade or 0,
        spawns = spawns,
        store = {
            coords = vec3(c.x + 0.0, c.y + 0.0, c.z + 0.0),
            radius = radius,
        },
    }
end

function JC_C.OpenGarage(marker)
    local d = marker.data or {}
    local mode = d.ox_mode or 'job_fleet'

    if oxGarageReady() then
        -- Garage ox_garage perso / public / privé (owned_vehicles)
        if mode == 'ox_garage' and d.ox_garage_id and d.ox_garage_id ~= '' then
            exports.ox_garage:OpenGarage(d.ox_garage_id)
            return
        end

        -- Flotte entreprise ox_garage
        exports.ox_garage:OpenJobGarage(markerToOxData(marker))
        return
    end

    -- Fallback NUI
    local list = {}
    local job = JC_C.GetJob()
    for _i, v in pairs(JC_C.Vehicles) do
        if v.job_name == marker.job_name and (not v.marker_id or v.marker_id == marker.id) then
            if job and (job.grade or 0) >= (v.min_grade or 0) then
                list[#list + 1] = v
            end
        end
    end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'playerMenu',
        data = {
            type = 'garage',
            title = marker.label or 'Garage',
            items = list,
            markerId = marker.id,
            spawn = d.spawn or nil,
        },
    })
end

function JC_C.StoreVehicle(marker)
    local d = marker.data or {}
    local mode = d.ox_mode or 'job_fleet'

    if oxGarageReady() then
        if mode == 'ox_garage' and d.ox_garage_id and d.ox_garage_id ~= '' then
            if exports.ox_garage.OpenGarageStore then
                exports.ox_garage:OpenGarageStore(d.ox_garage_id)
            else
                exports.ox_garage:OpenGarage(d.ox_garage_id)
            end
            return
        end

        exports.ox_garage:OpenJobStore(markerToOxData(marker))
        return
    end

    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        local coords = GetEntityCoords(ped)
        local closest, closestDist = 0, 8.0
        for _i, v in ipairs(GetGamePool('CVehicle')) do
            local dist = #(coords - GetEntityCoords(v))
            if dist < closestDist then
                closestDist = dist
                closest = v
            end
        end
        veh = closest
    end
    if not veh or veh == 0 then
        return JC_C.Notify(L('no_vehicle'))
    end

    local maxDist = tonumber(d.radius) or 8.0
    local c = marker.coords
    if #(GetEntityCoords(veh) - vector3(c.x, c.y, c.z)) > maxDist then
        return JC_C.Notify(L('no_vehicle'))
    end

    TaskLeaveVehicle(ped, veh, 0)
    Wait(1200)
    SetEntityAsMissionEntity(veh, true, true)
    DeleteVehicle(veh)
    JC_C.Notify(L('vehicle_stored'))
end

function JC_C.SpawnJobVehicle(model, spawn, livery)
    local ped = PlayerPedId()
    local hash = type(model) == 'number' and model or joaat(model)

    if not IsModelInCdimage(hash) then
        JC_C.Notify('Modèle invalide')
        return
    end

    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(50) end
    if not HasModelLoaded(hash) then return end

    local coords = spawn
    if not coords then
        local c = GetEntityCoords(ped)
        local h = GetEntityHeading(ped)
        coords = { x = c.x + 2.0, y = c.y, z = c.z, w = h }
    end

    local veh = CreateVehicle(hash, coords.x, coords.y, coords.z, coords.w or 0.0, true, false)
    SetVehicleOnGroundProperly(veh)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetVehicleNeedsToBeHotwired(veh, false)
    SetModelAsNoLongerNeeded(hash)

    if livery and livery > 0 then
        SetVehicleLivery(veh, livery)
    end

    TaskWarpPedIntoVehicle(ped, veh, -1)
    JC_C.Notify(L('vehicle_spawned'))
end

RegisterNUICallback('garageSpawn', function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closePlayerMenu' })
    JC_C.SpawnJobVehicle(data.model, data.spawn, data.livery)
    cb({ ok = true })
end)

--- Rafraîchir la liste ox_garage pour le panel (via serveur)
RegisterNUICallback('adminGetOxGarages', function(_, cb)
    TriggerServerEvent('job_creator:requestOxGarages')
    cb({ ok = true })
end)

RegisterNetEvent('job_creator:oxGarages', function(list)
    SendNUIMessage({
        action = 'oxGarages',
        data = list or {},
    })
end)
