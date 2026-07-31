--[[
    Compatibilité clés véhicule (vehiclekeys / wasabi / qb / ox)
]]

local KEY_RESOURCES = {
    'vehiclekeys',
    'wasabi_carlock',
    'qb-vehiclekeys',
    'qbx_vehiclekeys',
    'ox_vehiclekeys',
    'Renewed-Vehiclekeys',
}

local function resolveResource()
    local cfg = Config.VehicleKeys or {}
    if cfg.enabled == false or cfg.resource == 'none' then return nil end
    if cfg.resource and cfg.resource ~= 'auto' then
        if GetResourceState(cfg.resource) == 'started' then return cfg.resource end
        return nil
    end
    for _i, name in ipairs(KEY_RESOURCES) do
        if GetResourceState(name) == 'started' then return name end
    end
    return nil
end

--- Donne les clés après spawn
---@param plate string
---@param entity number|nil
function GiveVehicleKeys(plate, entity)
    local cfg = Config.VehicleKeys or {}
    if cfg.enabled == false then return end

    plate = (plate or ''):gsub('^%s+', ''):gsub('%s+$', '')
    local res = resolveResource()

    if res == 'wasabi_carlock' then
        pcall(function() exports.wasabi_carlock:GiveKey(plate) end)
        return
    end

    if res == 'qb-vehiclekeys' or res == 'qbx_vehiclekeys' then
        pcall(function()
            TriggerEvent('qb-vehiclekeys:client:AddKeys', plate)
            exports[res]:GiveKeys(plate)
        end)
        return
    end

    if res == 'ox_vehiclekeys' then
        pcall(function()
            if entity and DoesEntityExist(entity) then
                exports.ox_vehiclekeys:giveKeys(entity)
            else
                exports.ox_vehiclekeys:giveKeys(plate)
            end
        end)
        return
    end

    if res == 'vehiclekeys' or res == 'Renewed-Vehiclekeys' then
        pcall(function()
            exports[res]:addKeys(plate)
        end)
        pcall(function()
            exports[res]:giveKeys(plate)
        end)
    end

    -- Events génériques (beaucoup de scripts FR)
    TriggerEvent('vehiclekeys:client:SetOwner', plate)
    TriggerEvent('keys:addNew', entity, plate)
    TriggerServerEvent('ox_garage:giveKeys', plate)
end

--- Retire les clés (optionnel au rangement)
---@param plate string
function RemoveVehicleKeys(plate)
    local res = resolveResource()
    if not res then return end
    plate = (plate or ''):gsub('^%s+', ''):gsub('%s+$', '')
    pcall(function()
        if res == 'wasabi_carlock' then
            exports.wasabi_carlock:RemoveKey(plate)
        elseif exports[res] and exports[res].removeKeys then
            exports[res]:removeKeys(plate)
        end
    end)
end
