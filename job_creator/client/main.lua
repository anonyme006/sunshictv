JC_C = JC_C or {}
JC_C.Jobs = {}
JC_C.Markers = {}
JC_C.Vehicles = {}
JC_C.Outfits = {}
JC_C.Shops = {}
JC_C.Crafts = {}
JC_C.OnDuty = true
JC_C.Blips = {}
JC_C.AdminOpen = false

function L(key, ...)
    local str = (Locales[Config.Locale] and Locales[Config.Locale][key]) or key
    if ... then return str:format(...) end
    return str
end

function JC_C.Notify(msg)
    TriggerEvent('esx:showNotification', msg)
end

function JC_C.GetJob()
    local data = ESX.GetPlayerData()
    return data and data.job or nil
end

function JC_C.HasJobAccess(marker)
    if not marker then return false end
    if marker.public then return true end
    local job = JC_C.GetJob()
    if not job then return false end
    if job.name ~= marker.job_name then return false end
    if (job.grade or 0) < (marker.min_grade or 0) then return false end
    return true
end

RegisterNetEvent('job_creator:sync', function(payload)
    if type(payload) ~= 'table' then return end
    JC_C.Jobs = payload.jobs or {}
    JC_C.Markers = payload.markers or {}
    JC_C.Vehicles = payload.vehicles or {}
    JC_C.Outfits = payload.outfits or {}
    JC_C.Shops = payload.shops or {}
    JC_C.Crafts = payload.crafts or {}
    JC_C.RefreshBlips()
end)

RegisterNetEvent('job_creator:dutyChanged', function(state)
    JC_C.OnDuty = state
end)

CreateThread(function()
    while not ESX do Wait(100) end
    while not ESX.IsPlayerLoaded or not ESX.IsPlayerLoaded() do Wait(200) end
    TriggerServerEvent('job_creator:requestSync')
end)

function JC_C.RefreshBlips()
    for _i, b in pairs(JC_C.Blips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    JC_C.Blips = {}

    local job = JC_C.GetJob()

    for name, j in pairs(JC_C.Jobs) do
        if j.blip and j.blip.sprite and j.blip.sprite > 0 and j.blip.coords then
            local c = j.blip.coords
            local blip = AddBlipForCoord(c.x + 0.0, c.y + 0.0, c.z + 0.0)
            SetBlipSprite(blip, j.blip.sprite)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, j.blip.scale or 0.8)
            SetBlipColour(blip, j.blip.color or 0)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(j.label or name)
            EndTextCommandSetBlipName(blip)
            JC_C.Blips[#JC_C.Blips + 1] = blip
        end
    end

    for _i, m in pairs(JC_C.Markers) do
        if m.blip_enabled and m.coords then
            if m.public or (job and job.name == m.job_name) then
                local c = m.coords
                local blip = AddBlipForCoord(c.x + 0.0, c.y + 0.0, c.z + 0.0)
                SetBlipSprite(blip, m.blip_sprite or 1)
                SetBlipDisplay(blip, 4)
                SetBlipScale(blip, m.blip_scale or 0.7)
                SetBlipColour(blip, m.blip_color or 0)
                SetBlipAsShortRange(blip, true)
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentSubstringPlayerName(m.label or m.type)
                EndTextCommandSetBlipName(blip)
                JC_C.Blips[#JC_C.Blips + 1] = blip
            end
        end
    end
end

RegisterNetEvent('esx:setJob', function()
    Wait(100)
    JC_C.RefreshBlips()
end)

-- Help text
function JC_C.Help(msg)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

-- Progress simple
function JC_C.Progress(ms, label)
    local endAt = GetGameTimer() + ms
    local ped = PlayerPedId()
    local dict = Config.FarmAnim.dict
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(10) end
    TaskPlayAnim(ped, dict, Config.FarmAnim.clip, 8.0, -8.0, -1, Config.FarmAnim.flag, 0, false, false, false)

    while GetGameTimer() < endAt do
        Wait(0)
        DisableAllControlActions(0)
        EnableControlAction(0, 1, true)
        EnableControlAction(0, 2, true)
        JC_C.Help(label or '…')
    end
    ClearPedTasks(ped)
end
