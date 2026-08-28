Database = {}

local initialized = false

local CREATE_CREATOR = [[
CREATE TABLE IF NOT EXISTS character_creator (
    id INT AUTO_INCREMENT PRIMARY KEY,
    citizenid VARCHAR(50) NOT NULL,
    firstname VARCHAR(50) NOT NULL,
    lastname VARCHAR(50) NOT NULL,
    birthdate VARCHAR(20) NOT NULL,
    gender VARCHAR(20) NOT NULL,
    height INT DEFAULT 180,
    nationality VARCHAR(50),
    appearance LONGTEXT,
    clothing LONGTEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uniq_citizenid (citizenid)
)
]]

local CREATE_DRAFTS = [[
CREATE TABLE IF NOT EXISTS character_creator_drafts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    license VARCHAR(100) NOT NULL,
    citizenid VARCHAR(50) NULL,
    payload LONGTEXT NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uniq_license (license)
)
]]

local CREATE_PLAYERSKINS = [[
CREATE TABLE IF NOT EXISTS playerskins (
    id INT AUTO_INCREMENT PRIMARY KEY,
    citizenid VARCHAR(255) NOT NULL,
    model VARCHAR(255) NOT NULL,
    skin LONGTEXT NOT NULL,
    active TINYINT(4) NOT NULL DEFAULT 1,
    KEY citizenid (citizenid),
    KEY active (active)
)
]]

function Database.Init()
    if initialized then return end

    MySQL.query.await(CREATE_CREATOR)
    MySQL.query.await(CREATE_DRAFTS)

    local skins = MySQL.scalar.await([[
        SELECT COUNT(*) FROM information_schema.tables
        WHERE table_schema = DATABASE() AND table_name = 'playerskins'
    ]])
    if not skins or tonumber(skins) == 0 then
        MySQL.query.await(CREATE_PLAYERSKINS)
    end

    initialized = true
end

function Database.GetByCitizenId(citizenid)
    if not citizenid then return nil end
    return MySQL.single.await('SELECT * FROM character_creator WHERE citizenid = ? LIMIT 1', { citizenid })
end

function Database.HasAppearance(citizenid)
    if not citizenid then return false end
    local id = MySQL.scalar.await('SELECT id FROM character_creator WHERE citizenid = ? LIMIT 1', { citizenid })
    if id then return true end

    local skin = MySQL.scalar.await('SELECT id FROM playerskins WHERE citizenid = ? AND active = 1 LIMIT 1', { citizenid })
    return skin ~= nil
end

function Database.UpsertIdentity(citizenid, identity)
    if not citizenid or type(identity) ~= 'table' then return end

    MySQL.query.await([[
        INSERT INTO character_creator
            (citizenid, firstname, lastname, birthdate, gender, height, nationality)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            firstname = VALUES(firstname),
            lastname = VALUES(lastname),
            birthdate = VALUES(birthdate),
            gender = VALUES(gender),
            height = VALUES(height),
            nationality = VALUES(nationality)
    ]], {
        citizenid,
        identity.firstname,
        identity.lastname,
        identity.birthdate,
        tostring(identity.gender or 0),
        identity.height,
        identity.nationality,
    })
end

function Database.UpsertCharacter(citizenid, identity, appearance)
    local appearanceJson = json.encode(appearance)
    local clothingJson = json.encode(appearance.clothing or {})

    MySQL.query.await([[
        INSERT INTO character_creator
            (citizenid, firstname, lastname, birthdate, gender, height, nationality, appearance, clothing)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            firstname = VALUES(firstname),
            lastname = VALUES(lastname),
            birthdate = VALUES(birthdate),
            gender = VALUES(gender),
            height = VALUES(height),
            nationality = VALUES(nationality),
            appearance = VALUES(appearance),
            clothing = VALUES(clothing)
    ]], {
        citizenid,
        identity.firstname,
        identity.lastname,
        identity.birthdate,
        tostring(identity.gender),
        identity.height,
        identity.nationality,
        appearanceJson,
        clothingJson,
    })
end

function Database.SavePlayerSkin(citizenid, appearance, identity)
    if not citizenid then return end

    local illenium = SharedUtils.ToIllenium({
        identity = identity,
        appearance = appearance,
    })

    MySQL.query.await('UPDATE playerskins SET active = 0 WHERE citizenid = ?', { citizenid })
    MySQL.insert.await(
        'INSERT INTO playerskins (citizenid, model, skin, active) VALUES (?, ?, ?, 1)',
        { citizenid, appearance.model, json.encode(illenium) }
    )
end

function Database.SaveDraft(license, citizenid, payload)
    if not license then return end
    MySQL.query.await([[
        INSERT INTO character_creator_drafts (license, citizenid, payload)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE
            citizenid = VALUES(citizenid),
            payload = VALUES(payload)
    ]], { license, citizenid, json.encode(payload) })
end

function Database.GetDraft(license)
    if not license then return nil end
    local row = MySQL.single.await('SELECT payload, updated_at FROM character_creator_drafts WHERE license = ? LIMIT 1', { license })
    if not row then return nil end

    local updated = row.updated_at
    if type(updated) == 'string' then
        local year, month, day, hour, min, sec = updated:match('^(%d+)%-(%d+)%-(%d+) (%d+):(%d+):(%d+)$')
        if year then
            local stamp = os.time({
                year = tonumber(year),
                month = tonumber(month),
                day = tonumber(day),
                hour = tonumber(hour),
                min = tonumber(min),
                sec = tonumber(sec),
            })
            if stamp and (os.time() - stamp) > (Config.Draft.timeoutMinutes * 60) then
                Database.ClearDraft(license)
                return nil
            end
        end
    end

    local ok, payload = pcall(json.decode, row.payload)
    if not ok then return nil end
    return payload
end

function Database.ClearDraft(license)
    if not license then return end
    MySQL.query.await('DELETE FROM character_creator_drafts WHERE license = ?', { license })
end

function Database.ResetAppearance(citizenid, gender)
    local identityRow = Database.GetByCitizenId(citizenid)
    local identity = {
        firstname = identityRow and identityRow.firstname or 'John',
        lastname = identityRow and identityRow.lastname or 'Doe',
        birthdate = identityRow and identityRow.birthdate or '1990-01-01',
        gender = gender or tonumber(identityRow and identityRow.gender) or 0,
        height = identityRow and identityRow.height or Config.Identity.defaultHeight,
        nationality = identityRow and identityRow.nationality or Config.Identity.defaultNationality,
    }
    local appearance = SharedUtils.DefaultAppearance(identity.gender)
    Database.UpsertCharacter(citizenid, identity, appearance)
    Database.SavePlayerSkin(citizenid, appearance, identity)
    return appearance
end
