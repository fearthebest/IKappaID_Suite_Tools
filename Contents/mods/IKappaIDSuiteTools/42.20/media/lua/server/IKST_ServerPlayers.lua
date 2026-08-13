-- Shared server JVM player iteration helpers (username / online-id keys).

if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end

require "IKST_Shared"

IKST_ServerPlayers = IKST_ServerPlayers or {}

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
end
