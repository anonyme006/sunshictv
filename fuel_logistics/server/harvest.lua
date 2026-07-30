local lastHarvest = {}

lib.callback.register('fuel_logistics:harvest', function(source, pointId)
    local src = source
    local xPlayer = FL.GetPlayer(src)
    if not FL.Can(xPlayer, 'harvest') then return { ok = false, error = 'permission' } end
    if FL.IsBusy(src) then return { ok = false, error = 'busy' } end

    local point
    for _i, p in ipairs(Config.HarvestPoints) do
        if p.id == pointId then point = p break end
    end
    if not point then return { ok = false, error = 'invalid' } end

    local ped = GetPlayerPed(src)
    if #(GetEntityCoords(ped) - point.coords) > (point.radius + 4.0) then
        return { ok = false, error = 'distance' }
    end

    local now = os.time()
    if lastHarvest[src] and (now - lastHarvest[src]) < math.ceil((Config.Harvest.cooldown or 2000) / 1000) then
        return { ok = false, error = 'cooldown' }
    end

    local count = math.random(Config.Harvest.rewardMin, Config.Harvest.rewardMax)
    local item = Config.Harvest.rewardItem

    if exports.ox_inventory:CanCarryItem(src, item, count) == false then
        return { ok = false, error = 'inventory' }
    end

    FL.SetBusy(src, true)
    exports.ox_inventory:AddItem(src, item, count)
    lastHarvest[src] = now
    FL.SetBusy(src, nil)

    FL.AddHistory({
        type = 'harvest',
        identifier = xPlayer.identifier,
        player_name = xPlayer.getName and xPlayer.getName() or GetPlayerName(src),
        meta = { item = item, count = count, point = pointId },
    })

    return { ok = true, count = count, item = item }
end)
