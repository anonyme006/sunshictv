--- Panneau admin Job Creator

RegisterNetEvent('job_creator:openAdminUI', function(payload)
    JC_C.AdminOpen = true
    SetNuiFocus(true, true)
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local h = GetEntityHeading(ped)
    SendNUIMessage({
        action = 'openAdmin',
        data = payload,
        playerCoords = { x = tonumber(('%.2f'):format(c.x)), y = tonumber(('%.2f'):format(c.y)), z = tonumber(('%.2f'):format(c.z)), w = tonumber(('%.2f'):format(h)) },
    })
end)

RegisterNUICallback('adminClose', function(_, cb)
    JC_C.AdminOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeAdmin' })
    cb({ ok = true })
end)

RegisterNUICallback('adminSaveJob', function(data, cb)
    TriggerServerEvent('job_creator:saveJob', data)
    SetTimeout(400, function()
        TriggerServerEvent('job_creator:reload')
    end)
    cb({ ok = true })
end)

RegisterNUICallback('adminDeleteJob', function(data, cb)
    TriggerServerEvent('job_creator:deleteJob', data.name)
    SetTimeout(400, function()
        TriggerServerEvent('job_creator:reload')
    end)
    cb({ ok = true })
end)

RegisterNUICallback('adminSaveGrade', function(data, cb)
    TriggerServerEvent('job_creator:saveGrade', data)
    SetTimeout(400, function()
        TriggerServerEvent('job_creator:reload')
    end)
    cb({ ok = true })
end)

RegisterNUICallback('adminDeleteGrade', function(data, cb)
    TriggerServerEvent('job_creator:deleteGrade', data.id)
    SetTimeout(400, function()
        TriggerServerEvent('job_creator:reload')
    end)
    cb({ ok = true })
end)

RegisterNUICallback('adminSaveMarker', function(data, cb)
    TriggerServerEvent('job_creator:saveMarker', data)
    SetTimeout(400, function()
        TriggerServerEvent('job_creator:reload')
    end)
    cb({ ok = true })
end)

RegisterNUICallback('adminDeleteMarker', function(data, cb)
    TriggerServerEvent('job_creator:deleteMarker', data.id)
    SetTimeout(400, function()
        TriggerServerEvent('job_creator:reload')
    end)
    cb({ ok = true })
end)

RegisterNUICallback('adminSaveVehicle', function(data, cb)
    TriggerServerEvent('job_creator:saveVehicle', data)
    SetTimeout(400, function()
        TriggerServerEvent('job_creator:reload')
    end)
    cb({ ok = true })
end)

RegisterNUICallback('adminDeleteVehicle', function(data, cb)
    TriggerServerEvent('job_creator:deleteVehicle', data.id)
    SetTimeout(400, function()
        TriggerServerEvent('job_creator:reload')
    end)
    cb({ ok = true })
end)

RegisterNUICallback('adminSaveShopItem', function(data, cb)
    TriggerServerEvent('job_creator:saveShopItem', data)
    SetTimeout(400, function()
        TriggerServerEvent('job_creator:reload')
    end)
    cb({ ok = true })
end)

RegisterNUICallback('adminDeleteShopItem', function(data, cb)
    TriggerServerEvent('job_creator:deleteShopItem', data.id)
    SetTimeout(400, function()
        TriggerServerEvent('job_creator:reload')
    end)
    cb({ ok = true })
end)

RegisterNUICallback('adminSaveCraft', function(data, cb)
    TriggerServerEvent('job_creator:saveCraft', data)
    SetTimeout(400, function()
        TriggerServerEvent('job_creator:reload')
    end)
    cb({ ok = true })
end)

RegisterNUICallback('adminDeleteCraft', function(data, cb)
    TriggerServerEvent('job_creator:deleteCraft', data.id)
    SetTimeout(400, function()
        TriggerServerEvent('job_creator:reload')
    end)
    cb({ ok = true })
end)

RegisterNUICallback('adminGetCoords', function(_, cb)
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local h = GetEntityHeading(ped)
    cb({
        x = tonumber(('%.2f'):format(c.x)),
        y = tonumber(('%.2f'):format(c.y)),
        z = tonumber(('%.2f'):format(c.z)),
        w = tonumber(('%.2f'):format(h)),
    })
end)

RegisterNUICallback('adminSetJob', function(data, cb)
    TriggerServerEvent('job_creator:setPlayerJob', data.targetId, data.job, data.grade)
    cb({ ok = true })
end)

RegisterNUICallback('adminReload', function(_, cb)
    TriggerServerEvent('job_creator:reload')
    cb({ ok = true })
end)

-- ESC
CreateThread(function()
    while true do
        if JC_C.AdminOpen then
            DisableControlAction(0, 200, true)
            if IsDisabledControlJustReleased(0, 200) then
                JC_C.AdminOpen = false
                SetNuiFocus(false, false)
                SendNUIMessage({ action = 'closeAdmin' })
            end
            Wait(0)
        else
            Wait(400)
        end
    end
end)
