-- Menus NUI joueur (shop, craft, wash, stash, actions)

local menuOpen = false

local function openMenu(payload)
    menuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'playerMenu', data = payload })
end

local function closeMenu()
    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closePlayerMenu' })
end

function JC_C.OpenShop(marker)
    local items = {}
    for _i, s in pairs(JC_C.Shops) do
        if s.job_name == marker.job_name and (not s.marker_id or s.marker_id == marker.id) then
            local job = JC_C.GetJob()
            if job and (job.grade or 0) >= (s.min_grade or 0) then
                items[#items + 1] = s
            end
        end
    end
    openMenu({ type = 'shop', title = marker.label or 'Boutique', items = items })
end

function JC_C.OpenCraft(marker)
    local list = {}
    for _i, c in pairs(JC_C.Crafts) do
        if c.job_name == marker.job_name and (not c.marker_id or c.marker_id == marker.id) then
            local job = JC_C.GetJob()
            if job and (job.grade or 0) >= (c.min_grade or 0) then
                list[#list + 1] = c
            end
        end
    end
    openMenu({ type = 'craft', title = marker.label or 'Craft', items = list })
end

function JC_C.OpenWash(marker)
    openMenu({
        type = 'wash',
        title = marker.label or 'Blanchiment',
        markerId = marker.id,
        fee = (marker.data and marker.data.fee_percent) or 30,
    })
end

function JC_C.OpenActionsMenu()
    local job = JC_C.GetJob()
    if not job or not JC_C.Jobs[job.name] then return end
    local actions = JC_C.Jobs[job.name].actions or {}
    local list = {}
    for _i, a in ipairs(Config.DefaultActions) do
        if actions[a.id] then
            list[#list + 1] = a
        end
    end
    if #list == 0 then return end
    openMenu({ type = 'actions', title = job.label .. ' — Actions', items = list })
end

RegisterNetEvent('job_creator:openStashUI', function(data)
    openMenu({
        type = 'stash',
        title = data.label or 'Coffre',
        stashId = data.stashId,
        items = data.items or {},
        playerItems = data.playerItems or {},
    })
end)

RegisterNetEvent('job_creator:refreshStash', function(items)
    SendNUIMessage({ action = 'refreshStash', items = items })
end)

RegisterNetEvent('job_creator:nearbyPlayers', function(players)
    SendNUIMessage({ action = 'nearbyPlayers', players = players })
end)

RegisterNetEvent('job_creator:searchResult', function(data)
    openMenu({ type = 'search', title = 'Fouille — ' .. (data.name or ''), data = data })
end)

RegisterNetEvent('job_creator:employeesData', function(data)
    SendNUIMessage({ action = 'employeesData', data = data })
end)

RegisterNetEvent('job_creator:societyData', function(data)
    SendNUIMessage({ action = 'societyData', data = data })
end)

-- NUI callbacks joueur
RegisterNUICallback('playerClose', function(_, cb)
    closeMenu()
    cb({ ok = true })
end)

RegisterNUICallback('shopBuy', function(data, cb)
    TriggerServerEvent('job_creator:buyShopItem', data.id)
    cb({ ok = true })
end)

RegisterNUICallback('craftDo', function(data, cb)
    closeMenu()
    local craft = JC_C.Crafts[tostring(data.id)] or JC_C.Crafts[data.id]
    local duration = craft and craft.duration or 5000
    CreateThread(function()
        JC_C.Progress(duration, 'Craft…')
        TriggerServerEvent('job_creator:craft', data.id)
    end)
    cb({ ok = true })
end)

RegisterNUICallback('washDo', function(data, cb)
    TriggerServerEvent('job_creator:wash', data.markerId, data.amount)
    closeMenu()
    cb({ ok = true })
end)

RegisterNUICallback('stashDeposit', function(data, cb)
    TriggerServerEvent('job_creator:stashDeposit', data.stashId, data.item, data.count)
    cb({ ok = true })
end)

RegisterNUICallback('stashWithdraw', function(data, cb)
    TriggerServerEvent('job_creator:stashWithdraw', data.stashId, data.item, data.count)
    cb({ ok = true })
end)

RegisterNUICallback('actionDo', function(data, cb)
    local action = data.action
    closeMenu()

    if action == 'billing' then
        TriggerServerEvent('job_creator:getNearbyPlayers')
        Wait(200)
        openMenu({ type = 'billing', title = 'Facturer' })
    elseif action == 'handcuff' or action == 'escort' or action == 'putinveh' or action == 'outveh' or action == 'search' or action == 'identity' then
        local target = JC_C.GetClosestPlayer(2.5)
        if not target then
            JC_C.Notify(L('no_player_nearby'))
            cb({ ok = false })
            return
        end
        if action == 'handcuff' then
            TriggerServerEvent('job_creator:handcuff', target)
        elseif action == 'escort' then
            TriggerServerEvent('job_creator:escort', target)
        elseif action == 'putinveh' then
            TriggerServerEvent('job_creator:putInVehicle', target)
        elseif action == 'outveh' then
            TriggerServerEvent('job_creator:outVehicle', target)
        elseif action == 'search' then
            TriggerServerEvent('job_creator:search', target)
        elseif action == 'identity' then
            JC_C.Notify('ID joueur : ' .. target)
        end
    end
    cb({ ok = true })
end)

RegisterNUICallback('billSend', function(data, cb)
    TriggerServerEvent('job_creator:bill', data.targetId, data.amount, data.reason)
    closeMenu()
    cb({ ok = true })
end)

RegisterNUICallback('requestNearby', function(_, cb)
    TriggerServerEvent('job_creator:getNearbyPlayers')
    cb({ ok = true })
end)

function JC_C.GetClosestPlayer(maxDist)
    local players = GetActivePlayers()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local closest, closestDist = nil, maxDist or 2.5
    for _i, pid in ipairs(players) do
        local tp = GetPlayerPed(pid)
        if tp ~= ped then
            local dist = #(coords - GetEntityCoords(tp))
            if dist < closestDist then
                closestDist = dist
                closest = GetPlayerServerId(pid)
            end
        end
    end
    return closest
end

-- F6 actions
if Config.EnableActions then
    RegisterCommand('+jc_actions', function()
        JC_C.OpenActionsMenu()
    end, false)
    RegisterCommand('-jc_actions', function() end, false)
    RegisterKeyMapping('+jc_actions', 'Job Creator — Actions', 'keyboard', Config.ActionsKey or 'F6')
end

-- Handcuff / escort / vehicle
local isHandcuffed = false
local isEscorted = false
local escortOfficer = nil

RegisterNetEvent('job_creator:setHandcuff', function(state)
    isHandcuffed = state
    local ped = PlayerPedId()
    if state then
        RequestAnimDict('mp_arresting')
        while not HasAnimDictLoaded('mp_arresting') do Wait(10) end
        TaskPlayAnim(ped, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0, false, false, false)
        SetEnableHandcuffs(ped, true)
        DisablePlayerFiring(ped, true)
    else
        ClearPedTasks(ped)
        SetEnableHandcuffs(ped, false)
        DisablePlayerFiring(ped, false)
    end
end)

RegisterNetEvent('job_creator:escort', function(officerId)
    isEscorted = not isEscorted
    escortOfficer = officerId
end)

RegisterNetEvent('job_creator:putInVehicle', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local veh = 0
    if ESX.Game and ESX.Game.GetClosestVehicle then
        veh = ESX.Game.GetClosestVehicle()
    else
        local closestDist = 6.0
        for _i, v in ipairs(GetGamePool('CVehicle')) do
            local dist = #(coords - GetEntityCoords(v))
            if dist < closestDist then
                closestDist = dist
                veh = v
            end
        end
    end
    if veh and veh ~= 0 then
        for i = 0, GetVehicleMaxNumberOfPassengers(veh) do
            if IsVehicleSeatFree(veh, i) then
                TaskWarpPedIntoVehicle(ped, veh, i)
                return
            end
        end
    end
end)

RegisterNetEvent('job_creator:outVehicle', function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 16)
    end
end)

CreateThread(function()
    while true do
        local sleep = 500
        if isHandcuffed then
            sleep = 0
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 22, true)
            DisableControlAction(0, 288, true)
            DisableControlAction(0, 289, true)
            DisableControlAction(0, 170, true)
            DisableControlAction(0, 167, true)
            local ped = PlayerPedId()
            if not IsEntityPlayingAnim(ped, 'mp_arresting', 'idle', 3) then
                TaskPlayAnim(ped, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0, false, false, false)
            end
        end
        if isEscorted and escortOfficer then
            sleep = 0
            local oped = GetPlayerPed(GetPlayerFromServerId(escortOfficer))
            if oped and oped ~= 0 then
                AttachEntityToEntity(PlayerPedId(), oped, 11816, 0.45, 0.45, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
            end
        elseif isEscorted == false then
            DetachEntity(PlayerPedId(), true, false)
        end
        Wait(sleep)
    end
end)
