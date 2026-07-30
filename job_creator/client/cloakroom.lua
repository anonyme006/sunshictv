function JC_C.OpenCloakroom(marker)
    local job = JC_C.GetJob()
    local outfits = {}
    for _i, o in pairs(JC_C.Outfits) do
        if o.job_name == marker.job_name and job and (job.grade or 0) >= (o.min_grade or 0) then
            outfits[#outfits + 1] = o
        end
    end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'playerMenu',
        data = {
            type = 'cloakroom',
            title = marker.label or 'Vestiaire',
            items = outfits,
        },
    })
end

RegisterNUICallback('cloakApply', function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closePlayerMenu' })

    if data.civilian then
        if ESX.TriggerServerCallback then
            ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
                TriggerEvent('skinchanger:loadSkin', skin)
                JC_C.Notify(L('civilian_outfit'))
            end)
        else
            TriggerEvent('skinchanger:loadSkin')
            JC_C.Notify(L('civilian_outfit'))
        end
        cb({ ok = true })
        return
    end

    local outfit = JC_C.Outfits[tostring(data.id)] or JC_C.Outfits[data.id]
    if outfit and outfit.skin then
        TriggerEvent('skinchanger:getSkin', function(skin)
            TriggerEvent('skinchanger:loadClothes', skin, outfit.skin)
            JC_C.Notify(L('outfit_applied'))
        end)
    end
    cb({ ok = true })
end)

RegisterNUICallback('cloakSaveCurrent', function(data, cb)
    TriggerEvent('skinchanger:getSkin', function(skin)
        TriggerServerEvent('job_creator:saveOutfit', {
            job_name = data.job_name,
            label = data.label or 'Ma tenue',
            min_grade = data.min_grade or 0,
            skin = skin,
            gender = data.gender or 'both',
        })
    end)
    cb({ ok = true })
end)
