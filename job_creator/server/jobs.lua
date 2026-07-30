local ESX = exports['es_extended']:getSharedObject()

local function syncEsxJob(job)
    pcall(function()
        MySQL.query.await('INSERT INTO jobs (name, label) VALUES (?, ?) ON DUPLICATE KEY UPDATE label = VALUES(label)', {
            job.name, job.label
        })
    end)

    pcall(function()
        MySQL.query.await('UPDATE jobs SET whitelisted = ? WHERE name = ?', {
            job.whitelisted and 1 or 0, job.name
        })
    end)

    MySQL.query.await('DELETE FROM job_grades WHERE job_name = ?', { job.name })

    for _, g in ipairs(job.grades or {}) do
        MySQL.insert.await('INSERT INTO job_grades (job_name, grade, name, label, salary, skin_male, skin_female) VALUES (?, ?, ?, ?, ?, ?, ?)', {
            job.name, g.grade, g.name, g.label, g.salary or 0, '{}', '{}'
        })
    end

    if ESX.RefreshJobs then
        ESX.RefreshJobs()
    end
end

local function ensureSociety(jobName)
    MySQL.insert.await('INSERT IGNORE INTO jc_society (job_name, money) VALUES (?, 0)', { jobName })

    if Config.UseAddonAccount then
        local account = Config.SocietyPrefix .. jobName
        local exists = MySQL.single.await('SELECT 1 AS ok FROM addon_account WHERE name = ?', { account })
        if not exists then
            pcall(function()
                MySQL.insert.await('INSERT INTO addon_account (name, label, shared) VALUES (?, ?, 1)', {
                    account, 'Société ' .. jobName
                })
                MySQL.insert.await('INSERT INTO addon_account_data (account_name, money, owner) VALUES (?, 0, NULL)', {
                    account
                })
            end)
        end
    end
end

local function deleteSociety(jobName)
    MySQL.query.await('DELETE FROM jc_society WHERE job_name = ?', { jobName })
end

--- Ouvre le panneau admin
RegisterNetEvent('job_creator:openAdmin', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not JC.IsAdmin(xPlayer) then
        return JC.Notify(src, _('no_permission'))
    end
    TriggerClientEvent('job_creator:openAdminUI', src, JC.GetAdminPayload())
end)

ESX.RegisterCommand(Config.OpenCommand, 'user', function(xPlayer)
    if not JC.IsAdmin(xPlayer) then
        return JC.Notify(xPlayer.source, _('no_permission'))
    end
    TriggerClientEvent('job_creator:openAdminUI', xPlayer.source, JC.GetAdminPayload())
end, false, { help = 'Ouvrir le Job Creator' })

--- Créer / mettre à jour un job
RegisterNetEvent('job_creator:saveJob', function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not JC.IsAdmin(xPlayer) then return end
    if type(data) ~= 'table' or not data.name or not data.label then
        return JC.Notify(src, _('invalid_data'))
    end

    local name = data.name:lower():gsub('%s+', '_'):gsub('[^%w_]', '')
    if name == '' then return JC.Notify(src, _('invalid_data')) end

    local exists = MySQL.single.await('SELECT id FROM jc_jobs WHERE name = ?', { name })
    local actions = json.encode(data.actions or {})
    local blipCoords = data.blip and data.blip.coords and json.encode(data.blip.coords) or nil

    if exists then
        MySQL.update.await([[
            UPDATE jc_jobs SET label=?, type=?, whitelisted=?, enabled=?, actions=?,
            blip_sprite=?, blip_color=?, blip_scale=?, blip_coords=? WHERE name=?
        ]], {
            data.label,
            data.type or 'civil',
            data.whitelisted and 1 or 0,
            data.enabled ~= false and 1 or 0,
            actions,
            (data.blip and data.blip.sprite) or 0,
            (data.blip and data.blip.color) or 0,
            (data.blip and data.blip.scale) or 0.8,
            blipCoords,
            name,
        })
        JC.Notify(src, _('job_updated', data.label))
        JC.Log('Job mis à jour', ('**%s** a modifié `%s`'):format(xPlayer.getName(), name))
    else
        MySQL.insert.await([[
            INSERT INTO jc_jobs (name, label, type, whitelisted, enabled, actions, blip_sprite, blip_color, blip_scale, blip_coords)
            VALUES (?, ?, ?, ?, 1, ?, ?, ?, ?, ?)
        ]], {
            name, data.label, data.type or 'civil',
            data.whitelisted ~= false and 1 or 0,
            actions,
            (data.blip and data.blip.sprite) or 0,
            (data.blip and data.blip.color) or 0,
            (data.blip and data.blip.scale) or 0.8,
            blipCoords,
        })

        -- Grades par défaut
        if not data.grades or #data.grades == 0 then
            data.grades = {
                { grade = 0, name = 'employee', label = 'Employé', salary = 200, permissions = { stash = true, garage = true, cloakroom = true } },
                { grade = 1, name = 'boss', label = 'Patron', salary = 500, permissions = { ['*'] = true } },
            }
        end

        for _, g in ipairs(data.grades) do
            MySQL.insert.await('INSERT INTO jc_grades (job_name, grade, name, label, salary, permissions) VALUES (?, ?, ?, ?, ?, ?)', {
                name, g.grade, g.name, g.label, g.salary or 0, json.encode(g.permissions or {})
            })
        end

        ensureSociety(name)
        JC.Notify(src, _('job_created', data.label))
        JC.Log('Job créé', ('**%s** a créé `%s`'):format(xPlayer.getName(), name))
    end

    -- Sync grades if provided on update
    if exists and data.grades then
        MySQL.query.await('DELETE FROM jc_grades WHERE job_name = ?', { name })
        for _, g in ipairs(data.grades) do
            MySQL.insert.await('INSERT INTO jc_grades (job_name, grade, name, label, salary, permissions) VALUES (?, ?, ?, ?, ?, ?)', {
                name, g.grade, g.name, g.label, g.salary or 0, json.encode(g.permissions or {})
            })
        end
    end

    local jobRow = {
        name = name,
        label = data.label,
        whitelisted = data.whitelisted ~= false,
        grades = data.grades or (JC.Jobs[name] and JC.Jobs[name].grades) or {},
    }
    syncEsxJob(jobRow)
    ensureSociety(name)
    JC.LoadAll()
end)

RegisterNetEvent('job_creator:deleteJob', function(jobName)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not JC.IsAdmin(xPlayer) then return end
    if type(jobName) ~= 'string' then return end

    MySQL.query.await('DELETE FROM jc_jobs WHERE name = ?', { jobName })
    MySQL.query.await('DELETE FROM jc_grades WHERE job_name = ?', { jobName })
    MySQL.query.await('DELETE FROM jc_markers WHERE job_name = ?', { jobName })
    MySQL.query.await('DELETE FROM jc_vehicles WHERE job_name = ?', { jobName })
    MySQL.query.await('DELETE FROM jc_outfits WHERE job_name = ?', { jobName })
    MySQL.query.await('DELETE FROM jc_shop_items WHERE job_name = ?', { jobName })
    MySQL.query.await('DELETE FROM jc_crafts WHERE job_name = ?', { jobName })
    deleteSociety(jobName)

    pcall(function()
        MySQL.query.await('DELETE FROM job_grades WHERE job_name = ?', { jobName })
        MySQL.query.await('DELETE FROM jobs WHERE name = ?', { jobName })
        if ESX.RefreshJobs then ESX.RefreshJobs() end
    end)

    JC.Notify(src, _('job_deleted', jobName))
    JC.Log('Job supprimé', ('**%s** a supprimé `%s`'):format(xPlayer.getName(), jobName))
    JC.LoadAll()
end)

RegisterNetEvent('job_creator:saveGrade', function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not JC.IsAdmin(xPlayer) then return end
    if type(data) ~= 'table' or not data.job_name then return end

    if data.id then
        MySQL.update.await('UPDATE jc_grades SET grade=?, name=?, label=?, salary=?, permissions=? WHERE id=?', {
            data.grade, data.name, data.label, data.salary or 0, json.encode(data.permissions or {}), data.id
        })
    else
        MySQL.insert.await('INSERT INTO jc_grades (job_name, grade, name, label, salary, permissions) VALUES (?, ?, ?, ?, ?, ?)', {
            data.job_name, data.grade, data.name, data.label, data.salary or 0, json.encode(data.permissions or {})
        })
    end

    local job = JC.Jobs[data.job_name]
    if job then
        -- reload grades from DB after LoadAll
    end

    JC.LoadAll()
    if JC.Jobs[data.job_name] then
        syncEsxJob(JC.Jobs[data.job_name])
    end
    JC.Notify(src, _('grade_saved'))
end)

RegisterNetEvent('job_creator:deleteGrade', function(id)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not JC.IsAdmin(xPlayer) then return end
    local row = MySQL.single.await('SELECT job_name FROM jc_grades WHERE id = ?', { id })
    MySQL.query.await('DELETE FROM jc_grades WHERE id = ?', { id })
    JC.LoadAll()
    if row and JC.Jobs[row.job_name] then
        syncEsxJob(JC.Jobs[row.job_name])
    end
end)

RegisterNetEvent('job_creator:setPlayerJob', function(targetId, jobName, grade)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not JC.IsAdmin(xPlayer) then return end
    local target = ESX.GetPlayerFromId(tonumber(targetId))
    if not target then return end
    if not JC.Jobs[jobName] then return end
    target.setJob(jobName, tonumber(grade) or 0)
    JC.Notify(src, _('employee_hired'))
end)

--- Reload
RegisterNetEvent('job_creator:reload', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not JC.IsAdmin(xPlayer) then return end
    JC.LoadAll()
    TriggerClientEvent('job_creator:openAdminUI', src, JC.GetAdminPayload())
end)
