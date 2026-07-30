lib.callback.register('fuel_logistics:bossStats', function(source)
    local xPlayer = FL.GetPlayer(source)
    if not FL.Can(xPlayer, 'boss') then return nil end

    local money = FL.GetSocietyMoney()

    local deliveries = MySQL.single.await([[
        SELECT COUNT(*) AS cnt, COALESCE(SUM(liters),0) AS liters, COALESCE(SUM(amount),0) AS amount
        FROM fl_history WHERE type = 'delivery'
    ]]) or { cnt = 0, liters = 0, amount = 0 }

    local exportsRow = MySQL.single.await([[
        SELECT COUNT(*) AS cnt, COALESCE(SUM(barrels),0) AS barrels, COALESCE(SUM(amount),0) AS amount
        FROM fl_exports
    ]]) or { cnt = 0, barrels = 0, amount = 0 }

    local spent = MySQL.single.await([[
        SELECT COALESCE(SUM(ABS(amount)),0) AS amount FROM fl_transactions WHERE amount < 0
    ]]) or { amount = 0 }

    local earned = MySQL.single.await([[
        SELECT COALESCE(SUM(amount),0) AS amount FROM fl_transactions WHERE amount > 0
    ]]) or { amount = 0 }

    local recent = MySQL.query.await([[
        SELECT type, player_name, target_name, liters, amount, created_at
        FROM fl_history ORDER BY id DESC LIMIT 15
    ]]) or {}

    local employees = {}
    local xPlayers = FL.ESX.GetExtendedPlayers and FL.ESX.GetExtendedPlayers('job', Config.JobName) or {}
    for _, xp in pairs(xPlayers) do
        employees[#employees + 1] = {
            id = xp.source,
            name = xp.getName and xp.getName() or GetPlayerName(xp.source),
            grade = xp.job.grade,
            grade_label = xp.job.grade_label,
        }
    end

    local stations = {}
    for _, s in pairs(FL.Stations) do
        stations[#stations + 1] = {
            id = s.id, name = s.name, level = s.level, capacity = s.capacity,
            percent = s.capacity > 0 and FL.Round(s.level / s.capacity * 100, 1) or 0,
        }
    end

    local companies = {}
    for _, c in pairs(FL.Companies) do
        companies[#companies + 1] = {
            id = c.id, label = c.label, job_name = c.job_name,
            level = c.level, capacity = c.capacity,
            percent = c.capacity > 0 and FL.Round(c.level / c.capacity * 100, 1) or 0,
        }
    end

    -- Graphique simple : livraisons 7 derniers jours
    local chart = MySQL.query.await([[
        SELECT DATE(created_at) AS day, COALESCE(SUM(liters),0) AS liters, COALESCE(SUM(amount),0) AS amount
        FROM fl_history
        WHERE type = 'delivery' AND created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
        GROUP BY DATE(created_at)
        ORDER BY day ASC
    ]]) or {}

    return {
        money = money,
        deliveries = deliveries,
        exports = exportsRow,
        spent = spent.amount or 0,
        earned = earned.amount or 0,
        recent = recent,
        employees = employees,
        stations = stations,
        companies = companies,
        grades = Config.Grades,
        chart = chart,
    }
end)

lib.callback.register('fuel_logistics:setEmployeeGrade', function(source, targetId, grade)
    local xPlayer = FL.GetPlayer(source)
    if not FL.Can(xPlayer, 'boss') then return { ok = false } end
    local target = FL.GetPlayer(tonumber(targetId))
    if not target or target.job.name ~= Config.JobName then return { ok = false } end
    grade = tonumber(grade) or 0
    if grade >= (xPlayer.job.grade or 0) then return { ok = false, error = 'grade' } end
    target.setJob(Config.JobName, grade)
    return { ok = true }
end)

lib.callback.register('fuel_logistics:fireEmployee', function(source, targetId)
    local xPlayer = FL.GetPlayer(source)
    if not FL.Can(xPlayer, 'boss') then return { ok = false } end
    local target = FL.GetPlayer(tonumber(targetId))
    if not target or target.job.name ~= Config.JobName then return { ok = false } end
    if (target.job.grade or 0) >= (xPlayer.job.grade or 0) then return { ok = false } end
    target.setJob('unemployed', 0)
    return { ok = true }
end)

lib.callback.register('fuel_logistics:hireNearby', function(source, targetId, grade)
    local xPlayer = FL.GetPlayer(source)
    if not FL.Can(xPlayer, 'boss') then return { ok = false } end
    local target = FL.GetPlayer(tonumber(targetId))
    if not target then return { ok = false } end
    grade = tonumber(grade) or 0
    target.setJob(Config.JobName, grade)
    FL.Notify(target.source, 'Tu as été recruté chez ' .. Config.JobLabel, 'success')
    return { ok = true }
end)
