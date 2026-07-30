CreateThread(function()
    while not FL.ESX do Wait(100) end

    FL.ESX.RegisterCommand('fladmin', 'admin', function(xPlayer)
        TriggerClientEvent('fuel_logistics:openAdmin', xPlayer.source)
    end, false, { help = 'Fuel Logistics — admin stations' })

    FL.ESX.RegisterCommand('fuelboss', 'user', function(xPlayer)
        if not FL.Can(xPlayer, 'boss') then
            return FL.Notify(xPlayer.source, L('no_permission'), 'error')
        end
        TriggerClientEvent('fuel_logistics:openBoss', xPlayer.source)
    end, false, { help = 'Menu patron Fuel Logistics' })
end)

lib.callback.register('fuel_logistics:adminCreateStation', function(source, data)
    local xPlayer = FL.GetPlayer(source)
    if not FL.IsAdmin(xPlayer) then return { ok = false, error = 'permission' } end
    if type(data) ~= 'table' or not data.name or not data.coords then
        return { ok = false, error = 'invalid' }
    end

    local id = MySQL.insert.await([[
        INSERT INTO fl_stations (name, coords, capacity, level, buy_price, consumption, owner_job)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], {
        data.name,
        json.encode(data.coords),
        tonumber(data.capacity) or 5000,
        tonumber(data.level) or 0,
        tonumber(data.buy_price) or 6,
        tonumber(data.consumption) or 2.0,
        data.owner_job ~= '' and data.owner_job or nil,
    })

    FL.LoadStations()
    FL.BroadcastStations()
    FL.Log(('Station créée #%s par %s'):format(id, xPlayer.getName and xPlayer.getName() or source))

    -- Notifie les employés qu'une station a été ajoutée
    local xPlayers = FL.ESX.GetExtendedPlayers and FL.ESX.GetExtendedPlayers('job', Config.JobName) or {}
    for _i, xp in pairs(xPlayers) do
        FL.Notify(xp.source, ('Nouvelle station : %s'):format(data.name), 'inform')
        TriggerClientEvent('fuel_logistics:stationCreated', xp.source, { id = id, name = data.name })
    end

    return { ok = true, id = id }
end)

lib.callback.register('fuel_logistics:adminUpdateStation', function(source, data)
    local xPlayer = FL.GetPlayer(source)
    if not FL.IsAdmin(xPlayer) then return { ok = false } end
    if type(data) ~= 'table' or not data.id then return { ok = false } end

    MySQL.update.await([[
        UPDATE fl_stations SET name=?, capacity=?, buy_price=?, consumption=?, owner_job=?,
        coords = COALESCE(?, coords)
        WHERE id=?
    ]], {
        data.name,
        tonumber(data.capacity),
        tonumber(data.buy_price),
        tonumber(data.consumption),
        data.owner_job ~= '' and data.owner_job or nil,
        data.coords and json.encode(data.coords) or nil,
        data.id,
    })

    FL.LoadStations()
    FL.BroadcastStations()
    return { ok = true }
end)

lib.callback.register('fuel_logistics:adminDeleteStation', function(source, id)
    local xPlayer = FL.GetPlayer(source)
    if not FL.IsAdmin(xPlayer) then return { ok = false } end
    MySQL.update.await('UPDATE fl_stations SET enabled = 0 WHERE id = ?', { tonumber(id) })
    FL.LoadStations()
    FL.BroadcastStations()
    return { ok = true }
end)
