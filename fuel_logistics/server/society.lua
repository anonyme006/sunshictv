local societyMoney = 0

function FL.EnsureSociety()
    MySQL.insert.await('INSERT IGNORE INTO fl_storage (name, barrels) VALUES (?, 0)', { 'warehouse' })

    pcall(function()
        local account = Config.SocietyAccount
        local exists = MySQL.single.await('SELECT 1 AS ok FROM addon_account WHERE name = ?', { account })
        if not exists then
            MySQL.insert.await('INSERT INTO addon_account (name, label, shared) VALUES (?, ?, 1)', {
                account, Config.JobLabel
            })
            MySQL.insert.await('INSERT INTO addon_account_data (account_name, money, owner) VALUES (?, 0, NULL)', {
                account
            })
        end
        local row = MySQL.single.await(
            'SELECT money FROM addon_account_data WHERE account_name = ? AND (owner IS NULL OR owner = "")',
            { account }
        )
        societyMoney = row and row.money or 0
    end)
end

function FL.GetSocietyMoney()
    local ok, row = pcall(function()
        return MySQL.single.await(
            'SELECT money FROM addon_account_data WHERE account_name = ? AND (owner IS NULL OR owner = "")',
            { Config.SocietyAccount }
        )
    end)
    if ok and row then
        societyMoney = row.money or 0
        return societyMoney
    end
    return societyMoney
end

function FL.AddSocietyMoney(amount, note, identifier)
    amount = math.floor(tonumber(amount) or 0)
    if amount == 0 then return FL.GetSocietyMoney() end

    local current = FL.GetSocietyMoney()
    local nextBal = current + amount
    if nextBal < 0 then return false, current end

    pcall(function()
        MySQL.update.await(
            'UPDATE addon_account_data SET money = ? WHERE account_name = ? AND (owner IS NULL OR owner = "")',
            { nextBal, Config.SocietyAccount }
        )
    end)
    societyMoney = nextBal
    FL.AddTransaction(amount > 0 and 'credit' or 'debit', amount, nextBal, note, identifier)

    TriggerEvent('esx_addonaccount:getSharedAccount', Config.SocietyAccount, function(account)
        if account and account.addMoney and amount > 0 then
            -- keep esx cache in sync if available — already updated SQL
        end
    end)

    return true, nextBal
end

lib.callback.register('fuel_logistics:getSocietyMoney', function(source)
    local xPlayer = FL.GetPlayer(source)
    if not FL.IsJob(xPlayer) then return 0 end
    return FL.GetSocietyMoney()
end)

lib.callback.register('fuel_logistics:societyDeposit', function(source, amount)
    local xPlayer = FL.GetPlayer(source)
    if not FL.Can(xPlayer, 'boss') then return { ok = false } end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return { ok = false } end
    if xPlayer.getMoney() < amount then return { ok = false, error = 'money' } end
    xPlayer.removeMoney(amount)
    FL.AddSocietyMoney(amount, 'Dépôt patron', xPlayer.identifier)
    return { ok = true, money = FL.GetSocietyMoney() }
end)

lib.callback.register('fuel_logistics:societyWithdraw', function(source, amount)
    local xPlayer = FL.GetPlayer(source)
    if not FL.Can(xPlayer, 'boss') then return { ok = false } end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return { ok = false } end
    local ok = FL.AddSocietyMoney(-amount, 'Retrait patron', xPlayer.identifier)
    if not ok then return { ok = false, error = 'money' } end
    xPlayer.addMoney(amount)
    return { ok = true, money = FL.GetSocietyMoney() }
end)
