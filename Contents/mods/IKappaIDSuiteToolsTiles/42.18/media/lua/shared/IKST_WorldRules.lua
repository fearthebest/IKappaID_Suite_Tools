-- World rules and server settings (ModData IKST_WorldRules).

require "IKST_Shared"
require "IKST_Authority"

IKST_WorldRules = IKST_WorldRules or {}

function IKST_WorldRules.store()
    local data = ModData.getOrCreate("IKST_WorldRules")
    data.rules = data.rules or {
        disableDestroy = false,
        disablePickup = false,
    }
    data.spriteBlacklist = data.spriteBlacklist or {}
    data.safehouseBackup = data.safehouseBackup or nil
    data.showSafehouseBorders = data.showSafehouseBorders or false
    return data
end

function IKST_WorldRules.getRules()
    return IKST_WorldRules.store().rules
end

function IKST_WorldRules.setRule(key, value)
    if IKST_Authority and not IKST_Authority.guardServerMutate() then
        return false
    end
    local rules = IKST_WorldRules.getRules()
    if rules[key] ~= nil then
        rules[key] = value == true
        return true
    end
    return false
end

function IKST_WorldRules.isSpriteBlacklisted(spriteName)
    if not spriteName or spriteName == "" then
        return false
    end
    local list = IKST_WorldRules.store().spriteBlacklist
    local lower = string.lower(spriteName)
    for _, entry in ipairs(list) do
        if string.lower(entry) == lower or string.find(lower, string.lower(entry), 1, true) then
            return true
        end
    end
    return false
end

function IKST_WorldRules.addSpriteBlacklist(spriteName)
    if IKST_Authority and not IKST_Authority.guardServerMutate() then
        return false
    end
    spriteName = string.gsub(tostring(spriteName or ""), "^%s*(.-)%s*$", "%1")
    if spriteName == "" then
        return false
    end
    local list = IKST_WorldRules.store().spriteBlacklist
    for _, entry in ipairs(list) do
        if entry == spriteName then
            return true
        end
    end
    list[#list + 1] = spriteName
    return true
end

function IKST_WorldRules.removeSpriteBlacklist(spriteName)
    local list = IKST_WorldRules.store().spriteBlacklist
    for i, entry in ipairs(list) do
        if entry == spriteName then
            table.remove(list, i)
            return true
        end
    end
    return false
end
