local deliveryZones = {}

function SpawnDeliveryTruck()
    if FL_C.Truck and DoesEntityExist(FL_C.Truck) then
        return Notify('Camion déjà sorti', 'error')
    end

    local spawn = Config.Delivery.truckSpawn
    local model = Config.Delivery.truckModel
    local trailerModel = Config.Delivery.trailerModel

    lib.requestModel(model, 5000)
    local truck = CreateVehicle(model, spawn.x, spawn.y, spawn.z, spawn.w, true, false)
    SetVehicleOnGroundProperly(truck)
    SetEntityAsMissionEntity(truck, true, true)
    SetVehicleHasBeenOwnedByPlayer(truck, true)
    SetVehicleNumberPlateText(truck, 'FUEL'..math.random(100, 999))

    if trailerModel then
        lib.requestModel(trailerModel, 5000)
        local trailer = CreateVehicle(trailerModel, spawn.x - 8.0, spawn.y, spawn.z, spawn.w, true, false)
        SetEntityAsMissionEntity(trailer, true, true)
        AttachVehicleToTrailer(truck, trailer, 1.0)
        FL_C.Trailer = trailer
        SetModelAsNoLongerNeeded(trailerModel)
    end

    TaskWarpPedIntoVehicle(PlayerPedId(), truck, -1)
    FL_C.Truck = truck
    SetModelAsNoLongerNeeded(model)
    Notify(_('truck_spawned'), 'success')
end

function StoreDeliveryTruck()
    if FL_C.Truck and DoesEntityExist(FL_C.Truck) then
        DeleteVehicle(FL_C.Truck)
    end
    if FL_C.Trailer and DoesEntityExist(FL_C.Trailer) then
        DeleteVehicle(FL_C.Trailer)
    end
    FL_C.Truck, FL_C.Trailer = nil, nil
    Notify(_('truck_stored'), 'success')
end

function LoadTruckMenu()
    local load = lib.callback.await('fuel_logistics:getLoad', false) or { barrels = 0, liters = 0 }
    local maxB = Config.Delivery.maxLoadBarrels
    local free = maxB - (load.barrels or 0)

    local input = lib.inputDialog('Chargement citerne', {
        { type = 'number', label = ('Barils à charger (max %d, déjà %d)'):format(free, load.barrels or 0), default = math.min(free, 2), min = 1, max = free },
    })
    if not input then return end

    local count = math.floor(tonumber(input[1]) or 0)
    local ok = DoProgress(3500, _('progress_load'), Config.Delivery.anim)
    if not ok then return Notify(_('cancelled'), 'inform') end

    local result = lib.callback.await('fuel_logistics:loadTruck', false, count)
    if not result or not result.ok then
        local err = result and result.error
        if err == 'missing' then Notify(_('missing_items'), 'error')
        elseif err == 'hose' then Notify('Il te faut un flexible (fuel_hose)', 'error')
        elseif err == 'full' then Notify('Citerne pleine', 'error')
        else Notify(_('cancelled'), 'error') end
        return
    end

    Notify(_('loaded', result.load.barrels, result.load.liters), 'success')
end

function RefreshDeliveryTargets()
    for _, zid in pairs(deliveryZones) do
        exports.ox_target:removeZone(zid)
    end
    deliveryZones = {}

    for id, s in pairs(FL_C.Stations) do
        local c = s.coords
        if c then
            local zoneId = exports.ox_target:addSphereZone({
                coords = vec3(c.x, c.y, c.z),
                radius = 3.0,
                options = {{
                    name = 'fl_deliver_station_' .. id,
                    icon = 'fa-solid fa-gas-pump',
                    label = _('target_deliver') .. ' — ' .. (s.name or 'Station'),
                    canInteract = function() return CanPerm('deliver') end,
                    onSelect = function()
                        DeliverMenu('station', tonumber(id) or s.id, s)
                    end,
                }},
            })
            deliveryZones[#deliveryZones + 1] = zoneId
        end
    end

    for id, co in pairs(FL_C.Companies) do
        local c = co.coords
        if c then
            local zoneId = exports.ox_target:addSphereZone({
                coords = vec3(c.x, c.y, c.z),
                radius = 3.0,
                options = {{
                    name = 'fl_deliver_company_' .. id,
                    icon = 'fa-solid fa-building',
                    label = _('target_deliver') .. ' — ' .. (co.label or 'Entreprise'),
                    canInteract = function() return CanPerm('deliver') end,
                    onSelect = function()
                        DeliverMenu('company', tonumber(id) or co.id, co)
                    end,
                }},
            })
            deliveryZones[#deliveryZones + 1] = zoneId
        end
    end
end

function DeliverMenu(targetType, targetId, target)
    local load = lib.callback.await('fuel_logistics:getLoad', false) or { liters = 0 }
    if (load.liters or 0) < 1 then
        return Notify(_('not_enough_fuel'), 'error')
    end

    local capacity = target.capacity or 0
    local level = target.level or 0
    local space = math.max(0, capacity - level)
    local maxDeliver = math.min(load.liters, space)

    if maxDeliver < 1 then return Notify(_('station_full'), 'error') end

    local input = lib.inputDialog(target.name or target.label or 'Livraison', {
        {
            type = 'number',
            label = ('Litres (dispo camion %d L · place %d L)'):format(load.liters, space),
            default = maxDeliver,
            min = 1,
            max = maxDeliver,
        },
    })
    if not input then return end

    local liters = math.floor(tonumber(input[1]) or 0)
    local ok = DoProgress(Config.Delivery.deliverDuration, _('progress_deliver'), Config.Delivery.anim)
    if not ok then return Notify(_('cancelled'), 'inform') end

    local result
    if targetType == 'station' then
        result = lib.callback.await('fuel_logistics:deliverStation', false, targetId, liters)
    else
        result = lib.callback.await('fuel_logistics:deliverCompany', false, targetId, liters)
    end

    if not result or not result.ok then
        local err = result and result.error
        if err == 'full' then Notify(_('station_full'), 'error')
        elseif err == 'fuel' then Notify(_('not_enough_fuel'), 'error')
        elseif err == 'distance' then Notify('Trop loin', 'error')
        else Notify(_('cancelled'), 'error') end
        return
    end

    Notify(_('delivered', result.liters, result.payment), 'success')
    if FL_C.Stations[tostring(targetId)] then
        FL_C.Stations[tostring(targetId)].level = result.level
    end
    if FL_C.Companies[tostring(targetId)] then
        FL_C.Companies[tostring(targetId)].level = result.level
    end
end
