local blips = {}

function L(key, ...)
    local str = Locales[Config.Locale] and Locales[Config.Locale][key] or key
    if select('#', ...) > 0 then
        return str:format(...)
    end
    return str
end

function Notify(desc, nType)
    lib.notify({
        title = 'Garage',
        description = desc,
        type = nType or 'inform',
        position = 'top-right',
        duration = 4500,
    })
end

function GetGarageById(id)
    for _i, g in ipairs(Config.Garages) do
        if g.id == id then return g end
    end
end

function IsNearGarageStore(garage)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local store = garage.store or { coords = garage.coords, radius = Config.StoreDistance }
    return #(coords - store.coords) <= (store.radius or Config.StoreDistance)
end

function PlayerInOwnedVehicle()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return nil end
    local veh = GetVehiclePedIsIn(ped, false)
    if GetPedInVehicleSeat(veh, -1) ~= ped then return nil end
    return veh
end

function GetVehicleDisplayName(model)
    local hash = type(model) == 'number' and model or joaat(model)
    local display = GetDisplayNameFromVehicleModel(hash)
    local label = GetLabelText(display)
    if not label or label == 'NULL' or label == '' then
        return display or 'Véhicule'
    end
    return label
end

function GetVehicleIcon(model)
    local hash = type(model) == 'number' and model or joaat(model)
    local class = GetVehicleClassFromName(hash)
    return Config.ClassIcons[class] or 'car'
end

function IsSpawnPointClear(coords, radius)
    radius = radius or 2.5
    local vehicles = GetGamePool('CVehicle')
    for _i, veh in ipairs(vehicles) do
        if #(GetEntityCoords(veh) - vec3(coords.x, coords.y, coords.z)) < radius then
            return false
        end
    end
    return true
end

function FindFreeSpawn(spawns)
    for _i, s in ipairs(spawns or {}) do
        if IsSpawnPointClear(s, 2.8) then
            return s
        end
    end
    return nil
end

function ApplyFuel(vehicle, level)
    level = tonumber(level) or 100.0
    if Config.FuelResource == 'ox_fuel' then
        Entity(vehicle).state.fuel = level
    elseif Config.FuelResource == 'LegacyFuel' then
        exports['LegacyFuel']:SetFuel(vehicle, level)
    else
        SetVehicleFuelLevel(vehicle, level + 0.0)
    end
end

function ReadFuel(vehicle)
    if Config.FuelResource == 'ox_fuel' then
        return Entity(vehicle).state.fuel or GetVehicleFuelLevel(vehicle)
    elseif Config.FuelResource == 'LegacyFuel' then
        return exports['LegacyFuel']:GetFuel(vehicle)
    end
    return GetVehicleFuelLevel(vehicle)
end

--- Props complets pour sauvegarde
function GetVehicleProps(vehicle)
    if ESX.Game and ESX.Game.GetVehicleProperties then
        local props = ESX.Game.GetVehicleProperties(vehicle)
        props.fuelLevel = ReadFuel(vehicle)
        return props
    end

    -- Fallback minimal
    return {
        model = GetEntityModel(vehicle),
        plate = GetVehicleNumberPlateText(vehicle),
        engineHealth = GetVehicleEngineHealth(vehicle),
        bodyHealth = GetVehicleBodyHealth(vehicle),
        fuelLevel = ReadFuel(vehicle),
        dirtLevel = GetVehicleDirtLevel(vehicle),
    }
end

function SetVehicleProps(vehicle, props)
    if ESX.Game and ESX.Game.SetVehicleProperties then
        ESX.Game.SetVehicleProperties(vehicle, props)
    else
        if props.plate then SetVehicleNumberPlateText(vehicle, props.plate) end
        if props.engineHealth then SetVehicleEngineHealth(vehicle, props.engineHealth + 0.0) end
        if props.bodyHealth then SetVehicleBodyHealth(vehicle, props.bodyHealth + 0.0) end
        if props.dirtLevel then SetVehicleDirtLevel(vehicle, props.dirtLevel + 0.0) end
    end
    ApplyFuel(vehicle, props.fuelLevel or props.fuel or 100.0)
end

--- Blips + ox_target
CreateThread(function()
    for _i, garage in ipairs(Config.Garages) do
        if garage.blip and garage.blip.enabled then
            local blip = AddBlipForCoord(garage.coords.x, garage.coords.y, garage.coords.z)
            SetBlipSprite(blip, garage.blip.sprite or 357)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, garage.blip.scale or 0.75)
            SetBlipColour(blip, garage.blip.color or 3)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(garage.label)
            EndTextCommandSetBlipName(blip)
            blips[#blips + 1] = blip
        end

        local t = garage.target
        exports.ox_target:addSphereZone({
            coords = t.coords,
            radius = t.radius or 2.0,
            debug = t.debug or false,
            options = {
                {
                    name = 'ox_garage_open_' .. garage.id,
                    icon = 'fa-solid fa-warehouse',
                    label = L('target_open'),
                    distance = 2.0,
                    onSelect = function()
                        OpenGarageMenu(garage.id)
                    end,
                },
                {
                    name = 'ox_garage_store_' .. garage.id,
                    icon = 'fa-solid fa-square-parking',
                    label = L('target_store'),
                    distance = 2.5,
                    canInteract = function()
                        return PlayerInOwnedVehicle() ~= nil and IsNearGarageStore(garage)
                    end,
                    onSelect = function()
                        OpenStoreMenu(garage.id)
                    end,
                },
            },
        })
    end
end)
