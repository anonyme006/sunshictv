local lastCall = {}
local function rateLimit(source, key, delay)
    lastCall[source] = lastCall[source] or {}
    local now = GetGameTimer()
    if lastCall[source][key] and now - lastCall[source][key] < delay then
        return false
    end
    lastCall[source][key] = now
    return true
end

local function getLicenses(source)
    return GetPlayerIdentifierByType(source, 'license2'), GetPlayerIdentifierByType(source, 'license')
end

local function maxSlots(source)
    local license2, license = getLicenses(source)
    local overrides = Config.Multichar.PlayersNumberOfCharacters or {}
    if license2 and overrides[license2] then
        return overrides[license2]
    end
    if license and overrides[license] then
        return overrides[license]
    end
    return Config.Multichar.DefaultNumberOfCharacters or 3
end

local function decodeJson(value)
    if type(value) == 'table' then return value end
    if type(value) ~= 'string' or value == '' then return {} end
    local ok, decoded = pcall(json.decode, value)
    if ok and type(decoded) == 'table' then return decoded end
    return {}
end

local function ownsCharacter(source, citizenid)
    if type(citizenid) ~= 'string' or citizenid == '' then return false end
    local license2, license = getLicenses(source)
    local row = MySQL.single.await(
        'SELECT citizenid FROM players WHERE citizenid = ? AND (license = ? OR license = ?) LIMIT 1',
        { citizenid, license2, license }
    )
    return row ~= nil
end

local function sanitizeCharacter(row)
    local charinfo = decodeJson(row.charinfo)
    local money = decodeJson(row.money)
    local job = decodeJson(row.job)
    return {
        citizenid = row.citizenid,
        cid = tonumber(row.cid) or tonumber(charinfo.cid) or 1,
        charinfo = {
            firstname = charinfo.firstname or '',
            lastname = charinfo.lastname or '',
            birthdate = charinfo.birthdate or '',
            nationality = charinfo.nationality or '',
            gender = tonumber(charinfo.gender) or 0,
            phone = charinfo.phone,
            account = charinfo.account,
        },
        money = {
            cash = tonumber(money.cash) or 0,
            bank = tonumber(money.bank) or 0,
        },
        job = {
            label = job.label or 'Sans emploi',
            grade = job.grade and (job.grade.name or job.grade.label) or '',
        },
    }
end

local function fetchCharacters(source)
    local license2, license = getLicenses(source)
    local rows = MySQL.query.await(
        'SELECT citizenid, cid, charinfo, money, job FROM players WHERE license = ? OR license = ? ORDER BY cid ASC',
        { license2, license }
    ) or {}

    local list = {}
    for i = 1, #rows do
        list[#list + 1] = sanitizeCharacter(rows[i])
    end
    return list, maxSlots(source)
end

lib.callback.register('qbx-charactercreator:server:getSlots', function(source)
    return maxSlots(source)
end)

lib.callback.register('qbx-charactercreator:server:getCharacters', function(source)
    local characters, slots = fetchCharacters(source)
    return {
        characters = characters,
        slots = slots,
        enableDelete = Config.Multichar.EnableDeleteButton == true,
        translations = Locales[Config.Locale] or Locales.fr,
    }
end)

lib.callback.register('qbx-charactercreator:server:previewPed', function(source, citizenid)
    if not ownsCharacter(source, citizenid) then return end

    local skin, model
    local ok, previewSkin, previewModel = pcall(function()
        local ped = MySQL.single.await('SELECT model, skin FROM playerskins WHERE citizenid = ? AND active = 1 LIMIT 1', { citizenid })
        if not ped then
            ped = MySQL.single.await('SELECT model, skin FROM playerskins WHERE citizenid = ? LIMIT 1', { citizenid })
        end
        if not ped then return end
        return ped.skin, ped.model
    end)

    if ok then
        skin, model = previewSkin, previewModel
    end

    local player = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ? LIMIT 1', { citizenid })
    local gender = 0
    if player then
        local charinfo = decodeJson(player.charinfo)
        gender = tonumber(charinfo.gender) or 0
    end

    return skin, model, gender
end)

lib.callback.register('qbx-charactercreator:server:loadCharacter', function(source, citizenid)
    if not Config.Multichar.Enabled then
        return { ok = false, error = 'notify.not_allowed' }
    end
    if not rateLimit(source, 'load', Config.RateLimit.loadMs or 1500) then
        return { ok = false, error = 'notify.rate_limited' }
    end
    if not ownsCharacter(source, citizenid) then
        return { ok = false, error = 'notify.not_your_character' }
    end

    local success = exports.qbx_core:Login(source, citizenid)
    if not success then
        return { ok = false, error = 'notify.save_error' }
    end

    if Config.Creator.IsolateBucket then
        exports.qbx_core:SetPlayerBucket(source, 0)
    else
        SetPlayerRoutingBucket(source, 0)
    end

    return { ok = true, citizenid = citizenid }
end)

lib.callback.register('qbx-charactercreator:server:deleteCharacter', function(source, citizenid)
    if not Config.Multichar.Enabled then
        return { ok = false, error = 'notify.not_allowed' }
    end
    if not Config.Multichar.EnableDeleteButton then
        return { ok = false, error = 'notify.delete_disabled' }
    end
    if not rateLimit(source, 'delete', Config.RateLimit.deleteMs or 2500) then
        return { ok = false, error = 'notify.rate_limited' }
    end
    if not ownsCharacter(source, citizenid) then
        return { ok = false, error = 'notify.not_your_character' }
    end

    local deleted = pcall(function()
        exports.qbx_core:DeleteCharacter(source, citizenid)
    end)
    if not deleted then
        local license2, license = getLicenses(source)
        MySQL.query.await(
            'DELETE FROM players WHERE citizenid = ? AND (license = ? OR license = ?)',
            { citizenid, license2, license }
        )
    end

    MySQL.query.await('DELETE FROM character_creator WHERE citizenid = ?', { citizenid })
    MySQL.query.await('DELETE FROM playerskins WHERE citizenid = ?', { citizenid })

    return { ok = true }
end)

local function giveStarterItems(source)
    if not Config.Multichar.GiveStarterItems then return end
    if GetResourceState('ox_inventory') ~= 'started' then return end

    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end
    local info = player.PlayerData.charinfo or {}
    local citizenid = player.PlayerData.citizenid

    pcall(function()
        exports.ox_inventory:AddItem(source, 'id_card', 1, {
            type = ('%s %s'):format(info.firstname or '', info.lastname or ''),
            description = ('CID: %s\nNaissance: %s\nSexe: %s\nNationalité: %s'):format(
                citizenid or '',
                info.birthdate or '',
                tonumber(info.gender) == 0 and 'Homme' or 'Femme',
                info.nationality or ''
            ),
        })
    end)
    pcall(function()
        exports.ox_inventory:AddItem(source, 'driver_license', 1, {
            type = 'Permis B',
            description = ('Prénom: %s\nNom: %s\nNaissance: %s'):format(
                info.firstname or '',
                info.lastname or '',
                info.birthdate or ''
            ),
        })
    end)
end

exports('GiveStarterItems', giveStarterItems)
exports('ResourceStarted', resourceStarted)

AddEventHandler('playerJoining', function()
    if not Config.Multichar.Enabled then return end
    local src = source
    SetPlayerRoutingBucket(src, src)
end)
