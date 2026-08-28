local selectOpen = false
local selectCam
local selectLocation
local justCreatedAt = 0
local pendingCid

local function resourceStarted(name)
    local alt = name:find('_') and name:gsub('_', '-') or name:gsub('-', '_')
    return GetResourceState(name):find('start') or GetResourceState(alt):find('start')
end

local function sendNui(action, data)
    SendNUIMessage({ action = action, data = data })
end

local function destroySelectCam()
    if selectCam and DoesCamExist(selectCam) then
        RenderScriptCams(false, true, 600, true, true)
        SetCamActive(selectCam, false)
        DestroyCam(selectCam, true)
    end
    selectCam = nil
    SetTimecycleModifier('default')
end

local function setupSelectCam()
    destroySelectCam()
    if not selectLocation then return end

    local cam = selectLocation.CamCoords
    selectCam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', cam.x, cam.y, cam.z, -6.0, 0.0, cam.w, 40.0, false, 0)
    SetCamActive(selectCam, true)
    SetCamUseShallowDofMode(selectCam, true)
    SetCamNearDof(selectCam, 0.4)
    SetCamFarDof(selectCam, 1.8)
    SetCamDofStrength(selectCam, 0.7)
    RenderScriptCams(true, false, 1, true, true)

    CreateThread(function()
        while selectOpen and DoesCamExist(selectCam) do
            SetUseHiDof()
            Wait(0)
        end
    end)
end

local function randomClothes(entity)
    for i = 0, 11 do
        SetPedComponentVariation(entity, i, 0, 0, 0)
    end
    for i = 0, 7 do
        ClearPedProp(entity, i)
    end
    Appearance.Apply(entity, SharedUtils.DefaultAppearance(GetEntityModel(entity) == joaat(Config.Models.female) and 1 or 0))
end

local function applyPreview(citizenid)
    if not citizenid then
        randomClothes(PlayerPedId())
        return
    end

    if Rcore.IsAvailable() and Rcore.ApplyPreview(PlayerPedId(), citizenid) then
        return
    end

    local clothing, model, gender = lib.callback.await('qbx-charactercreator:server:previewPed', false, citizenid)
    if model then
        local modelName = type(model) == 'string' and model or nil
        if not modelName then
            modelName = (tonumber(gender) == 1) and Config.Models.female or Config.Models.male
        end
        ClientUtils.SetPlayerModel(modelName)
    end

    local ped = PlayerPedId()
    if clothing then
        local decoded = clothing
        if type(clothing) == 'string' then
            local ok, result = pcall(json.decode, clothing)
            decoded = ok and result or nil
        end
        if type(decoded) == 'table' then
            if decoded.heritage or decoded.face or decoded.clothing then
                Appearance.Apply(ped, decoded)
            elseif GetResourceState('illenium-appearance') == 'started' then
                pcall(function()
                    exports['illenium-appearance']:setPedAppearance(ped, decoded)
                end)
            else
                Clothing.Apply(ped, {
                    components = decoded.components,
                    props = decoded.props,
                }, decoded)
            end
            return
        end
    end

    randomClothes(ped)
end

local function closeSelect(keepPed)
    selectOpen = false
    SetNuiFocus(false, false)
    sendNui('closeSelect')
    destroySelectCam()
    if not keepPed then
        FreezeEntityPosition(PlayerPedId(), false)
    end
end

local function spawnAfterSelect(character)
    closeSelect(false)
    DoScreenFadeOut(400)
    while not IsScreenFadedOut() do Wait(10) end

    pcall(function()
        TriggerEvent('qb-weathersync:client:EnableSync')
        TriggerEvent('qbx_weathersync:client:EnableSync')
    end)

    DisplayRadar(true)
    DisplayHud(true)
    FreezeEntityPosition(PlayerPedId(), false)
    SetEntityVisible(PlayerPedId(), true, false)
    SetEntityInvincible(PlayerPedId(), false)

    local citizenid = character and (character.citizenid or character) or nil
    if Config.Multichar.StartingApartment and resourceStarted('qbx_apartments') then
        TriggerEvent('apartments:client:setupSpawnUI', citizenid or character)
        DoScreenFadeIn(250)
    elseif resourceStarted('qbx_spawn') then
        TriggerEvent('qb-spawn:client:setupSpawns', citizenid)
        TriggerEvent('qb-spawn:client:openUI', true)
        DoScreenFadeIn(250)
    else
        local coords = Config.Multichar.DefaultSpawn or Config.Spawn.coords
        SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z, false, false, false, false)
        SetEntityHeading(PlayerPedId(), coords.w)
        pcall(function()
            exports.spawnmanager:spawnPlayer({
                x = coords.x,
                y = coords.y,
                z = coords.z,
                heading = coords.w,
            })
        end)
        DoScreenFadeIn(400)
    end
end

function OpenCharacterSelect()
    if not Config.Multichar.Enabled then return end
    if selectOpen then return end

    local payload = lib.callback.await('qbx-charactercreator:server:getCharacters', false)
    if not payload then return end

    selectLocation = Config.Multichar.Locations[math.random(1, #Config.Multichar.Locations)]
    DoScreenFadeOut(400)
    while not IsScreenFadedOut() do Wait(10) end

    FreezeEntityPosition(PlayerPedId(), true)
    DisplayRadar(false)
    DisplayHud(false)
    SetEntityCoords(PlayerPedId(), selectLocation.PedCoords.x, selectLocation.PedCoords.y, selectLocation.PedCoords.z, false, false, false, false)
    SetEntityHeading(PlayerPedId(), selectLocation.PedCoords.w)
    pcall(function()
        TriggerEvent('qb-weathersync:client:DisableSync')
        TriggerEvent('qbx_weathersync:client:DisableSync')
    end)

    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()

    if payload.characters[1] then
        applyPreview(payload.characters[1].citizenid)
    else
        ClientUtils.SetPlayerModel(Config.Models.male)
        randomClothes(PlayerPedId())
    end

    selectOpen = true
    setupSelectCam()
    SetNuiFocus(true, true)
    sendNui('select', payload)
    DoScreenFadeIn(500)
end

RegisterNUICallback('selectPreview', function(data, cb)
    if not selectOpen then
        cb({ ok = false })
        return
    end
    applyPreview(data and data.citizenid or nil)
    cb({ ok = true })
end)

RegisterNUICallback('selectPlay', function(data, cb)
    if not selectOpen or type(data) ~= 'table' or not data.citizenid then
        cb({ ok = false })
        return
    end

    DoScreenFadeOut(200)
    local result = lib.callback.await('qbx-charactercreator:server:loadCharacter', false, data.citizenid)
    if not result or not result.ok then
        DoScreenFadeIn(200)
        ClientUtils.Notify(SharedUtils.Locale(result and result.error or 'notify.save_error'), 'error')
        cb({ ok = false, error = result and result.error })
        return
    end

    spawnAfterSelect(data)
    cb({ ok = true })
end)

RegisterNUICallback('selectCreate', function(data, cb)
    if not selectOpen then
        cb({ ok = false })
        return
    end

    pendingCid = data and tonumber(data.cid) or nil
    selectOpen = false
    SetNuiFocus(false, false)
    sendNui('closeSelect')
    cb({ ok = true })
    Wait(50)
    TriggerEvent('qbx-charactercreator:client:open', {
        mode = 'register',
        first = true,
        cid = pendingCid,
        fromMultichar = true,
        skipStudio = true,
        identityOnly = true,
    })
end)

RegisterNUICallback('selectDelete', function(data, cb)
    if not selectOpen or type(data) ~= 'table' or not data.citizenid then
        cb({ ok = false })
        return
    end

    local result = lib.callback.await('qbx-charactercreator:server:deleteCharacter', false, data.citizenid)
    if not result or not result.ok then
        ClientUtils.Notify(SharedUtils.Locale(result and result.error or 'notify.save_error'), 'error')
        cb({ ok = false, error = result and result.error })
        return
    end

    ClientUtils.Notify(SharedUtils.Locale('notify.char_deleted'), 'success')
    local payload = lib.callback.await('qbx-charactercreator:server:getCharacters', false)
    sendNui('select', payload)
    if payload and payload.characters[1] then
        applyPreview(payload.characters[1].citizenid)
    else
        randomClothes(PlayerPedId())
    end
    cb({ ok = true })
end)

RegisterNetEvent('qbx-charactercreator:client:chooseChar', function()
    OpenCharacterSelect()
end)

RegisterNetEvent('qb-multicharacter:client:chooseChar', function()
    OpenCharacterSelect()
end)

RegisterNetEvent('qbx-charactercreator:client:releaseSelectScene', function()
    destroySelectCam()
    selectOpen = false
end)

RegisterNetEvent('qbx-charactercreator:client:afterCreated', function(citizenid)
    justCreatedAt = GetGameTimer()
    destroySelectCam()
    spawnAfterSelect(citizenid and { citizenid = citizenid } or nil)
end)

RegisterNetEvent('qbx-charactercreator:client:returnToSelect', function()
    destroySelectCam()
    OpenCharacterSelect()
end)

-- Ne pas annuler qb-clothes:client:CreateFirstCharacter : rCore Clothing l'utilise
-- pour ouvrir le créateur d'apparence initial.

if Config.Multichar.Enabled and Config.Multichar.TakeOverSession then
    CreateThread(function()
        while true do
            Wait(0)
            if NetworkIsSessionStarted() then
                pcall(function() exports.spawnmanager:setAutoSpawn(false) end)
                Wait(250)
                lib.requestModel(joaat(Config.Models.male), 10000)
                SetPlayerModel(PlayerId(), joaat(Config.Models.male))
                OpenCharacterSelect()
                break
            end
        end
    end)
end

RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
    if GetInvokingResource() then return end
    if Config.Multichar.Enabled then
        OpenCharacterSelect()
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if selectOpen then
        closeSelect(false)
    end
end)

exports('OpenCharacterSelect', OpenCharacterSelect)
exports('IsSelectOpen', function()
    return selectOpen
end)
