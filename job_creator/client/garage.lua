local spawnedVehicles = {}

function JC_C.OpenGarage(marker)
    local list = {}
    local job = JC_C.GetJob()
    for _, v in pairs(JC_C.Vehicles) do
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
            spawn = (marker.data and marker.data.spawn) or nil,
        },
    })
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
    spawnedVehicles[veh] = true
    JC_C.Notify(_('vehicle_spawned'))
end

local function getClosestVehicle(maxDist)
    if ESX.Game and ESX.Game.GetClosestVehicle then
        return ESX.Game.GetClosestVehicle()
    end
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local vehicles = GetGamePool('CVehicle')
    local closest, closestDist = 0, maxDist or 8.0
    for _, veh in ipairs(vehicles) do
        local dist = #(coords - GetEntityCoords(veh))
        if dist < closestDist then
            closestDist = dist
            closest = veh
        end
    end
    return closest
end

local function deleteVehicle(veh)
    if ESX.Game and ESX.Game.DeleteVehicle then
        ESX.Game.DeleteVehicle(veh)
        return
    end
    SetEntityAsMissionEntity(veh, true, true)
    DeleteVehicle(veh)
end

function JC_C.StoreVehicle(marker)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        veh = getClosestVehicle(8.0)
    end
    if not veh or veh == 0 then
        return JC_C.Notify(_('no_vehicle'))
    end

    local maxDist = (marker.data and marker.data.radius) or 8.0
    local c = marker.coords
    if #(GetEntityCoords(veh) - vector3(c.x, c.y, c.z)) > maxDist then
        return JC_C.Notify(_('no_vehicle'))
    end

    TaskLeaveVehicle(ped, veh, 0)
    Wait(1200)
    deleteVehicle(veh)
    JC_C.Notify(_('vehicle_stored'))
end

RegisterNUICallback('garageSpawn', function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closePlayerMenu' })
    JC_C.SpawnJobVehicle(data.model, data.spawn, data.livery)
    cb({ ok = true })
end)
