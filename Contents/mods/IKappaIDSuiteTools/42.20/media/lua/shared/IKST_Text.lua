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

