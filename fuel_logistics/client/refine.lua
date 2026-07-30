function StartRefine()
    if not CanPerm('refine') then return Notify(_('no_permission'), 'error') end

    local input = lib.inputDialog('Raffinage', {
        {
            type = 'number',
            label = ('Cycles (1 cycle = %sx %s → %sx %s)'):format(
                Config.Refine.inputCount, Config.Refine.inputItem,
                Config.Refine.outputCount, Config.Refine.outputItem
            ),
            default = 1,
            min = 1,
            max = 20,
        },
    })
    if not input then return end

    local cycles = math.floor(tonumber(input[1]) or 1)
    for i = 1, cycles do
        local ok = DoProgress(Config.Refine.duration, _('progress_refine') .. (' (%d/%d)'):format(i, cycles), Config.Refine.anim)
        if not ok then
            Notify(_('cancelled'), 'inform')
            break
        end

        local result = lib.callback.await('fuel_logistics:refine', false)
        if not result or not result.ok then
            local err = result and result.error
            if err == 'missing' then Notify(_('missing_items'), 'error')
            elseif err == 'inventory' then Notify(_('inventory_full'), 'error')
            else Notify(_('cancelled'), 'error') end
            break
        end
        Notify(_('refined', result.count), 'success')
    end
end
