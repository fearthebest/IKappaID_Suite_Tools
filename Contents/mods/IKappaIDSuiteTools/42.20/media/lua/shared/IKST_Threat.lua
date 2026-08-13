-- Shared zombie threat scan/cull (server authority + client mirror for MP visuals).

require "IKST_Shared"

IKST_Threat = IKST_Threat or {}

-- Same radius math for scan/cull UI preview and server ops.
function IKST_Threat.normalizeRadius(radius)
    return tonumber(radius) or IKST.RADIUS_PRESETS.M
end

function IKST_Threat.affectsLabel(radius)
    radius = IKST_Threat.normalizeRadius(radius)
    local span = (2 * math.floor(radius)) + 1
    return IKST.text("IGUI_IKST_Loot_Affects", "Affects")
        .. " r=" .. tostring(radius)
        .. " (~" .. tostring(span) .. "×" .. tostring(span) .. ")"
end

function IKST_Threat.applyClientPreview(cx, cy, cz, radius, colorKey)
    if not IKST_PreviewOverlay or type(IKST_PreviewOverlay.setJobRadius) ~= "function" then
        return
    end
    IKST_PreviewOverlay.setJobRadius(
        math.floor(tonumber(cx) or 0),
        math.floor(tonumber(cy) or 0),
        tonumber(cz) or 0,
        IKST_Threat.normalizeRadius(radius),
        colorKey or "warn")
end

function IKST_Threat.cullAt(x, y, z, radius, maxPerTick)
    local removed = 0
    if not getCell or not getCell().getZombieList then
        return removed
    end
    local zombies = getCell():getZombieList()
    if not zombies then
        return removed
    end
    maxPerTick = maxPerTick or 50
    radius = IKST_Threat.normalizeRadius(radius)
    for i = zombies:size() - 1, 0, -1 do
        if removed >= maxPerTick then
            break
        end
        local zombie = zombies:get(i)
        if zombie and IKST.distance2d(x, y, zombie:getX(), zombie:getY()) <= radius then
            if zombie.removeFromSquare then
                zombie:removeFromSquare()
            end
            if zombie.removeFromWorld then
                zombie:removeFromWorld()
            end
            removed = removed + 1
        end
    end
    return removed
end

function IKST_Threat.countAt(x, y, z, radius)
    local total, sprinters = 0, 0
    if not getCell or not getCell().getZombieList then
        return total, sprinters
    end
    local zombies = getCell():getZombieList()
    if not zombies then
        return total, sprinters
    end
    radius = IKST_Threat.normalizeRadius(radius)
    for i = 0, zombies:size() - 1 do
        local zombie = zombies:get(i)
        if zombie and IKST.distance2d(x, y, zombie:getX(), zombie:getY()) <= radius then
            total = total + 1
            if type(zombie.isRunning) == "function" and zombie:isRunning() then
                sprinters = sprinters + 1
            end
        end
    end
    return total, sprinters
end
