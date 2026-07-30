function OpenOrdersMenu()
    if not IsFuelJob() then return Notify(L('need_job'), 'error') end

    local orders = lib.callback.await('fuel_logistics:getOrders', false) or {}
    local opts = {}

    for _i, o in ipairs(orders) do
        local color = o.status == 'pending' and '#e6b35a' or '#3d8bfd'
        opts[#opts + 1] = {
            title = ('#%d — %s'):format(o.id, o.target_name or 'Cible'),
            description = ('%d L · %s · reward %d$ · %s'):format(o.liters or 0, o.status, o.reward or 0, o.expires_at or ''),
            icon = 'clipboard-list',
            iconColor = color,
            arrow = true,
            onSelect = function()
                OpenOrderActions(o)
            end,
        }
    end

    if #opts == 0 then
        opts[1] = { title = 'Aucune commande active', icon = 'inbox', disabled = true }
    end

    lib.registerContext({
        id = 'fl_orders',
        title = 'Commandes automatiques',
        options = opts,
    })
    lib.showContext('fl_orders')
end

function OpenOrderActions(order)
    local opts = {}

    if order.status == 'pending' then
        opts[#opts + 1] = {
            title = 'Accepter',
            icon = 'check',
            iconColor = '#3ecf8e',
            onSelect = function()
                local res = lib.callback.await('fuel_logistics:acceptOrder', false, order.id)
                if res and res.ok then
                    Notify(L('order_accepted'), 'success')
                    -- Waypoint si station connue
                    local target = FL_C.Stations[tostring(order.target_id)] or FL_C.Companies[tostring(order.target_id)]
                    if target and target.coords then
                        SetNewWaypoint(target.coords.x + 0.0, target.coords.y + 0.0)
                    end
                else
                    Notify('Impossible', 'error')
                end
            end,
        }
        opts[#opts + 1] = {
            title = 'Refuser',
            icon = 'xmark',
            iconColor = '#f07178',
            onSelect = function()
                lib.callback.await('fuel_logistics:declineOrder', false, order.id)
                Notify(L('order_declined'), 'inform')
            end,
        }
    else
        opts[#opts + 1] = {
            title = 'Acceptée par ' .. (order.accepted_name or '?'),
            icon = 'user-check',
            disabled = true,
        }
        opts[#opts + 1] = {
            title = 'Mettre le GPS',
            icon = 'location-dot',
            onSelect = function()
                local target = FL_C.Stations[tostring(order.target_id)] or FL_C.Companies[tostring(order.target_id)]
                if target and target.coords then
                    SetNewWaypoint(target.coords.x + 0.0, target.coords.y + 0.0)
                    Notify('GPS défini', 'success')
                end
            end,
        }
    end

    opts[#opts + 1] = { title = 'Retour', icon = 'arrow-left', onSelect = OpenOrdersMenu }

    lib.registerContext({
        id = 'fl_order_actions',
        title = 'Commande #' .. order.id,
        menu = 'fl_orders',
        options = opts,
    })
    lib.showContext('fl_order_actions')
end

RegisterNetEvent('fuel_logistics:newOrder', function(data)
    if not IsFuelJob() then return end
    lib.notify({
        title = L('notify_title'),
        description = L('order_new', data.target_name or '?', data.liters or 0),
        type = 'warning',
        duration = 10000,
        position = 'top-right',
    })
end)

RegisterNetEvent('fuel_logistics:orderPing', function()
    PlaySoundFrontend(-1, 'Menu_Accept', 'Phone_SoundSet_Default', true)
end)

-- Raccourci commandes
RegisterCommand('florders', function()
    OpenOrdersMenu()
end, false)
