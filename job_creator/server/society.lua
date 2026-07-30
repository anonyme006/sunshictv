local ESX = exports['es_extended']:getSharedObject()

local function getSocietyMoney(jobName)
    if Config.UseAddonAccount then
        local account = Config.SocietyPrefix .. jobName
        local ok, result = pcall(function()
            return MySQL.single.await('SELECT money FROM addon_account_data WHERE account_name = ? AND (owner IS NULL OR owner = "")', { account })
        end)
        if ok and result then
            return result.money or 0
        end
    end
    local row = MySQL.single.await('SELECT money FROM jc_society WHERE job_name = ?', { jobName })
    return row and row.money or 0
end

local function setSocietyMoney(jobName, money)
    money = math.max(0, math.floor(money))
    MySQL.insert.await('INSERT INTO jc_society (job_name, money) VALUES (?, ?) ON DUPLICATE KEY UPDATE money = VALUES(money)', {
        jobName, money
    })

    if Config.UseAddonAccount then
        local account = Config.SocietyPrefix .. jobName
        pcall(function()
            MySQL.update.await('UPDATE addon_account_data SET money = ? WHERE account_name = ? AND (owner IS NULL OR owner = "")', {
                money, account
            })
        end)
    end
end

AddEventHandler('job_creator:addSocietyMoney', function(jobName, amount)
    local current = getSocietyMoney(jobName)
    setSocietyMoney(jobName, current + (tonumber(amount) or 0))
end)

RegisterNetEvent('job_creator:getSociety', function(jobName)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or xPlayer.job.name ~= jobName then return end
    if not JC.HasPermission(xPlayer, 'boss') and not JC.HasPermission(xPlayer, 'withdraw') and not JC.HasPermission(xPlayer, 'deposit') then
        return
    end
    TriggerClientEvent('job_creator:societyData', src, {
        job = jobName,
        money = getSocietyMoney(jobName),
    })
end)

RegisterNetEvent('job_creator:societyDeposit', function(jobName, amount)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return end
    if not xPlayer or xPlayer.job.name ~= jobName then return end
    if not JC.HasPermission(xPlayer, 'deposit') and not JC.HasPermission(xPlayer, 'boss') then return end

    if xPlayer.getMoney() < amount then
        return JC.Notify(src, L('no_money'))
    end

    xPlayer.removeMoney(amount)
    setSocietyMoney(jobName, getSocietyMoney(jobName) + amount)
    JC.Notify(src, L('society_deposit', amount))
    TriggerClientEvent('job_creator:societyData', src, { job = jobName, money = getSocietyMoney(jobName) })
end)

RegisterNetEvent('job_creator:societyWithdraw', function(jobName, amount)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return end
    if not xPlayer or xPlayer.job.name ~= jobName then return end
    if not JC.HasPermission(xPlayer, 'withdraw') and not JC.HasPermission(xPlayer, 'boss') then return end

    local current = getSocietyMoney(jobName)
    if current < amount then
        return JC.Notify(src, L('no_money'))
    end

    setSocietyMoney(jobName, current - amount)
    xPlayer.addMoney(amount)
    JC.Notify(src, L('society_withdraw', amount))
    TriggerClientEvent('job_creator:societyData', src, { job = jobName, money = getSocietyMoney(jobName) })
end)

--- Duty
RegisterNetEvent('job_creator:toggleDuty', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or not xPlayer.job then return end

    local row = MySQL.single.await('SELECT on_duty FROM jc_duty WHERE identifier = ?', { xPlayer.identifier })
    local onDuty = true
    if row then
        onDuty = row.on_duty ~= 1
        MySQL.update.await('UPDATE jc_duty SET on_duty = ?, job_name = ? WHERE identifier = ?', {
            onDuty and 1 or 0, xPlayer.job.name, xPlayer.identifier
        })
    else
        MySQL.insert.await('INSERT INTO jc_duty (identifier, job_name, on_duty) VALUES (?, ?, 1)', {
            xPlayer.identifier, xPlayer.job.name
        })
        onDuty = true
    end

    Player(src).state:set('jc_duty', onDuty, true)
    JC.Notify(src, onDuty and L('on_duty') or L('off_duty'))
    TriggerClientEvent('job_creator:dutyChanged', src, onDuty)
end)

lib_duty = function(src)
    local state = Player(src).state.jc_duty
    if state == nil then return true end
    return state == true
end
