require "IKST_Constants"

function IKST.text(key, fallback)
    if not key then
        return fallback or ""
    end
    if getText and type(getText) == "function" then
        local value = getText(key)
        if value and value ~= "" and value ~= key then
            return value
        end
    end
    return fallback or key
end

-- Safe substitution for UI strings. Prefer {1}/{2} placeholders — never %1 in
-- Translate files used with bare getText (B42 Translator throws MissingFormatArgumentException).
function IKST.format(key, fallback, ...)
    local fmt = IKST.text(key, fallback)
    local argc = select("#", ...)
    for i = 1, argc do
        local v = tostring(select(i, ...) or "")
        fmt = string.gsub(fmt, "{" .. i .. "}", v)
        -- Legacy: tolerate old %n in fallbacks only (EN JSON must use {n}).
        fmt = string.gsub(fmt, "%%" .. i, v)
    end
    return fmt
end

