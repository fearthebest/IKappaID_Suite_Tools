-- Client UI size/position prefs for the jobs panel (UTF-8, no secrets).
if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"

IKST_UIPrefs = IKST_UIPrefs or {}

local FILE = "IKST_UIPrefs.txt"
local cache = nil

local function ensureCache()
    if cache then
        return cache
    end
    cache = {}
    if type(getFileReader) ~= "function" then
        return cache
    end
    local reader = getFileReader(FILE, true)
    if not reader then
        return cache
    end
    local line = reader:readLine()
    while line ~= nil do
        local k, v = string.match(line, "^([^|]+)|(.*)$")
        if k and k ~= "" then
            cache[k] = v
        end
        line = reader:readLine()
    end
    if type(reader.close) == "function" then
        reader:close()
    end
    return cache
end

function IKST_UIPrefs.get(key)
    if not key then
        return nil
    end
    return ensureCache()[key]
end

function IKST_UIPrefs.getNumber(key)
    local v = IKST_UIPrefs.get(key)
    if v == nil then
        return nil
    end
    if IKST and type(IKST.parseNumberOptional) == "function" then
        return IKST.parseNumberOptional(v)
    end
    return nil
end

function IKST_UIPrefs.set(key, value)
    if not key or key == "" then
        return
    end
    ensureCache()[key] = tostring(value)
    if type(getFileWriter) ~= "function" then
        return
    end
    local writer = getFileWriter(FILE, true, false)
    if not writer then
        return
    end
    for k, v in pairs(cache) do
        writer:write(tostring(k) .. "|" .. tostring(v) .. "\n")
    end
    if type(writer.close) == "function" then
        writer:close()
    end
end

function IKST_UIPrefs.loadPanelGeometry()
    return {
        x = IKST_UIPrefs.getNumber("panelX"),
        y = IKST_UIPrefs.getNumber("panelY"),
        w = IKST_UIPrefs.getNumber("panelW"),
        h = IKST_UIPrefs.getNumber("panelH"),
    }
end

function IKST_UIPrefs.savePanelGeometry(panel)
    if not panel then
        return
    end
    local x = panel.x or (type(panel.getX) == "function" and panel:getX()) or 0
    local y = panel.y or (type(panel.getY) == "function" and panel:getY()) or 0
    local w = panel.width or (type(panel.getWidth) == "function" and panel:getWidth()) or 0
    local h = panel.height or (type(panel.getHeight) == "function" and panel:getHeight()) or 0
    IKST_UIPrefs.set("panelX", math.floor(x))
    IKST_UIPrefs.set("panelY", math.floor(y))
    IKST_UIPrefs.set("panelW", math.floor(w))
    IKST_UIPrefs.set("panelH", math.floor(h))
end

function IKST_UIPrefs.loadActionLogGeometry()
    return {
        x = IKST_UIPrefs.getNumber("logX"),
        y = IKST_UIPrefs.getNumber("logY"),
    }
end

function IKST_UIPrefs.saveActionLogGeometry(panel)
    if not panel then
        return
    end
    local x = panel.x or (type(panel.getX) == "function" and panel:getX()) or 0
    local y = panel.y or (type(panel.getY) == "function" and panel:getY()) or 0
    IKST_UIPrefs.set("logX", math.floor(x))
    IKST_UIPrefs.set("logY", math.floor(y))
end
