function StartExport()
    if not CanPerm('export') then return Notify(_('no_permission'), 'error') end

    local input = lib.inputDialog('Export carburant', {
        {
            type = 'number',
            label = ('Nombre de barils (prix %d$/baril)'):format(Config.Export.pricePerBarrel),
            default = Config.Export.minBarrels or 1,
            min = Config.Export.minBarrels or 1,
            max = 50,
        },
    })
    if not input then return end

    local count = math.floor(tonumber(input[1]) or 0)
    local confirm = lib.alertDialog({
        header = 'Confirmer l\'export',
        content = ('Exporter **%d** baril(s) pour **%d$** (société) ?'):format(count, count * Config.Export.pricePerBarrel),
        centered = true,
        cancel = true,
    })
    if confirm ~= 'confirm' then return end

    local ok = DoProgress(Config.Export.duration, _('progress_export'), Config.Export.anim)
    if not ok then return Notify(_('cancelled'), 'inform') end

    local result = lib.callback.await('fuel_logistics:export', false, count)
    if not result or not result.ok then
        local err = result and result.error
        if err == 'missing' then Notify(_('missing_items'), 'error')
        else Notify(_('cancelled'), 'error') end
        return
    end

    Notify(_('exported', result.barrels, result.amount), 'success')
end
