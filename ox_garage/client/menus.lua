local function bar(pct)
    pct = math.max(0, math.min(100, tonumber(pct) or 0))
    return ('%d %%'):format(pct)
end

local function statusMeta(vehicle)
    local stored = vehicle.stored
    return {
        { label = _('plate'), value = vehicle.plate },
        { label = _('status'), value = stored and _('vehicle_stored') or _('vehicle_out') },
        { label = _('engine'), value = bar(vehicle.engine), progress = vehicle.engine },
        { label = _('body'), value = bar(vehicle.body), progress = vehicle.body },
        { label = _('fuel'), value = bar(vehicle.fuel), progress = vehicle.fuel },
    }
end

local function vehicleDescription(vehicle)
    local st = vehicle.stored and _('vehicle_stored') or _('vehicle_out')
    return ('%s  ·  %s  ·  🔧 %s  ·  🛡 %s  ·  ⛽ %s'):format(
        vehicle.plate or '—',
        st,
        bar(vehicle.engine),
        bar(vehicle.body),
        bar(vehicle.fuel)
    )
end

--- Menu principal : liste des véhicules
function OpenGarageMenu(garageId)
    local garage = GetGarageById(garageId)
    if not garage then return end

    -- Si le joueur est dans un véhicule → menu rangement
    local veh = PlayerInOwnedVehicle()
    if veh and IsNearGarageStore(garage) then
        OpenStoreMenu(garageId)
        return
    end

    local vehicles = lib.callback.await('ox_garage:getVehicles', false, garageId) or {}

    if #vehicles == 0 then
        lib.registerContext({
            id = 'ox_garage_main_' .. garageId,
            title = _('menu_title', garage.label),
            options = {
                {
                    title = _('menu_empty'),
                    icon = 'inbox',
                    iconColor = '#8b97a8',
                    disabled = true,
                },
            },
        })
        lib.showContext('ox_garage_main_' .. garageId)
        return
    end

    local options = {}
    for _, v in ipairs(vehicles) do
        local name = GetVehicleDisplayName(v.model)
        local stored = v.stored
        options[#options + 1] = {
            title = name,
            description = vehicleDescription(v),
            icon = GetVehicleIcon(v.model),
            iconColor = stored and Config.StatusColors.stored or Config.StatusColors.out,
            metadata = statusMeta(v),
            arrow = true,
            onSelect = function()
                OpenVehicleDetailMenu(garageId, v)
            end,
        }
    end

    lib.registerContext({
        id = 'ox_garage_main_' .. garageId,
        title = _('menu_title', garage.label),
        options = options,
    })
    lib.showContext('ox_garage_main_' .. garageId)
end

--- Second menu : détail + actions
function OpenVehicleDetailMenu(garageId, vehicle)
    local garage = GetGarageById(garageId)
    if not garage then return end

    -- Refresh frais depuis le serveur
    local fresh = lib.callback.await('ox_garage:getVehicle', false, vehicle.plate)
    if fresh then vehicle = fresh end

    local name = GetVehicleDisplayName(vehicle.model)
    local stored = vehicle.stored

    local options = {
        {
            title = name,
            description = vehicleDescription(vehicle),
            icon = GetVehicleIcon(vehicle.model),
            iconColor = stored and Config.StatusColors.stored or Config.StatusColors.out,
            metadata = statusMeta(vehicle),
            readOnly = true,
        },
    }

    if stored then
        options[#options + 1] = {
            title = _('take_out'),
            description = 'Faire apparaître le véhicule au point de sortie',
            icon = 'key',
            iconColor = Config.StatusColors.stored,
            onSelect = function()
                TakeOutVehicle(garageId, vehicle)
            end,
        }
    else
        options[#options + 1] = {
            title = _('already_out'),
            description = 'Ce véhicule est déjà dehors',
            icon = 'ban',
            iconColor = Config.StatusColors.out,
            disabled = true,
        }
    end

    options[#options + 1] = {
        title = _('view_info'),
        description = 'Détails moteur / carrosserie / carburant',
        icon = 'circle-info',
        onSelect = function()
            OpenVehicleInfoMenu(garageId, vehicle)
        end,
    }

    options[#options + 1] = {
        title = _('back'),
        icon = 'arrow-left',
        onSelect = function()
            OpenGarageMenu(garageId)
        end,
    }

    lib.registerContext({
        id = 'ox_garage_detail_' .. garageId,
        title = name,
        menu = 'ox_garage_main_' .. garageId,
        options = options,
    })
    lib.showContext('ox_garage_detail_' .. garageId)
end

--- Infos détaillées
function OpenVehicleInfoMenu(garageId, vehicle)
    local name = GetVehicleDisplayName(vehicle.model)

    lib.registerContext({
        id = 'ox_garage_info_' .. garageId,
        title = _('info_title', name),
        menu = 'ox_garage_detail_' .. garageId,
        options = {
            {
                title = _('plate'),
                description = vehicle.plate,
                icon = 'id-card',
            },
            {
                title = _('status'),
                description = vehicle.stored and _('vehicle_stored') or _('vehicle_out'),
                icon = vehicle.stored and 'warehouse' or 'road',
                iconColor = vehicle.stored and Config.StatusColors.stored or Config.StatusColors.out,
            },
            {
                title = _('engine'),
                description = bar(vehicle.engine),
                icon = 'engine',
                progress = vehicle.engine,
                colorScheme = vehicle.engine > 50 and 'green' or (vehicle.engine > 25 and 'yellow' or 'red'),
            },
            {
                title = _('body'),
                description = bar(vehicle.body),
                icon = 'car-burst',
                progress = vehicle.body,
                colorScheme = vehicle.body > 50 and 'green' or (vehicle.body > 25 and 'yellow' or 'red'),
            },
            {
                title = _('fuel'),
                description = bar(vehicle.fuel),
                icon = 'gas-pump',
                progress = vehicle.fuel,
                colorScheme = vehicle.fuel > 50 and 'green' or (vehicle.fuel > 25 and 'yellow' or 'red'),
            },
            {
                title = _('back'),
                icon = 'arrow-left',
                onSelect = function()
                    OpenVehicleDetailMenu(garageId, vehicle)
                end,
            },
        },
    })
    lib.showContext('ox_garage_info_' .. garageId)
end

--- Menu rangement (assis dans le véhicule)
function OpenStoreMenu(garageId)
    local garage = GetGarageById(garageId)
    if not garage then return end

    local veh = PlayerInOwnedVehicle()
    if not veh then
        Notify(_('notify_not_in_vehicle'), 'error')
        return
    end

    local plate = GetVehicleNumberPlateText(veh)
    local model = GetEntityModel(veh)
    local name = GetVehicleDisplayName(model)

    lib.registerContext({
        id = 'ox_garage_store_' .. garageId,
        title = _('store_menu_title'),
        options = {
            {
                title = name,
                description = ('%s  ·  🔧 %s  ·  🛡 %s  ·  ⛽ %s'):format(
                    plate,
                    bar(math.floor(GetVehicleEngineHealth(veh) / 10 + 0.5)),
                    bar(math.floor(GetVehicleBodyHealth(veh) / 10 + 0.5)),
                    bar(math.floor(ReadFuel(veh) + 0.5))
                ),
                icon = GetVehicleIcon(model),
                iconColor = Config.StatusColors.out,
                readOnly = true,
            },
            {
                title = _('store_vehicle'),
                description = 'Sauvegarder et ranger dans ' .. garage.label,
                icon = 'square-parking',
                iconColor = Config.StatusColors.stored,
                onSelect = function()
                    StoreVehicle(garageId, veh)
                end,
            },
            {
                title = _('cancel'),
                icon = 'xmark',
                onSelect = function() end,
            },
        },
    })
    lib.showContext('ox_garage_store_' .. garageId)
end

--- Sortir le véhicule
function TakeOutVehicle(garageId, vehicle)
    local garage = GetGarageById(garageId)
    if not garage then return end

    local result = lib.callback.await('ox_garage:takeOut', false, garageId, vehicle.plate)
    if not result or not result.ok then
        local err = result and result.error or 'error'
        local map = {
            already_out = _('notify_already_out'),
            not_yours = _('notify_not_yours'),
            not_stored = _('notify_not_stored'),
            error = _('notify_error'),
        }
        Notify(map[err] or _('notify_error'), 'error')
        return
    end

    local spawn = FindFreeSpawn(result.spawns or garage.spawns)
    if not spawn then
        -- Rollback soft : on laisse le serveur en "sorti" mais on prévient
        -- Mieux : remettre stored=1 — pour simplicité on notifie
        Notify(_('no_spawn'), 'error')
        -- Re-store côté serveur via store impossible sans entity — force callback reverse
        TriggerServerEvent('ox_garage:forceStore', vehicle.plate, garageId)
        return
    end

    local success = lib.progressCircle({
        duration = Config.ProgressSpawn,
        label = _('progress_spawn'),
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = {
            dict = 'anim@heists@keycard@',
            clip = 'exit',
        },
    })

    if not success then
        TriggerServerEvent('ox_garage:forceStore', vehicle.plate, garageId)
        Notify(_('cancel'), 'inform')
        return
    end

    local props = result.props
    local model = props.model
    if type(model) == 'string' then model = joaat(model) end

    lib.requestModel(model, 5000)

    local entity = CreateVehicle(model, spawn.x, spawn.y, spawn.z, spawn.w or 0.0, true, false)
    if not entity or entity == 0 then
        TriggerServerEvent('ox_garage:forceStore', vehicle.plate, garageId)
        Notify(_('notify_error'), 'error')
        return
    end

    SetVehicleOnGroundProperly(entity)
    SetEntityAsMissionEntity(entity, true, true)
    SetVehicleHasBeenOwnedByPlayer(entity, true)
    SetVehicleNeedsToBeHotwired(entity, false)
    SetVehRadioStation(entity, 'OFF')
    SetVehicleProps(entity, props)
    SetVehicleNumberPlateText(entity, result.plate or props.plate or vehicle.plate)

    local netId = NetworkGetNetworkIdFromEntity(entity)
    SetNetworkIdCanMigrate(netId, true)
    TriggerServerEvent('ox_garage:registerSpawn', vehicle.plate, netId)

    TaskWarpPedIntoVehicle(PlayerPedId(), entity, -1)
    SetModelAsNoLongerNeeded(model)

    Notify(_('notify_spawned', GetVehicleDisplayName(model)), 'success')
    -- Fermeture auto : pas de menu réouvert
end

--- Ranger
function StoreVehicle(garageId, veh)
    local garage = GetGarageById(garageId)
    if not garage then return end
    if not veh or not DoesEntityExist(veh) then
        Notify(_('notify_not_in_vehicle'), 'error')
        return
    end

    if not IsNearGarageStore(garage) then
        Notify(_('notify_too_far'), 'error')
        return
    end

    local success = lib.progressCircle({
        duration = Config.ProgressStore,
        label = _('progress_store'),
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = {
            dict = 'anim@heists@keycard@',
            clip = 'exit',
        },
    })

    if not success then
        Notify(_('cancel'), 'inform')
        return
    end

    if not DoesEntityExist(veh) then
        Notify(_('notify_error'), 'error')
        return
    end

    local props = GetVehicleProps(veh)
    local netId = NetworkGetNetworkIdFromEntity(veh)
    local plate = props.plate or GetVehicleNumberPlateText(veh)
    local name = GetVehicleDisplayName(GetEntityModel(veh))

    local result = lib.callback.await('ox_garage:store', false, garageId, netId, props)
    if not result or not result.ok then
        local err = result and result.error or 'error'
        local map = {
            not_yours = _('notify_not_yours'),
            too_far = _('notify_too_far'),
            error = _('notify_error'),
        }
        Notify(map[err] or _('notify_error'), 'error')
        return
    end

    TaskLeaveVehicle(PlayerPedId(), veh, 16)
    Wait(800)
    if DoesEntityExist(veh) then
        SetEntityAsMissionEntity(veh, true, true)
        DeleteVehicle(veh)
    end

    Notify(_('notify_stored', name), 'success')
end
