ClientUtils = {}

function ClientUtils.Notify(description, notifyType)
    lib.notify({
        title = SharedUtils.Locale('ui.title'),
        description = description,
        type = notifyType or 'inform',
        position = 'top-right',
        duration = 4500,
    })
end

function ClientUtils.Debug(...)
    if not Config.Debug then return end
    print('[qbx-charactercreator]', ...)
end

function ClientUtils.LoadAnimDict(dict)
    if not dict or dict == '' then return false end
    if HasAnimDictLoaded(dict) then return true end

    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > timeout then
            return false
        end
        Wait(10)
    end
    return true
end

function ClientUtils.RequestModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then
        return false
    end

    lib.requestModel(hash, 10000)
    return HasModelLoaded(hash)
end

function ClientUtils.SetPlayerModel(modelName)
    local ped = PlayerPedId()
    local hash = joaat(modelName)
    if GetEntityModel(ped) == hash then
        return PlayerPedId()
    end

    if not ClientUtils.RequestModel(hash) then
        return ped
    end

    local health = GetEntityHealth(ped)
    local maxHealth = GetEntityMaxHealth(ped)
    SetPlayerModel(PlayerId(), hash)
    SetModelAsNoLongerNeeded(hash)

    ped = PlayerPedId()
    SetPedDefaultComponentVariation(ped)
    SetEntityHealth(ped, health, 0)
    SetPedMaxHealth(ped, maxHealth)
    return ped
end

function ClientUtils.HideHud(hidden)
    DisplayRadar(not hidden)
    DisplayHud(not hidden)

    local events = hidden and Config.HudEvents.hide or Config.HudEvents.show
    for i = 1, #events do
        TriggerEvent(events[i])
    end

    if Config.Creator.DisableTarget and GetResourceState('ox_target') == 'started' then
        pcall(function()
            exports.ox_target:disableTargeting(hidden)
        end)
    end

    if Config.Creator.DisableInventory then
        LocalPlayer.state:set('invBusy', hidden, true)
        LocalPlayer.state:set('invHotkeys', not hidden, true)
    end
end

function ClientUtils.PlayFrontendSound(name, set)
    if not Config.Sound.enabled or not Config.Creator.EnableSound then return end
    PlaySoundFrontend(-1, name, set or 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
end

function ClientUtils.DrawStudioLight(ped)
    if not Config.Lights.enabled then return end
    local coords = GetEntityCoords(ped)
    local color = Config.Lights.color
    DrawLightWithRange(coords.x, coords.y, coords.z + 1.15, color[1], color[2], color[3], Config.Lights.range, Config.Lights.intensity)
end
