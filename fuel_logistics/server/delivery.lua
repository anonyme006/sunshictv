--[[
    Chargement camion + livraison stations / entreprises
    Le "chargement" consomme des fuel_barrel de l'inventaire joueur.
    State bag player: fl_load = { liters = N, barrels = N }
]]

local function getLoad(src)
    local state = Player(src).state.fl_load
    if type(state) ~= 'table' then
        return { liters = 0, barrels = 0 }
    end
    return { liters = tonumber(state.liters) or 0, barrels = tonumber(state.barrels) or 0 }
end

local function setLoad(src, load)
    Player(src).state:set('fl_load', load, true)
end

lib.callback.register('fuel_logistics:getLoad', function(source)
    return getLoad(source)
end)

lib.callback.register('fuel_logistics:loadTruck', function(source, barrelCount)
    local src = source
    local xPlayer = FL.GetPlayer(src)
    if not FL.Can(xPlayer, 'deliver') then return { ok = false, error = 'permission' } end
    if FL.IsBusy(src) then return { ok = false, error = 'busy' } end

    barrelCount = math.floor(tonumber(barrelCount) or 0)
    if barrelCount < 1 then return { ok = false, error = 'invalid' } end

    local current = getLoad(src)
    local maxB = Config.Delivery.maxLoadBarrels
    if current.barrels + barrelCount > maxB then
        barrelCount = maxB - current.barrels
        if barrelCount < 1 then return { ok = false, error = 'full' } end
    end

    local item = Config.Items.fuelBarrel
    local have = exports.ox_inventory:GetItemCount(src, item) or 0
    if have < barrelCount then return { ok = false, error = 'missing' } end

    if Config.Delivery.requireHose then
        local hose = exports.ox_inventory:GetItemCount(src, Config.Items.hose) or 0
        if hose < 1 then return { ok = false, error = 'hose' } end
    end

    FL.SetBusy(src, true)

    have = exports.ox_inventory:GetItemCount(src, item) or 0
    if have < barrelCount then
        FL.SetBusy(src, nil)
        return { ok = false, error = 'missing' }
    end

    if not exports.ox_inventory:RemoveItem(src, item, barrelCount) then
        FL.SetBusy(src, nil)
        return { ok = false, error = 'missing' }
    end

    local liters = barrelCount * Config.BarrelLiters
    local newLoad = {
        barrels = current.barrels + barrelCount,
        liters = current.liters + liters,
    }
    setLoad(src, newLoad)
    FL.SetBusy(src, nil)

    return { ok = true, load = newLoad }
end)

local function deliverToTarget(src, xPlayer, targetType, targetId, liters)
    liters = math.floor(tonumber(liters) or 0)
    if liters < 1 then return { ok = false, error = 'invalid' } end

    local load = getLoad(src)
    if load.liters < liters then return { ok = false, error = 'fuel' } end

    local target, pricePerLiter
    if targetType == 'station' then
        target = FL.Stations[targetId]
        pricePerLiter = target and (target.buy_price or Config.Delivery.paymentPerLiter) or Config.Delivery.paymentPerLiter
    elseif targetType == 'company' then
        target = FL.Companies[targetId]
        pricePerLiter = target and (target.buy_price or Config.Delivery.companyPaymentPerLiter) or Config.Delivery.companyPaymentPerLiter
    else
        return { ok = false, error = 'invalid' }
    end

    if not target then return { ok = false, error = 'invalid' } end

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    if #(coords - target.coords) > 12.0 then
        return { ok = false, error = 'distance' }
    end

    local space = target.capacity - target.level
    if space <= 0 then return { ok = false, error = 'full' } end
    if liters > space then liters = math.floor(space) end
    if liters < 1 then return { ok = false, error = 'full' } end

    FL.SetBusy(src, true)

    xPlayer = FL.GetPlayer(src)
    if not xPlayer then FL.SetBusy(src, nil) return { ok = false } end

    load = getLoad(src)
    if load.liters < liters then
        FL.SetBusy(src, nil)
        return { ok = false, error = 'fuel' }
    end

    -- Re-check space
    if targetType == 'station' then target = FL.Stations[targetId]
    else target = FL.Companies[targetId] end
    if not target then FL.SetBusy(src, nil) return { ok = false } end

    space = target.capacity - target.level
    if liters > space then liters = math.floor(space) end
    if liters < 1 then FL.SetBusy(src, nil) return { ok = false, error = 'full' } end

    local newLevel = target.level + liters
    if targetType == 'station' then
        FL.SaveStationLevel(targetId, newLevel)
    else
        FL.SaveCompanyLevel(targetId, newLevel)
    end

    local barrelsUsed = math.ceil(liters / Config.BarrelLiters)
    local newLoad = {
        liters = math.max(0, load.liters - liters),
        barrels = math.max(0, load.barrels - barrelsUsed),
    }
    if newLoad.liters == 0 then newLoad.barrels = 0 end
    setLoad(src, newLoad)

    local payment = math.floor(liters * pricePerLiter)
    FL.AddSocietyMoney(payment, ('Livraison %s'):format(target.name or target.label), xPlayer.identifier)

    FL.AddHistory({
        type = 'delivery',
        identifier = xPlayer.identifier,
        player_name = xPlayer.getName and xPlayer.getName() or GetPlayerName(src),
        target_type = targetType,
        target_id = targetId,
        target_name = target.name or target.label,
        liters = liters,
        amount = payment,
    })

    TriggerEvent('fuel_logistics:tryCompleteOrder', targetType, targetId, liters, xPlayer)

    FL.SetBusy(src, nil)
    TriggerClientEvent('fuel_logistics:updateLevels', -1, FL.GetLevelsPayload())

    return {
        ok = true,
        liters = liters,
        payment = payment,
        level = newLevel,
        capacity = target.capacity,
        load = newLoad,
    }
end

lib.callback.register('fuel_logistics:deliverStation', function(source, stationId, liters)
    local xPlayer = FL.GetPlayer(source)
    if not FL.Can(xPlayer, 'deliver') then return { ok = false, error = 'permission' } end
    if FL.IsBusy(source) then return { ok = false, error = 'busy' } end
    return deliverToTarget(source, xPlayer, 'station', tonumber(stationId), liters)
end)

lib.callback.register('fuel_logistics:deliverCompany', function(source, companyId, liters)
    local xPlayer = FL.GetPlayer(source)
    if not FL.Can(xPlayer, 'deliver') then return { ok = false, error = 'permission' } end
    if FL.IsBusy(source) then return { ok = false, error = 'busy' } end
    return deliverToTarget(source, xPlayer, 'company', tonumber(companyId), liters)
end)

AddEventHandler('playerDropped', function()
    Player(source).state:set('fl_load', nil, true)
end)
