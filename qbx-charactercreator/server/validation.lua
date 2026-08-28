Validation = {}

local PARENT_IDS = {}

CreateThread(function()
    for i = 1, #Config.Parents.fathers do
        PARENT_IDS[Config.Parents.fathers[i].id] = true
    end
    for i = 1, #Config.Parents.mothers do
        PARENT_IDS[Config.Parents.mothers[i].id] = true
    end
end)

local function fail(key)
    return false, key
end

local function containsForbidden(value)
    local lowered = value:lower()
    if Config.ForbiddenNames[lowered] then return true end
    for word in lowered:gmatch('%S+') do
        if Config.ForbiddenNames[word] then return true end
    end
    return false
end

local function isAllowedNameChar(code)
    if code == 32 or code == 39 or code == 45 then
        return true
    end
    return (code >= 65 and code <= 90)
        or (code >= 97 and code <= 122)
        or (code >= 192 and code <= 214)
        or (code >= 216 and code <= 246)
        or (code >= 248 and code <= 687)
end

local function validName(value)
    value = SharedUtils.Trim(value or '')
    local length = utf8.len(value) or #value
    if length < Config.Identity.minNameLength or length > Config.Identity.maxNameLength then
        return false
    end
    for _, code in utf8.codes(value) do
        if not isAllowedNameChar(code) then
            return false
        end
    end
    if containsForbidden(value) then
        return false
    end
    return true
end

local function parseDate(value)
    if type(value) ~= 'string' then return nil end
    local year, month, day = value:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    if not year then
        day, month, year = value:match('^(%d%d)/(%d%d)/(%d%d%d%d)$')
    end
    year, month, day = tonumber(year), tonumber(month), tonumber(day)
    if not year or not month or not day then return nil end
    if month < 1 or month > 12 or day < 1 or day > 31 then return nil end
    return year, month, day
end

local function ageFromDate(year, month, day)
    local now = os.date('*t')
    local age = now.year - year
    if now.month < month or (now.month == month and now.day < day) then
        age = age - 1
    end
    return age
end

local function inList(list, value)
    for i = 1, #list do
        if list[i] == value then return true end
    end
    return false
end

function Validation.Identity(identity)
    if type(identity) ~= 'table' then
        return fail('notify.invalid_value')
    end

    local firstname = SharedUtils.Capitalize(identity.firstname)
    local lastname = SharedUtils.Capitalize(identity.lastname)
    if not validName(firstname) then return fail('notify.invalid_firstname') end
    if not validName(lastname) then return fail('notify.invalid_lastname') end

    local year, month, day = parseDate(SharedUtils.Trim(identity.birthdate or ''))
    if not year then return fail('notify.invalid_birthdate') end
    local age = ageFromDate(year, month, day)
    if age < Config.MinimumAge or age > Config.MaximumAge then
        return fail('notify.invalid_age')
    end

    local gender = tonumber(identity.gender)
    if gender ~= 0 and gender ~= 1 then
        gender = 0
    end

    local minHeight = Config.MinHeight or Config.Identity.minHeight
    local maxHeight = Config.MaxHeight or Config.Identity.maxHeight
    local height = tonumber(identity.height)
    if not height or height < minHeight or height > maxHeight then
        return fail('notify.invalid_height')
    end

    local nationality = SharedUtils.Trim(identity.nationality or '')
    if nationality == '' or not inList(Config.Nationalities, nationality) then
        return fail('notify.invalid_nationality')
    end

    return true, {
        firstname = firstname,
        lastname = lastname,
        birthdate = ('%04d-%02d-%02d'):format(year, month, day),
        gender = gender,
        height = math.floor(height),
        nationality = nationality,
    }
end

local function clampNumber(value, minValue, maxValue, integer)
    value = tonumber(value)
    if not value or value ~= value then return nil end
    value = SharedUtils.Clamp(value, minValue, maxValue)
    if integer then
        value = math.floor(value + 0.0)
    else
        value = SharedUtils.Round(value, 3)
    end
    return value
end

local function sanitizeOverlay(data)
    data = type(data) == 'table' and data or {}
    return {
        style = clampNumber(data.style, Config.Limits.overlayStyle.min, Config.Limits.overlayStyle.max, true) or 0,
        opacity = clampNumber(data.opacity, Config.Limits.opacity.min, Config.Limits.opacity.max, false) or 0.0,
        color = clampNumber(data.color, Config.Limits.overlayColor.min, Config.Limits.overlayColor.max, true) or 0,
        secondColor = clampNumber(data.secondColor, Config.Limits.overlayColor.min, Config.Limits.overlayColor.max, true) or 0,
    }
end

local function sanitizeClothing(clothing)
    clothing = type(clothing) == 'table' and clothing or {}
    local sanitized = { components = {}, props = {} }

    local function take(bucket, source, drawableLimit, textureLimit, allowNegative)
        for key, item in pairs(source or {}) do
            local id = tonumber(key)
            if id and type(item) == 'table' then
                local drawable = clampNumber(item.drawable, drawableLimit.min, drawableLimit.max, true)
                local texture = clampNumber(item.texture, textureLimit.min, textureLimit.max, true)
                if drawable and texture then
                    if allowNegative or drawable >= 0 then
                        bucket[id] = { drawable = drawable, texture = texture }
                    end
                end
            end
        end
    end

    take(sanitized.components, clothing.components, Config.Limits.componentDrawable, Config.Limits.componentTexture, false)
    take(sanitized.props, clothing.props, Config.Limits.propDrawable, Config.Limits.propTexture, true)
    return sanitized
end

function Validation.Appearance(appearance, gender)
    if type(appearance) ~= 'table' then
        return fail('notify.invalid_value')
    end

    local model = appearance.model or SharedUtils.GetModelFromGender(gender)
    if type(model) ~= 'string' or not Config.AllowedModels[model] then
        return fail('notify.invalid_model')
    end

    if gender == 0 and model ~= Config.Models.male then
        return fail('notify.invalid_model')
    end
    if gender == 1 and model ~= Config.Models.female then
        return fail('notify.invalid_model')
    end

    local heritage = appearance.heritage or {}
    local mother = clampNumber(heritage.mother, Config.Limits.parent.min, Config.Limits.parent.max, true)
    local father = clampNumber(heritage.father, Config.Limits.parent.min, Config.Limits.parent.max, true)
    if not mother or not father or not PARENT_IDS[mother] or not PARENT_IDS[father] then
        return fail('notify.invalid_value')
    end

    local face = {}
    for name in pairs(Config.FaceFeatures) do
        face[name] = clampNumber(appearance.face and appearance.face[name], Config.Limits.face.min, Config.Limits.face.max, false) or 0.0
    end

    local hair = appearance.hair or {}
    local overlays = {}
    for name in pairs(Config.Overlays) do
        overlays[name] = sanitizeOverlay(appearance.overlays and appearance.overlays[name])
    end

    local eyes = appearance.eyes or {}

    local sanitized = {
        model = model,
        heritage = {
            mother = mother,
            father = father,
            resemblance = clampNumber(heritage.resemblance, Config.Limits.mix.min, Config.Limits.mix.max, false) or 0.5,
            faceResemblance = clampNumber(heritage.faceResemblance, Config.Limits.mix.min, Config.Limits.mix.max, false) or 0.5,
            skinMix = clampNumber(heritage.skinMix, Config.Limits.mix.min, Config.Limits.mix.max, false) or 0.5,
        },
        face = face,
        hair = {
            style = clampNumber(hair.style, Config.Limits.hairStyle.min, Config.Limits.hairStyle.max, true) or 0,
            texture = clampNumber(hair.texture, Config.Limits.componentTexture.min, Config.Limits.componentTexture.max, true) or 0,
            color = clampNumber(hair.color, Config.Limits.hairColor.min, Config.Limits.hairColor.max, true) or 0,
            highlight = clampNumber(hair.highlight, Config.Limits.hairColor.min, Config.Limits.hairColor.max, true) or 0,
        },
        overlays = overlays,
        eyes = {
            color = clampNumber(eyes.color, Config.Limits.eyeColor.min, Config.Limits.eyeColor.max, true) or 0,
            size = clampNumber(eyes.size, Config.Limits.face.min, Config.Limits.face.max, false) or 0.0,
            opening = clampNumber(eyes.opening, Config.Limits.face.min, Config.Limits.face.max, false) or 0.0,
            position = clampNumber(eyes.position, Config.Limits.face.min, Config.Limits.face.max, false) or 0.0,
        },
        clothing = sanitizeClothing(appearance.clothing),
    }

    return true, sanitized
end

function Validation.Payload(payload)
    if type(payload) ~= 'table' then
        return fail('notify.invalid_value')
    end

    local okIdentity, identity = Validation.Identity(payload.identity)
    if not okIdentity then
        return false, identity
    end

    local okAppearance, appearance = Validation.Appearance(payload.appearance, identity.gender)
    if not okAppearance then
        return false, appearance
    end

    return true, {
        identity = identity,
        appearance = appearance,
    }
end

function Validation.IdentityPayload(payload)
    if type(payload) ~= 'table' then
        return fail('notify.invalid_value')
    end

    local okIdentity, identity = Validation.Identity(payload.identity)
    if not okIdentity then
        return false, identity
    end

    return true, { identity = identity }
end

function Validation.Draft(payload)
    if type(payload) ~= 'table' or type(payload.identity) ~= 'table' or type(payload.appearance) ~= 'table' then
        return fail('notify.invalid_value')
    end

    local gender = tonumber(payload.identity.gender) or 0
    if gender ~= 0 and gender ~= 1 then
        gender = 0
    end

    local firstname = SharedUtils.Trim(payload.identity.firstname or '')
    local lastname = SharedUtils.Trim(payload.identity.lastname or '')
    if utf8.len(firstname) and utf8.len(firstname) > Config.Identity.maxNameLength then
        firstname = firstname:sub(1, Config.Identity.maxNameLength)
    end
    if utf8.len(lastname) and utf8.len(lastname) > Config.Identity.maxNameLength then
        lastname = lastname:sub(1, Config.Identity.maxNameLength)
    end

    local okAppearance, appearance = Validation.Appearance(payload.appearance, gender)
    if not okAppearance then
        appearance = SharedUtils.DefaultAppearance(gender)
    end

    return true, {
        identity = {
            firstname = firstname,
            lastname = lastname,
            birthdate = SharedUtils.Trim(payload.identity.birthdate or ''),
            gender = gender,
            height = SharedUtils.Clamp(tonumber(payload.identity.height) or Config.Identity.defaultHeight, Config.Identity.minHeight, Config.Identity.maxHeight),
            nationality = SharedUtils.Trim(payload.identity.nationality or Config.Identity.defaultNationality),
        },
        appearance = appearance,
    }
end
