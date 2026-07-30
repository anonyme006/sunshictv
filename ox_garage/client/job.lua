--[[
    Menus garage entreprise (même UX que le garage perso)
]]

local function bar(pct)
    pct = math.max(0, math.min(100, tonumber(pct) or 0))
    return ('%d %%'):format(pct)
end

local function statusMeta(vehicle)
    return {
        { label = L('plate'), value = vehicle.plate },
        { label = L('status'), value = vehicle.stored and L('vehicle_stored') or L('vehicle_out') },
        { label = L('engine'), value = bar(vehicle.engine), progress = vehicle.engine },
        { label = L('body'), value = bar(vehicle.body), progress = vehicle.body },
        { label = L('fuel'), value = bar(vehicle.fuel), progress = vehicle.fuel },
    }
end

local function vehicleDescription(vehicle)
    local st = vehicle.stored and L('vehicle_stored') or L('vehicle_out')
    local kind = vehicle.isPersonal and L('job_personal_tag') or L('job_fleet_tag')
    return ('%s  ·  %s  ·  %s  ·  🔧 %s  ·  🛡 %s  ·  ⛽ %s'):format(
        vehicle.plate or '—', kind, st, bar(vehicle.engine), bar(vehicle.body), bar(vehicle.fuel)
    )
end

local function displayName(vehicle)
    if vehicle.label and vehicle.label ~= '' and vehicle.label ~= vehicle.model then
        return vehicle.label
    end
    return GetVehicleDisplayName(vehicle.model)
end

local function allowPersonal()
    return Config.JobCreator and Config.JobCreator.allowPersonalVehicles ~= false
end

---@param data table { job, garageId, label, spawns, store }
function OpenJobGarageMenu(data)
    if not data or not data.job then return end

    local garageId = tostring(data.garageId or '')
    local title = data.label or L('job_menu_title', data.job)

    -- Assis dans un véhicule → menu ranger (flotte OU perso)
    local veh = PlayerInOwnedVehicle()
    if veh and data.store then
        local coords = GetEntityCoords(veh)
        local storeCoords = data.store.coords
        local radius = data.store.radius or Config.StoreDistance
        if storeCoords and #(coords - storeCoords) <= radius then
            local plate = GetVehicleNumberPlateText(veh)
            local jobVeh = lib.callback.await('ox_garage:getJobVehicle', false, plate)
            if jobVeh then
                OpenJobStoreMenu(data, veh, jobVeh)
                return
            end
            if allowPersonal() then
                local personal = lib.callback.await('ox_garage:getVehicle', false, plate)
                if personal then
                    OpenJobStoreMenu(data, veh, {
                        plate = personal.plate,
                        model = personal.model,
                        isPersonal = true,
                        stored = personal.stored,
                        engine = personal.engine,
                        body = personal.body,
                        fuel = personal.fuel,
                    })
                    return
                end
            end
        end
    end

    local result = lib.callback.await('ox_garage:getJobVehicles', false, data.job, garageId)
    if not result or not result.ok then
        local err = result and result.error
        if err == 'wrong_job' then Notify(L('job_wrong_job'), 'error')
        else Notify(L('notify_error'), 'error') end
        return
    end

    local vehicles = result.vehicles or {}
    local ctxId = ('ox_garage_job_%s_%s'):format(data.job, garageId)

    if #vehicles == 0 then
        lib.registerContext({
            id = ctxId,
            title = title,
            options = {{
                title = L('menu_empty'),
                icon = 'inbox',
                iconColor = '#8b97a8',
                disabled = true,
                description = allowPersonal() and L('job_empty_hint_personal') or L('job_empty_hint'),
            }},
        })
        lib.showContext(ctxId)
        return
    end

    local options = {}
    for _i, v in ipairs(vehicles) do
        local name = displayName(v)
        options[#options + 1] = {
            title = name,
            description = vehicleDescription(v),
            icon = GetVehicleIcon(v.model),
            iconColor = v.stored and Config.StatusColors.stored or Config.StatusColors.out,
            metadata = statusMeta(v),
            arrow = true,
            onSelect = function()
                OpenJobVehicleDetail(data, v)
            end,
        }
    end

    lib.registerContext({ id = ctxId, title = title, options = options })
    lib.showContext(ctxId)
end

function OpenJobVehicleDetail(data, vehicle)
    local fresh
    if vehicle.isPersonal then
        fresh = lib.callback.await('ox_garage:getVehicle', false, vehicle.plate)
        if fresh then
            fresh.isPersonal = true
            fresh.isJob = false
            vehicle = fresh
        end
    else
        fresh = lib.callback.await('ox_garage:getJobVehicle', false, vehicle.plate)
        if fresh then vehicle = fresh end
    end

    local name = displayName(vehicle)
    local ctxId = ('ox_garage_job_detail_%s'):format(normalizePlateLocal(vehicle.plate))
    local parentId = ('ox_garage_job_%s_%s'):format(data.job, tostring(data.garageId or ''))

    local options = {
        {
            title = name,
            description = vehicleDescription(vehicle),
            icon = GetVehicleIcon(vehicle.model),
            iconColor = vehicle.stored and Config.StatusColors.stored or Config.StatusColors.out,
            metadata = statusMeta(vehicle),
        },
    }

    if vehicle.stored then
        options[#options + 1] = {
            title = L('take_out'),
            description = vehicle.isPersonal and L('job_take_personal') or L('job_take_fleet'),
            icon = 'key',
            iconColor = Config.StatusColors.stored,
            onSelect = function()
                TakeOutJobVehicle(data, vehicle)
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
        icon = 'circle-info',
        onSelect = function()
            OpenJobVehicleInfo(data, vehicle)
        end,
    }

    options[#options + 1] = {
        title = L('back'),
        icon = 'arrow-left',
        onSelect = function()
            OpenJobGarageMenu(data)
        end,
    }

    lib.registerContext({
        id = ctxId,
        title = name,
        menu = parentId,
        options = options,
    })
    lib.showContext(ctxId)
end

function OpenJobVehicleInfo(data, vehicle)
    local name = displayName(vehicle)
    lib.registerContext({
        id = 'ox_garage_job_info',
        title = L('info_title', name),
        options = {
            { title = L('plate'), description = vehicle.plate, icon = 'id-card' },
            {
                title = L('status'),
                description = vehicle.stored and L('vehicle_stored') or L('vehicle_out'),
                icon = vehicle.stored and 'warehouse' or 'road',
                iconColor = vehicle.stored and Config.StatusColors.stored or Config.StatusColors.out,
            },
            {
                title = L('engine'), description = bar(vehicle.engine), icon = 'engine',
                progress = vehicle.engine,
                colorScheme = vehicle.engine > 50 and 'green' or (vehicle.engine > 25 and 'yellow' or 'red'),
            },
            {
                title = L('body'), description = bar(vehicle.body), icon = 'car-burst',
                progress = vehicle.body,
                colorScheme = vehicle.body > 50 and 'green' or (vehicle.body > 25 and 'yellow' or 'red'),
            },
            {
                title = L('fuel'), description = bar(vehicle.fuel), icon = 'gas-pump',
                progress = vehicle.fuel,
                colorScheme = vehicle.fuel > 50 and 'green' or (vehicle.fuel > 25 and 'yellow' or 'red'),
            },
            {
                title = L('back'), icon = 'arrow-left',
                onSelect = function() OpenJobVehicleDetail(data, vehicle) end,
            },
        },
    })
    lib.showContext('ox_garage_job_info')
end

function OpenJobStoreMenu(data, veh, jobVeh)
    local name = displayName(jobVeh or {
        model = GetEntityModel(veh),
        label = GetVehicleDisplayName(GetEntityModel(veh)),
    })
    local plate = GetVehicleNumberPlateText(veh)

    lib.registerContext({
        id = 'ox_garage_job_store',
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
                icon = GetVehicleIcon(GetEntityModel(veh)),
                iconColor = Config.StatusColors.out,
            },
            {
                title = L('store_vehicle'),
                description = (jobVeh and jobVeh.isPersonal) and L('job_store_personal') or L('job_store_fleet'),
                icon = 'square-parking',
                iconColor = Config.StatusColors.stored,
                onSelect = function()
                    StoreJobVehicle(data, veh)
                end,
            },
            {
                title = L('cancel'),
                icon = 'xmark',
                onSelect = function() end,
            },
        },
    })
    lib.showContext('ox_garage_job_store')
end

function normalizePlateLocal(plate)
    return (plate or ''):gsub('%s+', ''):upper()
end

function TakeOutJobVehicle(data, vehicle)
    local isPersonal = vehicle.isPersonal == true
    local result = lib.callback.await(
        'ox_garage:takeOutJob',
        false,
        data.job,
        data.garageId,
        vehicle.plate,
        isPersonal
    )
    if not result or not result.ok then
        local map = {
            wrong_job = L('job_wrong_job'),
            grade = L('job_grade'),
            already_out = L('notify_already_out'),
            not_job_vehicle = L('job_not_job_vehicle'),
            not_yours = L('notify_not_yours'),
            not_stored = L('notify_not_stored'),
        }
        Notify(map[result and result.error] or L('notify_error'), 'error')
        return
    end

    isPersonal = result.isPersonal == true or isPersonal

    local spawns = data.spawns or {}
    local spawn = FindFreeSpawn(spawns)

    if not spawn then
        if Config.CheckSpawnClear and #spawns > 0 then
            TriggerServerEvent('ox_garage:forceStoreJob', vehicle.plate, data.garageId, isPersonal)
            Notify(L('no_spawn'), 'error')
            return
        elseif #spawns > 0 then
            spawn = spawns[1]
        else
            local ped = PlayerPedId()
            local c = GetEntityCoords(ped)
            local h = GetEntityHeading(ped)
            spawn = vec4(c.x + 3.0, c.y, c.z, h)
        end
    end

    local success = lib.progressCircle({
        duration = Config.ProgressSpawn,
        label = L('progress_spawn'),
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'anim@heists@keycard@', clip = 'exit' },
    })

    if not success then
        TriggerServerEvent('ox_garage:forceStoreJob', vehicle.plate, data.garageId, isPersonal)
        Notify(L('cancel'), 'inform')
        return
    end

    local props = result.props
    local model = props.model
    if type(model) == 'string' then model = joaat(model) end

    lib.requestModel(model, 5000)
    local entity = CreateVehicle(model, spawn.x, spawn.y, spawn.z, spawn.w or 0.0, true, false)
    if not entity or entity == 0 then
        TriggerServerEvent('ox_garage:forceStoreJob', vehicle.plate, data.garageId, isPersonal)
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

    local livery = result.livery or props.livery or 0
    if livery and livery > 0 then SetVehicleLivery(entity, livery) end

    local netId = NetworkGetNetworkIdFromEntity(entity)
    SetNetworkIdCanMigrate(netId, true)
    if isPersonal then
        TriggerServerEvent('ox_garage:registerSpawn', vehicle.plate, netId)
    else
        TriggerServerEvent('ox_garage:registerJobSpawn', vehicle.plate, netId)
    end
    TaskWarpPedIntoVehicle(PlayerPedId(), entity, -1)
    SetModelAsNoLongerNeeded(model)

    Notify(L('notify_spawned', result.label or displayName(vehicle)), 'success')
end

function StoreJobVehicle(data, veh)
    if not veh or not DoesEntityExist(veh) then
        Notify(L('notify_not_in_vehicle'), 'error')
        return
    end

    if data.store and data.store.coords then
        local radius = data.store.radius or Config.StoreDistance
        if #(GetEntityCoords(veh) - data.store.coords) > radius then
            Notify(L('notify_too_far'), 'error')
            return
        end
    end

    local success = lib.progressCircle({
        duration = Config.ProgressStore,
        label = L('progress_store'),
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'anim@heists@keycard@', clip = 'exit' },
    })

    if not success then
        Notify(L('cancel'), 'inform')
        return
    end

    if not DoesEntityExist(veh) then
        Notify(L('notify_error'), 'error')
        return
    end

    local props = GetVehicleProps(veh)
    local netId = NetworkGetNetworkIdFromEntity(veh)
    local name = GetVehicleDisplayName(GetEntityModel(veh))

    local result = lib.callback.await('ox_garage:storeJob', false, data.job, data.garageId, netId, props)
    if not result or not result.ok then
        local map = {
            wrong_job = L('job_wrong_job'),
            not_job_vehicle = L('job_not_job_vehicle'),
            not_yours = L('notify_not_yours'),
            too_far = L('notify_too_far'),
        }
        Notify(map[result and result.error] or L('notify_error'), 'error')
        return
    end

    TaskLeaveVehicle(PlayerPedId(), veh, 16)
    Wait(800)
    if DoesEntityExist(veh) then
        SetEntityAsMissionEntity(veh, true, true)
        DeleteVehicle(veh)
    end

    Notify(L('notify_stored', result.label or name), 'success')
end

--- Exports pour job_creator
exports('OpenJobGarage', function(data)
    if not Config.JobCreator or not Config.JobCreator.enabled then
        Notify('Intégration Job Creator désactivée', 'error')
        return
    end
    OpenJobGarageMenu(data)
end)

exports('OpenJobStore', function(data)
    local veh = PlayerInOwnedVehicle()
    if not veh then
        Notify(L('notify_not_in_vehicle'), 'error')
        return
    end
    local plate = GetVehicleNumberPlateText(veh)
    local jobVeh = lib.callback.await('ox_garage:getJobVehicle', false, plate)
    if jobVeh then
        OpenJobStoreMenu(data, veh, jobVeh)
        return
    end
    if allowPersonal() then
        local personal = lib.callback.await('ox_garage:getVehicle', false, plate)
        if personal then
            OpenJobStoreMenu(data, veh, {
                plate = personal.plate,
                model = personal.model,
                isPersonal = true,
            })
            return
        end
    end
    Notify(L('job_not_job_vehicle'), 'error')
end)
