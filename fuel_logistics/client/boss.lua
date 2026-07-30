function OpenBossMenu()
    if not CanPerm('boss') then return Notify(_('no_permission'), 'error') end

    local stats = lib.callback.await('fuel_logistics:bossStats', false)
    if not stats then return Notify(_('no_permission'), 'error') end

    local chartLines = {}
    for _, row in ipairs(stats.chart or {}) do
        chartLines[#chartLines + 1] = ('%s : %d L · %d$'):format(row.day or '?', math.floor(row.liters or 0), math.floor(row.amount or 0))
    end

    lib.registerContext({
        id = 'fl_boss_main',
        title = Config.JobLabel .. ' — Patron',
        options = {
            {
                title = 'Société',
                description = ('Solde : %s$'):format(lib.math and lib.math.groupdigits and lib.math.groupdigits(stats.money) or stats.money),
                icon = 'building-columns',
                iconColor = '#3ecf8e',
                onSelect = function() OpenBossSociety(stats) end,
            },
            {
                title = 'Statistiques',
                description = ('Livraisons %d · Export %d · Gain %d$ · Dépenses %d$'):format(
                    stats.deliveries.cnt or 0, stats.exports.cnt or 0, stats.earned or 0, stats.spent or 0
                ),
                icon = 'chart-line',
                metadata = {
                    { label = 'Litres livrés', value = tostring(math.floor(stats.deliveries.liters or 0)) },
                    { label = 'CA livraisons', value = (stats.deliveries.amount or 0) .. '$' },
                    { label = 'Barils exportés', value = tostring(stats.exports.barrels or 0) },
                    { label = 'CA export', value = (stats.exports.amount or 0) .. '$' },
                },
                onSelect = function()
                    lib.registerContext({
                        id = 'fl_boss_chart',
                        title = 'Livraisons (7 jours)',
                        menu = 'fl_boss_main',
                        options = (#chartLines > 0) and (function()
                            local opts = {}
                            for _, line in ipairs(chartLines) do
                                opts[#opts + 1] = { title = line, icon = 'calendar-day' }
                            end
                            opts[#opts + 1] = { title = 'Retour', icon = 'arrow-left', menu = 'fl_boss_main' }
                            return opts
                        end)() or { { title = 'Pas de données', disabled = true } },
                    })
                    lib.showContext('fl_boss_chart')
                end,
            },
            {
                title = 'Historique récent',
                icon = 'clock-rotate-left',
                arrow = true,
                onSelect = function() OpenBossHistory(stats.recent or {}) end,
            },
            {
                title = 'Stations (live)',
                description = (#(stats.stations or {})) .. ' stations — niveaux en direct',
                icon = 'gas-pump',
                arrow = true,
                onSelect = function() OpenStationsLiveMenu() end,
            },
            {
                title = 'Entreprises clientes',
                description = (#(stats.companies or {})) .. ' cuves',
                icon = 'building',
                arrow = true,
                onSelect = function() OpenBossCompanies(stats.companies or {}) end,
            },
            {
                title = 'Employés',
                description = (#(stats.employees or {})) .. ' en service',
                icon = 'users',
                arrow = true,
                onSelect = function() OpenBossEmployees(stats) end,
            },
            {
                title = 'Commandes',
                icon = 'clipboard-list',
                onSelect = function() OpenOrdersMenu() end,
            },
        },
    })
    lib.showContext('fl_boss_main')
end

function OpenBossSociety(stats)
    lib.registerContext({
        id = 'fl_boss_society',
        title = 'Compte société',
        menu = 'fl_boss_main',
        options = {
            {
                title = (stats.money or 0) .. ' $',
                icon = 'sack-dollar',
                iconColor = '#3ecf8e',
            },
            {
                title = 'Déposer',
                icon = 'arrow-down',
                onSelect = function()
                    local input = lib.inputDialog('Dépôt', { { type = 'number', label = 'Montant', min = 1 } })
                    if not input then return end
                    local res = lib.callback.await('fuel_logistics:societyDeposit', false, input[1])
                    if res and res.ok then Notify('Dépôt effectué', 'success') else Notify('Échec', 'error') end
                    OpenBossMenu()
                end,
            },
            {
                title = 'Retirer',
                icon = 'arrow-up',
                onSelect = function()
                    local input = lib.inputDialog('Retrait', { { type = 'number', label = 'Montant', min = 1 } })
                    if not input then return end
                    local res = lib.callback.await('fuel_logistics:societyWithdraw', false, input[1])
                    if res and res.ok then Notify('Retrait effectué', 'success') else Notify('Échec', 'error') end
                    OpenBossMenu()
                end,
            },
        },
    })
    lib.showContext('fl_boss_society')
end

function OpenBossHistory(rows)
    local opts = {}
    for _, r in ipairs(rows) do
        opts[#opts + 1] = {
            title = ('[%s] %s'):format(r.type, r.target_name or r.player_name or '—'),
            description = ('%s L · %s$ · %s'):format(math.floor(r.liters or 0), r.amount or 0, r.created_at or ''),
            icon = r.type == 'export' and 'ship' or (r.type == 'delivery' and 'truck' or 'circle'),
        }
    end
    if #opts == 0 then opts[1] = { title = 'Vide', disabled = true } end
    opts[#opts + 1] = { title = 'Retour', icon = 'arrow-left', onSelect = OpenBossMenu }
    lib.registerContext({ id = 'fl_boss_history', title = 'Historique', menu = 'fl_boss_main', options = opts })
    lib.showContext('fl_boss_history')
end

function OpenBossStations(stations)
    local opts = {}
    for _, s in ipairs(stations) do
        local color = s.percent < 20 and '#f07178' or (s.percent < 50 and '#e6b35a' or '#3ecf8e')
        opts[#opts + 1] = {
            title = s.name,
            description = ('%d / %d L (%.1f%%)'):format(math.floor(s.level), s.capacity, s.percent),
            icon = 'gas-pump',
            iconColor = color,
            progress = s.percent,
            colorScheme = s.percent < 20 and 'red' or (s.percent < 50 and 'yellow' or 'green'),
        }
    end
    opts[#opts + 1] = { title = 'Retour', icon = 'arrow-left', onSelect = OpenBossMenu }
    lib.registerContext({ id = 'fl_boss_stations', title = 'Stations', menu = 'fl_boss_main', options = opts })
    lib.showContext('fl_boss_stations')
end

function OpenBossCompanies(companies)
    local opts = {}
    for _, c in ipairs(companies) do
        opts[#opts + 1] = {
            title = c.label,
            description = ('%s · %d / %d L (%.1f%%)'):format(c.job_name, math.floor(c.level), c.capacity, c.percent),
            icon = 'building',
            progress = c.percent,
        }
    end
    if #opts == 0 then opts[1] = { title = 'Aucune cuve cliente', disabled = true } end
    opts[#opts + 1] = { title = 'Retour', icon = 'arrow-left', onSelect = OpenBossMenu }
    lib.registerContext({ id = 'fl_boss_companies', title = 'Clients', menu = 'fl_boss_main', options = opts })
    lib.showContext('fl_boss_companies')
end

function OpenBossEmployees(stats)
    local opts = {}
    for _, e in ipairs(stats.employees or {}) do
        opts[#opts + 1] = {
            title = e.name,
            description = e.grade_label or ('Grade ' .. tostring(e.grade)),
            icon = 'user',
            arrow = true,
            onSelect = function()
                lib.registerContext({
                    id = 'fl_boss_emp_actions',
                    title = e.name,
                    menu = 'fl_boss_employees',
                    options = {
                        {
                            title = 'Changer grade',
                            icon = 'arrow-up-right-dots',
                            onSelect = function()
                                local gradeOpts = {}
                                for _, g in ipairs(stats.grades or {}) do
                                    gradeOpts[#gradeOpts + 1] = { value = g.grade, label = g.label }
                                end
                                local input = lib.inputDialog('Grade', {
                                    { type = 'select', label = 'Nouveau grade', options = gradeOpts },
                                })
                                if not input then return end
                                local res = lib.callback.await('fuel_logistics:setEmployeeGrade', false, e.id, input[1])
                                if res and res.ok then Notify('Grade mis à jour', 'success') else Notify('Impossible', 'error') end
                                OpenBossMenu()
                            end,
                        },
                        {
                            title = 'Licencier',
                            icon = 'user-xmark',
                            iconColor = '#f07178',
                            onSelect = function()
                                local conf = lib.alertDialog({
                                    header = 'Licenciement',
                                    content = 'Licencier ' .. e.name .. ' ?',
                                    centered = true,
                                    cancel = true,
                                })
                                if conf ~= 'confirm' then return end
                                local res = lib.callback.await('fuel_logistics:fireEmployee', false, e.id)
                                if res and res.ok then Notify('Licencié', 'success') end
                                OpenBossMenu()
                            end,
                        },
                    },
                })
                lib.showContext('fl_boss_emp_actions')
            end,
        }
    end
    opts[#opts + 1] = {
        title = 'Recruter (ID serveur)',
        icon = 'user-plus',
        onSelect = function()
            local input = lib.inputDialog('Recrutement', {
                { type = 'number', label = 'ID joueur', min = 1 },
                { type = 'number', label = 'Grade', default = 0, min = 0 },
            })
            if not input then return end
            local res = lib.callback.await('fuel_logistics:hireNearby', false, input[1], input[2])
            if res and res.ok then Notify('Recruté', 'success') else Notify('Échec', 'error') end
            OpenBossMenu()
        end,
    }
    opts[#opts + 1] = { title = 'Retour', icon = 'arrow-left', onSelect = OpenBossMenu }
    lib.registerContext({ id = 'fl_boss_employees', title = 'Employés', menu = 'fl_boss_main', options = opts })
    lib.showContext('fl_boss_employees')
end

RegisterNetEvent('fuel_logistics:openBoss', function()
    OpenBossMenu()
end)
