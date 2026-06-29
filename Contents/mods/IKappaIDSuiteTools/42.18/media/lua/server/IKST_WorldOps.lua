if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end
-- Core world ops kept in base (results, inspect bridge, zombie threat scans).

require "IKST_Shared"
require "IKST_Grid"
require "IKST_Threat"

IKST_WorldOps = IKST_WorldOps or {}

function IKST_WorldOps.getSquare(x, y, z)
    return IKST_Grid.getSquare(x, y, z)
end

function IKST_WorldOps.threatCull(x, y, z, radius, maxPerTick)
    if IKST_Threat and IKST_Threat.cullAt then
        return IKST_Threat.cullAt(x, y, z, radius, maxPerTick)
    end
    return 0
end

function IKST_WorldOps.threatPopulation(x, y, z, radius)
    if IKST_Threat and IKST_Threat.countAt then
        return IKST_Threat.countAt(x, y, z, radius)
    end
    return 0, 0
end

function IKST_WorldOps.broadcastThreatCull(actor, x, y, z, radius, removed)
    if not IKST.isMultiplayerSession or not IKST.isMultiplayerSession() then
        return
    end
    if not IKST.runsOnServerJvm or not IKST.runsOnServerJvm() then
        return
    end
    if not IKST.deliverClientCommand or not getOnlinePlayers then
        return
    end
    removed = math.floor(tonumber(removed) or 0)
    if removed < 1 then
        return
    end
    radius = IKST.clampRadius(radius)
    local payload = {
        removed = removed,
        x = math.floor(tonumber(x) or 0),
        y = math.floor(tonumber(y) or 0),
        z = tonumber(z) or 0,
        radius = radius,
        mirrorCull = true,
    }
    local list = getOnlinePlayers()
    if not list or not list.size or not list.get then
        return
    end
    local broadcastRadius = radius + 32
    for i = 0, list:size() - 1 do
        local onlinePlayer = list:get(i)
        if onlinePlayer and onlinePlayer ~= actor then
            if IKST.distance2d(x, y, onlinePlayer:getX(), onlinePlayer:getY()) <= broadcastRadius then
                IKST.deliverClientCommand(onlinePlayer, IKST.CMD.threatResult, payload)
            end
        end
    end
end

function IKST_WorldOps.sendResult(player, ok, message, x, y, z, mode, extra)
    if not player then
        return
    end
    if not IKST_Debug then
        require "IKST_Debug"
    end
    if IKST_Debug and IKST_Debug.logResult then
        IKST_Debug.logResult(mode, player, ok, message)
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
