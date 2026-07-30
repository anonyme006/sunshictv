--[[
    Menus fourrière générale + mécano (ox_lib)
]]

local function GetImpoundById(id)
    for _i, imp in ipairs(Config.Impounds or {}) do
        if imp.id == id then return imp end
    end
end

local function jobAllowed(map)
    if not map then return false end
    local data = ESX.GetPlayerData()
    if not data or not data.job then return false end
    local minGrade = map[data.job.name]
    if minGrade == nil then return false end
    return (data.job.grade or 0) >= (tonumber(minGrade) or 0)
end

local function canSeize(impound)
    return jobAllowed(impound.jobs)
end

local function formatPrice(n)
    n = math.floor(tonumber(n) or 0)
    local s = tostring(n)
    while true do
        local k
        s, k = s:gsub('^(-?%d+)(%d%d%d)', '%1 %2')
        if k == 0 then break end
    end
    return s
end

function OpenImpoundMenu(impoundId)
    if not Config.Impound or not Config.Impound.enabled then
        return Notify(L('notify_impound_disabled'), 'error')
    end

    local impound = GetImpoundById(impoundId)
    if not impound then return end

    local vehicles = lib.callback.await('ox_garage:getImpoundVehicles', false, impoundId) or {}
    local price = tonumber(impound.price) or 0

    if #vehicles == 0 then
        lib.registerContext({
            id = 'ox_garage_impound_' .. impoundId,
            title = L('impound_menu_title', impound.label),
            options = {{
                title = L('impound_empty'),
                icon = 'inbox',
                iconColor = '#8b97a8',
                disabled = true,
            }},
        })
        lib.showContext('ox_garage_impound_' .. impoundId)
        return
    end

    local options = {}
    for _i, v in ipairs(vehicles) do
        local name = GetVehicleDisplayName(v.model)
        options[#options + 1] = {
            title = name,
            description = ('%s  ·  🔧 %d%%  ·  🛡 %d%%  ·  ⛽ %d%%'):format(
                v.plate or '—', v.engine or 0, v.body or 0, v.fuel or 0
            ),
            icon = GetVehicleIcon(v.model),
            iconColor = Config.StatusColors.impound or '#e6b35a',
            metadata = {
                { label = L('plate'), value = v.plate },
                { label = L('status'), value = Config.StatusLabels.impound or 'Fourrière' },
                { label = L('engine'), value = (v.engine or 0) .. ' %', progress = v.engine },
                { label = L('body'), value = (v.body or 0) .. ' %', progress = v.body },
                { label = L('fuel'), value = (v.fuel or 0) .. ' %', progress = v.fuel },
                { label = 'Tarif', value = formatPrice(price) .. ' $' },
            },
            arrow = true,
            onSelect = function()
                OpenImpoundDetail(impoundId, v)
            end,
        }
    end

    -- Option saisie si job autorisé + véhicule proche
    if canSeize(impound) then
        table.insert(options, 1, {
            title = L('target_impound_seize'),
            description = 'Mettre le véhicule proche / actuel en fourrière',
            icon = 'truck-ramp-box',
            iconColor = Config.StatusColors.impound,
            onSelect = function()
                SeizeNearbyVehicle(impoundId)
            end,
        })
    end

    lib.registerContext({
        id = 'ox_garage_impound_' .. impoundId,
        title = L('impound_menu_title', impound.label),
        options = options,
    })
    lib.showContext('ox_garage_impound_' .. impoundId)
end

function OpenImpoundDetail(impoundId, vehicle)
    local impound = GetImpoundById(impoundId)
    if not impound then return end

    local name = GetVehicleDisplayName(vehicle.model)
    local price = tonumber(impound.price) or 0
    local asStaff = jobAllowed(impound.retrieveJobs)
    local retrieveLabel = (asStaff and price > 0) and L('impound_retrieve_free')
        or L('impound_retrieve', formatPrice(price))

    -- Staff sortant un véhicule d'autrui : gratuit côté UI
    if asStaff then
        retrieveLabel = L('impound_retrieve_free')
    end

    lib.registerContext({
        id = 'ox_garage_impound_detail',
        title = name,
        menu = 'ox_garage_impound_' .. impoundId,
        options = {
            {
                title = name,
                description = vehicle.plate,
                icon = GetVehicleIcon(vehicle.model),
                iconColor = Config.StatusColors.impound,
            },
            {
                title = retrieveLabel,
                description = asStaff and 'Sortie staff (sans frais)' or ('Paiement : ' .. formatPrice(price) .. ' $'),
                icon = 'key',
                iconColor = '#3ecf8e',
                onSelect = function()
                    RetrieveImpoundVehicle(impoundId, vehicle)
                end,
            },
            {
                title = L('back'),
                icon = 'arrow-left',
                onSelect = function()
                    OpenImpoundMenu(impoundId)
                end,
            },
        },
    })
    lib.showContext('ox_garage_impound_detail')
end

function SeizeNearbyVehicle(impoundId)
    local impound = GetImpoundById(impoundId)
    if not impound or not canSeize(impound) then
        return Notify(L('notify_impound_job'), 'error')
    end

    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        local coords = GetEntityCoords(ped)
        local closest, dist = 0, 6.0
        for _i, v in ipairs(GetGamePool('CVehicle')) do
            local d = #(coords - GetEntityCoords(v))
            if d < dist then
                dist = d
                closest = v
            end
        end
        veh = closest
    end

    if not veh or veh == 0 then
        return Notify(L('notify_error'), 'error')
    end

    local store = impound.store or { coords = impound.coords, radius = 12.0 }
    if #(GetEntityCoords(veh) - store.coords) > (store.radius or 12.0) then
        return Notify(L('notify_too_far'), 'error')
    end

    local ok = lib.progressCircle({
        duration = Config.Impound.progressDuration or 3500,
        label = L('impound_progress'),
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'mini@repair', clip = 'fixing_a_ped' },
    })
    if not ok then return Notify(L('cancel'), 'inform') end

    if not DoesEntityExist(veh) then return Notify(L('notify_error'), 'error') end

    local props = GetVehicleProps(veh)
    local result = lib.callback.await('ox_garage:impoundVehicle', false, impoundId, props)
    if not result or not result.ok then
        local err = result and result.error
        if err == 'job' then Notify(L('notify_impound_job'), 'error')
        elseif err == 'already' then Notify(L('notify_already_impound'), 'error')
        elseif err == 'too_far' then Notify(L('notify_too_far'), 'error')
        elseif err == 'not_yours' then Notify('Véhicule non enregistré (owned_vehicles)', 'error')
        else Notify(L('notify_error'), 'error') end
        return
    end

    TaskLeaveVehicle(ped, veh, 16)
    Wait(900)
    if DoesEntityExist(veh) then
        SetEntityAsMissionEntity(veh, true, true)
        DeleteVehicle(veh)
    end

    Notify(L('notify_impounded', result.plate or props.plate or ''), 'success')
end

function RetrieveImpoundVehicle(impoundId, vehicle)
    local impound = GetImpoundById(impoundId)
    if not impound then return end

    local ok = lib.progressCircle({
        duration = Config.ProgressSpawn or 2500,
        label = L('impound_retrieve_progress'),
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'anim@heists@keycard@', clip = 'exit' },
    })
    if not ok then return Notify(L('cancel'), 'inform') end

    local result = lib.callback.await('ox_garage:retrieveImpound', false, impoundId, vehicle.plate)
    if not result or not result.ok then
        local err = result and result.error
        if err == 'money' then Notify(L('notify_no_money'), 'error')
        elseif err == 'job' then Notify(L('notify_impound_job'), 'error')
        elseif err == 'not_impound' then Notify(L('notify_not_impound'), 'error')
        else Notify(L('notify_error'), 'error') end
        return
    end

    local spawn = FindFreeSpawn(result.spawns or impound.spawns)
    if not spawn then
        TriggerServerEvent('ox_garage:forceStore', vehicle.plate, impoundId)
        Notify(L('no_spawn'), 'error')
        return
    end

    local props = result.props
    local model = props.model
    if type(model) == 'string' then model = joaat(model) end

    lib.requestModel(model, 5000)
    local entity = CreateVehicle(model, spawn.x, spawn.y, spawn.z, spawn.w or 0.0, true, false)
    if not entity or entity == 0 then
        TriggerServerEvent('ox_garage:forceStore', vehicle.plate, impoundId)
        Notify(L('notify_error'), 'error')
        return
    end

    SetVehicleOnGroundProperly(entity)
    SetEntityAsMissionEntity(entity, true, true)
    SetVehicleHasBeenOwnedByPlayer(entity, true)
    SetVehicleNeedsToBeHotwired(entity, false)
    SetVehRadioStation(entity, 'OFF')
    SetVehicleProps(entity, props)
    SetVehicleNumberPlateText(entity, result.plate or vehicle.plate)

    local netId = NetworkGetNetworkIdFromEntity(entity)
    TriggerServerEvent('ox_garage:registerSpawn', vehicle.plate, netId)
    TaskWarpPedIntoVehicle(PlayerPedId(), entity, -1)
    SetModelAsNoLongerNeeded(model)

    local price = result.price or 0
    if price > 0 then
        Notify(L('notify_retrieved', GetVehicleDisplayName(model), formatPrice(price)), 'success')
    else
        Notify(L('notify_retrieved_free', GetVehicleDisplayName(model)), 'success')
    end
end

--- Zones ox_target + blips
CreateThread(function()
    if not Config.Impound or not Config.Impound.enabled then return end

    for _i, impound in ipairs(Config.Impounds or {}) do
        if impound.blip and impound.blip.enabled then
            local blip = AddBlipForCoord(impound.coords.x, impound.coords.y, impound.coords.z)
            SetBlipSprite(blip, impound.blip.sprite or 67)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, impound.blip.scale or 0.75)
            SetBlipColour(blip, impound.blip.color or 1)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(impound.label)
            EndTextCommandSetBlipName(blip)
        end

        local t = impound.target or { coords = impound.coords, radius = 2.2 }
        exports.ox_target:addSphereZone({
            coords = t.coords,
            radius = t.radius or 2.2,
            debug = t.debug or false,
            options = {
                {
                    name = 'ox_garage_impound_open_' .. impound.id,
                    icon = 'fa-solid fa-building-shield',
                    label = L('target_impound_open'),
                    distance = 2.2,
                    onSelect = function()
                        OpenImpoundMenu(impound.id)
                    end,
                },
                {
                    name = 'ox_garage_impound_seize_' .. impound.id,
                    icon = 'fa-solid fa-truck-ramp-box',
                    label = L('target_impound_seize'),
                    distance = 2.5,
                    canInteract = function()
                        return canSeize(impound)
                    end,
                    onSelect = function()
                        SeizeNearbyVehicle(impound.id)
                    end,
                },
            },
        })
    end
end)

exports('OpenImpound', OpenImpoundMenu)
