function StartHarvest(pointId)
    if not CanPerm('harvest') then return Notify(L('no_permission'), 'error') end

    local ok = DoProgress(Config.Harvest.duration, L('progress_harvest'), Config.Harvest.anim)
    if not ok then return Notify(L('cancelled'), 'inform') end

    local result = lib.callback.await('fuel_logistics:harvest', false, pointId)
    if not result or not result.ok then
        local err = result and result.error
        if err == 'inventory' then Notify(L('inventory_full'), 'error')
        elseif err == 'permission' then Notify(L('no_permission'), 'error')
        elseif err == 'busy' then Notify(L('busy'), 'error')
        else Notify(L('cancelled'), 'error') end
        return
    end

    Notify(L('harvested', result.count), 'success')
end
