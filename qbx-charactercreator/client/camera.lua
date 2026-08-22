CreatorCamera = {}

local cam
local currentPreset = 'body'
local headingOffset = 0.0
local transitioning = false

local function lerp(a, b, t)
    return a + ((b - a) * t)
end

local function easeInOut(t)
    return t * t * (3.0 - (2.0 * t))
end

local function cameraWorld(presetName)
    local preset = Config.Cameras[presetName] or Config.Cameras.body
    local ped = PlayerPedId()
    local coords = GetOffsetFromEntityInWorldCoords(ped, preset.offset.x, preset.offset.y, preset.offset.z)
    local point = GetOffsetFromEntityInWorldCoords(ped, preset.point.x, preset.point.y, preset.point.z)
    return coords, point, preset.fov or 40.0
end

local function setCamImmediate(presetName)
    local coords, point, fov = cameraWorld(presetName)
    SetCamCoord(cam, coords.x, coords.y, coords.z)
    PointCamAtCoord(cam, point.x, point.y, point.z)
    SetCamFov(cam, fov)
end

function CreatorCamera.Create()
    if not Config.CreatorCamera or not Config.Creator.EnableCameraMovement then
        return
    end

    CreatorCamera.Destroy()

    local coords, point, fov = cameraWorld('body')
    cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, fov, false, 0)
    PointCamAtCoord(cam, point.x, point.y, point.z)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 800, true, true)
    currentPreset = 'body'
    headingOffset = 0.0
end

function CreatorCamera.Destroy()
    transitioning = false
    if cam and DoesCamExist(cam) then
        RenderScriptCams(false, true, 600, true, true)
        SetCamActive(cam, false)
        DestroyCam(cam, true)
    end
    cam = nil
    currentPreset = 'body'
    headingOffset = 0.0
end

function CreatorCamera.Exists()
    return cam ~= nil and DoesCamExist(cam)
end

function CreatorCamera.UpdateFollow()
    if not CreatorCamera.Exists() or transitioning then return end
    setCamImmediate(currentPreset)
end

function CreatorCamera.SetPreset(presetName, instant)
    if not CreatorCamera.Exists() then return end
    presetName = Config.Cameras[presetName] and presetName or 'body'
    if presetName == currentPreset and not instant then return end

    if instant or not Config.Creator.EnableCameraMovement then
        currentPreset = presetName
        setCamImmediate(presetName)
        return
    end

    local from = currentPreset
    local duration = (Config.Cameras[presetName].duration or 500)
    currentPreset = presetName
    transitioning = true

    CreateThread(function()
        local start = GetGameTimer()
        local startCoords, startPoint, startFov = cameraWorld(from)
        while transitioning and CreatorCamera.Exists() do
            local progress = SharedUtils.Clamp((GetGameTimer() - start) / duration, 0.0, 1.0)
            local t = easeInOut(progress)
            local toCoords, toPoint, toFov = cameraWorld(presetName)
            local x = lerp(startCoords.x, toCoords.x, t)
            local y = lerp(startCoords.y, toCoords.y, t)
            local z = lerp(startCoords.z, toCoords.z, t)
            local px = lerp(startPoint.x, toPoint.x, t)
            local py = lerp(startPoint.y, toPoint.y, t)
            local pz = lerp(startPoint.z, toPoint.z, t)
            SetCamCoord(cam, x, y, z)
            PointCamAtCoord(cam, px, py, pz)
            SetCamFov(cam, lerp(startFov, toFov, t))
            if progress >= 1.0 then break end
            Wait(0)
        end
        transitioning = false
        if CreatorCamera.Exists() then
            setCamImmediate(presetName)
        end
    end)
end

function CreatorCamera.RotatePed(delta)
    local ped = PlayerPedId()
    headingOffset = headingOffset + delta
    SetEntityHeading(ped, (Config.CreatorPosition.w + headingOffset) % 360.0)
end

function CreatorCamera.SetAbsoluteRotation(delta)
    headingOffset = delta
    SetEntityHeading(PlayerPedId(), (Config.CreatorPosition.w + headingOffset) % 360.0)
end

function CreatorCamera.ResetRotation()
    headingOffset = 0.0
    SetEntityHeading(PlayerPedId(), Config.CreatorPosition.w)
end

function CreatorCamera.GetHeadingOffset()
    return headingOffset
end
