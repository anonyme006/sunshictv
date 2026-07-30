lib.callback.register('fuel_logistics:export', function(source, barrelCount)
    local src = source
    local xPlayer = FL.GetPlayer(src)
    if not FL.Can(xPlayer, 'export') then return { ok = false, error = 'permission' } end
    if FL.IsBusy(src) then return { ok = false, error = 'busy' } end

    barrelCount = math.floor(tonumber(barrelCount) or 0)
    if barrelCount < (Config.Export.minBarrels or 1) then
        return { ok = false, error = 'invalid' }
    end

    local ped = GetPlayerPed(src)
    if #(GetEntityCoords(ped) - Config.Export.coords) > (Config.Export.radius + 5.0) then
        return { ok = false, error = 'distance' }
    end

    local item = Config.Export.item
    local have = exports.ox_inventory:GetItemCount(src, item) or 0
    if have < barrelCount then return { ok = false, error = 'missing' } end

    FL.SetBusy(src, true)
    if not exports.ox_inventory:RemoveItem(src, item, barrelCount) then
        FL.SetBusy(src, nil)
        return { ok = false, error = 'missing' }
    end

    local amount = barrelCount * Config.Export.pricePerBarrel
    FL.AddSocietyMoney(amount, 'Export carburant', xPlayer.identifier)

    MySQL.insert.await(
        'INSERT INTO fl_exports (identifier, player_name, barrels, amount) VALUES (?, ?, ?, ?)',
        { xPlayer.identifier, xPlayer.getName and xPlayer.getName() or GetPlayerName(src), barrelCount, amount }
    )

    FL.AddHistory({
        type = 'export',
        identifier = xPlayer.identifier,
        player_name = xPlayer.getName and xPlayer.getName() or GetPlayerName(src),
        liters = barrelCount * Config.BarrelLiters,
        amount = amount,
        meta = { barrels = barrelCount },
    })

    FL.SetBusy(src, nil)
    return { ok = true, barrels = barrelCount, amount = amount }
end)
