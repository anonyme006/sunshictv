local busy = {}
local lastCall = {}
local memoryDrafts = {}

local function nowMs()
    return GetGameTimer()
end

local function notify(source, key, notifyType)
    exports.qbx_core:Notify(source, SharedUtils.Locale(key), notifyType or 'inform')
end

local function getLicense(source)
    return GetPlayerIdentifierByType(source, 'license2') or GetPlayerIdentifierByType(source, 'license')
end

local function getPlayer(source)
    return exports.qbx_core:GetPlayer(source)
end

local function hasAdminPermission(source)
    if source == 0 then return true end

    local ok, allowed = pcall(function()
        return exports.qbx_core:HasPermission(source, Config.Admin.qbxPermission)
    end)
    if ok and allowed == true then
        return true
    end

    return IsPlayerAceAllowed(source, Config.Admin.ace)
        or IsPlayerAceAllowed(source, 'god')
        or IsPlayerAceAllowed(source, Config.Admin.commandGroup)
end

local function rateLimit(source, key, delay)
    lastCall[source] = lastCall[source] or {}
    local stamp = lastCall[source][key] or 0
    local current = nowMs()
    if current - stamp < delay then
        return false
    end
    lastCall[source][key] = current
    return true
end

local function setBucket(source, isolated)
    if not Config.Creator.IsolateBucket then return end
    if isolated then
        exports.qbx_core:SetPlayerBucket(source, source + Config.Creator.BucketOffset)
    else
        exports.qbx_core:SetPlayerBucket(source, 0)
    end
end

local function updateQboxCharinfo(source, identity)
    local player = getPlayer(source)
    if not player then return false end

    exports.qbx_core:SetCharInfo(source, 'firstname', identity.firstname)
    exports.qbx_core:SetCharInfo(source, 'lastname', identity.lastname)
    exports.qbx_core:SetCharInfo(source, 'birthdate', identity.birthdate)
    exports.qbx_core:SetCharInfo(source, 'gender', identity.gender)
    exports.qbx_core:SetCharInfo(source, 'nationality', identity.nationality)
    exports.qbx_core:SetCharInfo(source, 'height', identity.height)
    return true
end

local function maybeCreateCharacter(source, identity, mode)
    local player = getPlayer(source)
    if player then
        return true, player.PlayerData.citizenid
    end

    if mode ~= 'register' then
        return false, 'notify.not_in_creator'
    end

    local success = exports.qbx_core:Login(source, nil, {
        charinfo = {
            firstname = identity.firstname,
            lastname = identity.lastname,
            birthdate = identity.birthdate,
            gender = identity.gender,
            nationality = identity.nationality,
            height = identity.height,
        },
    })

    if not success then
        return false, 'notify.save_error'
    end

    player = getPlayer(source)
    if not player then
        return false, 'notify.save_error'
    end
    return true, player.PlayerData.citizenid
end

lib.callback.register('qbx-charactercreator:server:canOpen', function(source, mode)
    if not rateLimit(source, 'open', Config.RateLimit.openMs) then
        return false
    end

    if mode == 'admin' then
        return hasAdminPermission(source)
    end

    if mode == 'register' then
        return true
    end

    return getPlayer(source) ~= nil or mode == 'create'
end)

lib.callback.register('qbx-charactercreator:server:getCharInfo', function(source)
    local player = getPlayer(source)
    if not player then
        return SharedUtils.DefaultIdentity()
    end

    local info = player.PlayerData.charinfo or {}
    return {
        firstname = info.firstname or '',
        lastname = info.lastname or '',
        birthdate = info.birthdate or '',
        gender = tonumber(info.gender) or 0,
        height = tonumber(info.height) or Config.Identity.defaultHeight,
        nationality = info.nationality or Config.Identity.defaultNationality,
    }
end)

lib.callback.register('qbx-charactercreator:server:getAppearance', function(source)
    local player = getPlayer(source)
    if not player then return nil end

    local row = Database.GetByCitizenId(player.PlayerData.citizenid)
    if not row or not row.appearance then return nil end

    local ok, appearance = pcall(json.decode, row.appearance)
    if not ok or type(appearance) ~= 'table' then return nil end
    return appearance
end)

lib.callback.register('qbx-charactercreator:server:hasAppearance', function(source)
    local player = getPlayer(source)
    if not player then return true end
    return Database.HasAppearance(player.PlayerData.citizenid)
end)

lib.callback.register('qbx-charactercreator:server:getDraft', function(source)
    if not Config.Draft.enabled then return nil end
    local license = getLicense(source)
    local memory = memoryDrafts[license]
    if memory and memory.expires > os.time() then
        return memory.payload
    end
    return Database.GetDraft(license)
end)

lib.callback.register('qbx-charactercreator:server:saveCharacter', function(source, payload)
    if not busy[source] then
        return { ok = false, error = 'notify.not_in_creator' }
    end

    if not rateLimit(source, 'save', Config.RateLimit.saveMs) then
        return { ok = false, error = 'notify.rate_limited' }
    end

    local ok, sanitized = Validation.Payload(payload)
    if not ok then
        return { ok = false, error = sanitized }
    end

    local created, citizenid = maybeCreateCharacter(source, sanitized.identity, payload.mode)
    if not created then
        return { ok = false, error = citizenid }
    end

    local player = getPlayer(source)
    if not player or player.PlayerData.citizenid ~= citizenid then
        return { ok = false, error = 'notify.save_error' }
    end

    updateQboxCharinfo(source, sanitized.identity)
    Database.UpsertCharacter(citizenid, sanitized.identity, sanitized.appearance)
    Database.SavePlayerSkin(citizenid, sanitized.appearance, sanitized.identity)
    Database.ClearDraft(getLicense(source))
    memoryDrafts[getLicense(source)] = nil
    setBucket(source, false)
    busy[source] = nil

    TriggerClientEvent('qbx-charactercreator:client:applyAppearance', source, sanitized.appearance)
    return { ok = true, citizenid = citizenid }
end)

RegisterNetEvent('qbx-charactercreator:server:saveDraft', function(payload)
    local source = source
    if not busy[source] or not Config.Draft.enabled then return end
    if not rateLimit(source, 'draft', Config.RateLimit.draftMs) then return end
    if type(payload) ~= 'table' then return end

    local ok, sanitized = Validation.Draft(payload)
    if not ok then return end

    local license = getLicense(source)
    local player = getPlayer(source)
    local citizenid = player and player.PlayerData.citizenid or nil
    memoryDrafts[license] = {
        payload = sanitized,
        expires = os.time() + (Config.Draft.timeoutMinutes * 60),
    }
    Database.SaveDraft(license, citizenid, sanitized)
end)

RegisterNetEvent('qbx-charactercreator:server:setBusy', function(state)
    local source = source
    busy[source] = state and true or nil
    setBucket(source, state == true)
end)

local function openFor(target, mode, first)
    TriggerClientEvent('qbx-charactercreator:client:open', target, {
        mode = mode or 'edit',
        first = first == true,
    })
end

lib.addCommand('charcreator', {
    help = SharedUtils.Locale('commands.charcreator'),
    params = {
        { name = 'id', type = 'playerId', help = SharedUtils.Locale('commands.charcreator_id'), optional = true },
    },
}, function(source, args)
    local target = args.id
    if target then
        if not hasAdminPermission(source) then
            notify(source, 'notify.not_allowed', 'error')
            return
        end
        if not getPlayer(target) then
            notify(source, 'notify.player_offline', 'error')
            return
        end
        openFor(target, 'admin', false)
        notify(source, 'notify.creator_open', 'success')
        return
    end

    if source == 0 then return end
    if not Config.Admin.allowSelfCommand then
        notify(source, 'notify.not_allowed', 'error')
        return
    end
    openFor(source, getPlayer(source) and 'edit' or 'register', getPlayer(source) == nil)
end)

lib.addCommand('charreset', {
    help = SharedUtils.Locale('commands.charreset'),
    params = {
        { name = 'id', type = 'playerId', help = SharedUtils.Locale('commands.charreset_id'), optional = false },
    },
    restricted = Config.Admin.commandGroup,
}, function(source, args)
    if source ~= 0 and not hasAdminPermission(source) then
        notify(source, 'notify.not_allowed', 'error')
        return
    end

    if not rateLimit(source, 'reset', Config.RateLimit.resetMs) then
        notify(source, 'notify.rate_limited', 'error')
        return
    end

    local target = args.id
    local player = getPlayer(target)
    if not player then
        notify(source, 'notify.player_offline', 'error')
        return
    end

    local gender = tonumber(player.PlayerData.charinfo and player.PlayerData.charinfo.gender) or 0
    local appearance = Database.ResetAppearance(player.PlayerData.citizenid, gender)
    TriggerClientEvent('qbx-charactercreator:client:applyAppearance', target, appearance)
    notify(source, 'notify.reset_success', 'success')
    notify(target, 'notify.reset_success', 'inform')
end)

AddEventHandler('playerDropped', function()
    local source = source
    busy[source] = nil
    lastCall[source] = nil
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    Database.Init()
end)

CreateThread(function()
    Database.Init()
end)

exports('OpenCreator', function(target, mode)
    if not target then return false end
    openFor(target, mode or 'edit', mode == 'create' or mode == 'register')
    return true
end)

exports('GetAppearance', function(citizenid)
    local row = Database.GetByCitizenId(citizenid)
    if not row or not row.appearance then return nil end
    local ok, appearance = pcall(json.decode, row.appearance)
    if not ok then return nil end
    return appearance
end)

exports('ResetAppearance', function(citizenid, gender)
    return Database.ResetAppearance(citizenid, gender)
end)

exports('HasAppearance', function(citizenid)
    return Database.HasAppearance(citizenid)
end)
