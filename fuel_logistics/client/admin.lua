function OpenAdminMenu()
    local stations = lib.callback.await('fuel_logistics:getStations', false) or {}

    local opts = {
        {
            title = 'Créer une station ici',
            icon = 'plus',
            iconColor = '#3ecf8e',
            description = 'Utilise ta position actuelle',
            onSelect = function() CreateStationHere() end,
        },
        {
            title = 'Enregistrer cuve entreprise ici',
            icon = 'building',
            onSelect = function() CreateCompanyTankHere() end,
        },
    }

    for _i, s in ipairs(stations) do
        opts[#opts + 1] = {
            title = s.name,
            description = ('#%d · %d/%d L · %.1f%%'):format(s.id, math.floor(s.level), s.capacity, s.percent),
            icon = 'gas-pump',
            arrow = true,
            onSelect = function() EditStation(s) end,
        }
    end

    lib.registerContext({
        id = 'fl_admin_main',
        title = 'FL Admin — Stations',
        options = opts,
    })
    lib.showContext('fl_admin_main')
end

function CreateStationHere()
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)

    local input = lib.inputDialog('Nouvelle station', {
        { type = 'input', label = 'Nom', required = true, placeholder = 'Station Downtown' },
        { type = 'number', label = 'Capacité (L)', default = 5000, min = 500 },
        { type = 'number', label = 'Niveau initial (L)', default = 0, min = 0 },
        { type = 'number', label = 'Prix d\'achat / L', default = 6, min = 1 },
        { type = 'number', label = 'Consommation / min', default = 2.0, min = 0 },
        { type = 'input', label = 'Job propriétaire (optionnel)', placeholder = 'mechanic' },
    })
    if not input then return end

    local result = lib.callback.await('fuel_logistics:adminCreateStation', false, {
        name = input[1],
        capacity = input[2],
        level = input[3],
        buy_price = input[4],
        consumption = input[5],
        owner_job = input[6],
        coords = { x = FL.Round(c.x, 2), y = FL.Round(c.y, 2), z = FL.Round(c.z, 2) },
    })

    if result and result.ok then
        Notify(L('station_created'), 'success')
        -- Ouvre le tableau live pour voir la nouvelle station
        Wait(300)
        if IsFuelJob() then
            OpenStationsLiveMenu(true)
        end
    else
        Notify(L('no_permission'), 'error')
    end
end

function CreateCompanyTankHere()
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)

    local input = lib.inputDialog('Cuve entreprise', {
        { type = 'input', label = 'Job (name)', required = true, placeholder = 'mechanic' },
        { type = 'input', label = 'Label', required = true, placeholder = 'Mécano' },
        { type = 'number', label = 'Capacité', default = Config.CompanyTanks.defaultCapacity, min = 200 },
        { type = 'number', label = 'Prix livraison / L', default = 10, min = 1 },
    })
    if not input then return end

    local result = lib.callback.await('fuel_logistics:registerCompanyTank', false, {
        job_name = input[1],
        label = input[2],
        capacity = input[3],
        buy_price = input[4],
        coords = { x = FL.Round(c.x, 2), y = FL.Round(c.y, 2), z = FL.Round(c.z, 2) },
    })

    if result and result.ok then
        Notify(L('company_tank_bought'), 'success')
    else
        Notify('Échec', 'error')
    end
end

function EditStation(s)
    lib.registerContext({
        id = 'fl_admin_edit',
        title = s.name,
        menu = 'fl_admin_main',
        options = {
            {
                title = 'Modifier',
                icon = 'pen',
                onSelect = function()
                    local input = lib.inputDialog('Modifier ' .. s.name, {
                        { type = 'input', label = 'Nom', default = s.name },
                        { type = 'number', label = 'Capacité', default = s.capacity },
                        { type = 'number', label = 'Prix / L', default = s.buy_price },
                        { type = 'number', label = 'Consommation / min', default = 2.0 },
                        { type = 'checkbox', label = 'Repositionner ici' },
                    })
                    if not input then return end
                    local data = {
                        id = s.id,
                        name = input[1],
                        capacity = input[2],
                        buy_price = input[3],
                        consumption = input[4],
                    }
                    if input[5] then
                        local c = GetEntityCoords(PlayerPedId())
                        data.coords = { x = FL.Round(c.x, 2), y = FL.Round(c.y, 2), z = FL.Round(c.z, 2) }
                    end
                    local res = lib.callback.await('fuel_logistics:adminUpdateStation', false, data)
                    if res and res.ok then Notify(L('station_updated'), 'success') end
                end,
            },
            {
                title = 'Supprimer',
                icon = 'trash',
                iconColor = '#f07178',
                onSelect = function()
                    local conf = lib.alertDialog({
                        header = 'Supprimer',
                        content = 'Désactiver la station **' .. s.name .. '** ?',
                        centered = true,
                        cancel = true,
                    })
                    if conf ~= 'confirm' then return end
                    local res = lib.callback.await('fuel_logistics:adminDeleteStation', false, s.id)
                    if res and res.ok then Notify(L('station_deleted'), 'success') end
                end,
            },
        },
    })
    lib.showContext('fl_admin_edit')
end

RegisterNetEvent('fuel_logistics:openAdmin', function()
    OpenAdminMenu()
end)
