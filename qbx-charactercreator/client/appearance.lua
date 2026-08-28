Appearance = {}

local FACE_ORDER = {
    'noseWidth',
    'nosePeakHeight',
    'nosePeakLength',
    'noseBoneHeight',
    'nosePeakLowering',
    'noseBoneTwist',
    'eyebrowHeight',
    'eyebrowDepth',
    'cheekboneHeight',
    'cheekboneWidth',
    'cheeksWidth',
    'eyesOpening',
    'lipsThickness',
    'jawBoneWidth',
    'jawBoneLength',
    'chinBoneLowering',
    'chinBoneLength',
    'chinBoneWidth',
    'chinDimple',
    'neckThickness',
}

local function applyHeadBlend(ped, heritage)
    local mother = tonumber(heritage.mother) or 21
    local father = tonumber(heritage.father) or 0
    local resemblance = tonumber(heritage.resemblance) or 0.5
    local faceResemblance = tonumber(heritage.faceResemblance) or resemblance
    local skinMix = tonumber(heritage.skinMix) or 0.5

    SetPedHeadBlendData(
        ped,
        mother,
        father,
        0,
        mother,
        father,
        0,
        faceResemblance,
        skinMix,
        0.0,
        false
    )
end

local function applyFace(ped, face, eyes)
    for name, index in pairs(Config.FaceFeatures) do
        local value = tonumber(face[name]) or 0.0
        if name == 'eyesOpening' and eyes and eyes.opening ~= nil then
            value = tonumber(eyes.opening) or value
        end
        SetPedFaceFeature(ped, index, value)
    end

    if eyes then
        SetPedEyeColor(ped, tonumber(eyes.color) or 0)
        if eyes.position ~= nil then
            SetPedFaceFeature(ped, Config.FaceFeatures.eyebrowHeight, tonumber(eyes.position) or 0.0)
        end
        if eyes.size ~= nil then
            local opening = tonumber(eyes.opening) or 0.0
            local size = tonumber(eyes.size) or 0.0
            SetPedFaceFeature(ped, Config.FaceFeatures.eyesOpening, SharedUtils.Clamp((opening * 0.65) + (size * 0.35), -1.0, 1.0))
        end
    end
end

local function applyHair(ped, hair)
    hair = hair or {}
    SetPedComponentVariation(ped, 2, tonumber(hair.style) or 0, tonumber(hair.texture) or 0, 0)
    SetPedHairColor(ped, tonumber(hair.color) or 0, tonumber(hair.highlight) or 0)
end

local function applyOverlay(ped, name, data)
    local index = Config.Overlays[name]
    if index == nil then return end

    data = data or {}
    local style = tonumber(data.style) or 0
    local opacity = tonumber(data.opacity) or 0.0
    SetPedHeadOverlay(ped, index, style, opacity)

    local colorType = Config.OverlayColorType[name] or 0
    if colorType > 0 then
        SetPedHeadOverlayColor(ped, index, colorType, tonumber(data.color) or 0, tonumber(data.secondColor) or 0)
    end
end

function Appearance.Apply(ped, data)
    if not ped or ped == 0 or not data then return end

    ped = ClientUtils.SetPlayerModel(data.model or SharedUtils.GetModelFromGender(0))
    applyHeadBlend(ped, data.heritage or {})
    applyFace(ped, data.face or {}, data.eyes or {})
    applyHair(ped, data.hair or {})

    for name in pairs(Config.Overlays) do
        applyOverlay(ped, name, data.overlays and data.overlays[name])
    end

    Clothing.Apply(ped, data.clothing, data)
    return ped
end

function Appearance.ApplyPartial(ped, section, payload)
    if not ped or ped == 0 or not payload then return end

    if section == 'heritage' then
        applyHeadBlend(ped, payload)
    elseif section == 'face' then
        applyFace(ped, payload, nil)
    elseif section == 'eyes' then
        applyFace(ped, {}, payload)
    elseif section == 'hair' then
        applyHair(ped, payload)
    elseif section == 'overlay' and payload.name then
        applyOverlay(ped, payload.name, payload)
    elseif section == 'overlays' then
        for name, overlay in pairs(payload) do
            applyOverlay(ped, name, overlay)
        end
    elseif section == 'clothing' then
        Clothing.Apply(ped, payload)
    end
end

function Appearance.Collect(ped)
    ped = ped or PlayerPedId()
    local appearance = SharedUtils.DefaultAppearance(0)
    appearance.model = GetEntityModel(ped) == joaat(Config.Models.female) and Config.Models.female or Config.Models.male

    local ok, shapeFirst, shapeSecond, _, _, _, _, shapeMix, skinMix = pcall(GetPedHeadBlendData, ped)
    if ok and shapeFirst then
        appearance.heritage.mother = shapeFirst
        appearance.heritage.father = shapeSecond
        appearance.heritage.resemblance = shapeMix or 0.5
        appearance.heritage.faceResemblance = shapeMix or 0.5
        appearance.heritage.skinMix = skinMix or 0.5
    end

    for i = 1, #FACE_ORDER do
        local name = FACE_ORDER[i]
        appearance.face[name] = GetPedFaceFeature(ped, i - 1)
    end

    appearance.hair.style = GetPedDrawableVariation(ped, 2)
    appearance.hair.texture = GetPedTextureVariation(ped, 2)
    appearance.eyes.opening = appearance.face.eyesOpening
    appearance.clothing = Clothing.Collect(ped)
    return appearance
end

function Appearance.GetLimits(ped)
    ped = ped or PlayerPedId()
    local overlays = {}
    for name, index in pairs(Config.Overlays) do
        overlays[name] = math.max(0, GetNumHeadOverlayValues(index) - 1)
    end

    return {
        hair = math.max(0, GetNumberOfPedDrawableVariations(ped, 2) - 1),
        hairColors = math.max(0, GetNumHairColors() - 1),
        makeupColors = math.max(0, GetNumMakeupColors() - 1),
        overlays = overlays,
        clothing = Clothing.GetLimits(ped),
    }
end

function Appearance.PlayCategoryAnimation(category)
    if not Config.Creator.EnableAnimations then return end

    local key = Config.CategoryAnimations[category] or 'default'
    local anim = Config.Animations[key] or Config.Animations.default
    local ped = PlayerPedId()

    ClearPedTasksImmediately(ped)
    if ClientUtils.LoadAnimDict(anim.dict) then
        TaskPlayAnim(ped, anim.dict, anim.anim, 2.0, 2.0, -1, anim.flag or 1, 0.0, false, false, false)
    end
end

function Appearance.StopAnimation()
    local ped = PlayerPedId()
    ClearPedTasksImmediately(ped)
    for _, anim in pairs(Config.Animations) do
        if HasAnimDictLoaded(anim.dict) then
            RemoveAnimDict(anim.dict)
        end
    end
end
