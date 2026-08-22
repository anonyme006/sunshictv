Clothing = {}

local function applyNative(ped, clothing)
    clothing = clothing or {}

    for id, item in pairs(clothing.components or {}) do
        local componentId = tonumber(id)
        if componentId then
            SetPedComponentVariation(
                ped,
                componentId,
                tonumber(item.drawable) or 0,
                tonumber(item.texture) or 0,
                0
            )
        end
    end

    for id, item in pairs(clothing.props or {}) do
        local propId = tonumber(id)
        if propId then
            local drawable = tonumber(item.drawable) or -1
            if drawable < 0 then
                ClearPedProp(ped, propId)
            else
                SetPedPropIndex(ped, propId, drawable, tonumber(item.texture) or 0, true)
            end
        end
    end
end

local function applyIllenium(ped, clothing, appearance)
    if GetResourceState('illenium-appearance') ~= 'started' then
        applyNative(ped, clothing)
        return
    end

    local payload = appearance or { clothing = clothing }
    local converted = SharedUtils.ToIllenium(payload)
    pcall(function()
        exports['illenium-appearance']:setPedAppearance(ped, converted)
    end)
end

local function applyCustom(ped, clothing)
    if type(Config.CustomClothingApply) == 'function' then
        Config.CustomClothingApply(ped, clothing)
        return
    end
    applyNative(ped, clothing)
end

function Clothing.Apply(ped, clothing, appearance)
    if not ped or ped == 0 then return end

    if Config.ClothingSystem == 'illenium-appearance' then
        applyIllenium(ped, clothing, appearance)
    elseif Config.ClothingSystem == 'custom' then
        applyCustom(ped, clothing)
    else
        applyNative(ped, clothing)
    end
end

function Clothing.ApplySlot(ped, slotType, slotId, drawable, texture)
    if slotType == 'prop' then
        if drawable < 0 then
            ClearPedProp(ped, slotId)
        else
            SetPedPropIndex(ped, slotId, drawable, texture or 0, true)
        end
        return
    end

    SetPedComponentVariation(ped, slotId, drawable or 0, texture or 0, 0)
end

function Clothing.Collect(ped)
    if type(Config.CustomClothingCollect) == 'function' then
        return Config.CustomClothingCollect(ped)
    end

    local clothing = { components = {}, props = {} }

    for i = 1, #Config.ClothingSlots do
        local slot = Config.ClothingSlots[i]
        clothing.components[slot.id] = {
            drawable = GetPedDrawableVariation(ped, slot.id),
            texture = GetPedTextureVariation(ped, slot.id),
        }
    end

    clothing.components[2] = {
        drawable = GetPedDrawableVariation(ped, 2),
        texture = GetPedTextureVariation(ped, 2),
    }

    for i = 1, #Config.AccessorySlots do
        local slot = Config.AccessorySlots[i]
        clothing.props[slot.id] = {
            drawable = GetPedPropIndex(ped, slot.id),
            texture = GetPedPropTextureIndex(ped, slot.id),
        }
    end

    return clothing
end

local function textureCount(ped, slotType, slotId, drawable)
    if slotType == 'prop' then
        if drawable < 0 then return 0 end
        return math.max(0, GetNumberOfPedPropTextureVariations(ped, slotId, drawable) - 1)
    end
    return math.max(0, GetNumberOfPedTextureVariations(ped, slotId, drawable) - 1)
end

function Clothing.GetLimits(ped)
    local limits = { components = {}, props = {} }

    for i = 1, #Config.ClothingSlots do
        local slot = Config.ClothingSlots[i]
        local drawableMax = math.max(0, GetNumberOfPedDrawableVariations(ped, slot.id) - 1)
        local current = GetPedDrawableVariation(ped, slot.id)
        limits.components[tostring(slot.id)] = {
            key = slot.key,
            label = slot.label,
            drawable = drawableMax,
            texture = textureCount(ped, 'component', slot.id, current),
        }
    end

    for i = 1, #Config.AccessorySlots do
        local slot = Config.AccessorySlots[i]
        local drawableMax = math.max(-1, GetNumberOfPedPropDrawableVariations(ped, slot.id) - 1)
        local current = GetPedPropIndex(ped, slot.id)
        limits.props[tostring(slot.id)] = {
            key = slot.key,
            label = slot.label,
            drawable = drawableMax,
            texture = textureCount(ped, 'prop', slot.id, current),
        }
    end

    return limits
end

function Clothing.GetTextureMax(ped, slotType, slotId, drawable)
    return textureCount(ped, slotType, slotId, drawable)
end
