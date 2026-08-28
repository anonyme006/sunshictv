local creatorOpen = false
local sessionThread = false
local draftThread = false
local currentMode = 'edit'
local currentState
local previousSnapshot
local previousCoords
local previousHeading
local lastDraftSent = 0
local firstCharacter = false

local function ped()
    return PlayerPedId()
end

local function visibleCategories()
    local list = {}
    for i = 1, #Config.Categories do
        local key = Config.Categories[i]
        local skip = (key == 'makeup' and not Config.EnableMakeup)
            or (key == 'clothing' and not Config.EnableClothing)
            or (key == 'accessories' and not Config.EnableAccessories)
        if not skip then
            list[#list + 1] = key
        end
    end
    return list
end

local function identityFromPlayer()
    local info = lib.callback.await('qbx-charactercreator:server:getCharInfo', false) or {}
    return {
        firstname = info.firstname or '',
        lastname = info.lastname or '',
        birthdate = info.birthdate or '',
        gender = tonumber(info.gender) or 0,
        height = tonumber(info.height) or Config.Identity.defaultHeight,
        nationality = info.nationality or Config.Identity.defaultNationality,
    }
end

local function buildState(mode, draft)
    local identity = identityFromPlayer()
    local appearance

    if draft and draft.appearance then
        appearance = draft.appearance
        if draft.identity then
            for key, value in pairs(draft.identity) do
                if value ~= nil and value ~= '' then
                    identity[key] = value
                end
            end
        end
    else
        local saved = lib.callback.await('qbx-charactercreator:server:getAppearance', false)
        appearance = saved or SharedUtils.DefaultAppearance(identity.gender)
    end

    appearance.model = SharedUtils.GetModelFromGender(identity.gender)
    return {
        mode = mode,
        first = firstCharacter,
        allowCancel = Config.AllowCancel and mode ~= 'register',
        identity = identity,
        appearance = appearance,
        categories = visibleCategories(),
        locales = Locales[Config.Locale] or Locales.fr,
        parents = Config.Parents,
        nationalities = Config.Nationalities,
        limits = Appearance.GetLimits(ped()),
        clothingSlots = Config.ClothingSlots,
        accessorySlots = Config.AccessorySlots,
        config = {
            minAge = Config.MinimumAge,
            maxAge = Config.MaximumAge,
            minHeight = Config.Identity.minHeight,
            maxHeight = Config.Identity.maxHeight,
            minName = Config.Identity.minNameLength,
            maxName = Config.Identity.maxNameLength,
            sound = Config.Sound.enabled and Config.Creator.EnableSound,
            volume = Config.Sound.volume,
            enableMakeup = Config.EnableMakeup,
            enableClothing = Config.EnableClothing,
            enableAccessories = Config.EnableAccessories,
        },
    }
end

local function freezeGameplay(state)
    local playerPed = ped()
    FreezeEntityPosition(playerPed, state)
    SetEntityInvincible(playerPed, state)
    SetEntityVisible(playerPed, true, false)
    SetEntityCollision(playerPed, not state, not state)
    SetPedCanRagdoll(playerPed, not state)
    SetPedCanBeTargetted(playerPed, not state)
    SetCurrentPedWeapon(playerPed, `WEAPON_UNARMED`, true)
    LocalPlayer.state:set('creatingCharacter', state, true)
end

local function placeInStudio()
    for i = 1, #Config.CreatorIpls do
        RequestIpl(Config.CreatorIpls[i])
    end

    local coords = Config.CreatorPosition
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    SetEntityCoords(ped(), coords.x, coords.y, coords.z, false, false, false, false)
    SetEntityHeading(ped(), coords.w)
    Wait(150)
    FreezeEntityPosition(ped(), true)
end

local function restoreLocation()
    if previousCoords then
        SetEntityCoords(ped(), previousCoords.x, previousCoords.y, previousCoords.z, false, false, false, false)
        SetEntityHeading(ped(), previousHeading or 0.0)
    elseif Config.Spawn and Config.Spawn.coords then
        local spawn = Config.Spawn.coords
        SetEntityCoords(ped(), spawn.x, spawn.y, spawn.z, false, false, false, false)
        SetEntityHeading(ped(), spawn.w)
    end
end

local function startSessionThread()
    if sessionThread then return end
    sessionThread = true

    CreateThread(function()
        while creatorOpen do
            local playerPed = ped()
            DisableAllControlActions(0)
            EnableControlAction(0, 249, true)

            HideHudAndRadarThisFrame()
            CreatorCamera.UpdateFollow()
            ClientUtils.DrawStudioLight(playerPed)
            Wait(0)
        end
        sessionThread = false
    end)
end

local function startDraftThread()
    if not Config.Draft.enabled or not Config.EnableDrafts or draftThread then return end
    draftThread = true

    CreateThread(function()
        while creatorOpen and currentState do
            Wait(Config.Draft.saveIntervalMs)
            if not creatorOpen or not currentState then break end
            local now = GetGameTimer()
            if now - lastDraftSent >= Config.Draft.saveIntervalMs then
                lastDraftSent = now
                TriggerServerEvent('qbx-charactercreator:server:saveDraft', {
                    identity = currentState.identity,
                    appearance = currentState.appearance,
                })
            end
        end
        draftThread = false
    end)
end

local function sendNui(action, data)
    SendNUIMessage({
        action = action,
        data = data,
    })
end

local function closeNui()
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    sendNui('close')
end

local function cleanup(restorePrevious)
    creatorOpen = false
    closeNui()
    CreatorCamera.Destroy()
    Appearance.StopAnimation()
    freezeGameplay(false)
    ClientUtils.HideHud(false)

    if Config.Creator.EnableBlur then
        TriggerScreenblurFadeOut(250)
    end

    if restorePrevious and previousSnapshot then
        Appearance.Apply(ped(), previousSnapshot)
    end

    LocalPlayer.state:set('creatingCharacter', false, true)
    TriggerServerEvent('qbx-charactercreator:server:setBusy', false)
end

local pendingCreateOptions
local identityOpen = false
local waitingForRcore = false
local identityThread = false
local openCreator
local lastCreatedCitizenId

local function usesRcoreAppearance()
    return Config.ClothingSystem == 'rcore_clothing'
end

local function shouldOpenIdentityForm(options)
    options = options or {}
    if options.identityOnly == false then return false end
    if options.identityOnly or options.mode == 'register' or options.first == true then
        return Config.Multichar.IdentityOnly ~= false
    end
    return false
end

local function identityPayload()
    return {
        identity = currentState and currentState.identity or SharedUtils.DefaultIdentity(),
        nationalities = Config.Nationalities,
        locales = Locales[Config.Locale] or Locales.fr,
        allowCancel = currentState and currentState.allowCancel,
        config = {
            minAge = Config.MinimumAge,
            maxAge = Config.MaximumAge,
            minHeight = Config.MinHeight or Config.Identity.minHeight,
            maxHeight = Config.MaxHeight or Config.Identity.maxHeight,
            defaultHeight = Config.Identity.defaultHeight,
            minName = Config.Identity.minNameLength,
            maxName = Config.Identity.maxNameLength,
            sound = Config.Sound.enabled,
            volume = Config.Sound.volume,
        },
    }
end

local function startIdentityThread()
    if identityThread then return end
    identityThread = true
    CreateThread(function()
        while identityOpen do
            DisableAllControlActions(0)
            EnableControlAction(0, 249, true)
            HideHudAndRadarThisFrame()
            Wait(0)
        end
        identityThread = false
    end)
end

local function closeIdentityUi()
    identityOpen = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    sendNui('closeIdentity')
end

local function finishAfterAppearance()
    waitingForRcore = false
    Rcore.ClearPending()
    closeIdentityUi()
    freezeGameplay(false)
    ClientUtils.HideHud(false)
    if Config.Creator.EnableBlur then
        TriggerScreenblurFadeOut(200)
    end
    LocalPlayer.state:set('creatingCharacter', false, true)
    TriggerServerEvent('qbx-charactercreator:server:setBusy', false)

    local gender = GetEntityModel(PlayerPedId()) == joaat(Config.Models.female) and 1 or 0
    TriggerServerEvent('qbx-charactercreator:server:syncGender', gender)

    ClientUtils.Notify(SharedUtils.Locale('notify.save_success'), 'success')
    pendingCreateOptions = nil
    currentState = nil
    firstCharacter = false
    local citizenid = lastCreatedCitizenId
    lastCreatedCitizenId = nil
    TriggerEvent('qbx-charactercreator:client:afterCreated', citizenid)
end

local function handoffToRcore()
    closeIdentityUi()
    freezeGameplay(false)
    if Config.Creator.EnableBlur then
        TriggerScreenblurFadeOut(200)
    end
    TriggerEvent('qbx-charactercreator:client:releaseSelectScene')
    TriggerServerEvent('qbx-charactercreator:server:setBusy', false)

    waitingForRcore = true
    Rcore.OnCreatorDone(function()
        CreateThread(function()
            if not waitingForRcore then return end
            Rcore.BlockReopen()
            Wait(400)
            finishAfterAppearance()
        end)
    end)

    if Rcore.IsAvailable() then
        Wait(250)
        Rcore.OpenFirstCharacter()
        return
    end

    waitingForRcore = false
    Rcore.ClearPending()
    if Config.Rcore and Config.Rcore.FallbackToInternalStudio then
        openCreator({
            mode = 'register',
            first = true,
            cid = pendingCreateOptions and pendingCreateOptions.cid,
            fromMultichar = pendingCreateOptions and pendingCreateOptions.fromMultichar,
            skipStudio = false,
            identityOnly = false,
        })
        return
    end

    ClientUtils.Notify(SharedUtils.Locale('notify.rcore_missing'), 'error')
    finishAfterAppearance()
end

local function openIdentity(options)
    options = options or {}
    if identityOpen or creatorOpen or waitingForRcore then return end

    currentMode = options.mode or 'register'
    firstCharacter = true
    pendingCreateOptions = options

    local allowed = lib.callback.await('qbx-charactercreator:server:canOpen', false, currentMode)
    if not allowed then
        ClientUtils.Notify(SharedUtils.Locale('notify.not_allowed'), 'error')
        return
    end

    currentState = {
        mode = currentMode,
        first = true,
        allowCancel = options.fromMultichar == true or Config.AllowCancel == true,
        identity = {
            firstname = '',
            lastname = '',
            birthdate = '',
            gender = 0,
            height = '',
            nationality = '',
        },
    }

    identityOpen = true
    ClientUtils.HideHud(true)
    freezeGameplay(true)
    startIdentityThread()
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    sendNui('openIdentity', identityPayload())
    TriggerServerEvent('qbx-charactercreator:server:setBusy', true)
end

function openCreator(options)
    options = options or {}
    if creatorOpen then return end

    currentMode = options.mode or 'edit'
    firstCharacter = options.first == true or currentMode == 'register'
    pendingCreateOptions = options

    local allowed = lib.callback.await('qbx-charactercreator:server:canOpen', false, currentMode)
    if not allowed then
        ClientUtils.Notify(SharedUtils.Locale('notify.not_allowed'), 'error')
        return
    end

    local draft
    if Config.Draft.enabled then
        draft = lib.callback.await('qbx-charactercreator:server:getDraft', false)
    end

    previousCoords = GetEntityCoords(ped())
    previousHeading = GetEntityHeading(ped())
    previousSnapshot = Appearance.Collect(ped())

    DoScreenFadeOut(200)
    while not IsScreenFadedOut() do Wait(10) end

    creatorOpen = true
    ClientUtils.HideHud(true)
    if not options.skipStudio then
        placeInStudio()
    end
    freezeGameplay(true)

    currentState = buildState(currentMode, draft)
    currentState.allowCancel = options.fromMultichar or (Config.AllowCancel and currentMode ~= 'register')
    Appearance.Apply(ped(), currentState.appearance)
    currentState.limits = Appearance.GetLimits(ped())
    Appearance.PlayCategoryAnimation('identity')

    if Config.Creator.EnableBlur then
        TriggerScreenblurFadeIn(400)
    end

    CreatorCamera.Create()
    CreatorCamera.SetPreset('body', true)
    startSessionThread()
    startDraftThread()

    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    sendNui('open', currentState)
    TriggerServerEvent('qbx-charactercreator:server:setBusy', true)

    DoScreenFadeIn(350)
    if draft and draft.appearance then
        ClientUtils.Notify(SharedUtils.Locale('notify.draft_restored'), 'inform')
    end
end

local function finishToWorld(success)
    local fromMultichar = pendingCreateOptions and pendingCreateOptions.fromMultichar
    cleanup(false)
    DoScreenFadeOut(250)
    while not IsScreenFadedOut() do Wait(10) end

    if success and fromMultichar and Config.Multichar.Enabled then
        ClientUtils.Notify(SharedUtils.Locale('notify.save_success'), 'success')
        currentState = nil
        previousSnapshot = nil
        firstCharacter = false
        pendingCreateOptions = nil
        TriggerEvent('qbx-charactercreator:client:afterCreated')
        return
    end

    if firstCharacter and Config.Spawn.useQboxSpawn == false then
        restoreLocation()
    elseif firstCharacter then
        local spawn = Config.Spawn.coords
        SetEntityCoords(ped(), spawn.x, spawn.y, spawn.z, false, false, false, false)
        SetEntityHeading(ped(), spawn.w)
    else
        restoreLocation()
    end

    freezeGameplay(false)
    ClientUtils.HideHud(false)
    Wait(200)
    DoScreenFadeIn(400)

    if success then
        ClientUtils.Notify(firstCharacter and SharedUtils.Locale('notify.save_success') or SharedUtils.Locale('notify.appearance_updated'), 'success')
        TriggerEvent('qbx-charactercreator:client:created')
    end

    currentState = nil
    previousSnapshot = nil
    firstCharacter = false
    pendingCreateOptions = nil
end

RegisterNUICallback('ready', function(_, cb)
    cb({ ok = true })
end)

RegisterNUICallback('updateAppearance', function(data, cb)
    if not creatorOpen or type(data) ~= 'table' then
        cb({ ok = false })
        return
    end

    currentState.appearance = currentState.appearance or SharedUtils.DefaultAppearance(0)
    if data.section == 'full' and data.appearance then
        currentState.appearance = data.appearance
        Appearance.Apply(ped(), currentState.appearance)
    elseif data.section == 'overlay' and data.payload and data.payload.name then
        currentState.appearance.overlays = currentState.appearance.overlays or {}
        currentState.appearance.overlays[data.payload.name] = data.payload
        Appearance.ApplyPartial(ped(), 'overlay', data.payload)
    elseif data.section and data.payload then
        currentState.appearance[data.section] = data.payload
        Appearance.ApplyPartial(ped(), data.section, data.payload)
    end
    cb({ ok = true })
end)

RegisterNUICallback('updateIdentity', function(data, cb)
    if not creatorOpen or type(data) ~= 'table' then
        cb({ ok = false })
        return
    end

    currentState.identity = currentState.identity or SharedUtils.DefaultIdentity()
    for key, value in pairs(data) do
        currentState.identity[key] = value
    end

    if data.gender ~= nil then
        local gender = tonumber(data.gender) or 0
        currentState.identity.gender = gender
        currentState.appearance.model = SharedUtils.GetModelFromGender(gender)
        currentState.appearance.clothing = SharedUtils.DeepCopy(gender == 1 and Config.DefaultClothing.female or Config.DefaultClothing.male)
        Appearance.Apply(ped(), currentState.appearance)
        currentState.limits = Appearance.GetLimits(ped())
        sendNui('limits', currentState.limits)
        sendNui('appearance', currentState.appearance)
        Appearance.PlayCategoryAnimation(data.category or 'identity')
    end

    cb({ ok = true })
end)

RegisterNUICallback('updateClothing', function(data, cb)
    if not creatorOpen or type(data) ~= 'table' then
        cb({ ok = false })
        return
    end

    currentState.appearance.clothing = currentState.appearance.clothing or { components = {}, props = {} }
    local bucket = data.prop and currentState.appearance.clothing.props or currentState.appearance.clothing.components
    bucket[tonumber(data.id)] = {
        drawable = tonumber(data.drawable) or 0,
        texture = tonumber(data.texture) or 0,
    }

    Clothing.ApplySlot(ped(), data.prop and 'prop' or 'component', tonumber(data.id), tonumber(data.drawable) or 0, tonumber(data.texture) or 0)
    cb({
        ok = true,
        textureMax = Clothing.GetTextureMax(ped(), data.prop and 'prop' or 'component', tonumber(data.id), tonumber(data.drawable) or 0),
    })
end)

RegisterNUICallback('rotateCharacter', function(data, cb)
    if not creatorOpen then
        cb({ ok = false })
        return
    end

    local action = data and data.action or 'add'
    if action == 'reset' then
        CreatorCamera.ResetRotation()
    elseif action == 'set' then
        CreatorCamera.SetAbsoluteRotation(tonumber(data.delta) or 0.0)
    else
        CreatorCamera.RotatePed(tonumber(data.delta) or 2.0)
    end
    cb({ ok = true })
end)

RegisterNUICallback('changeCamera', function(data, cb)
    if not creatorOpen then
        cb({ ok = false })
        return
    end

    local category = data and data.category or 'identity'
    local preset = (data and data.preset) or Config.CategoryCameras[category] or 'body'
    CreatorCamera.SetPreset(preset, false)
    Appearance.PlayCategoryAnimation(category)
    cb({ ok = true })
end)

RegisterNUICallback('resetCharacter', function(_, cb)
    if not creatorOpen or not currentState then
        cb({ ok = false })
        return
    end

    local gender = tonumber(currentState.identity.gender) or 0
    currentState.appearance = SharedUtils.DefaultAppearance(gender)
    Appearance.Apply(ped(), currentState.appearance)
    currentState.limits = Appearance.GetLimits(ped())
    CreatorCamera.ResetRotation()
    cb({ ok = true, appearance = currentState.appearance, limits = currentState.limits })
end)

RegisterNUICallback('getTextureCount', function(data, cb)
    if not creatorOpen then
        cb({ max = 0 })
        return
    end
    cb({
        max = Clothing.GetTextureMax(
            ped(),
            data.prop and 'prop' or 'component',
            tonumber(data.id) or 0,
            tonumber(data.drawable) or 0
        ),
    })
end)

RegisterNUICallback('saveCharacter', function(data, cb)
    if not creatorOpen or type(data) ~= 'table' then
        cb({ ok = false, error = 'invalid' })
        return
    end

    currentState.identity = data.identity or currentState.identity
    currentState.appearance = data.appearance or currentState.appearance

    local result = lib.callback.await('qbx-charactercreator:server:saveCharacter', false, {
        mode = currentMode,
        first = firstCharacter,
        cid = pendingCreateOptions and pendingCreateOptions.cid,
        identity = currentState.identity,
        appearance = currentState.appearance,
    })

    if not result or not result.ok then
        ClientUtils.Notify(SharedUtils.Locale(result and result.error or 'notify.save_error'), 'error')
        cb({ ok = false, error = result and result.error or 'notify.save_error' })
        return
    end

    ClientUtils.PlayFrontendSound('CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET')
    finishToWorld(true)
    cb({ ok = true })
end)

RegisterNUICallback('cancelCreator', function(_, cb)
    if not creatorOpen then
        cb({ ok = true })
        return
    end

    if firstCharacter and not Config.AllowCancel and not (pendingCreateOptions and pendingCreateOptions.fromMultichar) then
        ClientUtils.Notify(SharedUtils.Locale('notify.not_allowed'), 'error')
        cb({ ok = false })
        return
    end

    local returnToSelect = pendingCreateOptions and pendingCreateOptions.fromMultichar and Config.Multichar.Enabled
    cleanup(not returnToSelect)
    if returnToSelect then
        pendingCreateOptions = nil
        currentState = nil
        TriggerEvent('qbx-charactercreator:client:returnToSelect')
        cb({ ok = true })
        return
    end

    restoreLocation()
    currentState = nil
    cb({ ok = true })
end)

RegisterNUICallback('notify', function(data, cb)
    if data and data.message then
        ClientUtils.Notify(data.message, data.type or 'error')
    end
    cb({ ok = true })
end)

RegisterNUICallback('sound', function(data, cb)
    if data and data.name then
        ClientUtils.PlayFrontendSound(data.name, data.set)
    end
    cb({ ok = true })
end)

RegisterNUICallback('submitIdentity', function(data, cb)
    if not identityOpen or type(data) ~= 'table' then
        cb({ ok = false, error = 'ui.required_fields' })
        return
    end

    currentState = currentState or {}
    currentState.identity = data.identity or currentState.identity

    local result = lib.callback.await('qbx-charactercreator:server:saveIdentity', false, {
        mode = currentMode,
        cid = pendingCreateOptions and pendingCreateOptions.cid,
        identity = currentState.identity,
    })

    if not result or not result.ok then
        cb({ ok = false, error = result and result.error or 'notify.save_error' })
        return
    end

    cb({ ok = true, citizenid = result.citizenid })
    lastCreatedCitizenId = result.citizenid
    CreateThread(handoffToRcore)
end)

RegisterNUICallback('cancelIdentity', function(_, cb)
    if not identityOpen then
        cb({ ok = true })
        return
    end

    closeIdentityUi()
    freezeGameplay(false)
    ClientUtils.HideHud(false)
    LocalPlayer.state:set('creatingCharacter', false, true)
    TriggerServerEvent('qbx-charactercreator:server:setBusy', false)

    local returnToSelect = pendingCreateOptions and pendingCreateOptions.fromMultichar and Config.Multichar.Enabled
    pendingCreateOptions = nil
    currentState = nil
    firstCharacter = false
    cb({ ok = true })

    if returnToSelect then
        TriggerEvent('qbx-charactercreator:client:returnToSelect')
    end
end)

RegisterNetEvent('qbx-charactercreator:client:open', function(options)
    options = options or {}
    if shouldOpenIdentityForm(options) then
        openIdentity(options)
        return
    end
    if usesRcoreAppearance() and Rcore.IsAvailable() and (options.mode == 'edit' or options.mode == 'admin') then
        TriggerEvent('rcore_clothing:openClothingShopWithEverythingAndFree')
        return
    end
    openCreator(options)
end)

RegisterNetEvent('qbx-charactercreator:client:forceClose', function()
    if identityOpen then
        closeIdentityUi()
        freezeGameplay(false)
        ClientUtils.HideHud(false)
    end
    if creatorOpen then
        cleanup(true)
        restoreLocation()
    end
end)

RegisterNetEvent('qbx-charactercreator:client:applyAppearance', function(appearance)
    if type(appearance) ~= 'table' then return end
    Appearance.Apply(ped(), appearance)
end)

if Config.Hooks.CreateFirstCharacter and not usesRcoreAppearance() then
    RegisterNetEvent('qb-clothes:client:CreateFirstCharacter', function()
        if Config.Multichar.Enabled then return end
        openIdentity({ mode = 'register', first = true })
    end)
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    waitingForRcore = false
    if identityOpen then
        closeIdentityUi()
        freezeGameplay(false)
    end
    if creatorOpen then
        cleanup(false)
    end
end)

local autoOpenQueued = false
local function maybeOpenMissingAppearance()
    if autoOpenQueued or creatorOpen or identityOpen or waitingForRcore then return end
    if usesRcoreAppearance() then return end
    autoOpenQueued = true
    CreateThread(function()
        Wait(1500)
        autoOpenQueued = false
        if creatorOpen or identityOpen or waitingForRcore then return end
        if Config.Multichar.Enabled and exports[GetCurrentResourceName()]:IsSelectOpen() then return end
        local hasAppearance = lib.callback.await('qbx-charactercreator:server:hasAppearance', false)
        if hasAppearance == false then
            openCreator({ mode = 'create', first = true })
        end
    end)
end

if Config.Hooks.AutoOpenIfNoAppearance then
    RegisterNetEvent('qbx_core:client:playerLoggedIn', maybeOpenMissingAppearance)

    AddStateBagChangeHandler('isLoggedIn', nil, function(bagName, _, value)
        local player = GetPlayerFromStateBagName(bagName)
        if player ~= PlayerId() or not value then return end
        maybeOpenMissingAppearance()
    end)
end

exports('OpenCreator', function(mode)
    TriggerEvent('qbx-charactercreator:client:open', { mode = mode or 'edit' })
end)

exports('OpenIdentity', function(options)
    openIdentity(options or { mode = 'register', first = true })
end)

exports('CloseCreator', function()
    if identityOpen then
        closeIdentityUi()
        freezeGameplay(false)
        ClientUtils.HideHud(false)
    end
    if creatorOpen then
        cleanup(true)
        restoreLocation()
    end
end)

exports('IsOpen', function()
    return creatorOpen or identityOpen or waitingForRcore
end)

exports('ApplyAppearance', function(targetPed, data)
    Appearance.Apply(targetPed or ped(), data)
end)

exports('StartCreator', function(options)
    options = options or { mode = 'register', first = true }
    TriggerEvent('qbx-charactercreator:client:open', options)
end)
