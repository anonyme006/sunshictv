local interacting = false

local function drawMarker(m)
    local c = m.coords
    local s = m.marker_scale or Config.DefaultMarker.scale
    local col = m.marker_color or Config.DefaultMarker.color
    DrawMarker(
        m.marker_type or 1,
        c.x, c.y, c.z - 0.95,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        s.x or 1.0, s.y or 1.0, s.z or 0.8,
        col.r or 50, col.g or 150, col.b or 255, col.a or 120,
        false, false, 2, false, nil, nil, false
    )
end

local function interact(marker)
    if interacting then return end
    local id = marker.id
    local t = marker.type

    if t == 'boss' then
        JC_C.OpenBossMenu(marker)
    elseif t == 'stash' or t == 'armory' then
        TriggerServerEvent('job_creator:openStash', id)
    elseif t == 'cloakroom' then
        JC_C.OpenCloakroom(marker)
    elseif t == 'garage' then
        JC_C.OpenGarage(marker)
    elseif t == 'garage_store' then
        JC_C.StoreVehicle(marker)
    elseif t == 'shop' then
        JC_C.OpenShop(marker)
    elseif t == 'duty' then
        TriggerServerEvent('job_creator:toggleDuty')
    elseif t == 'harvest' then
        interacting = true
        JC_C.Progress(Config.HarvestTime, 'Récolte…')
        TriggerServerEvent('job_creator:harvest', id)
        interacting = false
    elseif t == 'process' then
        interacting = true
        JC_C.Progress(Config.ProcessTime, 'Traitement…')
        TriggerServerEvent('job_creator:process', id)
        interacting = false
    elseif t == 'craft' then
        JC_C.OpenCraft(marker)
    elseif t == 'sell' then
        interacting = true
        JC_C.Progress(Config.SellTime, 'Vente…')
        TriggerServerEvent('job_creator:sell', id)
        interacting = false
    elseif t == 'teleport' then
        local dest = marker.data and marker.data.destination
        if dest then
            DoScreenFadeOut(400)
            Wait(500)
            SetEntityCoords(PlayerPedId(), dest.x + 0.0, dest.y + 0.0, dest.z + 0.0, false, false, false, false)
            if dest.w then SetEntityHeading(PlayerPedId(), dest.w + 0.0) end
            DoScreenFadeIn(400)
            JC_C.Notify(L('teleported'))
        end
    elseif t == 'wash' then
        JC_C.OpenWash(marker)
    end
end

CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)

        for _i, m in pairs(JC_C.Markers) do
            if m.enabled ~= false and m.coords and JC_C.HasJobAccess(m) then
                local c = m.coords
                local dist = #(coords - vector3(c.x + 0.0, c.y + 0.0, c.z + 0.0))
                if dist < Config.MarkerDistance then
                    sleep = 0
                    drawMarker(m)
                    if dist < Config.InteractDistance then
                        JC_C.Help((L('press_interact')):format(m.label or m.type))
                        if IsControlJustReleased(0, 38) then -- E
                            interact(m)
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)
