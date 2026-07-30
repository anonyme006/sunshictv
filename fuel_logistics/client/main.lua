FL_C = FL_C or {}
FL_C.Stations = {}
FL_C.Companies = {}
FL_C.Blips = {}
FL_C.Truck = nil
FL_C.Trailer = nil

function Notify(desc, nType)
    lib.notify({
        title = L('notify_title'),
        description = desc,
        type = nType or 'inform',
        position = 'top-right',
    })
end

function IsFuelJob()
    local data = ESX.GetPlayerData()
    return data and data.job and data.job.name == Config.JobName
end

function JobGrade()
    local data = ESX.GetPlayerData()
    return data and data.job and data.job.grade or 0
end

function CanPerm(perm)
    if not IsFuelJob() then return false end
    return FL.HasPermission(FL.GetGradePermissions(JobGrade()), perm)
end

function DoProgress(duration, label, anim)
    return lib.progressCircle({
        duration = duration,
        label = label,
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = anim and {
            dict = anim.dict,
            clip = anim.clip,
            flag = anim.flag or 1,
        } or nil,
    })
end

function ClearJobBlips()
    for _i, b in pairs(FL_C.Blips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    FL_C.Blips = {}
end

function AddBlip(coords, data, name)
    if not data or not data.enabled then return end
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, data.sprite or 1)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, data.scale or 0.75)
    SetBlipColour(blip, data.color or 0)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(name or 'Fuel')
    EndTextCommandSetBlipName(blip)
    FL_C.Blips[#FL_C.Blips + 1] = blip
end

function RefreshBlips()
    ClearJobBlips()
    if not IsFuelJob() then return end

    if Config.JobBlip and Config.JobBlip.enabled then
        AddBlip(Config.JobBlip.coords, Config.JobBlip, Config.JobBlip.label)
    end
    for _i, p in ipairs(Config.HarvestPoints) do
        AddBlip(p.coords, p.blip, p.label)
    end
    AddBlip(Config.RefinePoint.coords, Config.RefinePoint.blip, Config.RefinePoint.label)
    AddBlip(Config.Export.coords, Config.Export.blip, 'Export carburant')

    for _i, s in pairs(FL_C.Stations) do
        if s.coords then
            AddBlip(vec3(s.coords.x, s.coords.y, s.coords.z), {
                enabled = true, sprite = 361, color = 1, scale = 0.55,
            }, s.name)
        end
    end
end

RegisterNetEvent('fuel_logistics:sync', function(payload)
    if type(payload) ~= 'table' then return end
    FL_C.Stations = payload.stations or {}
    FL_C.Companies = payload.companies or {}
    RefreshBlips()
    RefreshDeliveryTargets()
end)

RegisterNetEvent('fuel_logistics:updateLevels', function(payload)
    if type(payload) ~= 'table' then return end
    for id, level in pairs(payload.stations or {}) do
        if FL_C.Stations[id] then FL_C.Stations[id].level = level end
    end
    for id, level in pairs(payload.companies or {}) do
        if FL_C.Companies[id] then FL_C.Companies[id].level = level end
    end
end)

RegisterNetEvent('esx:setJob', function()
    Wait(100)
    RefreshBlips()
end)

CreateThread(function()
    while not ESX.IsPlayerLoaded or not ESX.IsPlayerLoaded() do Wait(200) end
    TriggerServerEvent('fuel_logistics:requestSync')
    SetupStaticTargets()
end)

function SetupStaticTargets()
    -- Harvest
    for _i, p in ipairs(Config.HarvestPoints) do
        exports.ox_target:addSphereZone({
            coords = p.coords,
            radius = p.radius or 2.0,
            options = {{
                name = 'fl_harvest_' .. p.id,
                icon = 'fa-solid fa-oil-well',
                label = L('target_harvest'),
                canInteract = function() return CanPerm('harvest') end,
                onSelect = function() StartHarvest(p.id) end,
            }},
        })
    end

    -- Refine
    exports.ox_target:addSphereZone({
        coords = Config.RefinePoint.coords,
        radius = Config.RefinePoint.radius or 2.0,
        options = {{
            name = 'fl_refine',
            icon = 'fa-solid fa-industry',
            label = L('target_refine'),
            canInteract = function() return CanPerm('refine') end,
            onSelect = function() StartRefine() end,
        }},
    })

    -- Stash
    exports.ox_target:addSphereZone({
        coords = Config.Stash.coords,
        radius = Config.Stash.radius or 1.5,
        options = {{
            name = 'fl_stash',
            icon = 'fa-solid fa-warehouse',
            label = L('target_stash'),
            canInteract = function() return CanPerm('stash') end,
            onSelect = function()
                exports.ox_inventory:openInventory('stash', Config.Stash.id)
            end,
        }},
    })

    -- Boss
    exports.ox_target:addSphereZone({
        coords = Config.BossMenu.coords,
        radius = Config.BossMenu.radius or 1.5,
        options = {
            {
                name = 'fl_boss',
                icon = 'fa-solid fa-briefcase',
                label = L('target_boss'),
                canInteract = function() return CanPerm('boss') end,
                onSelect = function() OpenBossMenu() end,
            },
            {
                name = 'fl_stations_board',
                icon = 'fa-solid fa-gauge-high',
                label = 'Tableau des stations',
                canInteract = function() return IsFuelJob() end,
                onSelect = function() OpenStationsLiveMenu() end,
            },
        },
    })

    -- Garage truck
    exports.ox_target:addSphereZone({
        coords = Config.Garage.coords,
        radius = Config.Garage.radius or 2.0,
        options = {
            {
                name = 'fl_truck_out',
                icon = 'fa-solid fa-truck',
                label = L('target_garage'),
                canInteract = function() return CanPerm('deliver') and not FL_C.Truck end,
                onSelect = function() SpawnDeliveryTruck() end,
            },
            {
                name = 'fl_truck_store',
                icon = 'fa-solid fa-square-parking',
                label = 'Ranger le camion',
                canInteract = function() return CanPerm('deliver') and FL_C.Truck ~= nil end,
                onSelect = function() StoreDeliveryTruck() end,
            },
            {
                name = 'fl_truck_load',
                icon = 'fa-solid fa-gas-pump',
                label = L('target_load'),
                canInteract = function() return CanPerm('deliver') end,
                onSelect = function() LoadTruckMenu() end,
            },
        },
    })

    -- Export
    exports.ox_target:addSphereZone({
        coords = Config.Export.coords,
        radius = Config.Export.radius or 2.5,
        options = {{
            name = 'fl_export',
            icon = 'fa-solid fa-ship',
            label = L('target_export'),
            canInteract = function() return CanPerm('export') end,
            onSelect = function() StartExport() end,
        }},
    })
end
