FL = FL or {}
FL.Stations = {}
FL.Companies = {}
FL.Ready = false

local ESX = exports['es_extended']:getSharedObject()
FL.ESX = ESX

local busy = {}

function FL.Notify(src, desc, nType)
    TriggerClientEvent('ox_lib:notify', src, {
        title = _('notify_title'),
        description = desc,
        type = nType or 'inform',
        position = 'top-right',
    })
end

function FL.GetPlayer(src)
    return ESX.GetPlayerFromId(src)
end

function FL.IsJob(xPlayer)
    return xPlayer and xPlayer.job and xPlayer.job.name == Config.JobName
end

function FL.IsAdmin(xPlayer)
    if not xPlayer then return false end
    local group = xPlayer.getGroup and xPlayer.getGroup() or 'user'
    return Config.AdminGroups[group] == true
end

function FL.Can(xPlayer, perm)
    if not FL.IsJob(xPlayer) then return false end
    local perms = FL.GetGradePermissions(xPlayer.job.grade or 0)
    return FL.HasPermission(perms, perm)
end

function FL.SetBusy(src, state)
    busy[src] = state and true or nil
end

function FL.IsBusy(src)
    return busy[src] == true
end

function FL.Log(msg)
    print(('[fuel_logistics] %s'):format(msg))
end

AddEventHandler('playerDropped', function()
    busy[source] = nil
end)

-- Sync job ESX
local function ensureJob()
    MySQL.query.await('INSERT INTO jobs (name, label) VALUES (?, ?) ON DUPLICATE KEY UPDATE label = VALUES(label)', {
        Config.JobName, Config.JobLabel
    })
    MySQL.query.await('DELETE FROM job_grades WHERE job_name = ?', { Config.JobName })
    for _, g in ipairs(Config.Grades) do
        MySQL.insert.await(
            'INSERT INTO job_grades (job_name, grade, name, label, salary, skin_male, skin_female) VALUES (?, ?, ?, ?, ?, ?, ?)',
            { Config.JobName, g.grade, g.name, g.label, g.salary, '{}', '{}' }
        )
    end
    if ESX.RefreshJobs then ESX.RefreshJobs() end
end

CreateThread(function()
    while GetResourceState('oxmysql') ~= 'started' do Wait(100) end
    Wait(500)
    FL.InitDatabase()
    ensureJob()
    FL.EnsureSociety()
    FL.LoadStations()
    FL.LoadCompanies()
    FL.Ready = true
    TriggerClientEvent('fuel_logistics:sync', -1, FL.GetClientPayload())
    FL.Log('ressource prête')
end)

function FL.GetClientPayload()
    local stations = {}
    for id, s in pairs(FL.Stations) do
        stations[tostring(id)] = {
            id = s.id,
            name = s.name,
            coords = { x = s.coords.x, y = s.coords.y, z = s.coords.z },
            capacity = s.capacity,
            level = s.level,
            buy_price = s.buy_price,
            owner_job = s.owner_job,
        }
    end
    local companies = {}
    for id, c in pairs(FL.Companies) do
        companies[tostring(id)] = {
            id = c.id,
            job_name = c.job_name,
            label = c.label,
            coords = { x = c.coords.x, y = c.coords.y, z = c.coords.z },
            capacity = c.capacity,
            level = c.level,
            buy_price = c.buy_price,
        }
    end
    return { stations = stations, companies = companies, job = Config.JobName }
end

RegisterNetEvent('fuel_logistics:requestSync', function()
    local src = source
    if not FL.Ready then return end
    TriggerClientEvent('fuel_logistics:sync', src, FL.GetClientPayload())
end)

AddEventHandler('esx:playerLoaded', function(playerId)
    if FL.Ready then
        TriggerClientEvent('fuel_logistics:sync', playerId, FL.GetClientPayload())
    end
end)

function FL.BroadcastStations()
    TriggerClientEvent('fuel_logistics:sync', -1, FL.GetClientPayload())
end

CreateThread(function()
    while GetResourceState('ox_inventory') ~= 'started' do Wait(200) end
    exports.ox_inventory:RegisterStash(
        Config.Stash.id,
        Config.Stash.label,
        Config.Stash.slots,
        Config.Stash.weight,
        false
    )
end)
