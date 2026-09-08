-- Optional PhunZones 2 integration (nosafehouse and zone lookup).

require "IKST_Shared"

IKST_PhunZones = IKST_PhunZones or {}

function IKST_PhunZones.available()
    return PhunZones ~= nil and type(PhunZones.getLocation) == "function"
end

function IKST_PhunZones.zoneAt(x, y, square)
    if not IKST_PhunZones.available() then
        return nil
    end
    if square then
        return PhunZones.getLocation(square)
    end
    return PhunZones.getLocation(x, y)
end

function IKST_PhunZones.blockMessage()
    if getText then
        local line = getText("IGUI_PhunZones_SayNoSafeHouse")
        if line and line ~= "" and line ~= "IGUI_PhunZones_SayNoSafeHouse" then
            return line
        end
    end
    return "You cannot create a safehouse in this area"
end

function IKST_PhunZones.pointBlocksSafehouse(x, y, square)
    local zone = IKST_PhunZones.zoneAt(x, y, square)
    return zone ~= nil and zone.nosafehouse == true
end

function IKST_PhunZones.rectBlocksSafehouse(x, y, w, h)
    if not IKST_PhunZones.available() then
        return false
    end
    x = math.floor(tonumber(x) or 0)
    y = math.floor(tonumber(y) or 0)
    w = math.floor(tonumber(w) or 0)
    h = math.floor(tonumber(h) or 0)
    if w < 1 or h < 1 then
        return IKST_PhunZones.pointBlocksSafehouse(x, y)
    end
    if type(PhunZones.getIntersectingZones) == "function"
        and type(PhunZones.anyZoneHas) == "function" then
        local zones = PhunZones.getIntersectingZones(x, y, x + w - 1, y + h - 1)
        return PhunZones.anyZoneHas(zones, "nosafehouse", true)
    end
    return IKST_PhunZones.pointBlocksSafehouse(x + math.floor(w / 2), y + math.floor(h / 2))
end

function IKST_PhunZones.claimAllowed(x, y, z, w, h, square)
    if not IKST_PhunZones.available() then
        return true, nil
    end
    if square and IKST_PhunZones.pointBlocksSafehouse(nil, nil, square) then
        return false, IKST_PhunZones.blockMessage()
    end
    if w and h and IKST_PhunZones.rectBlocksSafehouse(x, y, w, h) then
        return false, IKST_PhunZones.blockMessage()
    end
    if IKST_PhunZones.pointBlocksSafehouse(x, y) then
        return false, IKST_PhunZones.blockMessage()
    end
    return true, nil
end
