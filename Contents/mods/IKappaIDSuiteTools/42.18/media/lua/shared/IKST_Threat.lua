-- Shared zombie threat scan/cull (server authority + client mirror for MP visuals).

require "IKST_Shared"

IKST_Threat = IKST_Threat or {}

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
    radius = tonumber(radius) or IKST.RADIUS_PRESETS.M
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
    radius = tonumber(radius) or IKST.RADIUS_PRESETS.M
    for i = 0, zombies:size() - 1 do
        local zombie = zombies:get(i)
        if zombie and IKST.distance2d(x, y, zombie:getX(), zombie:getY()) <= radius then
            total = total + 1
            if zombie.isRunning and zombie:isRunning() then
                sprinters = sprinters + 1
            end
        end
    end
    return total, sprinters
end
