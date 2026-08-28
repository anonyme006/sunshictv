-- Bridge rCore Clothing — uniquement des événements / exports documentés.
-- Sources officielles :
--   https://documentation.rcore.cz/paid-resources/rcore_clothing/api/client.md
--   https://documentation.rcore.cz/paid-resources/rcore_clothing/integration/crm_multichar.md
--   https://documentation.rcore.cz/paid-resources/rcore_clothing/integration/qbox_multichar.md

Rcore = {}

local pendingDone
local blockReopen = false

local function resourceName()
    return (Config.Rcore and Config.Rcore.Resource) or 'rcore_clothing'
end

function Rcore.IsAvailable()
    return GetResourceState(resourceName()) == 'started'
end

--- Création initiale QB / Qbox : rCore écoute cet événement à la place de qb-clothing.
function Rcore.OpenFirstCharacter()
    local eventName = (Config.Rcore and Config.Rcore.FirstCharacterEvent) or 'qb-clothes:client:CreateFirstCharacter'
    blockReopen = false
    TriggerEvent(eventName)
end

function Rcore.BlockReopen()
    blockReopen = true
end

function Rcore.OnCreatorDone(callback)
    pendingDone = callback
end

function Rcore.ClearPending()
    pendingDone = nil
end

--- Aperçu d'un personnage existant (citizenid Qbox).
--- qbox_multichar : getSkinByIdentifier(citizenId) + setPedSkin(ped, skinData)
--- crm_multichar  : setPedSkin(ped, skin.skin) si la peau est imbriquée
function Rcore.ApplyPreview(targetPed, citizenid)
    if not Rcore.IsAvailable() or not citizenid or not targetPed or targetPed == 0 then
        return false
    end

    local ok, skin = pcall(function()
        return exports[resourceName()]:getSkinByIdentifier(citizenid)
    end)
    if not ok or type(skin) ~= 'table' then
        return false
    end

    local payload = skin
    local model = skin.ped_model
    if type(skin.skin) == 'table' then
        payload = skin.skin
        model = model or skin.skin.ped_model
    end

    if model and targetPed == PlayerPedId() then
        local modelHash = type(model) == 'string' and joaat(model) or model
        if modelHash and IsModelInCdimage(modelHash) then
            ClientUtils.SetPlayerModel(model)
            targetPed = PlayerPedId()
        end
    end

    local applied = pcall(function()
        exports[resourceName()]:setPedSkin(targetPed, payload)
    end)
    return applied == true
end

AddEventHandler('rcore_clothing:charcreator:done', function()
    local callback = pendingDone
    pendingDone = nil
    if callback then
        callback()
    end
end)

-- Après la première apparence, certains scripts appartements re-déclenchent
-- qb-clothes:client:CreateFirstCharacter. On ignore uniquement ce second appel.
AddEventHandler('qb-clothes:client:CreateFirstCharacter', function()
    if blockReopen then
        CancelEvent()
    end
end)
