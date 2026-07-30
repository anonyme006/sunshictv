local ESX = exports['es_extended']:getSharedObject()

RegisterNetEvent('job_creator:saveMarker', function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not JC.IsAdmin(xPlayer) then return end
    if type(data) ~= 'table' or not data.job_name or not data.type or not data.coords then
        return JC.Notify(src, L('invalid_data'))
    end

    local coords = json.encode(data.coords)
    local mdata = json.encode(data.data or {})
    local scale = json.encode(data.marker_scale or Config.DefaultMarker.scale)
    local color = json.encode(data.marker_color or Config.DefaultMarker.color)

    if data.id then
        MySQL.update.await([[
            UPDATE jc_markers SET job_name=?, type=?, label=?, coords=?, min_grade=?, data=?,
            marker_type=?, marker_scale=?, marker_color=?, blip_enabled=?, blip_sprite=?, blip_color=?,
            blip_scale=?, public=?, enabled=? WHERE id=?
        ]], {
            data.job_name, data.type, data.label or data.type, coords, data.min_grade or 0, mdata,
            data.marker_type or 1, scale, color,
            data.blip_enabled and 1 or 0, data.blip_sprite or 1, data.blip_color or 0,
            data.blip_scale or 0.7, data.public and 1 or 0, data.enabled ~= false and 1 or 0,
            data.id,
        })
    else
        MySQL.insert.await([[
            INSERT INTO jc_markers (job_name, type, label, coords, min_grade, data, marker_type, marker_scale,
            marker_color, blip_enabled, blip_sprite, blip_color, blip_scale, public, enabled)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)
        ]], {
            data.job_name, data.type, data.label or data.type, coords, data.min_grade or 0, mdata,
            data.marker_type or 1, scale, color,
            data.blip_enabled and 1 or 0, data.blip_sprite or 1, data.blip_color or 0,
            data.blip_scale or 0.7, data.public and 1 or 0,
        })
    end

    JC.Notify(src, L('marker_saved'))
    JC.LoadAll()
end)

RegisterNetEvent('job_creator:deleteMarker', function(id)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not JC.IsAdmin(xPlayer) then return end
    MySQL.query.await('DELETE FROM jc_markers WHERE id = ?', { id })
    MySQL.query.await('DELETE FROM jc_vehicles WHERE marker_id = ?', { id })
    MySQL.query.await('DELETE FROM jc_shop_items WHERE marker_id = ?', { id })
    MySQL.query.await('DELETE FROM jc_crafts WHERE marker_id = ?', { id })

    if Config.UseOxGarage and GetResourceState('ox_garage') == 'started' then
        pcall(function()
            MySQL.query.await('DELETE FROM ox_garage_job_vehicles WHERE garage_id = ?', { tostring(id) })
        end)
    end

    JC.Notify(src, L('marker_deleted'))
    JC.LoadAll()
end)

RegisterNetEvent('job_creator:saveVehicle', function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not JC.IsAdmin(xPlayer) then return end
    if type(data) ~= 'table' or not data.job_name or not data.model then return end

    local templateId = data.id
    if data.id then
        MySQL.update.await('UPDATE jc_vehicles SET job_name=?, marker_id=?, model=?, label=?, min_grade=?, price=?, livery=?, extras=? WHERE id=?', {
            data.job_name, data.marker_id, data.model, data.label or data.model,
            data.min_grade or 0, data.price or 0, data.livery or 0, json.encode(data.extras or {}), data.id
        })
    else
        templateId = MySQL.insert.await('INSERT INTO jc_vehicles (job_name, marker_id, model, label, min_grade, price, livery, extras) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
            data.job_name, data.marker_id, data.model, data.label or data.model,
            data.min_grade or 0, data.price or 0, data.livery or 0, json.encode(data.extras or {})
        })
    end

    -- Sync flotte ox_garage
    if Config.UseOxGarage and GetResourceState('ox_garage') == 'started' then
        pcall(function()
            exports.ox_garage:UpsertJobFleetVehicle({
                template_id = templateId,
                id = templateId,
                job_name = data.job_name,
                garage_id = data.marker_id,
                marker_id = data.marker_id,
                model = data.model,
                label = data.label or data.model,
                min_grade = data.min_grade or 0,
                livery = data.livery or 0,
            })
        end)
    end

    JC.LoadAll()
    JC.Notify(src, 'Véhicule sauvegardé')
end)

RegisterNetEvent('job_creator:deleteVehicle', function(id)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not JC.IsAdmin(xPlayer) then return end
    MySQL.query.await('DELETE FROM jc_vehicles WHERE id = ?', { id })

    if Config.UseOxGarage and GetResourceState('ox_garage') == 'started' then
        pcall(function()
            exports.ox_garage:DeleteJobFleetByTemplate(id)
        end)
    end

    JC.LoadAll()
end)

RegisterNetEvent('job_creator:saveOutfit', function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not JC.IsAdmin(xPlayer) then return end
    if type(data) ~= 'table' or not data.job_name or not data.skin then return end

    if data.id then
        MySQL.update.await('UPDATE jc_outfits SET label=?, min_grade=?, skin=?, gender=? WHERE id=?', {
            data.label, data.min_grade or 0, json.encode(data.skin), data.gender or 'both', data.id
        })
    else
        MySQL.insert.await('INSERT INTO jc_outfits (job_name, label, min_grade, skin, gender) VALUES (?, ?, ?, ?, ?)', {
            data.job_name, data.label or 'Tenue', data.min_grade or 0, json.encode(data.skin), data.gender or 'both'
        })
    end
    JC.LoadAll()
    JC.Notify(src, L('outfit_saved'))
end)

RegisterNetEvent('job_creator:deleteOutfit', function(id)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not JC.IsAdmin(xPlayer) then return end
    MySQL.query.await('DELETE FROM jc_outfits WHERE id = ?', { id })
    JC.LoadAll()
end)

RegisterNetEvent('job_creator:saveShopItem', function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not JC.IsAdmin(xPlayer) then return end
    if type(data) ~= 'table' or not data.job_name or not data.item then return end

    if data.id then
        MySQL.update.await('UPDATE jc_shop_items SET marker_id=?, item=?, label=?, price=?, min_grade=?, type=? WHERE id=?', {
            data.marker_id, data.item, data.label or data.item, data.price or 0, data.min_grade or 0, data.type or 'item', data.id
        })
    else
        MySQL.insert.await('INSERT INTO jc_shop_items (job_name, marker_id, item, label, price, min_grade, type) VALUES (?, ?, ?, ?, ?, ?, ?)', {
            data.job_name, data.marker_id, data.item, data.label or data.item, data.price or 0, data.min_grade or 0, data.type or 'item'
        })
    end
    JC.LoadAll()
    JC.Notify(src, 'Item boutique sauvegardé')
end)

RegisterNetEvent('job_creator:deleteShopItem', function(id)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not JC.IsAdmin(xPlayer) then return end
    MySQL.query.await('DELETE FROM jc_shop_items WHERE id = ?', { id })
    JC.LoadAll()
end)

RegisterNetEvent('job_creator:saveCraft', function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not JC.IsAdmin(xPlayer) then return end
    if type(data) ~= 'table' or not data.job_name or not data.result_item then return end

    if data.id then
        MySQL.update.await('UPDATE jc_crafts SET marker_id=?, label=?, result_item=?, result_count=?, ingredients=?, duration=?, min_grade=? WHERE id=?', {
            data.marker_id, data.label, data.result_item, data.result_count or 1,
            json.encode(data.ingredients or {}), data.duration or 5000, data.min_grade or 0, data.id
        })
    else
        MySQL.insert.await('INSERT INTO jc_crafts (job_name, marker_id, label, result_item, result_count, ingredients, duration, min_grade) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
            data.job_name, data.marker_id, data.label or data.result_item, data.result_item, data.result_count or 1,
            json.encode(data.ingredients or {}), data.duration or 5000, data.min_grade or 0
        })
    end
    JC.LoadAll()
    JC.Notify(src, 'Craft sauvegardé')
end)

RegisterNetEvent('job_creator:deleteCraft', function(id)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not JC.IsAdmin(xPlayer) then return end
    MySQL.query.await('DELETE FROM jc_crafts WHERE id = ?', { id })
    JC.LoadAll()
end)

--- Interactions markers (joueur)
local busy = {}

local function canUseMarker(xPlayer, marker)
    if not marker then return false end
    if marker.public then return true end
    if not xPlayer.job or xPlayer.job.name ~= marker.job_name then return false end
    if (xPlayer.job.grade or 0) < (marker.min_grade or 0) then return false end
    return true
end

RegisterNetEvent('job_creator:harvest', function(markerId)
    local src = source
    if busy[src] then return end
    local xPlayer = ESX.GetPlayerFromId(src)
    local marker = JC.Markers[markerId]
    if not xPlayer or not canUseMarker(xPlayer, marker) then return end

    local data = marker.data or {}
    local item = data.item
    local count = tonumber(data.count) or 1
    if not item then return end

    busy[src] = true
    SetTimeout(Config.HarvestTime, function()
        busy[src] = nil
        xPlayer = ESX.GetPlayerFromId(src)
        if not xPlayer then return end
        xPlayer.addInventoryItem(item, count)
        JC.Notify(src, L('harvested', count, data.label or item))
    end)
end)

RegisterNetEvent('job_creator:process', function(markerId)
    local src = source
    if busy[src] then return end
    local xPlayer = ESX.GetPlayerFromId(src)
    local marker = JC.Markers[markerId]
    if not xPlayer or not canUseMarker(xPlayer, marker) then return end

    local data = marker.data or {}
    local need = data.need_item
    local needCount = tonumber(data.need_count) or 1
    local give = data.give_item
    local giveCount = tonumber(data.give_count) or 1
    if not need or not give then return end

    local inv = xPlayer.getInventoryItem(need)
    if not inv or (inv.count or 0) < needCount then
        return JC.Notify(src, L('missing_items'))
    end

    busy[src] = true
    SetTimeout(Config.ProcessTime, function()
        busy[src] = nil
        xPlayer = ESX.GetPlayerFromId(src)
        if not xPlayer then return end
        inv = xPlayer.getInventoryItem(need)
        if not inv or (inv.count or 0) < needCount then
            return JC.Notify(src, L('missing_items'))
        end
        xPlayer.removeInventoryItem(need, needCount)
        xPlayer.addInventoryItem(give, giveCount)
        JC.Notify(src, L('processed'))
    end)
end)

RegisterNetEvent('job_creator:sell', function(markerId)
    local src = source
    if busy[src] then return end
    local xPlayer = ESX.GetPlayerFromId(src)
    local marker = JC.Markers[markerId]
    if not xPlayer or not canUseMarker(xPlayer, marker) then return end

    local data = marker.data or {}
    local item = data.item
    local price = tonumber(data.price) or 0
    local count = tonumber(data.count) or 1
    if not item or price <= 0 then return end

    local inv = xPlayer.getInventoryItem(item)
    if not inv or (inv.count or 0) < count then
        return JC.Notify(src, L('missing_items'))
    end

    busy[src] = true
    SetTimeout(Config.SellTime, function()
        busy[src] = nil
        xPlayer = ESX.GetPlayerFromId(src)
        if not xPlayer then return end
        inv = xPlayer.getInventoryItem(item)
        if not inv or (inv.count or 0) < count then
            return JC.Notify(src, L('missing_items'))
        end
        xPlayer.removeInventoryItem(item, count)
        local black = data.black_money == true
        if black then
            xPlayer.addAccountMoney('black_money', price)
        else
            xPlayer.addMoney(price)
        end

        -- Commission société
        local societyCut = tonumber(data.society_percent) or 0
        if societyCut > 0 then
            local cut = math.floor(price * societyCut / 100)
            if cut > 0 then
                TriggerEvent('job_creator:addSocietyMoney', marker.job_name, cut)
            end
        end

        JC.Notify(src, L('sold', price))
    end)
end)

RegisterNetEvent('job_creator:craft', function(craftId)
    local src = source
    if busy[src] then return end
    local xPlayer = ESX.GetPlayerFromId(src)
    local craft = JC.Crafts[craftId]
    if not xPlayer or not craft then return end
    if xPlayer.job.name ~= craft.job_name then return end
    if (xPlayer.job.grade or 0) < (craft.min_grade or 0) then return end

    for _i, ing in ipairs(craft.ingredients or {}) do
        local inv = xPlayer.getInventoryItem(ing.item)
        if not inv or (inv.count or 0) < (ing.count or 1) then
            return JC.Notify(src, L('missing_items'))
        end
    end

    busy[src] = true
    SetTimeout(craft.duration or 5000, function()
        busy[src] = nil
        xPlayer = ESX.GetPlayerFromId(src)
        if not xPlayer then return end
        for _i, ing in ipairs(craft.ingredients or {}) do
            local inv = xPlayer.getInventoryItem(ing.item)
            if not inv or (inv.count or 0) < (ing.count or 1) then
                return JC.Notify(src, L('missing_items'))
            end
        end
        for _i, ing in ipairs(craft.ingredients or {}) do
            xPlayer.removeInventoryItem(ing.item, ing.count or 1)
        end
        xPlayer.addInventoryItem(craft.result_item, craft.result_count or 1)
        JC.Notify(src, L('crafted'))
    end)
end)

RegisterNetEvent('job_creator:buyShopItem', function(itemId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local shop = JC.ShopItems[itemId]
    if not xPlayer or not shop then return end
    if xPlayer.job.name ~= shop.job_name then return end
    if (xPlayer.job.grade or 0) < (shop.min_grade or 0) then return end

    local price = shop.price or 0
    if xPlayer.getMoney() < price then
        return JC.Notify(src, L('no_money'))
    end

    xPlayer.removeMoney(price)
    if shop.type == 'weapon' then
        xPlayer.addWeapon(shop.item, 50)
    else
        xPlayer.addInventoryItem(shop.item, 1)
    end
    JC.Notify(src, L('bought', shop.label))
end)

RegisterNetEvent('job_creator:wash', function(markerId, amount)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local marker = JC.Markers[markerId]
    if not xPlayer or not canUseMarker(xPlayer, marker) then return end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return end

    local black = xPlayer.getAccount('black_money')
    if not black or black.money < amount then
        return JC.Notify(src, L('no_money'))
    end

    local fee = tonumber((marker.data or {}).fee_percent) or 30
    local clean = math.floor(amount * (100 - fee) / 100)

    xPlayer.removeAccountMoney('black_money', amount)
    xPlayer.addMoney(clean)
    JC.Notify(src, L('washed', clean))
end)

--- Stash ESX simple
RegisterNetEvent('job_creator:openStash', function(markerId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local marker = JC.Markers[markerId]
    if not xPlayer or not canUseMarker(xPlayer, marker) then return end
    if not JC.HasPermission(xPlayer, 'stash') and not JC.HasPermission(xPlayer, 'armory') then
        -- allow if min_grade ok (already checked) unless explicit deny — grades without perms still can if marker accessible
    end

    local stashId = ('jc_%s_%s'):format(marker.job_name, markerId)

    if Config.Inventory == 'ox' then
        exports.ox_inventory:RegisterStash(stashId, marker.label or 'Coffre', Config.DefaultStashSlots, Config.DefaultStashWeight, false)
        TriggerClientEvent('ox_inventory:openInventory', src, 'stash', stashId)
        return
    end

    local row = MySQL.single.await('SELECT items FROM jc_stashes WHERE stash_id = ?', { stashId })
    local items = {}
    if row and row.items then
        items = json.decode(row.items) or {}
    else
        MySQL.insert.await('INSERT IGNORE INTO jc_stashes (stash_id, job_name, items) VALUES (?, ?, ?)', {
            stashId, marker.job_name, '[]'
        })
    end

    TriggerClientEvent('job_creator:openStashUI', src, {
        stashId = stashId,
        label = marker.label,
        items = items,
        playerItems = xPlayer.getInventory and xPlayer.getInventory() or {},
    })
end)

RegisterNetEvent('job_creator:stashDeposit', function(stashId, itemName, count)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    count = math.floor(tonumber(count) or 0)
    if count <= 0 or type(itemName) ~= 'string' then return end

    local inv = xPlayer.getInventoryItem(itemName)
    if not inv or (inv.count or 0) < count then return end

    local row = MySQL.single.await('SELECT items, job_name FROM jc_stashes WHERE stash_id = ?', { stashId })
    if not row then return end
    if xPlayer.job.name ~= row.job_name then return end

    xPlayer.removeInventoryItem(itemName, count)
    local items = json.decode(row.items or '[]') or {}
    local found = false
    for _i, it in ipairs(items) do
        if it.name == itemName then
            it.count = (it.count or 0) + count
            found = true
            break
        end
    end
    if not found then
        items[#items + 1] = { name = itemName, label = inv.label or itemName, count = count }
    end
    MySQL.update.await('UPDATE jc_stashes SET items = ? WHERE stash_id = ?', { json.encode(items), stashId })
    TriggerClientEvent('job_creator:refreshStash', src, items)
end)

RegisterNetEvent('job_creator:stashWithdraw', function(stashId, itemName, count)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    count = math.floor(tonumber(count) or 0)
    if count <= 0 or type(itemName) ~= 'string' then return end

    local row = MySQL.single.await('SELECT items, job_name FROM jc_stashes WHERE stash_id = ?', { stashId })
    if not row then return end
    if xPlayer.job.name ~= row.job_name then return end

    local items = json.decode(row.items or '[]') or {}
    local idx = nil
    for i, it in ipairs(items) do
        if it.name == itemName then
            if (it.count or 0) < count then return end
            it.count = it.count - count
            if it.count <= 0 then idx = i end
            break
        end
    end
    if idx then table.remove(items, idx) end

    xPlayer.addInventoryItem(itemName, count)
    MySQL.update.await('UPDATE jc_stashes SET items = ? WHERE stash_id = ?', { json.encode(items), stashId })
    TriggerClientEvent('job_creator:refreshStash', src, items)
end)

AddEventHandler('playerDropped', function()
    busy[source] = nil
end)
