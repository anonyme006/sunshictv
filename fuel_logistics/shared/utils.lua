FL = FL or {}

function L(key, ...)
    local lang = Config.Locale or 'fr'
    local str = (Locales[lang] and Locales[lang][key]) or (Locales['en'] and Locales['en'][key]) or key
    if select('#', ...) > 0 then
        return str:format(...)
    end
    return str
end

function FL.Debug(...)
    if not Config.Debug then return end
    print('[fuel_logistics]', ...)
end

function FL.HasPermission(permissions, perm)
    if type(permissions) == 'string' then
        local ok, decoded = pcall(json.decode, permissions)
        permissions = ok and decoded or {}
    end
    if type(permissions) ~= 'table' then return false end
    if permissions['*'] or permissions.boss then return true end
    return permissions[perm] == true
end

function FL.GetGradePermissions(grade)
    for _i, g in ipairs(Config.Grades or {}) do
        if g.grade == grade then
            return g.permissions or {}
        end
    end
    return {}
end

function FL.Round(n, d)
    local m = 10 ^ (d or 0)
    return math.floor(n * m + 0.5) / m
end
