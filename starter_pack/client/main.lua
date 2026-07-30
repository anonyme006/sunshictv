local isNuiOpen = false
local awaitingResult = false

local function closeNui()
    if not isNuiOpen then return end
    isNuiOpen = false
    awaitingResult = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
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
    SetModelAsNoLongerNeeded(model)

    TriggerEvent('esx:showNotification', 'Ton BMX t\'attend à côté de toi.')
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
