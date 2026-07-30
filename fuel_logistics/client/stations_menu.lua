--[[
    Tableau de bord live — niveaux de toutes les stations
    Se met à jour automatiquement ; les stations créées in-game apparaissent aussitôt.
]]

FL_C.StationsMenuOpen = false
local refreshThread = false

local function percentColor(pct)
    if pct < 20 then return '#f07178', 'red' end
    if pct < 50 then return '#e6b35a', 'yellow' end
    return '#3ecf8e', 'green'
end

local function formatLiters(n)
    n = math.floor(tonumber(n) or 0)
    local s = tostring(n)
    local k
    while true do
        s, k = s:gsub('^(-?%d+)(%d%d%d)', '%1 %2')
        if k == 0 then break end
    end
    return s .. ' L'
end

--- Construit et affiche le menu (données fraîches serveur)
function OpenStationsLiveMenu(keepOpen)
    if not IsFuelJob() then
        return Notify(_('need_job'), 'error')
    end

    local stations = lib.callback.await('fuel_logistics:getStations', false) or {}
    local companies = lib.callback.await('fuel_logistics:getCompanies', false) or {}

    -- Sync local pour les blips / livraisons
    for _, s in ipairs(stations) do
        FL_C.Stations[tostring(s.id)] = {
            id = s.id,
            name = s.name,
            coords = s.coords,
            capacity = s.capacity,
            level = s.level,
            buy_price = s.buy_price,
        }
    end

    local opts = {
        {
            title = 'Actualiser',
            description = 'Rafraîchir les niveaux en direct',
            icon = 'arrows-rotate',
            iconColor = '#3d8bfd',
            onSelect = function()
                OpenStationsLiveMenu(true)
            end,
        },
        {
            title = ('Stations (%d)'):format(#stations),
            icon = 'gas-pump',
            disabled = true,
        },
    }

    if #stations == 0 then
        opts[#opts + 1] = {
            title = 'Aucune station',
            description = 'Crée-en une avec /fladmin',
            icon = 'inbox',
            disabled = true,
        }
    else
        table.sort(stations, function(a, b)
            return (a.percent or 0) < (b.percent or 0) -- plus vides en premier
        end)

        for _, s in ipairs(stations) do
            local pct = s.percent or 0
            local iconColor, scheme = percentColor(pct)
            local status = pct < 20 and '⚠ CRITIQUE' or (pct < 50 and 'Faible' or 'OK')

            opts[#opts + 1] = {
                title = s.name,
                description = ('%s / %s  ·  %.1f%%  ·  %s'):format(
                    formatLiters(s.level),
                    formatLiters(s.capacity),
                    pct,
                    status
                ),
                icon = 'gas-pump',
                iconColor = iconColor,
                progress = math.floor(pct),
                colorScheme = scheme,
                metadata = {
                    { label = 'Niveau', value = formatLiters(s.level) },
                    { label = 'Capacité', value = formatLiters(s.capacity) },
                    { label = 'Remplissage', value = ('%.1f %%'):format(pct) },
                    { label = 'Prix / L', value = (s.buy_price or 0) .. '$' },
                    { label = 'ID', value = tostring(s.id) },
                },
                arrow = true,
                onSelect = function()
                    OpenStationDetailLive(s)
                end,
            }
        end
    end

    if #companies > 0 then
        opts[#opts + 1] = {
            title = ('Cuves entreprises (%d)'):format(#companies),
            icon = 'building',
            disabled = true,
        }
        table.sort(companies, function(a, b)
            return (a.percent or 0) < (b.percent or 0)
        end)
        for _, c in ipairs(companies) do
            local pct = c.percent or 0
            local iconColor, scheme = percentColor(pct)
            opts[#opts + 1] = {
                title = c.label,
                description = ('%s / %s  ·  %.1f%%  ·  %s'):format(
                    formatLiters(c.level),
                    formatLiters(c.capacity),
                    pct,
                    c.job_name or ''
                ),
                icon = 'building',
                iconColor = iconColor,
                progress = math.floor(pct),
                colorScheme = scheme,
                metadata = {
                    { label = 'Niveau', value = formatLiters(c.level) },
                    { label = 'Capacité', value = formatLiters(c.capacity) },
                    { label = 'Job', value = c.job_name or '—' },
                },
            }
        end
    end

    opts[#opts + 1] = {
        title = 'Fermer le suivi live',
        icon = 'xmark',
        onSelect = function()
            FL_C.StationsMenuOpen = false
        end,
    }

    FL_C.StationsMenuOpen = true

    lib.registerContext({
        id = 'fl_stations_live',
        title = 'Stations — niveaux live',
        options = opts,
    })
    lib.showContext('fl_stations_live')

    StartStationsLiveRefresh()
end

function OpenStationDetailLive(s)
    local pct = s.percent or 0
    local iconColor = percentColor(pct)

    lib.registerContext({
        id = 'fl_station_live_detail',
        title = s.name,
        menu = 'fl_stations_live',
        options = {
            {
                title = formatLiters(s.level),
                description = ('sur %s (%.1f%%)'):format(formatLiters(s.capacity), pct),
                icon = 'droplet',
                iconColor = iconColor,
                progress = math.floor(pct),
            },
            {
                title = 'Mettre le GPS',
                icon = 'location-dot',
                onSelect = function()
                    if s.coords then
                        SetNewWaypoint(s.coords.x + 0.0, s.coords.y + 0.0)
                        Notify('GPS : ' .. s.name, 'success')
                    end
                end,
            },
            {
                title = 'Actualiser',
                icon = 'arrows-rotate',
                onSelect = function()
                    OpenStationsLiveMenu(true)
                end,
            },
            {
                title = 'Retour à la liste',
                icon = 'arrow-left',
                onSelect = function()
                    OpenStationsLiveMenu(true)
                end,
            },
        },
    })
    lib.showContext('fl_station_live_detail')
end

--- Rafraîchit le menu toutes les 5s tant qu'il est considéré ouvert
function StartStationsLiveRefresh()
    if refreshThread then return end
    refreshThread = true

    CreateThread(function()
        while FL_C.StationsMenuOpen do
            Wait(5000)
            if not FL_C.StationsMenuOpen then break end
            -- Ne force le re-show que si le context live est encore le focus
            if lib.getOpenContextMenu and lib.getOpenContextMenu() == 'fl_stations_live' then
                OpenStationsLiveMenu(true)
            elseif not lib.getOpenContextMenu then
                -- ox_lib sans getOpenContextMenu : on rafraîchit silencieusement les données locales
                local stations = lib.callback.await('fuel_logistics:getStations', false) or {}
                for _, s in ipairs(stations) do
                    if FL_C.Stations[tostring(s.id)] then
                        FL_C.Stations[tostring(s.id)].level = s.level
                        FL_C.Stations[tostring(s.id)].capacity = s.capacity
                    else
                        FL_C.Stations[tostring(s.id)] = {
                            id = s.id, name = s.name, coords = s.coords,
                            capacity = s.capacity, level = s.level, buy_price = s.buy_price,
                        }
                    end
                end
            end
        end
        refreshThread = false
    end)
end

-- Quand le serveur pousse les niveaux (conso / livraison), maj locale
RegisterNetEvent('fuel_logistics:updateLevels', function(payload)
    if type(payload) ~= 'table' then return end
    for id, level in pairs(payload.stations or {}) do
        if FL_C.Stations[id] then
            FL_C.Stations[id].level = level
        end
    end
    for id, level in pairs(payload.companies or {}) do
        if FL_C.Companies[id] then
            FL_C.Companies[id].level = level
        end
    end
end)

-- Nouvelle station créée → sync déjà via fuel_logistics:sync ; notif employés
RegisterNetEvent('fuel_logistics:sync', function(payload)
    if type(payload) ~= 'table' then return end
    -- main.lua gère aussi ; ici on s'assure que le menu live voit les nouvelles
    if FL_C.StationsMenuOpen and IsFuelJob() then
        Notify('Liste des stations mise à jour', 'inform')
    end
end)

RegisterCommand('flstations', function()
    OpenStationsLiveMenu()
end, false)

RegisterKeyMapping('flstations', 'Fuel Logistics — Stations live', 'keyboard', '')

RegisterNetEvent('fuel_logistics:openStationsLive', function()
    OpenStationsLiveMenu()
end)

RegisterNetEvent('fuel_logistics:stationCreated', function(data)
    if not IsFuelJob() then return end
    -- Force refresh si le tableau live est ouvert
    if FL_C.StationsMenuOpen then
        Wait(200)
        OpenStationsLiveMenu(true)
    end
end)
