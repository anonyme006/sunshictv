local function notifyJob(message)
    if not Config.AutoOrders.notifyEmployees then return end
    local xPlayers = FL.ESX.GetExtendedPlayers and FL.ESX.GetExtendedPlayers('job', Config.JobName) or {}
    for _, xp in pairs(xPlayers) do
        FL.Notify(xp.source, message, 'inform')
        TriggerClientEvent('fuel_logistics:orderPing', xp.source)
    end
end

local function createOrder(targetType, targetId, targetName, liters)
    -- Évite doublons pending
    local existing = MySQL.single.await([[
        SELECT id FROM fl_orders
        WHERE target_type = ? AND target_id = ? AND status IN ('pending', 'accepted')
        LIMIT 1
    ]], { targetType, targetId })
    if existing then return existing.id end

    local expire = os.date('%Y-%m-%d %H:%M:%S', os.time() + (Config.AutoOrders.expireMinutes or 45) * 60)
    local reward = math.floor(liters * (Config.Delivery.paymentPerLiter or 8) + (Config.AutoOrders.bonusPayment or 0))

    local id = MySQL.insert.await([[
        INSERT INTO fl_orders (target_type, target_id, target_name, liters, status, reward, expires_at)
        VALUES (?, ?, ?, ?, 'pending', ?, ?)
    ]], { targetType, targetId, targetName, liters, reward, expire })

    notifyJob(_('order_new', targetName, liters))
    TriggerClientEvent('fuel_logistics:newOrder', -1, {
        id = id,
        target_name = targetName,
        liters = liters,
        reward = reward,
    })
    return id
end

CreateThread(function()
    while true do
        Wait(Config.AutoOrders.checkInterval or 120000)
        if not FL.Ready or not Config.AutoOrders.enabled then goto continue end

        local threshold = (Config.AutoOrders.thresholdPercent or 20) / 100
        local defaultLiters = Config.AutoOrders.defaultLiters or 800

        for id, s in pairs(FL.Stations) do
            if s.capacity > 0 and (s.level / s.capacity) <= threshold then
                local need = math.min(defaultLiters, math.floor(s.capacity - s.level))
                if need > 50 then
                    createOrder('station', id, s.name, need)
                end
            end
        end

        for id, c in pairs(FL.Companies) do
            if c.capacity > 0 and (c.level / c.capacity) <= threshold then
                local need = math.min(defaultLiters, math.floor(c.capacity - c.level))
                if need > 50 then
                    createOrder('company', id, c.label, need)
                end
            end
        end

        -- Expire
        MySQL.update.await([[
            UPDATE fl_orders SET status = 'expired'
            WHERE status IN ('pending', 'accepted') AND expires_at IS NOT NULL AND expires_at < NOW()
        ]])

        ::continue::
    end
end)

lib.callback.register('fuel_logistics:getOrders', function(source)
    local xPlayer = FL.GetPlayer(source)
    if not FL.IsJob(xPlayer) then return {} end
    return MySQL.query.await([[
        SELECT * FROM fl_orders
        WHERE status IN ('pending', 'accepted')
        ORDER BY created_at ASC LIMIT 50
    ]]) or {}
end)

lib.callback.register('fuel_logistics:acceptOrder', function(source, orderId)
    local xPlayer = FL.GetPlayer(source)
    if not FL.Can(xPlayer, 'orders') and not FL.Can(xPlayer, 'deliver') then
        return { ok = false, error = 'permission' }
    end
    orderId = tonumber(orderId)
    local row = MySQL.single.await('SELECT * FROM fl_orders WHERE id = ?', { orderId })
    if not row or row.status ~= 'pending' then return { ok = false, error = 'invalid' } end

    MySQL.update.await([[
        UPDATE fl_orders SET status = 'accepted', accepted_by = ?, accepted_name = ? WHERE id = ? AND status = 'pending'
    ]], { xPlayer.identifier, xPlayer.getName and xPlayer.getName() or GetPlayerName(source), orderId })

    return { ok = true, order = MySQL.single.await('SELECT * FROM fl_orders WHERE id = ?', { orderId }) }
end)

lib.callback.register('fuel_logistics:declineOrder', function(source, orderId)
    local xPlayer = FL.GetPlayer(source)
    if not FL.IsJob(xPlayer) then return { ok = false } end
    MySQL.update.await([[
        UPDATE fl_orders SET status = 'declined' WHERE id = ? AND status = 'pending'
    ]], { tonumber(orderId) })
    return { ok = true }
end)

AddEventHandler('fuel_logistics:tryCompleteOrder', function(targetType, targetId, liters, xPlayer)
    local row = MySQL.single.await([[
        SELECT * FROM fl_orders
        WHERE target_type = ? AND target_id = ? AND status = 'accepted'
        ORDER BY id ASC LIMIT 1
    ]], { targetType, targetId })
    if not row then return end

    -- Clôture si livraison significative (>= 50% de la commande) ou cuve remplie
    local target = targetType == 'station' and FL.Stations[targetId] or FL.Companies[targetId]
    local filled = target and target.level >= (target.capacity * 0.95)
    if liters >= (row.liters * 0.5) or filled then
        MySQL.update.await([[
            UPDATE fl_orders SET status = 'completed', completed_at = NOW() WHERE id = ?
        ]], { row.id })

        if (Config.AutoOrders.bonusPayment or 0) > 0 and xPlayer then
            FL.AddSocietyMoney(Config.AutoOrders.bonusPayment, 'Bonus commande #' .. row.id, xPlayer.identifier)
        end

        if xPlayer then
            FL.Notify(xPlayer.source, _('order_done'), 'success')
        end
    end
end)
