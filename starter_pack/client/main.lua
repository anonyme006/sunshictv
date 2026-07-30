local isNuiOpen = false
local awaitingResult = false
local storingBmx = false

--- netId des BMX spawnés par ce client (fallback si state bag lent)
local localBmxNetIds = {}

local function closeNui()
    if not isNuiOpen then return end
    isNuiOpen = false
    awaitingResult = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function notify(msg)
    TriggerEvent('esx:showNotification', msg)
end

local function markAsStarterBmx(vehicle)
    if not vehicle or vehicle == 0 then return end
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    SetNetworkIdCanMigrate(netId, true)
    localBmxNetIds[netId] = true

    -- State bag synchronisé (pour ox_target / autres clients)
    Entity(vehicle).state:set('starter_pack_bmx', true, true)
end

local function isStarterBmx(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return false
    end
    if GetEntityModel(entity) ~= Config.BmxModel then
        return false
    end
    local st = Entity(entity).state
    if st and st.starter_pack_bmx then
        return true
    end
    local netId = NetworkGetNetworkIdFromEntity(entity)
    return localBmxNetIds[netId] == true
end

local function deleteBmxVehicle(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    localBmxNetIds[netId] = nil

    local ped = PlayerPedId()
    if IsPedInVehicle(ped, vehicle, false) then
        TaskLeaveVehicle(ped, vehicle, 16)
        local timeout = GetGameTimer() + 2000
        while IsPedInVehicle(ped, vehicle, false) and GetGameTimer() < timeout do
            Wait(50)
        end
    end

    SetEntityAsMissionEntity(vehicle, true, true)
    DeleteVehicle(vehicle)
    if DoesEntityExist(vehicle) then
        DeleteEntity(vehicle)
    end
end

--- Ouvre la fenêtre Carte Chance
RegisterNetEvent('starter_pack:openChanceCard', function(wheel)
    if isNuiOpen then return end

    isNuiOpen = true
    awaitingResult = false
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        wheel = wheel or Config.ChanceCard.wheel,
        minReward = Config.ChanceCard.minReward,
        maxReward = Config.ChanceCard.maxReward,
        successRate = Config.ChanceCard.successRate,
    })
end)

--- Résultat validé par le serveur → anime la roue côté NUI
RegisterNetEvent('starter_pack:spinResult', function(data)
    if not isNuiOpen then return end
    awaitingResult = false
    SendNUIMessage({
        action = 'result',
        success = data.success,
        amount = data.amount or 0,
        error = data.error == true,
    })
end)

--- Spawne un BMX près du joueur
RegisterNetEvent('starter_pack:spawnBmx', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local offset = Config.BmxSpawnOffset
    local model = Config.BmxModel

    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do
        Wait(50)
    end

    if not HasModelLoaded(model) then
        return
    end

    local x = coords.x + offset.x
    local y = coords.y + offset.y
    local z = coords.z + offset.z
    local vehicle = CreateVehicle(model, x, y, z, heading, true, false)

    SetVehicleOnGroundProperly(vehicle)
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    SetModelAsNoLongerNeeded(model)

    markAsStarterBmx(vehicle)

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    TriggerServerEvent('starter_pack:registerBmx', netId)

    notify(Config.Locale.bmx_spawned or 'Ton BMX t\'attend à côté de toi.')
end)

--- Ranger via ox_target
local function storeBmxEntity(entity)
    if storingBmx then
        return notify(Config.Locale.bmx_busy or 'Action déjà en cours…')
    end
    if not isStarterBmx(entity) then
        return notify(Config.Locale.bmx_invalid or 'Ce BMX ne peut pas être rangé.')
    end

    storingBmx = true

    local progress = Config.BmxTarget and Config.BmxTarget.progress or 0
    if progress > 0 and GetResourceState('ox_lib') == 'started' then
        local ok = exports.ox_lib:progressCircle({
            duration = progress,
            label = 'Rangement du BMX…',
            position = 'bottom',
            useWhileDead = false,
            canCancel = true,
            disable = { move = true, car = true, combat = true },
            anim = { dict = 'anim@heists@keycard@', clip = 'exit' },
        })
        if not ok then
            storingBmx = false
            return notify(Config.Locale.bmx_cancelled or 'Annulé.')
        end
    else
        Wait(math.max(progress, 0))
    end

    if not DoesEntityExist(entity) or not isStarterBmx(entity) then
        storingBmx = false
        return notify(Config.Locale.bmx_invalid or 'Ce BMX ne peut pas être rangé.')
    end

    local netId = NetworkGetNetworkIdFromEntity(entity)
    TriggerServerEvent('starter_pack:storeBmx', netId)
    -- La réponse arrive via starter_pack:storeBmxResult (suppression véhicule si ok)
end

RegisterNetEvent('starter_pack:storeBmxResult', function(result, netId)
    storingBmx = false

    if type(result) ~= 'table' or not result.ok then
        local err = result and result.error
        if err == 'inventory' then
            notify(Config.Locale.bmx_inventory_full or 'Inventaire plein.')
        elseif err == 'busy' then
            notify(Config.Locale.bmx_busy or 'Action déjà en cours…')
        else
            notify(Config.Locale.bmx_invalid or 'Impossible de ranger le BMX.')
        end
        return
    end

    local entity = 0
    if netId then
        entity = NetworkGetEntityFromNetworkId(netId)
    end
    if entity and entity ~= 0 and DoesEntityExist(entity) then
        deleteBmxVehicle(entity)
    end

    notify(Config.Locale.bmx_stored or 'BMX rangé dans ton inventaire.')
end)

--- ox_target sur le modèle BMX
CreateThread(function()
    if not Config.BmxTarget or not Config.BmxTarget.enabled then return end

    while GetResourceState('ox_target') ~= 'started' do
        Wait(500)
    end

    exports.ox_target:addModel(Config.BmxModel, {
        {
            name = 'starter_pack_store_bmx',
            icon = Config.BmxTarget.icon or 'fa-solid fa-box',
            label = Config.BmxTarget.label or 'Ranger dans l\'inventaire',
            distance = Config.BmxTarget.distance or 2.5,
            canInteract = function(entity)
                return isStarterBmx(entity) and not storingBmx
            end,
            onSelect = function(data)
                storeBmxEntity(data.entity)
            end,
        },
    })
end)

--- NUI callbacks
RegisterNUICallback('spin', function(_, cb)
    if not isNuiOpen or awaitingResult then
        cb({ ok = false })
        return
    end

    awaitingResult = true
    TriggerServerEvent('starter_pack:claimSpin')
    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    if awaitingResult then
        cb({ ok = false })
        return
    end

    TriggerServerEvent('starter_pack:cancelSpin')
    closeNui()
    cb({ ok = true })
end)

RegisterNUICallback('done', function(_, cb)
    closeNui()
    cb({ ok = true })
end)

--- ESC pour fermer (si pas en cours de tirage)
CreateThread(function()
    while true do
        if isNuiOpen then
            DisableControlAction(0, 200, true) -- pause
            if IsDisabledControlJustReleased(0, 200) and not awaitingResult then
                TriggerServerEvent('starter_pack:cancelSpin')
                closeNui()
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)
