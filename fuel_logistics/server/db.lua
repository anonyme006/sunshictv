function FL.InitDatabase()
    local sql = LoadResourceFile(GetCurrentResourceName(), 'sql/install.sql')
    if sql then
        for statement in sql:gmatch('([^;]+);') do
            local trimmed = statement:gsub('^%s+', ''):gsub('%s+$', '')
            if trimmed ~= '' then
                MySQL.query.await(trimmed)
            end
        end
    end

    MySQL.insert.await('INSERT IGNORE INTO fl_storage (name, barrels) VALUES (?, 0)', { 'warehouse' })

    local count = MySQL.scalar.await('SELECT COUNT(*) FROM fl_stations') or 0
    if count == 0 and Config.DefaultStations then
        for _, s in ipairs(Config.DefaultStations) do
            MySQL.insert.await([[
                INSERT INTO fl_stations (name, coords, capacity, level, buy_price, consumption, owner_job)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            ]], {
                s.name,
                json.encode({ x = s.coords.x, y = s.coords.y, z = s.coords.z }),
                s.capacity, s.level, s.buyPrice, s.consumption, s.owner_job
            })
        end
        FL.Log('stations par défaut insérées')
    end
end

function FL.DecodeCoords(raw)
    if type(raw) == 'table' then
        return vec3(raw.x + 0.0, raw.y + 0.0, raw.z + 0.0)
    end
    local ok, data = pcall(json.decode, raw or '')
    if ok and data then
        return vec3(data.x + 0.0, data.y + 0.0, data.z + 0.0)
    end
    return vec3(0.0, 0.0, 0.0)
end

function FL.AddHistory(data)
    MySQL.insert.await([[
        INSERT INTO fl_history (type, identifier, player_name, target_type, target_id, target_name, liters, amount, meta)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        data.type,
        data.identifier,
        data.player_name,
        data.target_type,
        data.target_id,
        data.target_name,
        data.liters or 0,
        data.amount or 0,
        data.meta and json.encode(data.meta) or nil,
    })
end

function FL.AddTransaction(kind, amount, balanceAfter, note, identifier)
    MySQL.insert.await(
        'INSERT INTO fl_transactions (kind, amount, balance_after, note, identifier) VALUES (?, ?, ?, ?, ?)',
        { kind, amount, balanceAfter, note, identifier }
    )
end
