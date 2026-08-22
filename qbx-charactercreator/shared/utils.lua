SharedUtils = {}

function SharedUtils.Locale(key)
    local lang = (Config and Config.Locale) or 'fr'
    local pack = Locales and (Locales[lang] or Locales.fr)
    if not pack then return key end

    local current = pack
    for part in string.gmatch(key, '[^%.]+') do
        if type(current) ~= 'table' then return key end
        current = current[part]
    end

    return current or key
end

function SharedUtils.Clamp(value, minValue, maxValue)
    value = tonumber(value)
    if not value then return minValue end
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

function SharedUtils.Round(value, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor((value * mult) + 0.5) / mult
end

function SharedUtils.DeepCopy(value)
    if type(value) ~= 'table' then return value end

    local copy = {}
    for key, item in pairs(value) do
        copy[key] = SharedUtils.DeepCopy(item)
    end
    return copy
end

function SharedUtils.IsInteger(value)
    if type(value) ~= 'number' then
        value = tonumber(value)
    end
    return value ~= nil and value == math.floor(value)
end

function SharedUtils.Trim(value)
    if type(value) ~= 'string' then return '' end
    return (value:gsub('^%s+', ''):gsub('%s+$', ''))
end

function SharedUtils.Capitalize(value)
    value = SharedUtils.Trim(value)
    return value:gsub("(%w)([%w']*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)
end

function SharedUtils.GetModelFromGender(gender)
    gender = tonumber(gender) or 0
    if gender == 1 then
        return Config.Models.female
    end
    return Config.Models.male
end

function SharedUtils.DefaultIdentity()
    return {
        firstname = '',
        lastname = '',
        birthdate = '',
        gender = 0,
        height = Config.Identity.defaultHeight,
        nationality = Config.Identity.defaultNationality,
    }
end

function SharedUtils.DefaultAppearance(gender)
    gender = tonumber(gender) or 0
    local clothing = SharedUtils.DeepCopy(gender == 1 and Config.DefaultClothing.female or Config.DefaultClothing.male)

    return {
        model = SharedUtils.GetModelFromGender(gender),
        heritage = {
            mother = 21,
            father = 0,
            resemblance = 0.5,
            skinMix = 0.5,
            faceResemblance = 0.5,
        },
        face = {
            noseWidth = 0.0,
            nosePeakHeight = 0.0,
            nosePeakLength = 0.0,
            noseBoneHeight = 0.0,
            nosePeakLowering = 0.0,
            noseBoneTwist = 0.0,
            eyebrowHeight = 0.0,
            eyebrowDepth = 0.0,
            cheekboneHeight = 0.0,
            cheekboneWidth = 0.0,
            cheeksWidth = 0.0,
            eyesOpening = 0.0,
            lipsThickness = 0.0,
            jawBoneWidth = 0.0,
            jawBoneLength = 0.0,
            chinBoneLowering = 0.0,
            chinBoneLength = 0.0,
            chinBoneWidth = 0.0,
            chinDimple = 0.0,
            neckThickness = 0.0,
        },
        hair = {
            style = gender == 1 and 4 or 0,
            texture = 0,
            color = 0,
            highlight = 0,
        },
        overlays = {
            blemishes = { style = 0, opacity = 0.0, color = 0, secondColor = 0 },
            beard = { style = 0, opacity = 0.0, color = 0, secondColor = 0 },
            eyebrows = { style = 1, opacity = 1.0, color = 0, secondColor = 0 },
            ageing = { style = 0, opacity = 0.0, color = 0, secondColor = 0 },
            makeup = { style = 0, opacity = 0.0, color = 0, secondColor = 0 },
            blush = { style = 0, opacity = 0.0, color = 0, secondColor = 0 },
            complexion = { style = 0, opacity = 0.0, color = 0, secondColor = 0 },
            sunDamage = { style = 0, opacity = 0.0, color = 0, secondColor = 0 },
            lipstick = { style = 0, opacity = 0.0, color = 0, secondColor = 0 },
            moles = { style = 0, opacity = 0.0, color = 0, secondColor = 0 },
            chestHair = { style = 0, opacity = 0.0, color = 0, secondColor = 0 },
            bodyBlemishes = { style = 0, opacity = 0.0, color = 0, secondColor = 0 },
        },
        eyes = {
            color = 0,
            size = 0.0,
            opening = 0.0,
            position = 0.0,
        },
        clothing = clothing,
    }
end

function SharedUtils.FaceFeatureIndex(name)
    return Config.FaceFeatures[name]
end

function SharedUtils.OverlayIndex(name)
    return Config.Overlays[name]
end

function SharedUtils.ToIllenium(payload)
    local appearance = payload.appearance or payload
    local clothing = appearance.clothing or payload.clothing or SharedUtils.DefaultAppearance(payload.identity and payload.identity.gender or 0).clothing
    local heritage = appearance.heritage or {}
    local face = appearance.face or {}
    local hair = appearance.hair or {}
    local overlays = appearance.overlays or {}
    local eyes = appearance.eyes or {}

    local function overlay(entry)
        entry = entry or {}
        return {
            style = tonumber(entry.style) or 0,
            opacity = tonumber(entry.opacity) or 0.0,
            color = tonumber(entry.color) or 0,
            secondColor = tonumber(entry.secondColor) or 0,
        }
    end

    local components = {}
    for id, item in pairs(clothing.components or {}) do
        components[#components + 1] = {
            component_id = tonumber(id),
            drawable = tonumber(item.drawable) or 0,
            texture = tonumber(item.texture) or 0,
        }
    end

    local props = {}
    for id, item in pairs(clothing.props or {}) do
        props[#props + 1] = {
            prop_id = tonumber(id),
            drawable = tonumber(item.drawable) or -1,
            texture = tonumber(item.texture) or -1,
        }
    end

    return {
        model = appearance.model or SharedUtils.GetModelFromGender(payload.identity and payload.identity.gender or 0),
        tattoos = {},
        headBlend = {
            shapeFirst = tonumber(heritage.mother) or 21,
            shapeSecond = tonumber(heritage.father) or 0,
            shapeThird = 0,
            skinFirst = tonumber(heritage.mother) or 21,
            skinSecond = tonumber(heritage.father) or 0,
            skinThird = 0,
            shapeMix = tonumber(heritage.resemblance) or 0.5,
            skinMix = tonumber(heritage.skinMix) or 0.5,
            thirdMix = 0.0,
        },
        faceFeatures = {
            noseWidth = face.noseWidth or 0.0,
            nosePeakHigh = face.nosePeakHeight or 0.0,
            nosePeakSize = face.nosePeakLength or 0.0,
            noseBoneHigh = face.noseBoneHeight or 0.0,
            nosePeakLowering = face.nosePeakLowering or 0.0,
            noseBoneTwist = face.noseBoneTwist or 0.0,
            eyeBrownHigh = face.eyebrowHeight or 0.0,
            eyeBrownForward = face.eyebrowDepth or 0.0,
            cheeksBoneHigh = face.cheekboneHeight or 0.0,
            cheeksBoneWidth = face.cheekboneWidth or 0.0,
            cheeksWidth = face.cheeksWidth or 0.0,
            eyesOpening = (eyes.opening ~= nil) and eyes.opening or (face.eyesOpening or 0.0),
            lipsThickness = face.lipsThickness or 0.0,
            jawBoneWidth = face.jawBoneWidth or 0.0,
            jawBoneBackSize = face.jawBoneLength or 0.0,
            chinBoneLowering = face.chinBoneLowering or 0.0,
            chinBoneLenght = face.chinBoneLength or 0.0,
            chinBoneSize = face.chinBoneWidth or 0.0,
            chinHole = face.chinDimple or 0.0,
            neckThickness = face.neckThickness or 0.0,
        },
        headOverlays = {
            blemishes = overlay(overlays.blemishes),
            beard = overlay(overlays.beard),
            eyebrows = overlay(overlays.eyebrows),
            ageing = overlay(overlays.ageing),
            makeUp = overlay(overlays.makeup),
            blush = overlay(overlays.blush),
            complexion = overlay(overlays.complexion),
            sunDamage = overlay(overlays.sunDamage),
            lipstick = overlay(overlays.lipstick),
            moleAndFreckles = overlay(overlays.moles),
            chestHair = overlay(overlays.chestHair),
            bodyBlemishes = overlay(overlays.bodyBlemishes),
        },
        hair = {
            style = hair.style or 0,
            color = hair.color or 0,
            highlight = hair.highlight or 0,
            texture = hair.texture or 0,
        },
        eyeColor = eyes.color or 0,
        components = components,
        props = props,
    }
end
