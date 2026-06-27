if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end
-- Core world ops kept in base (results, inspect bridge, zombie threat scans).

require "IKST_Shared"
require "IKST_Grid"

IKST_WorldOps = IKST_WorldOps or {}

function IKST_WorldOps.getSquare(x, y, z)
    return IKST_Grid.getSquare(x, y, z)
end

function IKST_WorldOps.threatCull(x, y, z, radius, maxPerTick)
    local removed = 0
    if not getCell or not getCell().getZombieList then
        return removed
    end
    local zombies = getCell():getZombieList()
    if not zombies then
        return removed
    end
    maxPerTick = maxPerTick or 50
    for i = zombies:size() - 1, 0, -1 do
        if removed >= maxPerTick then
            break
        end
        local z = zombies:get(i)
        if z and IKST.distance2d(x, y, z:getX(), z:getY()) <= radius then
            if z.removeFromWorld then
                z:removeFromWorld()
            end
            removed = removed + 1
        end
    end
    return removed
end

function IKST_WorldOps.threatPopulation(x, y, z, radius)
    local total, sprinters = 0, 0
    if not getCell or not getCell().getZombieList then
        return total, sprinters
    end
    local zombies = getCell():getZombieList()
    if not zombies then
        return total, sprinters
    end
    for i = 0, zombies:size() - 1 do
        local z = zombies:get(i)
        if z and IKST.distance2d(x, y, z:getX(), z:getY()) <= radius then
            total = total + 1
            if z.isRunning and z:isRunning() then
                sprinters = sprinters + 1
            end
        end
    end
    return total, sprinters
end

function IKST_WorldOps.sendResult(player, ok, message, x, y, z, mode, extra)
    if not player then
        return
    end
    local payload = {
        success = ok,
        message = message,
        x = x,
        y = y,
        z = z,
        mode = mode,
    }
    if extra then
        for key, value in pairs(extra) do
            payload[key] = value
        end
    end
    if IKST.deliverClientCommand then
        IKST.deliverClientCommand(player, IKST.CMD.result, payload)
        return
    end
    if payload.success and payload.message then
        local line = tostring(payload.mode or "action") .. " @ "
            .. tostring(payload.x) .. "," .. tostring(payload.y) .. "," .. tostring(payload.z)
            .. " — " .. tostring(payload.message)
        IKST.pushLog(player, line)
    end
    if IKST_JobsPanel and IKST_JobsPanel.instance then
        IKST_JobsPanel.instance:onServerResult(payload)
    elseif message and IKST.shouldNotifyResult and IKST.shouldNotifyResult(mode) then
        IKST.notify(player, tostring(message), ok == true)
    end
end

function IKST_WorldOps.sendInspect(player, x, y, z, items)
    local payload = { x = x, y = y, z = z, items = items }
    if IKST.deliverClientCommand then
        IKST.deliverClientCommand(player, IKST.CMD.inspectResult, payload)
        return
    end
    if IKST_JobsPanel and IKST_JobsPanel.instance and IKST_JobsPanel.instance.onInspectResult then
        IKST_JobsPanel.instance:onInspectResult(payload)
    end
end
