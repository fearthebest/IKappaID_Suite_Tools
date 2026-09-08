-- Event waypoint: staff marks event; players join and can return to origin.

require "IKST_Shared"
require "IKST_Authority"
require "IKST_Access"
require "IKST_Waypoints"

IKST_EventTp = IKST_EventTp or {}
IKST_EventTp.KEY = "IKST_EventTp"

function IKST_EventTp.store()
    local data = ModData.getOrCreate(IKST_EventTp.KEY)
    data.active = data.active or false
    return data
end

function IKST_EventTp.enabled()
    if IKST_Access and type(IKST_Access.sandboxBool) == "function" then
        return IKST_Access.sandboxBool("EventTpEnabled", true)
    end
    return true
end

function IKST_EventTp.cooldownMs()
    if IKST_Access and type(IKST_Access.sandboxInt) == "function" then
        return IKST_Access.sandboxInt("EventTpCooldownSec", 60, 15, 3600) * 1000
    end
    return 60000
end

local function nowMs()
    if type(getTimestampMs) == "function" then
        return getTimestampMs()
    end
    if type(getTimeInMillis) == "function" then
        return getTimeInMillis()
    end
    return 0
end

local function playerModData(player)
    if not player or type(player.getModData) ~= "function" then
        return nil
    end
    return player:getModData()
end

local function checkCooldown(md)
    local now = nowMs()
    local untilMs = tonumber(md.IKST_eventTpUntil) or 0
    if untilMs > now then
        local wait = math.ceil((untilMs - now) / 1000)
        return false, "cooldown " .. tostring(wait) .. "s"
    end
    return true, now
end

local function stampCooldown(md, now)
    md.IKST_eventTpUntil = (now or nowMs()) + IKST_EventTp.cooldownMs()
end

function IKST_EventTp.getEvent()
    local data = IKST_EventTp.store()
    if not data.active or data.x == nil or data.y == nil then
        return nil
    end
    return data
end

function IKST_EventTp.setEvent(player, name)
    if IKST_Authority and not IKST_Authority.guardServerMutate() then
        return false, "server only"
    end
    if not IKST_EventTp.enabled() then
        return false, "event tp disabled"
    end
    if not player then
        return false, "no player"
    end
    name = IKST_Waypoints.normalizeName(name) or "Event"
    local data = IKST_EventTp.store()
    data.active = true
    data.name = name
    data.x = math.floor(player:getX())
    data.y = math.floor(player:getY())
    data.z = player:getZ() or 0
    data.by = type(player.getUsername) == "function" and player:getUsername() or "?"
    if IKST.transmitModData then
        IKST.transmitModData(IKST_EventTp.KEY)
    end
    if IKST_StaffHistory and type(IKST_StaffHistory.record) == "function" then
        IKST_StaffHistory.record(player, "event", "set " .. name, true)
    end
    return true, "event set: " .. name
end

function IKST_EventTp.clearEvent(player)
    if IKST_Authority and not IKST_Authority.guardServerMutate() then
        return false, "server only"
    end
    local data = IKST_EventTp.store()
    data.active = false
    data.name = nil
    data.x, data.y, data.z = nil, nil, nil
    if IKST.transmitModData then
        IKST.transmitModData(IKST_EventTp.KEY)
    end
    if IKST_StaffHistory and player and type(IKST_StaffHistory.record) == "function" then
        IKST_StaffHistory.record(player, "event", "cleared", true)
    end
    return true, "event cleared"
end

function IKST_EventTp.join(player)
    if IKST_Authority and not IKST_Authority.guardServerMutate() then
        return false, "server only"
    end
    if not IKST_EventTp.enabled() then
        return false, "event tp disabled"
    end
    local ev = IKST_EventTp.getEvent()
    if not ev then
        return false, "no active event"
    end
    if not player then
        return false, "no player"
    end
    local md = playerModData(player)
    if not md then
        return false, "no modData"
    end
    local coolOk, nowOrMsg = checkCooldown(md)
    if not coolOk then
        return false, nowOrMsg
    end
    local now = nowOrMsg
    if type(player.getX) == "function" and type(player.getY) == "function" then
        local dx = math.abs(player:getX() - ev.x)
        local dy = math.abs(player:getY() - ev.y)
        if dx <= 5 and dy <= 5 then
            return false, "already at event"
        end
    end
    md.IKST_eventReturnX = math.floor(player:getX())
    md.IKST_eventReturnY = math.floor(player:getY())
    md.IKST_eventReturnZ = player:getZ() or 0
    if not IKST_StaffOps or type(IKST_StaffOps.teleportPlayer) ~= "function" then
        return false, "teleport unavailable"
    end
    IKST_StaffOps.teleportPlayer(player, ev.x, ev.y, ev.z)
    stampCooldown(md, now)
    return true, "joined " .. tostring(ev.name or "event")
end

function IKST_EventTp.returnHome(player)
    if IKST_Authority and not IKST_Authority.guardServerMutate() then
        return false, "server only"
    end
    if not IKST_EventTp.enabled() then
        return false, "event tp disabled"
    end
    if not player then
        return false, "no player"
    end
    local md = playerModData(player)
    if not md or md.IKST_eventReturnX == nil then
        return false, "no return point"
    end
    local coolOk, nowOrMsg = checkCooldown(md)
    if not coolOk then
        return false, nowOrMsg
    end
    local now = nowOrMsg
    local x, y, z = md.IKST_eventReturnX, md.IKST_eventReturnY, md.IKST_eventReturnZ or 0
    md.IKST_eventReturnX, md.IKST_eventReturnY, md.IKST_eventReturnZ = nil, nil, nil
    if not IKST_StaffOps or type(IKST_StaffOps.teleportPlayer) ~= "function" then
        return false, "teleport unavailable"
    end
    IKST_StaffOps.teleportPlayer(player, x, y, z)
    stampCooldown(md, now)
    return true, "returned"
end
