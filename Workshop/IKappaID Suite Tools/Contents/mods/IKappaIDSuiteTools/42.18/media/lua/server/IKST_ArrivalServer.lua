-- Arrival Stabilization: server-owned grace window after join or respawn.

if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end

require "IKST_Shared"
require "IKST_Arrival"

IKST_ArrivalServer = IKST_ArrivalServer or {}
IKST_ArrivalServer._grace = IKST_ArrivalServer._grace or {}

local function nowMs()
    if getTimestampMs then
        return getTimestampMs()
    end
    if getTimeInMillis then
        return getTimeInMillis()
    end
    return 0
end

local function playerKey(player)
    if not player then
        return nil
    end
    if player.getUsername then
        local name = player:getUsername()
        if name and name ~= "" then
            return name
        end
    end
    if player.getOnlineID then
        return "id:" .. tostring(player:getOnlineID())
    end
    return nil
end

function IKST_ArrivalServer.getGrace(player)
    local key = playerKey(player)
    if not key then
        return nil
    end
    return IKST_ArrivalServer._grace[key]
end

function IKST_ArrivalServer.sync(player, grace, ended, reason)
    if not player or not grace then
        return
    end
    local remainingMs = 0
    if not ended then
        remainingMs = math.max(0, (grace.expiresAt or 0) - nowMs())
    end
    IKST.deliverClientCommand(player, IKST.CMD.arrivalSync, {
        active = not ended,
        remainingMs = remainingMs,
        reason = reason or "",
    })
end

function IKST_ArrivalServer.endGrace(player, reason)
    local key = playerKey(player)
    if not key then
        return
    end
    local grace = IKST_ArrivalServer._grace[key]
    if not grace then
        return
    end
    IKST_ArrivalServer._grace[key] = nil
    if player and player.setZombiesDontAttack then
        player:setZombiesDontAttack(false)
    end
    IKST_ArrivalServer.sync(player, grace, true, reason)
    if IKST_AuditLog and IKST_AuditLog.record then
        IKST_AuditLog.record(player, "arrivalEnd", { reason = reason }, true, reason or "ended")
    end
end

function IKST_ArrivalServer.beginGrace(player, reason)
    if not player or not IKST_Arrival.shouldApply(reason) then
        return
    end
    if IKST_ArrivalServer.getGrace(player) then
        return
    end
    local key = playerKey(player)
    if not key then
        return
    end
    local duration = IKST_Arrival.durationMs()
    local grace = {
        reason = reason,
        startedAt = nowMs(),
        expiresAt = nowMs() + duration,
        anchorX = player:getX(),
        anchorY = player:getY(),
        anchorZ = player:getZ() or 0,
    }
    IKST_ArrivalServer._grace[key] = grace
    if player.setZombiesDontAttack then
        player:setZombiesDontAttack(true)
    end
    IKST_ArrivalServer.sync(player, grace, false, "started")
    if IKST_AuditLog and IKST_AuditLog.record then
        IKST_AuditLog.record(player, "arrivalStart", { reason = reason, ms = duration }, true, "grace started")
    end
end

function IKST_ArrivalServer.onPlayerConnect(player, reason)
    if not player then
        return
    end
    IKST_ArrivalServer.beginGrace(player, reason or "join")
end

function IKST_ArrivalServer.enforce(player)
    local grace = IKST_ArrivalServer.getGrace(player)
    if not grace then
        return
    end
    if player.setZombiesDontAttack then
        player:setZombiesDontAttack(true)
    end
    if IKST_Arrival.attackEndsGrace() and player.isAttackStarted and player:isAttackStarted() then
        IKST_ArrivalServer.endGrace(player, "attack")
        return
    end
    if IKST_Arrival.moveEndsGrace() and grace.anchorX and grace.anchorY then
        local threshold = IKST_Arrival.moveThresholdTiles()
        if IKST.distance2d(player:getX(), player:getY(), grace.anchorX, grace.anchorY) >= threshold then
            IKST_ArrivalServer.endGrace(player, "moved")
            return
        end
    end
    if nowMs() >= (grace.expiresAt or 0) then
        IKST_ArrivalServer.endGrace(player, "expired")
        return
    end
end

local function onPlayerDeath(player)
    if not player or not player.getModData then
        return
    end
    local md = player:getModData()
    md.IKST_pendingRespawnGrace = true
end

local function resolveConnectReason(player)
    if not player or not player.getModData then
        return "join"
    end
    local md = player:getModData()
    if md.IKST_pendingRespawnGrace then
        md.IKST_pendingRespawnGrace = nil
        return "respawn"
    end
    return "join"
end

local function hookPlayerConnect(player)
    if not IKST_Arrival.enabled() then
        return
    end
    local reason = resolveConnectReason(player)
    IKST_ArrivalServer.onPlayerConnect(player, reason)
end

local function onCreatePlayer(playerIndex)
    local player = getSpecificPlayer and getSpecificPlayer(playerIndex)
    hookPlayerConnect(player)
end

local function onConnected(player)
    hookPlayerConnect(player)
end

if Events then
    if Events.OnCreatePlayer then
        Events.OnCreatePlayer.Add(onCreatePlayer)
    end
    if Events.OnConnected then
        Events.OnConnected.Add(onConnected)
    end
    if Events.OnPlayerDeath then
        Events.OnPlayerDeath.Add(onPlayerDeath)
    end
    if Events.OnTick then
        Events.OnTick.Add(function()
            IKST_ArrivalServer._tick = (IKST_ArrivalServer._tick or 0) + 1
            if IKST_ArrivalServer._tick % 15 ~= 0 then
                return
            end
            local list = getOnlinePlayers and getOnlinePlayers()
            if not list or not list.size then
                local sp = getSpecificPlayer and getSpecificPlayer(0)
                if sp then
                    IKST_ArrivalServer.enforce(sp)
                end
                return
            end
            for i = 0, list:size() - 1 do
                local p = list:get(i)
                if p then
                    IKST_ArrivalServer.enforce(p)
                end
            end
        end)
    end
end
