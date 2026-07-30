--[[
    Callbacks serveur — créateur garages ox_lib
]]

local ESX = exports['es_extended']:getSharedObject()

local function insertMarker(data)
    local coords = json.encode(data.coords)
    local mdata = json.encode(data.data or {})
    local scale = json.encode(Config.DefaultMarker.scale)
    local color = json.encode(Config.DefaultMarker.color)

    return MySQL.insert.await([[
        INSERT INTO jc_markers (job_name, type, label, coords, min_grade, data, marker_type, marker_scale,
        marker_color, blip_enabled, blip_sprite, blip_color, blip_scale, public, enabled)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 1)
    ]], {
        data.job_name,
        data.type,
        data.label or data.type,
        coords,
        data.min_grade or 0,
        mdata,
        data.marker_type or 36,
        scale,
        color,
        data.blip_enabled and 1 or 0,
        data.blip_sprite or 357,
        data.blip_color or 47,
        data.blip_scale or 0.7,
    })
end

lib.callback.register('job_creator:isAdmin', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    return JC.IsAdmin(xPlayer) == true
end)

lib.callback.register('job_creator:getOxGarages', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not JC.IsAdmin(xPlayer) then return {} end
    return JC.GetOxGarageList and JC.GetOxGarageList() or {}
end)

lib.callback.register('job_creator:createOxGarage', function(source, payload)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not JC.IsAdmin(xPlayer) then
        return { ok = false, error = 'no_permission' }
    end
    if type(payload) ~= 'table' or not payload.job_name or not payload.coords then
        return { ok = false, error = 'invalid_data' }
    end
    if not JC.Jobs[payload.job_name] then
        return { ok = false, error = 'invalid_data' }
    end

    local kind = payload.kind or 'fleet'
    local coords = payload.coords
    local heading = tonumber(payload.heading) or tonumber(coords.w) or 0.0
    local radius = tonumber(payload.radius) or 10.0
    local label = payload.label or ('Garage ' .. payload.job_name)
    local minGrade = tonumber(payload.min_grade) or 0
    local oxGarageId = payload.ox_garage_id
    local oxMode = payload.ox_mode or 'job_fleet'

    -- Flotte : crée l'emplacement ox_garage + marker
    if kind == 'fleet' then
        oxMode = 'job_fleet'
        if Config.UseOxGarage and GetResourceState('ox_garage') == 'started' then
            local ok, garage = pcall(function()
                return exports.ox_garage:AddJobGarage({
                    job = payload.job_name,
                    label = label,
                    x = coords.x,
                    y = coords.y,
                    z = coords.z,
                    heading = heading,
                    min_grade = minGrade,
                    store_radius = radius,
                    blip_enabled = payload.blip_enabled == true,
                    created_by = xPlayer.identifier,
                })
            end)
            if ok and type(garage) == 'table' and garage.id then
                oxGarageId = garage.id
            elseif Config.Debug then
                print(('[job_creator] AddJobGarage failed: %s'):format(tostring(garage)))
            end
        end

        local markerId = insertMarker({
            job_name = payload.job_name,
            type = 'garage',
            label = label,
            coords = { x = coords.x, y = coords.y, z = coords.z },
            min_grade = minGrade,
            blip_enabled = payload.blip_enabled == true,
            blip_sprite = 357,
            blip_color = 47,
            data = {
                ox_mode = oxMode,
                ox_garage_id = oxGarageId,
                radius = radius,
                spawn = { x = coords.x + 2.0, y = coords.y + 2.0, z = coords.z, w = heading },
                heading = heading,
            },
        })

        if payload.also_store then
            insertMarker({
                job_name = payload.job_name,
                type = 'garage_store',
                label = (label .. ' — Ranger'),
                coords = { x = coords.x, y = coords.y, z = coords.z },
                min_grade = minGrade,
                blip_enabled = false,
                data = {
                    ox_mode = oxMode,
                    ox_garage_id = oxGarageId,
                    radius = radius,
                },
            })
        end

        JC.LoadAll()
        return {
            ok = true,
            marker_id = markerId,
            ox_garage_id = oxGarageId,
            label = label,
        }
    end

    -- Lié à un garage ox_garage perso/public/privé
    if kind == 'linked' then
        if not oxGarageId or oxGarageId == '' then
            return { ok = false, error = 'invalid_data' }
        end
        oxMode = 'ox_garage'

        local markerId = insertMarker({
            job_name = payload.job_name,
            type = 'garage',
            label = label,
            coords = { x = coords.x, y = coords.y, z = coords.z },
            min_grade = minGrade,
            blip_enabled = payload.blip_enabled == true,
            blip_sprite = 357,
            blip_color = 5,
            data = {
                ox_mode = oxMode,
                ox_garage_id = oxGarageId,
                radius = radius,
                spawn = { x = coords.x + 2.0, y = coords.y + 2.0, z = coords.z, w = heading },
            },
        })

        if payload.also_store then
            insertMarker({
                job_name = payload.job_name,
                type = 'garage_store',
                label = (label .. ' — Ranger'),
                coords = { x = coords.x, y = coords.y, z = coords.z },
                min_grade = minGrade,
                blip_enabled = false,
                data = {
                    ox_mode = oxMode,
                    ox_garage_id = oxGarageId,
                    radius = radius,
                },
            })
        end

        JC.LoadAll()
        return { ok = true, marker_id = markerId, ox_garage_id = oxGarageId, label = label }
    end

    -- Marker ranger seul
    if kind == 'store_only' then
        local markerId = insertMarker({
            job_name = payload.job_name,
            type = 'garage_store',
            label = label,
            coords = { x = coords.x, y = coords.y, z = coords.z },
            min_grade = minGrade,
            blip_enabled = false,
            data = {
                ox_mode = oxMode,
                ox_garage_id = oxGarageId,
                radius = radius,
            },
        })
        JC.LoadAll()
        return { ok = true, marker_id = markerId, label = label }
    end

    return { ok = false, error = 'invalid_data' }
end)

lib.callback.register('job_creator:createFleetVehicle', function(source, payload)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not JC.IsAdmin(xPlayer) then
        return { ok = false, error = 'no_permission' }
    end
    if type(payload) ~= 'table' or not payload.job_name or not payload.model then
        return { ok = false, error = 'invalid_data' }
    end

    local markerId = payload.marker_id and tonumber(payload.marker_id) or nil
    local templateId = MySQL.insert.await(
        'INSERT INTO jc_vehicles (job_name, marker_id, model, label, min_grade, price, livery, extras) VALUES (?, ?, ?, ?, ?, 0, ?, ?)',
        {
            payload.job_name,
            markerId,
            tostring(payload.model):lower():gsub('%s+', ''),
            payload.label or payload.model,
            tonumber(payload.min_grade) or 0,
            tonumber(payload.livery) or 0,
            json.encode({}),
        }
    )

    if Config.UseOxGarage and GetResourceState('ox_garage') == 'started' then
        local garageId = markerId
        local marker = markerId and JC.Markers[markerId]
        if marker and marker.data and marker.data.ox_garage_id and marker.data.ox_garage_id ~= '' then
            garageId = marker.data.ox_garage_id
        end
        pcall(function()
            exports.ox_garage:UpsertJobFleetVehicle({
                template_id = templateId,
                id = templateId,
                job_name = payload.job_name,
                garage_id = garageId,
                marker_id = markerId,
                model = tostring(payload.model):lower():gsub('%s+', ''),
                label = payload.label or payload.model,
                min_grade = tonumber(payload.min_grade) or 0,
                livery = tonumber(payload.livery) or 0,
            })
        end)
    end

    JC.LoadAll()
    return { ok = true, id = templateId }
end)
