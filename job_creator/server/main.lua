JC = JC or {}
JC.Jobs = {}
JC.Markers = {}
JC.Vehicles = {}
JC.Outfits = {}
JC.ShopItems = {}
JC.Crafts = {}
JC.Ready = false

function _(key, ...)
    local str = (Locales[Config.Locale] and Locales[Config.Locale][key]) or key
    if ... then
        return str:format(...)
    end
    return str
end

function JC.Notify(src, msg)
    TriggerClientEvent('esx:showNotification', src, msg)
end

function JC.IsAdmin(xPlayer)
    if not xPlayer then return false end
    local group = xPlayer.getGroup and xPlayer.getGroup() or 'user'
    return Config.AdminGroups[group] == true
end

function JC.HasPermission(xPlayer, perm)
    if not xPlayer or not xPlayer.job then return false end
    local job = JC.Jobs[xPlayer.job.name]
    if not job then return false end

    local gradeData = nil
    for _, g in ipairs(job.grades or {}) do
        if g.grade == xPlayer.job.grade then
            gradeData = g
            break
        end
    end
    if not gradeData then return false end

    local perms = gradeData.permissions or {}
    if type(perms) == 'string' then
        perms = json.decode(perms) or {}
    end

    if perms['*'] or perms.boss then
        return true
    end
    return perms[perm] == true
end

function JC.Log(title, message)
    if Config.Webhook == nil or Config.Webhook == '' then return end
    PerformHttpRequest(Config.Webhook, function() end, 'POST', json.encode({
        username = 'Job Creator',
        embeds = {{
            title = title,
            description = message,
            color = 3447003,
            footer = { text = os.date('%d/%m/%Y %H:%M:%S') },
        }},
    }), { ['Content-Type'] = 'application/json' })
end

local function decodeJson(val, fallback)
    if val == nil or val == '' then return fallback end
    if type(val) == 'table' then return val end
    local ok, data = pcall(json.decode, val)
    if ok and data then return data end
    return fallback
end

function JC.LoadAll()
    JC.Jobs = {}
    JC.Markers = {}
    JC.Vehicles = {}
    JC.Outfits = {}
    JC.ShopItems = {}
    JC.Crafts = {}

    local jobs = MySQL.query.await('SELECT * FROM jc_jobs WHERE enabled = 1') or {}
    local grades = MySQL.query.await('SELECT * FROM jc_grades ORDER BY grade ASC') or {}
    local markers = MySQL.query.await('SELECT * FROM jc_markers WHERE enabled = 1') or {}
    local vehicles = MySQL.query.await('SELECT * FROM jc_vehicles') or {}
    local outfits = MySQL.query.await('SELECT * FROM jc_outfits') or {}
    local shops = MySQL.query.await('SELECT * FROM jc_shop_items') or {}
    local crafts = MySQL.query.await('SELECT * FROM jc_crafts') or {}

    for _, j in ipairs(jobs) do
        JC.Jobs[j.name] = {
            id = j.id,
            name = j.name,
            label = j.label,
            type = j.type,
            whitelisted = j.whitelisted == 1,
            enabled = j.enabled == 1,
            actions = decodeJson(j.actions, {}),
            blip = {
                sprite = j.blip_sprite or 0,
                color = j.blip_color or 0,
                scale = j.blip_scale or 0.8,
                coords = decodeJson(j.blip_coords, nil),
            },
            grades = {},
        }
    end

    for _, g in ipairs(grades) do
        if JC.Jobs[g.job_name] then
            JC.Jobs[g.job_name].grades[#JC.Jobs[g.job_name].grades + 1] = {
                id = g.id,
                grade = g.grade,
                name = g.name,
                label = g.label,
                salary = g.salary,
                permissions = decodeJson(g.permissions, {}),
            }
        end
    end

    for _, m in ipairs(markers) do
        local entry = {
            id = m.id,
            job_name = m.job_name,
            type = m.type,
            label = m.label,
            coords = decodeJson(m.coords, { x = 0, y = 0, z = 0 }),
            min_grade = m.min_grade or 0,
            data = decodeJson(m.data, {}),
            marker_type = m.marker_type or 1,
            marker_scale = decodeJson(m.marker_scale, Config.DefaultMarker.scale),
            marker_color = decodeJson(m.marker_color, Config.DefaultMarker.color),
            blip_enabled = m.blip_enabled == 1,
            blip_sprite = m.blip_sprite or 1,
            blip_color = m.blip_color or 0,
            blip_scale = m.blip_scale or 0.7,
            public = m.public == 1,
            enabled = true,
        }
        JC.Markers[m.id] = entry
    end

    for _, v in ipairs(vehicles) do
        JC.Vehicles[v.id] = {
            id = v.id,
            job_name = v.job_name,
            marker_id = v.marker_id,
            model = v.model,
            label = v.label,
            min_grade = v.min_grade or 0,
            price = v.price or 0,
            livery = v.livery or 0,
            extras = decodeJson(v.extras, {}),
        }
    end

    for _, o in ipairs(outfits) do
        JC.Outfits[o.id] = {
            id = o.id,
            job_name = o.job_name,
            label = o.label,
            min_grade = o.min_grade or 0,
            skin = decodeJson(o.skin, {}),
            gender = o.gender or 'both',
        }
    end

    for _, s in ipairs(shops) do
        JC.ShopItems[s.id] = {
            id = s.id,
            job_name = s.job_name,
            marker_id = s.marker_id,
            item = s.item,
            label = s.label,
            price = s.price or 0,
            min_grade = s.min_grade or 0,
            type = s.type or 'item',
        }
    end

    for _, c in ipairs(crafts) do
        JC.Crafts[c.id] = {
            id = c.id,
            job_name = c.job_name,
            marker_id = c.marker_id,
            label = c.label,
            result_item = c.result_item,
            result_count = c.result_count or 1,
            ingredients = decodeJson(c.ingredients, {}),
            duration = c.duration or 5000,
            min_grade = c.min_grade or 0,
        }
    end

    JC.Ready = true
    TriggerClientEvent('job_creator:sync', -1, JC.GetClientPayload())
    print(('[job_creator] Chargé : %d jobs, %d markers'):format(
        (function() local n=0 for _ in pairs(JC.Jobs) do n=n+1 end return n end)(),
        (function() local n=0 for _ in pairs(JC.Markers) do n=n+1 end return n end)()
    ))
end

function JC.GetClientPayload()
    local jobs = {}
    for name, j in pairs(JC.Jobs) do
        jobs[name] = {
            name = j.name,
            label = j.label,
            type = j.type,
            actions = j.actions,
            blip = j.blip,
            grades = j.grades,
        }
    end

    local markers = {}
    for id, m in pairs(JC.Markers) do
        markers[tostring(id)] = m
    end

    local vehicles = {}
    for id, v in pairs(JC.Vehicles) do
        vehicles[tostring(id)] = v
    end

    local outfits = {}
    for id, o in pairs(JC.Outfits) do
        outfits[tostring(id)] = o
    end

    local shops = {}
    for id, s in pairs(JC.ShopItems) do
        shops[tostring(id)] = s
    end

    local crafts = {}
    for id, c in pairs(JC.Crafts) do
        crafts[tostring(id)] = c
    end

    return {
        jobs = jobs,
        markers = markers,
        vehicles = vehicles,
        outfits = outfits,
        shops = shops,
        crafts = crafts,
    }
end

function JC.GetAdminPayload()
    local payload = JC.GetClientPayload()
    payload.markerTypes = Config.MarkerTypes
    payload.permissions = Config.Permissions
    payload.defaultActions = Config.DefaultActions
    return payload
end

MySQL.ready(function()
    local sql = LoadResourceFile(GetCurrentResourceName(), 'sql/install.sql')
    if sql then
        for statement in sql:gmatch('([^;]+);') do
            local trimmed = statement:gsub('^%s+', ''):gsub('%s+$', '')
            if trimmed ~= '' then
                MySQL.query.await(trimmed)
            end
        end
    end
    Wait(500)
    JC.LoadAll()
end)

RegisterNetEvent('job_creator:requestSync', function()
    local src = source
    if not JC.Ready then return end
    TriggerClientEvent('job_creator:sync', src, JC.GetClientPayload())
end)

AddEventHandler('esx:playerLoaded', function(playerId)
    if JC.Ready then
        TriggerClientEvent('job_creator:sync', playerId, JC.GetClientPayload())
    end
end)

print('^2[job_creator]^0 serveur initialisé.')
