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

function GetGarageStoreInfo(garage)
    return garage.store or { coords = garage.coords, radius = Config.StoreDistance }
end

function IsCoordsNearGarageStore(coords, garage)
    local store = GetGarageStoreInfo(garage)
    if not store.coords then return false end
    return #(coords - store.coords) <= (store.radius or Config.StoreDistance)
end

function IsNearGarageStore(garage)
    return IsCoordsNearGarageStore(GetEntityCoords(PlayerPedId()), garage)
end

function IsVehicleNearGarageStore(veh, garage)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false end
    return IsCoordsNearGarageStore(GetEntityCoords(veh), garage)
end

--- Garage dont le point de rangement couvre ce véhicule
function GetStoreGarageForVehicle(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    local vCoords = GetEntityCoords(veh)
    for _i, garage in ipairs(Config.Garages) do
        if IsCoordsNearGarageStore(vCoords, garage) then
            return garage
        end
    end
    return nil
end

--- Véhicule le plus proche sur le point de rangement
function GetClosestVehicleAtStore(garage, maxDist)
    local store = GetGarageStoreInfo(garage)
    if not store.coords then return nil end
    maxDist = maxDist or (store.radius or Config.StoreDistance)
    local best, bestDist
    for _i, veh in ipairs(GetGamePool('CVehicle')) do
        local d = #(GetEntityCoords(veh) - store.coords)
        if d <= maxDist and (not bestDist or d < bestDist) then
            best, bestDist = veh, d
        end
    end
    return best
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

local storeMarkers = {}

local function registerStoreZone(garage)
    local store = garage.store
    if not store then return end

    local st = store.target or {
        coords = store.coords or garage.coords,
        radius = math.min(store.radius or Config.StoreDistance, 5.0),
        debug = false,
    }

    exports.ox_target:addSphereZone({
        coords = st.coords,
        radius = st.radius or 4.0,
        debug = st.debug or false,
        options = {
            {
                name = 'ox_garage_store_' .. garage.id,
                icon = 'fa-solid fa-square-parking',
                label = L('target_store'),
                distance = 3.5,
                canInteract = function()
                    if not IsNearGarageStore(garage) then return false end
                    if PlayerInOwnedVehicle() then return true end
                    return GetClosestVehicleAtStore(garage) ~= nil
                end,
                onSelect = function()
                    local veh = PlayerInOwnedVehicle() or GetClosestVehicleAtStore(garage)
                    OpenStoreMenu(garage.id, veh)
                end,
            },
        },
    })

    if store.marker and store.marker.enabled then
        storeMarkers[#storeMarkers + 1] = {
            coords = store.coords or st.coords,
            marker = store.marker,
            garage = garage,
        }
    end
end

--- Blips + ox_target (ouvrir + point ranger dédié)
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

        local t = garage.target or { coords = garage.coords, radius = 2.0 }
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
            },
        })

        registerStoreZone(garage)
    end
end)

--- Markers des points de rangement
CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local pCoords = GetEntityCoords(ped)

        for _i, entry in ipairs(storeMarkers) do
            local m = entry.marker
            local c = entry.coords
            local drawDist = m.drawDistance or 35.0
            local dist = #(pCoords - c)
            if dist < drawDist then
                sleep = 0
                local scale = m.scale or vec3(1.0, 1.0, 1.0)
                local col = m.color or { r = 255, g = 200, b = 40, a = 150 }
                DrawMarker(
                    m.type or 36,
                    c.x, c.y, c.z + 0.15,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    scale.x, scale.y, scale.z,
                    col.r, col.g, col.b, col.a,
                    m.bobUpAndDown == true,
                    m.faceCamera ~= false,
                    2,
                    m.rotate == true,
                    nil, nil, false
                )
            end
        end

        Wait(sleep)
    end
end)

--- Target sur le véhicule au point de rangement (à pied ou dedans)
CreateThread(function()
    exports.ox_target:addGlobalVehicle({
        {
            name = 'ox_garage_store_on_vehicle',
            icon = 'fa-solid fa-square-parking',
            label = L('target_store_vehicle'),
            distance = 3.0,
            canInteract = function(entity)
                if not entity or entity == 0 or not DoesEntityExist(entity) then return false end
                local garage = GetStoreGarageForVehicle(entity)
                if not garage then return false end
                -- Joueur proche du point OU du véhicule (après être descendu)
                local pedCoords = GetEntityCoords(PlayerPedId())
                local nearStore = IsNearGarageStore(garage)
                local nearVeh = #(pedCoords - GetEntityCoords(entity)) <= 4.0
                return nearStore or (nearVeh and IsVehicleNearGarageStore(entity, garage))
            end,
            onSelect = function(data)
                local veh = data.entity
                if not veh or not DoesEntityExist(veh) then return end
                local garage = GetStoreGarageForVehicle(veh)
                if not garage then
                    Notify(L('notify_too_far'), 'error')
                    return
                end
                OpenStoreMenu(garage.id, veh)
            end,
        },
    })
end)
