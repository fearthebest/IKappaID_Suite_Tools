-- Shared server JVM player iteration helpers (username / online-id keys).

if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end

require "IKST_Shared"

IKST_ServerPlayers = IKST_ServerPlayers or {}
IKST_ServerPlayers._connectedAt = IKST_ServerPlayers._connectedAt or {}
IKST_ServerPlayers.JOIN_HOLD_MS = 15000

local JOIN_HOLD_GROUPS = {
    claim_write = true,
    economy_write = true,
    vehicle_mutate = true,
    staff_give = true,
    lock_auth = true,
}

function IKST_ServerPlayers.nowMs()
    if type(getTimeInMillis) == "function" then
        return getTimeInMillis()
    end
    return 0
end

function IKST_ServerPlayers.markConnected(player)
    local key = IKST_ServerPlayers.playerKey(player)
    if not key then
        return
    end
    if not IKST_ServerPlayers._connectedAt[key] then
        IKST_ServerPlayers._connectedAt[key] = IKST_ServerPlayers.nowMs()
    end
end

function IKST_ServerPlayers.joinHoldRemainingMs(player)
    if not IKST.isMultiplayerSession or not IKST.isMultiplayerSession() then
        return 0
    end
    local key = IKST_ServerPlayers.playerKey(player)
    if not key then
        return 0
    end
    local at = IKST_ServerPlayers._connectedAt[key]
    if at == nil then
        IKST_ServerPlayers.markConnected(player)
        at = IKST_ServerPlayers._connectedAt[key]
    end
    if at == nil then
        return 0
    end
    local remain = IKST_ServerPlayers.JOIN_HOLD_MS - (IKST_ServerPlayers.nowMs() - at)
    if remain < 1 then
        return 0
    end
    return remain
end

function IKST_ServerPlayers.joinHoldBlocks(command)
    if not command then
        return false
    end
    if not IKST_RateLimit then
        require "IKST_RateLimit"
    end
    if not IKST_RateLimit or type(IKST_RateLimit.groupForCommand) ~= "function" then
        return false
    end
    local group = IKST_RateLimit.groupForCommand(command)
    return JOIN_HOLD_GROUPS[group] == true
end


function IKST_ServerPlayers.playerKey(player)
    if not player then
        return nil
    end
    if type(player.getUsername) == "function" then
        local name = player:getUsername()
        if name and name ~= "" then
            return name
        end
    end
    if type(player.getOnlineID) == "function" then
        return "id:" .. tostring(player:getOnlineID())
    end
    return nil
end

function IKST_ServerPlayers.playerInWorld(player)
    if not player then
        return false
    end
    if type(player.isDead) == "function" and player:isDead() then
        return false
    end
    if type(player.getSquare) == "function" then
        local sq = player:getSquare()
        if sq then
            return true
        end
    end
    if type(player.getX) == "function" and type(player.getY) == "function" then
        local x = player:getX()
        local y = player:getY()
        if x and y and (x ~= 0 or y ~= 0) then
            return true
        end
    end
    return false
end

function IKST_ServerPlayers.foreachOnlinePlayer(fn)
    if type(fn) ~= "function" then
        return
    end
    local list = getOnlinePlayers and getOnlinePlayers()
    if list and type(list.size) == "function" and type(list.get) == "function" then
        for i = 0, list:size() - 1 do
            fn(list:get(i))
        end
        return
    end
    if getSpecificPlayer then
        local p = getSpecificPlayer(0)
        if p then
            fn(p)
        end
    end
end

function IKST_ServerPlayers.pruneDisconnected(seen)
    seen = seen or {}
    local still = {}
    IKST_ServerPlayers.foreachOnlinePlayer(function(p)
        local key = IKST_ServerPlayers.playerKey(p)
        if key then
            still[key] = true
        end
    end)
    for key in pairs(seen) do
        if not still[key] then
            seen[key] = nil
        end
    end
    local connected = IKST_ServerPlayers._connectedAt
    for key in pairs(connected) do
        if not still[key] then
            connected[key] = nil
        end
    end
end
