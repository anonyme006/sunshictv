local function bar(pct)
    pct = math.max(0, math.min(100, tonumber(pct) or 0))
    return ('%d %%'):format(pct)
end

local function statusMeta(vehicle)
    local stored = vehicle.stored
    return {
        { label = L('plate'), value = vehicle.plate },
        { label = L('status'), value = stored and L('vehicle_stored') or L('vehicle_out') },
        { label = L('engine'), value = bar(vehicle.engine), progress = vehicle.engine },
        { label = L('body'), value = bar(vehicle.body), progress = vehicle.body },
        { label = L('fuel'), value = bar(vehicle.fuel), progress = vehicle.fuel },
    }
end

local function vehicleDescription(vehicle)
    local st = vehicle.stored and L('vehicle_stored') or L('vehicle_out')
    return ('%s  ·  %s  ·  🔧 %s  ·  🛡 %s  ·  ⛽ %s'):format(
        vehicle.plate or '—',
        st,
        bar(vehicle.engine),
        bar(vehicle.body),
        bar(vehicle.fuel)
    )
end

local function formatMoney(n)
    n = tonumber(n) or 0
    local s = tostring(math.floor(n))
    local k
    while true do
        s, k = s:gsub('^(%-?%d+)(%d%d%d)', '%1 %2')
        if k == 0 then break end
    end
    return s .. ' $'
end

--- Menu achat garage privé / places
function OpenPrivateAccessMenu(garageId, info)
    local garage = GetGarageById(garageId)
    if not garage then return end
    info = info or lib.callback.await('ox_garage:getPrivateInfo', false, garageId)
    if not info then return end

    local options = {
        {
            title = garage.label,
            description = info.owned
                and L('private_owned_desc', info.used or 0, info.slots or 0)
                or L('private_buy_desc', formatMoney(info.price or 0), info.includedSlots or 1),
            icon = 'warehouse',
            iconColor = '#e6b35a',
        },
    }

    if not info.owned then
        options[#options + 1] = {
            title = L('private_buy', formatMoney(info.price or 0)),
            description = L('private_buy_hint'),
            icon = 'cart-shopping',
            iconColor = '#3ecf8e',
            onSelect = function()
                local result = lib.callback.await('ox_garage:buyPrivateAccess', false, garageId)
                if not result or not result.ok then
                    local err = result and result.error
                    if err == 'no_money' then Notify(L('notify_no_money'), 'error')
                    elseif err == 'already_owned' then Notify(L('private_already'), 'error')
                    else Notify(L('notify_error'), 'error') end
                    return
                end
                Notify(L('private_bought', result.priceLabel or formatMoney(result.price)), 'success')
                OpenGarageMenu(garageId)
            end,
        }
    else
        options[#options + 1] = {
            title = L('private_open_vehicles'),
            description = L('private_slots_info', info.used or 0, info.slots or 0, info.maxSlots or info.slots or 0),
            icon = 'car',
            iconColor = Config.StatusColors.stored,
            onSelect = function()
                OpenGarageVehicleList(garageId)
            end,
        }

        if (info.slots or 0) < (info.maxSlots or 0) then
            options[#options + 1] = {
                title = L('private_buy_slot', formatMoney(info.pricePerSlot or 0)),
                description = L('private_buy_slot_hint'),
                icon = 'plus',
                iconColor = '#5b9bd5',
                onSelect = function()
                    local result = lib.callback.await('ox_garage:buyPrivateSlot', false, garageId)
                    if not result or not result.ok then
                        local err = result and result.error
                        if err == 'no_money' then Notify(L('notify_no_money'), 'error')
                        elseif err == 'max_slots' then Notify(L('private_max_slots'), 'error')
                        elseif err == 'not_owned' then Notify(L('private_need_own'), 'error')
                        else Notify(L('notify_error'), 'error') end
                        return
                    end
                    Notify(L('private_slot_bought', result.slots, result.priceLabel or formatMoney(result.price)), 'success')
                    OpenPrivateAccessMenu(garageId)
                end,
            }
        end
    end

    options[#options + 1] = {
        title = L('cancel'),
        icon = 'xmark',
        onSelect = function() end,
    }

    lib.registerContext({
        id = 'ox_garage_private_' .. garageId,
        title = L('private_menu_title', garage.label),
        options = options,
    })
    lib.showContext('ox_garage_private_' .. garageId)
end

--- Liste véhicules (après accès OK)
function OpenGarageVehicleList(garageId)
    local garage = GetGarageById(garageId)
    if not garage then return end

    local vehicles = lib.callback.await('ox_garage:getVehicles', false, garageId) or {}

    if #vehicles == 0 then
        local emptyOptions = {
            {
                title = L('menu_empty'),
                icon = 'inbox',
                iconColor = '#8b97a8',
                disabled = true,
            },
        }
        if garage.kind == 'private' then
            emptyOptions[#emptyOptions + 1] = {
                title = L('private_manage'),
                icon = 'gears',
                onSelect = function()
                    OpenPrivateAccessMenu(garageId)
                end,
            }
        end
        lib.registerContext({
            id = 'ox_garage_main_' .. garageId,
            title = L('menu_title', garage.label),
            options = emptyOptions,
        })
        lib.showContext('ox_garage_main_' .. garageId)
        return
    end

    local options = {}
    for _i, v in ipairs(vehicles) do
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

    if garage.kind == 'private' then
        options[#options + 1] = {
            title = L('private_manage'),
            icon = 'gears',
            onSelect = function()
                OpenPrivateAccessMenu(garageId)
            end,
        }
    end

    lib.registerContext({
        id = 'ox_garage_main_' .. garageId,
        title = L('menu_title', garage.label),
        options = options,
    })
    lib.showContext('ox_garage_main_' .. garageId)
end

--- Export pour job_creator / autres ressources
exports('OpenGarage', function(garageId)
    OpenGarageMenu(garageId)
end)

exports('OpenGarageStore', function(garageId)
    OpenStoreMenu(garageId)
end)

--- Menu principal : liste des véhicules
function OpenGarageMenu(garageId)
    local garage = GetGarageById(garageId)
    if not garage then return end

    -- Si le joueur est dans un véhicule → menu rangement
    local veh = PlayerInOwnedVehicle()
    if veh and IsNearGarageStore(garage) then
        if garage.kind == 'private' then
            local info = lib.callback.await('ox_garage:getPrivateInfo', false, garageId)
            if not info or not info.owned then
                OpenPrivateAccessMenu(garageId, info)
                return
            end
        end
        OpenStoreMenu(garageId)
        return
    end

    if garage.kind == 'private' then
        local info = lib.callback.await('ox_garage:getPrivateInfo', false, garageId)
        if not info or not info.owned then
            OpenPrivateAccessMenu(garageId, info)
            return
        end
    end

    OpenGarageVehicleList(garageId)
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
        },
    }

    if stored then
        options[#options + 1] = {
            title = L('take_out'),
            description = 'Faire apparaître le véhicule au point de sortie',
            icon = 'key',
            iconColor = Config.StatusColors.stored,
            onSelect = function()
                TakeOutVehicle(garageId, vehicle)
            end,
        }
    else
        options[#options + 1] = {
            title = L('already_out'),
            description = 'Ce véhicule est déjà dehors',
            icon = 'ban',
            iconColor = Config.StatusColors.out,
            disabled = true,
        }
    end

    options[#options + 1] = {
        title = L('view_info'),
        description = 'Détails moteur / carrosserie / carburant',
        icon = 'circle-info',
        onSelect = function()
            OpenVehicleInfoMenu(garageId, vehicle)
        end,
    }

    options[#options + 1] = {
        title = L('back'),
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
        title = L('info_title', name),
        menu = 'ox_garage_detail_' .. garageId,
        options = {
            {
                title = L('plate'),
                description = vehicle.plate,
                icon = 'id-card',
            },
            {
                title = L('status'),
                description = vehicle.stored and L('vehicle_stored') or L('vehicle_out'),
                icon = vehicle.stored and 'warehouse' or 'road',
                iconColor = vehicle.stored and Config.StatusColors.stored or Config.StatusColors.out,
            },
            {
                title = L('engine'),
                description = bar(vehicle.engine),
                icon = 'engine',
                progress = vehicle.engine,
                colorScheme = vehicle.engine > 50 and 'green' or (vehicle.engine > 25 and 'yellow' or 'red'),
            },
            {
                title = L('body'),
                description = bar(vehicle.body),
                icon = 'car-burst',
                progress = vehicle.body,
                colorScheme = vehicle.body > 50 and 'green' or (vehicle.body > 25 and 'yellow' or 'red'),
            },
            {
                title = L('fuel'),
                description = bar(vehicle.fuel),
                icon = 'gas-pump',
                progress = vehicle.fuel,
                colorScheme = vehicle.fuel > 50 and 'green' or (vehicle.fuel > 25 and 'yellow' or 'red'),
            },
            {
                title = L('back'),
                icon = 'arrow-left',
                onSelect = function()
                    OpenVehicleDetailMenu(garageId, vehicle)
                end,
            },
        },
    })
    lib.showContext('ox_garage_info_' .. garageId)
end

--- Menu rangement (dans le véhicule OU target dessus au point)
function OpenStoreMenu(garageId, veh)
    local garage = GetGarageById(garageId)
    if not garage then return end

    if garage.kind == 'private' then
        local info = lib.callback.await('ox_garage:getPrivateInfo', false, garageId)
        if not info or not info.owned then
            OpenPrivateAccessMenu(garageId, info)
            return
        end
    end

    veh = veh or PlayerInOwnedVehicle() or GetClosestVehicleAtStore(garage)
    if not veh or not DoesEntityExist(veh) then
        Notify(L('notify_no_vehicle_store'), 'error')
        return
    end

    if not IsVehicleNearGarageStore(veh, garage) and not IsNearGarageStore(garage) then
        Notify(L('notify_too_far'), 'error')
        return
    end

    local plate = GetVehicleNumberPlateText(veh)
    local model = GetEntityModel(veh)
    local name = GetVehicleDisplayName(model)
    local inVeh = IsPedInVehicle(PlayerPedId(), veh, false)

    lib.registerContext({
        id = 'ox_garage_store_' .. garageId,
        title = L('store_menu_title'),
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
            },
            {
                title = inVeh and L('store_exit_and_store') or L('store_vehicle'),
                description = inVeh
                    and L('store_exit_and_store_desc', garage.label)
                    or L('store_vehicle_desc', garage.label),
                icon = inVeh and 'person-walking-arrow-right' or 'square-parking',
                iconColor = Config.StatusColors.stored,
                onSelect = function()
                    StoreVehicle(garageId, veh)
                end,
            },
            {
                title = L('cancel'),
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
            already_out = L('notify_already_out'),
            not_yours = L('notify_not_yours'),
            not_stored = L('notify_not_stored'),
            not_owned = L('private_need_own'),
            error = L('notify_error'),
        }
        Notify(map[err] or L('notify_error'), 'error')
        return
    end

    local spawn = FindFreeSpawn(result.spawns or garage.spawns)
    if not spawn then
        -- Rollback soft : on laisse le serveur en "sorti" mais on prévient
        -- Mieux : remettre stored=1 — pour simplicité on notifie
        Notify(L('no_spawn'), 'error')
        -- Re-store côté serveur via store impossible sans entity — force callback reverse
        TriggerServerEvent('ox_garage:forceStore', vehicle.plate, garageId)
        return
    end

    local success = lib.progressCircle({
        duration = Config.ProgressSpawn,
        label = L('progress_spawn'),
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
        Notify(L('cancel'), 'inform')
        return
    end

    local props = result.props
    local model = props.model
    if type(model) == 'string' then model = joaat(model) end

    lib.requestModel(model, 5000)

    local entity = CreateVehicle(model, spawn.x, spawn.y, spawn.z, spawn.w or 0.0, true, false)
    if not entity or entity == 0 then
        TriggerServerEvent('ox_garage:forceStore', vehicle.plate, garageId)
        Notify(L('notify_error'), 'error')
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

    Notify(L('notify_spawned', GetVehicleDisplayName(model)), 'success')
    -- Fermeture auto : pas de menu réouvert
end

--- Ranger (descend d'abord si encore assis)
function StoreVehicle(garageId, veh)
    local garage = GetGarageById(garageId)
    if not garage then return end
    if not veh or not DoesEntityExist(veh) then
        Notify(L('notify_no_vehicle_store'), 'error')
        return
    end

    if not IsVehicleNearGarageStore(veh, garage) and not IsNearGarageStore(garage) then
        Notify(L('notify_too_far'), 'error')
        return
    end

    local ped = PlayerPedId()
    if IsPedInVehicle(ped, veh, false) then
        TaskLeaveVehicle(ped, veh, 16)
        local timeout = GetGameTimer() + 4000
        while IsPedInVehicle(ped, veh, false) and GetGameTimer() < timeout do
            Wait(100)
        end
        Wait(400)
    end

    if not DoesEntityExist(veh) then
        Notify(L('notify_error'), 'error')
        return
    end

    local success = lib.progressCircle({
        duration = Config.ProgressStore,
        label = L('progress_store'),
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
        Notify(L('cancel'), 'inform')
        return
    end

    if not DoesEntityExist(veh) then
        Notify(L('notify_error'), 'error')
        return
    end

    -- Re-check distance après la progress (véhicule doit rester sur le point)
    if not IsVehicleNearGarageStore(veh, garage) then
        Notify(L('notify_too_far'), 'error')
        return
    end

    local props = GetVehicleProps(veh)
    local netId = NetworkGetNetworkIdFromEntity(veh)
    local name = GetVehicleDisplayName(GetEntityModel(veh))

    local result = lib.callback.await('ox_garage:store', false, garageId, netId, props)
    if not result or not result.ok then
        local err = result and result.error or 'error'
        local map = {
            not_yours = L('notify_not_yours'),
            too_far = L('notify_too_far'),
            not_owned = L('private_need_own'),
            no_slot = L('private_no_slot'),
            error = L('notify_error'),
        }
        Notify(map[err] or L('notify_error'), 'error')
        return
    end

    if DoesEntityExist(veh) then
        SetEntityAsMissionEntity(veh, true, true)
        DeleteVehicle(veh)
    end

    Notify(L('notify_stored', name), 'success')
end
