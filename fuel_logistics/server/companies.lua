function FL.LoadCompanies()
    FL.Companies = {}
    local rows = MySQL.query.await('SELECT * FROM fl_companies WHERE enabled = 1') or {}
    for _i, r in ipairs(rows) do
        FL.Companies[r.id] = {
            id = r.id,
            job_name = r.job_name,
            label = r.label,
            coords = FL.DecodeCoords(r.coords),
            capacity = r.capacity,
            level = tonumber(r.level) or 0,
            buy_price = r.buy_price,
        }
    end
end

function FL.SaveCompanyLevel(id, level)
    MySQL.update.await('UPDATE fl_companies SET level = ? WHERE id = ?', { level, id })
    if FL.Companies[id] then FL.Companies[id].level = level end
end

lib.callback.register('fuel_logistics:getCompanies', function(source)
    local list = {}
    for _i, c in pairs(FL.Companies) do
        list[#list + 1] = {
            id = c.id,
            job_name = c.job_name,
            label = c.label,
            coords = { x = c.coords.x, y = c.coords.y, z = c.coords.z },
            capacity = c.capacity,
            level = c.level,
            buy_price = c.buy_price,
            percent = c.capacity > 0 and FL.Round((c.level / c.capacity) * 100, 1) or 0,
        }
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end)

--- Achat / enregistrement cuve (admin FL ou admin serveur)
lib.callback.register('fuel_logistics:registerCompanyTank', function(source, data)
    local xPlayer = FL.GetPlayer(source)
    if not FL.IsAdmin(xPlayer) and not FL.Can(xPlayer, 'boss') then
        return { ok = false, error = 'permission' }
    end
    if type(data) ~= 'table' or not data.job_name or not data.coords then
        return { ok = false, error = 'invalid' }
    end

    local label = data.label or data.job_name
    local capacity = tonumber(data.capacity) or Config.CompanyTanks.defaultCapacity
    local buyPrice = tonumber(data.buy_price) or 10
    local coords = json.encode(data.coords)

    local exists = MySQL.single.await('SELECT id FROM fl_companies WHERE job_name = ?', { data.job_name })
    if exists then
        MySQL.update.await([[
            UPDATE fl_companies SET label=?, coords=?, capacity=?, buy_price=?, enabled=1 WHERE id=?
        ]], { label, coords, capacity, buyPrice, exists.id })
    else
        MySQL.insert.await([[
            INSERT INTO fl_companies (job_name, label, coords, capacity, level, buy_price)
            VALUES (?, ?, ?, ?, 0, ?)
        ]], { data.job_name, label, coords, capacity, buyPrice })
    end

    FL.LoadCompanies()
    FL.BroadcastStations()
    return { ok = true }
end)
