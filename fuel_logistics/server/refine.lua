lib.callback.register('fuel_logistics:refine', function(source)
    local src = source
    local xPlayer = FL.GetPlayer(src)
    if not FL.Can(xPlayer, 'refine') then return { ok = false, error = 'permission' } end
    if FL.IsBusy(src) then return { ok = false, error = 'busy' } end

    local ped = GetPlayerPed(src)
    if #(GetEntityCoords(ped) - Config.RefinePoint.coords) > (Config.RefinePoint.radius + 4.0) then
        return { ok = false, error = 'distance' }
    end

    local inputItem = Config.Refine.inputItem
    local inputCount = Config.Refine.inputCount
    local have = exports.ox_inventory:GetItemCount(src, inputItem) or 0
    if have < inputCount then return { ok = false, error = 'missing' } end

    local outItem = Config.Refine.outputItem
    local outCount = Config.Refine.outputCount
    if exports.ox_inventory:CanCarryItem(src, outItem, outCount) == false then
        return { ok = false, error = 'inventory' }
    end

    FL.SetBusy(src, true)
    if not exports.ox_inventory:RemoveItem(src, inputItem, inputCount) then
        FL.SetBusy(src, nil)
        return { ok = false, error = 'missing' }
    end
    exports.ox_inventory:AddItem(src, outItem, outCount)
    FL.SetBusy(src, nil)

    FL.AddHistory({
        type = 'refine',
        identifier = xPlayer.identifier,
        player_name = xPlayer.getName and xPlayer.getName() or GetPlayerName(src),
        meta = { input = inputCount, output = outCount },
    })

    return { ok = true, count = outCount, item = outItem }
end)
