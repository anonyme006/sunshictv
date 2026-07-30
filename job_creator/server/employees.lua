local ESX = exports['es_extended']:getSharedObject()

RegisterNetEvent('job_creator:getEmployees', function(jobName)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or xPlayer.job.name ~= jobName then return end
    if not JC.HasPermission(xPlayer, 'boss') and not JC.HasPermission(xPlayer, 'hire') then return end

    local online = {}
    local xPlayers = ESX.GetExtendedPlayers and ESX.GetExtendedPlayers('job', jobName) or {}

    if type(xPlayers) == 'table' then
        for _, xp in pairs(xPlayers) do
            online[#online + 1] = {
                id = xp.source,
                identifier = xp.identifier,
                name = xp.getName and xp.getName() or GetPlayerName(xp.source),
                grade = xp.job.grade,
                grade_label = xp.job.grade_label,
                online = true,
            }
        end
    end

    -- Offline depuis users
    local offline = {}
    pcall(function()
        local rows = MySQL.query.await('SELECT identifier, firstname, lastname, job_grade FROM users WHERE job = ?', { jobName }) or {}
        local onlineIds = {}
        for _, e in ipairs(online) do onlineIds[e.identifier] = true end
        for _, r in ipairs(rows) do
            if not onlineIds[r.identifier] then
                offline[#offline + 1] = {
                    identifier = r.identifier,
                    name = ((r.firstname or '') .. ' ' .. (r.lastname or '')):gsub('^%s+', ''),
                    grade = r.job_grade or 0,
                    online = false,
                }
            end
        end
    end)

    local grades = (JC.Jobs[jobName] and JC.Jobs[jobName].grades) or {}
    TriggerClientEvent('job_creator:employeesData', src, {
        online = online,
        offline = offline,
        grades = grades,
    })
end)

RegisterNetEvent('job_creator:hire', function(targetId, jobName, grade)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or xPlayer.job.name ~= jobName then return end
    if not JC.HasPermission(xPlayer, 'hire') and not JC.HasPermission(xPlayer, 'boss') then return end

    local target = ESX.GetPlayerFromId(tonumber(targetId))
    if not target then
        return JC.Notify(src, _('no_player_nearby'))
    end

    grade = tonumber(grade) or 0
    target.setJob(jobName, grade)
    JC.Notify(src, _('employee_hired'))
    JC.Notify(target.source, ('Tu as été recruté : %s'):format((JC.Jobs[jobName] and JC.Jobs[jobName].label) or jobName))
end)

RegisterNetEvent('job_creator:fire', function(targetId, identifier)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local jobName = xPlayer.job.name
    if not JC.HasPermission(xPlayer, 'fire') and not JC.HasPermission(xPlayer, 'boss') then return end

    if targetId then
        local target = ESX.GetPlayerFromId(tonumber(targetId))
        if target and target.job.name == jobName then
            if target.job.grade >= xPlayer.job.grade and target.source ~= src then
                return JC.Notify(src, _('no_permission'))
            end
            target.setJob('unemployed', 0)
            JC.Notify(src, _('employee_fired'))
            JC.Notify(target.source, 'Tu as été licencié.')
            return
        end
    end

    if identifier and type(identifier) == 'string' then
        MySQL.update.await('UPDATE users SET job = ?, job_grade = 0 WHERE identifier = ? AND job = ?', {
            'unemployed', identifier, jobName
        })
        JC.Notify(src, _('employee_fired'))
    end
end)

RegisterNetEvent('job_creator:setGrade', function(targetId, identifier, grade)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local jobName = xPlayer.job.name
    if not JC.HasPermission(xPlayer, 'promote') and not JC.HasPermission(xPlayer, 'boss') then return end

    grade = tonumber(grade) or 0
    if grade >= xPlayer.job.grade then
        return JC.Notify(src, _('no_permission'))
    end

    if targetId then
        local target = ESX.GetPlayerFromId(tonumber(targetId))
        if target and target.job.name == jobName then
            target.setJob(jobName, grade)
            JC.Notify(src, _('employee_promoted'))
            return
        end
    end

    if identifier then
        MySQL.update.await('UPDATE users SET job_grade = ? WHERE identifier = ? AND job = ?', {
            grade, identifier, jobName
        })
        JC.Notify(src, _('employee_promoted'))
    end
end)

RegisterNetEvent('job_creator:getNearbyPlayers', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local nearby = {}

    for _, id in ipairs(ESX.GetPlayers()) do
        id = tonumber(id)
        if id ~= src then
            local tPed = GetPlayerPed(id)
            if tPed and tPed ~= 0 then
                local tCoords = GetEntityCoords(tPed)
                if #(coords - tCoords) < 3.0 then
                    local xp = ESX.GetPlayerFromId(id)
                    nearby[#nearby + 1] = {
                        id = id,
                        name = xp and xp.getName and xp.getName() or GetPlayerName(id),
                        job = xp and xp.job and xp.job.label or '?',
                    }
                end
            end
        end
    end

    TriggerClientEvent('job_creator:nearbyPlayers', src, nearby)
end)
