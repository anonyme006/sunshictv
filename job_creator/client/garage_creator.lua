--[[
    Créateur de garages — ox_lib (même thème que ox_garage)
    Commande : Config.GarageCreatorCommand (défaut /jagarage)
]]

local function libReady()
    return GetResourceState('ox_lib') == 'started' and lib ~= nil
end

local function oxGarageReady()
    return Config.UseOxGarage and GetResourceState('ox_garage') == 'started'
end

local function notify(msg, nType)
    if libReady() then
        lib.notify({
            title = 'Job Creator',
            description = msg,
            type = nType or 'inform',
            position = 'top-right',
            duration = 4500,
        })
    else
        JC_C.Notify(msg)
    end
end

local function playerCoords()
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local h = GetEntityHeading(ped)
    return {
        x = tonumber(('%.2f'):format(c.x)),
        y = tonumber(('%.2f'):format(c.y)),
        z = tonumber(('%.2f'):format(c.z)),
        w = tonumber(('%.2f'):format(h)),
    }
end

local function jobOptions()
    local opts = {}
    for name, j in pairs(JC_C.Jobs or {}) do
        opts[#opts + 1] = {
            value = name,
            label = ('%s (%s)'):format(j.label or name, name),
        }
    end
    table.sort(opts, function(a, b) return a.label < b.label end)
    return opts
end

local function pickJob(cb)
    local jobs = jobOptions()
    if #jobs == 0 then
        notify(L('gc_no_jobs'), 'error')
        return
    end

    local options = {}
    for _i, j in ipairs(jobs) do
        options[#options + 1] = {
            title = j.label,
            icon = 'briefcase',
            onSelect = function()
                cb(j.value)
            end,
        }
    end
    options[#options + 1] = {
        title = L('gc_back'),
        icon = 'arrow-left',
        onSelect = function()
            JC_C.OpenGarageCreator()
        end,
    }

    lib.registerContext({
        id = 'jc_gc_pick_job',
        title = L('gc_pick_job'),
        menu = 'jc_garage_creator',
        options = options,
    })
    lib.showContext('jc_gc_pick_job')
end

--- Créer garage flotte + marker(s) à la position
local function createFleetGarage()
    pickJob(function(jobName)
        local input = lib.inputDialog(L('gc_create_fleet_title'), {
            { type = 'input', label = L('gc_label'), required = true, default = 'Garage ' .. jobName },
            { type = 'number', label = L('gc_grade'), default = 0, min = 0, max = 20 },
            { type = 'number', label = L('gc_radius'), default = 10, min = 4, max = 40 },
            { type = 'checkbox', label = L('gc_also_store'), checked = true },
            { type = 'checkbox', label = L('gc_blip'), checked = true },
        })
        if not input then return JC_C.OpenGarageCreator() end

        local c = playerCoords()
        local result = lib.callback.await('job_creator:createOxGarage', false, {
            kind = 'fleet',
            job_name = jobName,
            label = input[1],
            min_grade = input[2],
            radius = input[3],
            also_store = input[4] == true,
            blip_enabled = input[5] == true,
            coords = c,
            heading = c.w,
        })

        if not result or not result.ok then
            notify(L(result and result.error or 'invalid_data'), 'error')
            return JC_C.OpenGarageCreator()
        end

        notify(L('gc_created', result.label or input[1], result.ox_garage_id or 'local'), 'success')
        JC_C.OpenGarageCreator()
    end)
end

--- Marker qui ouvre un garage ox_garage perso/public/privé
local function createLinkedGarage()
    if not oxGarageReady() then
        notify(L('gc_need_ox_garage'), 'error')
        return JC_C.OpenGarageCreator()
    end

    local oxList = lib.callback.await('job_creator:getOxGarages', false) or {}
    local personal = {}
    for _i, g in ipairs(oxList) do
        if g.kind ~= 'job' then
            personal[#personal + 1] = {
                value = g.id,
                label = ('%s (%s) [%s]'):format(g.label or g.id, g.id, g.kind or 'public'),
            }
        end
    end

    if #personal == 0 then
        notify(L('gc_no_ox_garages'), 'error')
        return JC_C.OpenGarageCreator()
    end

    pickJob(function(jobName)
        local input = lib.inputDialog(L('gc_link_title'), {
            {
                type = 'select',
                label = L('gc_ox_garage'),
                options = personal,
                required = true,
            },
            { type = 'input', label = L('gc_label'), required = true, default = 'Garage' },
            { type = 'number', label = L('gc_grade'), default = 0, min = 0, max = 20 },
            { type = 'number', label = L('gc_radius'), default = 8, min = 4, max = 40 },
            { type = 'checkbox', label = L('gc_also_store'), checked = true },
            { type = 'checkbox', label = L('gc_blip'), checked = false },
        })
        if not input then return JC_C.OpenGarageCreator() end

        local c = playerCoords()
        local result = lib.callback.await('job_creator:createOxGarage', false, {
            kind = 'linked',
            job_name = jobName,
            ox_garage_id = input[1],
            label = input[2],
            min_grade = input[3],
            radius = input[4],
            also_store = input[5] == true,
            blip_enabled = input[6] == true,
            coords = c,
            heading = c.w,
        })

        if not result or not result.ok then
            notify(L(result and result.error or 'invalid_data'), 'error')
            return JC_C.OpenGarageCreator()
        end

        notify(L('gc_linked', input[2], input[1]), 'success')
        JC_C.OpenGarageCreator()
    end)
end

--- Marker ranger seul
local function createStoreOnly()
    pickJob(function(jobName)
        local oxList = oxGarageReady() and (lib.callback.await('job_creator:getOxGarages', false) or {}) or {}
        local garageOpts = { { value = '', label = L('gc_none_marker') } }
        for _i, g in ipairs(oxList) do
            garageOpts[#garageOpts + 1] = {
                value = g.id,
                label = ('%s (%s)'):format(g.label or g.id, g.id),
            }
        end

        local input = lib.inputDialog(L('gc_store_title'), {
            {
                type = 'select',
                label = L('gc_mode'),
                options = {
                    { value = 'job_fleet', label = L('gc_mode_fleet') },
                    { value = 'ox_garage', label = L('gc_mode_personal') },
                },
                default = 'job_fleet',
                required = true,
            },
            {
                type = 'select',
                label = L('gc_ox_garage'),
                options = garageOpts,
            },
            { type = 'input', label = L('gc_label'), required = true, default = 'Ranger véhicule' },
            { type = 'number', label = L('gc_grade'), default = 0, min = 0, max = 20 },
            { type = 'number', label = L('gc_radius'), default = 10, min = 4, max = 40 },
        })
        if not input then return JC_C.OpenGarageCreator() end

        local c = playerCoords()
        local result = lib.callback.await('job_creator:createOxGarage', false, {
            kind = 'store_only',
            job_name = jobName,
            ox_mode = input[1],
            ox_garage_id = input[2] ~= '' and input[2] or nil,
            label = input[3],
            min_grade = input[4],
            radius = input[5],
            coords = c,
            heading = c.w,
        })

        if not result or not result.ok then
            notify(L(result and result.error or 'invalid_data'), 'error')
            return JC_C.OpenGarageCreator()
        end

        notify(L('marker_saved'), 'success')
        JC_C.OpenGarageCreator()
    end)
end

--- Ajouter un véhicule à la flotte
local function addFleetVehicle()
    pickJob(function(jobName)
        -- Markers garage de ce job
        local markerOpts = { { value = '', label = L('gc_none_marker') } }
        for id, m in pairs(JC_C.Markers or {}) do
            if m.job_name == jobName and m.type == 'garage' then
                markerOpts[#markerOpts + 1] = {
                    value = tostring(m.id),
                    label = ('#%s %s'):format(m.id, m.label or 'Garage'),
                }
            end
        end

        local input = lib.inputDialog(L('gc_vehicle_title'), {
            { type = 'input', label = L('gc_vehicle_model'), required = true, placeholder = 'police' },
            { type = 'input', label = L('gc_vehicle_label'), required = true, placeholder = 'Cruiser' },
            {
                type = 'select',
                label = L('gc_vehicle_marker'),
                options = markerOpts,
            },
            { type = 'number', label = L('gc_grade'), default = 0, min = 0, max = 20 },
            { type = 'number', label = L('gc_vehicle_livery'), default = 0, min = 0, max = 50 },
        })
        if not input then return JC_C.OpenGarageCreator() end

        local result = lib.callback.await('job_creator:createFleetVehicle', false, {
            job_name = jobName,
            model = input[1],
            label = input[2],
            marker_id = input[3] ~= '' and tonumber(input[3]) or nil,
            min_grade = input[4],
            livery = input[5],
        })

        if not result or not result.ok then
            notify(L(result and result.error or 'invalid_data'), 'error')
            return JC_C.OpenGarageCreator()
        end

        notify(L('gc_vehicle_added', input[2]), 'success')
        JC_C.OpenGarageCreator()
    end)
end

local function listGarageMarkers()
    local options = {}
    for id, m in pairs(JC_C.Markers or {}) do
        if m.type == 'garage' or m.type == 'garage_store' then
            local d = m.data or {}
            options[#options + 1] = {
                title = m.label or m.type,
                description = ('%s · %s · mode %s · %s'):format(
                    m.job_name or '?',
                    m.type,
                    d.ox_mode or 'job_fleet',
                    d.ox_garage_id or ('marker#' .. tostring(m.id))
                ),
                icon = m.type == 'garage' and 'warehouse' or 'square-parking',
                metadata = {
                    { label = 'ID', value = tostring(m.id) },
                    { label = 'Job', value = m.job_name },
                    { label = 'ox_garage', value = d.ox_garage_id or '—' },
                },
            }
        end
    end

    table.sort(options, function(a, b)
        return (a.title or '') < (b.title or '')
    end)

    if #options == 0 then
        options[1] = {
            title = L('gc_list_empty'),
            icon = 'inbox',
            disabled = true,
        }
    end

    options[#options + 1] = {
        title = L('gc_back'),
        icon = 'arrow-left',
        onSelect = function() JC_C.OpenGarageCreator() end,
    }

    lib.registerContext({
        id = 'jc_gc_list_markers',
        title = L('gc_list_markers'),
        menu = 'jc_garage_creator',
        options = options,
    })
    lib.showContext('jc_gc_list_markers')
end

local function listOxGarages()
    local list = lib.callback.await('job_creator:getOxGarages', false) or {}
    local options = {}
    for _i, g in ipairs(list) do
        options[#options + 1] = {
            title = g.label or g.id,
            description = ('%s · %s%s'):format(
                g.id,
                g.kind or '?',
                g.job and (' · ' .. g.job) or ''
            ),
            icon = g.kind == 'job' and 'building' or (g.kind == 'private' and 'key' or 'car'),
            metadata = {
                { label = 'ID', value = g.id },
                { label = 'Type', value = g.kind or '?' },
                { label = 'Source', value = g.source or '?' },
            },
        }
    end

    if #options == 0 then
        options[1] = { title = L('gc_no_ox_garages'), icon = 'inbox', disabled = true }
    end
    options[#options + 1] = {
        title = L('gc_back'),
        icon = 'arrow-left',
        onSelect = function() JC_C.OpenGarageCreator() end,
    }

    lib.registerContext({
        id = 'jc_gc_list_ox',
        title = L('gc_list_ox'),
        menu = 'jc_garage_creator',
        options = options,
    })
    lib.showContext('jc_gc_list_ox')
end

function JC_C.OpenGarageCreator()
    if not libReady() then
        notify(L('gc_need_ox_lib'), 'error')
        return
    end

    local isAdmin = lib.callback.await('job_creator:isAdmin', false)
    if not isAdmin then
        notify(L('no_permission'), 'error')
        return
    end

    lib.registerContext({
        id = 'jc_garage_creator',
        title = L('gc_menu_title'),
        options = {
            {
                title = L('gc_opt_fleet'),
                description = L('gc_opt_fleet_desc'),
                icon = 'warehouse',
                iconColor = '#3ecf8e',
                arrow = true,
                onSelect = createFleetGarage,
            },
            {
                title = L('gc_opt_link'),
                description = L('gc_opt_link_desc'),
                icon = 'link',
                iconColor = '#5b9bd5',
                arrow = true,
                disabled = not oxGarageReady(),
                onSelect = createLinkedGarage,
            },
            {
                title = L('gc_opt_store'),
                description = L('gc_opt_store_desc'),
                icon = 'square-parking',
                iconColor = '#e6b35a',
                arrow = true,
                onSelect = createStoreOnly,
            },
            {
                title = L('gc_opt_vehicle'),
                description = L('gc_opt_vehicle_desc'),
                icon = 'car',
                arrow = true,
                onSelect = addFleetVehicle,
            },
            {
                title = L('gc_list_markers'),
                icon = 'list',
                arrow = true,
                onSelect = listGarageMarkers,
            },
            {
                title = L('gc_list_ox'),
                icon = 'map-location-dot',
                arrow = true,
                disabled = not oxGarageReady(),
                onSelect = listOxGarages,
            },
        },
    })
    lib.showContext('jc_garage_creator')
end

RegisterCommand(Config.GarageCreatorCommand or 'jagarage', function()
    JC_C.OpenGarageCreator()
end, false)

TriggerEvent('chat:addSuggestion', '/' .. (Config.GarageCreatorCommand or 'jagarage'), 'Créateur de garages Job Creator (ox_lib)')

exports('OpenGarageCreator', JC_C.OpenGarageCreator)
