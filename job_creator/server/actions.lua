local ESX = exports['es_extended']:getSharedObject()

local handcuffed = {}

RegisterNetEvent('job_creator:bill', function(targetId, amount, reason)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    if not JC.HasPermission(xPlayer, 'billing') and not JC.HasPermission(xPlayer, 'boss') then return end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return end

    local target = ESX.GetPlayerFromId(tonumber(targetId))
    if not target then
        return JC.Notify(src, _('no_player_nearby'))
    end

    -- Facture ESX billing si dispo
    local ok = pcall(function()
        TriggerEvent('esx_billing:sendBill', target.source, Config.SocietyPrefix .. xPlayer.job.name, reason or xPlayer.job.label, amount)
    end)

    if not ok then
        if target.getMoney() >= amount then
            target.removeMoney(amount)
            TriggerEvent('job_creator:addSocietyMoney', xPlayer.job.name, amount)
        else
            return JC.Notify(src, _('no_money'))
        end
    end

    JC.Notify(src, _('bill_sent', amount))
    JC.Notify(target.source, _('bill_received', amount))
end)

RegisterNetEvent('job_creator:handcuff', function(targetId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    if not JC.HasPermission(xPlayer, 'actions') and not JC.HasPermission(xPlayer, 'boss') then return end

    local target = tonumber(targetId)
    if not target or not GetPlayerPed(target) then
        return JC.Notify(src, _('no_player_nearby'))
    end

    handcuffed[target] = not handcuffed[target]
    TriggerClientEvent('job_creator:setHandcuff', target, handcuffed[target])
    JC.Notify(src, handcuffed[target] and _('handcuffed') or _('unhandcuffed'))
end)

RegisterNetEvent('job_creator:escort', function(targetId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    if not JC.HasPermission(xPlayer, 'actions') and not JC.HasPermission(xPlayer, 'boss') then return end

    local target = tonumber(targetId)
    if not target then return end
    TriggerClientEvent('job_creator:escort', target, src)
end)

RegisterNetEvent('job_creator:putInVehicle', function(targetId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    if not JC.HasPermission(xPlayer, 'actions') and not JC.HasPermission(xPlayer, 'boss') then return end
    TriggerClientEvent('job_creator:putInVehicle', tonumber(targetId))
end)

RegisterNetEvent('job_creator:outVehicle', function(targetId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    if not JC.HasPermission(xPlayer, 'actions') and not JC.HasPermission(xPlayer, 'boss') then return end
    TriggerClientEvent('job_creator:outVehicle', tonumber(targetId))
end)

RegisterNetEvent('job_creator:search', function(targetId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    if not JC.HasPermission(xPlayer, 'actions') and not JC.HasPermission(xPlayer, 'boss') then return end

    local target = ESX.GetPlayerFromId(tonumber(targetId))
    if not target then return end

    local items = {}
    local inv = target.getInventory and target.getInventory() or {}
    for _, it in pairs(inv) do
        if type(it) == 'table' and (it.count or 0) > 0 then
            items[#items + 1] = { name = it.name, label = it.label or it.name, count = it.count }
        end
    end

    local weapons = {}
    local loadout = target.getLoadout and target.getLoadout() or {}
    for _, w in pairs(loadout) do
        weapons[#weapons + 1] = { name = w.name, label = w.label or w.name, ammo = w.ammo or 0 }
    end

    TriggerClientEvent('job_creator:searchResult', src, {
        name = target.getName and target.getName() or GetPlayerName(target.source),
        items = items,
        weapons = weapons,
        money = target.getMoney and target.getMoney() or 0,
        black = (target.getAccount and target.getAccount('black_money') and target.getAccount('black_money').money) or 0,
    })
end)

AddEventHandler('playerDropped', function()
    handcuffed[source] = nil
end)
