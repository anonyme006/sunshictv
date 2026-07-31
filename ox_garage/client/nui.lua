--[[
    Pont NUI + aperçu monde (caméra)
]]

local nuiOpen = false
local previewVeh, previewCam
local pendingJobData

local function uiMode()
    return (Config.UI and Config.UI.mode) or 'nui'
end

function IsGarageNuiOpen()
    return nuiOpen
end

local function cleanupPreview()
    if previewCam then
        RenderScriptCams(false, true, 250, true, true)
        DestroyCam(previewCam, false)
        previewCam = nil
    end
    if previewVeh and DoesEntityExist(previewVeh) then
        SetEntityAsMissionEntity(previewVeh, true, true)
        DeleteVehicle(previewVeh)
        previewVeh = nil
    end
end

local function spawnPreview(model, props)
    if not Config.UI or not Config.UI.useWorldPreview then return end
    cleanupPreview()

    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return end

    lib.requestModel(hash, 4000)
    local ped = PlayerPedId()
    local pcoords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    local offset = Config.UI.previewOffset or vec3(3.5, 6.0, 0.4)
    local x = pcoords.x + forward.x * offset.y + (-forward.y) * offset.x
    local y = pcoords.y + forward.y * offset.y + forward.x * offset.x
    local z = pcoords.z + offset.z
    local heading = GetEntityHeading(ped) + 140.0

    previewVeh = CreateVehicle(hash, x, y, z, heading, false, false)
    if not previewVeh or previewVeh == 0 then
        SetModelAsNoLongerNeeded(hash)
        return
    end

    SetEntityCollision(previewVeh, false, false)
    FreezeEntityPosition(previewVeh, true)
    SetEntityInvincible(previewVeh, true)
    SetVehicleDoorsLocked(previewVeh, 2)
    SetEntityAlpha(previewVeh, 210, false)
    if props then SetVehicleProps(previewVeh, props) end
    SetModelAsNoLongerNeeded(hash)

    local vehCoords = GetEntityCoords(previewVeh)
    local camPos = vehCoords + vector3(
        math.cos(math.rad(heading + 35.0)) * 5.2,
        math.sin(math.rad(heading + 35.0)) * 5.2,
        1.6
    )
    previewCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(previewCam, camPos.x, camPos.y, camPos.z)
    PointCamAtEntity(previewCam, previewVeh, 0.0, 0.0, 0.4, true)
    SetCamFov(previewCam, Config.UI.previewFov or 42.0)
    SetCamActive(previewCam, true)
    RenderScriptCams(true, true, 350, true, true)
end

local function enrichVehicles(list)
    local out = {}
    for _i, v in ipairs(list or {}) do
        local model = v.model
        local hash = type(model) == 'number' and model or joaat(model or 0)
        local name = v.label
        if not name or name == '' then
            name = GetVehicleDisplayName(hash)
        end
        local display = GetDisplayNameFromVehicleModel(hash)
        out[#out + 1] = {
            plate = v.plate,
            model = hash,
            modelName = display,
            name = name,
            props = v.props,
            stored = v.stored == true,
            engine = v.engine or 100,
            body = v.body or 100,
            fuel = v.fuel or 100,
            type = v.type,
            class = GetVehicleClassFromName(hash),
            isPersonal = v.isPersonal == true,
            isJob = v.isJob == true,
            garage = v.garage or v.garage_id,
        }
    end
    return out
end

--- Ouvre la NUI garage perso
function OpenGarageNui(garageId, vehicles, extra)
    if uiMode() ~= 'nui' then return false end
    local garage = GetGarageById(garageId)
    if not garage then return false end

    extra = extra or {}
    nuiOpen = true
    pendingJobData = nil
    SetNuiFocus(true, true)

    SendNUIMessage({
        action = 'open',
        mode = 'personal',
        garageId = garageId,
        label = garage.label,
        type = garage.type or 'car',
        kind = garage.kind or 'public',
        location = garage.label,
        brand = (Config.UI and Config.UI.brand) or 'OX GARAGE',
        logo = (Config.UI and Config.UI.logo) or 'img/logo.svg',
        theme = (Config.UI and Config.UI.theme) or {},
        privateOwned = extra.privateOwned ~= false,
        vehicles = enrichVehicles(vehicles),
    })
    return true
end

--- Ouvre la NUI garage job
function OpenJobGarageNui(data, vehicles)
    if uiMode() ~= 'nui' then return false end
    if not data then return false end

    nuiOpen = true
    pendingJobData = data
    SetNuiFocus(true, true)

    SendNUIMessage({
        action = 'open',
        mode = 'job',
        job = data.job,
        garageId = tostring(data.garageId or ''),
        label = data.label or L('job_menu_title', data.job),
        type = data.type or 'car',
        kind = 'job',
        location = data.label or data.job,
        brand = (Config.UI and Config.UI.brand) or 'OX GARAGE',
        logo = (Config.UI and Config.UI.logo) or 'img/logo.svg',
        theme = (Config.UI and Config.UI.theme) or {},
        vehicles = enrichVehicles(vehicles),
    })
    return true
end

function CloseGarageNui()
    if not nuiOpen then return end
    nuiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    cleanupPreview()
end

RegisterNUICallback('garageClose', function(_, cb)
    CloseGarageNui()
    cb({ ok = true })
end)

RegisterNUICallback('garageSelect', function(data, cb)
    if data and data.model then
        spawnPreview(data.model, data.props)
    end
    cb({ ok = true })
end)

RegisterNUICallback('garageManage', function(data, cb)
    CloseGarageNui()
    if data and data.garageId then
        SetTimeout(120, function()
            OpenPrivateAccessMenu(data.garageId)
        end)
    end
    cb({ ok = true })
end)

RegisterNUICallback('garageTakeOut', function(data, cb)
    cb({ ok = true })
    if not data or not data.plate then return end

    local jobSnapshot = pendingJobData
    CloseGarageNui()

    SetTimeout(100, function()
        if data.mode == 'job' then
            local ctx = jobSnapshot or {
                job = data.job,
                garageId = data.garageId,
            }
            TakeOutJobVehicle(ctx, {
                plate = data.plate,
                isPersonal = data.isPersonal == true,
            })
        else
            TakeOutVehicle(data.garageId, { plate = data.plate })
        end
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    CloseGarageNui()
end)
