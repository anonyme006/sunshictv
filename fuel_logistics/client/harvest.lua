function StartHarvest(pointId)
    if not CanPerm('harvest') then return Notify(_('no_permission'), 'error') end

    local ok = DoProgress(Config.Harvest.duration, _('progress_harvest'), Config.Harvest.anim)
    if not ok then return Notify(_('cancelled'), 'inform') end

    local result = lib.callback.await('fuel_logistics:harvest', false, pointId)
    if not result or not result.ok then
        local err = result and result.error
        if err == 'inventory' then Notify(_('inventory_full'), 'error')
        elseif err == 'permission' then Notify(_('no_permission'), 'error')
        elseif err == 'busy' then Notify(_('busy'), 'error')
        else Notify(_('cancelled'), 'error') end
        return
    end

    Notify(_('harvested', result.count), 'success')
end
