function FL.LoadStations()
    FL.Stations = {}
    local rows = MySQL.query.await('SELECT * FROM fl_stations WHERE enabled = 1') or {}
    for _i, r in ipairs(rows) do
        FL.Stations[r.id] = {
            id = r.id,
            name = r.name,
            coords = FL.DecodeCoords(r.coords),
            capacity = r.capacity,
            level = tonumber(r.level) or 0,
            buy_price = r.buy_price,
            consumption = tonumber(r.consumption) or 0,
            owner_job = r.owner_job,
        }
    end
end

function FL.SaveStationLevel(id, level)
    MySQL.update.await('UPDATE fl_stations SET level = ? WHERE id = ?', { level, id })
    if FL.Stations[id] then FL.Stations[id].level = level end
end

-- Consommation automatique
CreateThread(function()
    while true do
        Wait(Config.ConsumptionTick or 60000)
        if not FL.Ready then goto continue end
        local changed = false
        for id, s in pairs(FL.Stations) do
            if s.consumption and s.consumption > 0 and s.level > 0 then
                local nextLevel = math.max(0, s.level - s.consumption)
                if nextLevel ~= s.level then
                    FL.SaveStationLevel(id, nextLevel)
                    changed = true
                end
            end
        end
        if changed then
            -- soft sync levels only
            TriggerClientEvent('fuel_logistics:updateLevels', -1, FL.GetLevelsPayload())
        end
        ::continue::
    end
end)

function FL.GetLevelsPayload()
    local stations, companies = {}, {}
    for id, s in pairs(FL.Stations) do
        stations[tostring(id)] = s.level
    end
    for id, c in pairs(FL.Companies) do
        companies[tostring(id)] = c.level
    end
    return { stations = stations, companies = companies }
end

lib.callback.register('fuel_logistics:getStations', function(source)
    local xPlayer = FL.GetPlayer(source)
    if not FL.IsJob(xPlayer) and not FL.IsAdmin(xPlayer) then
        return {}
    end

    -- Toujours depuis la mémoire à jour (inclut stations créées à chaud)
    local list = {}
    for _i, s in pairs(FL.Stations) do
        list[#list + 1] = {
            id = s.id,
            name = s.name,
            coords = { x = s.coords.x, y = s.coords.y, z = s.coords.z },
            capacity = s.capacity,
            level = s.level,
            buy_price = s.buy_price,
            percent = s.capacity > 0 and FL.Round((s.level / s.capacity) * 100, 1) or 0,
        }
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end)

--- Broadcast dédié niveaux (pour clients qui ont le menu live)
function FL.PushLevels()
    TriggerClientEvent('fuel_logistics:updateLevels', -1, FL.GetLevelsPayload())
end
