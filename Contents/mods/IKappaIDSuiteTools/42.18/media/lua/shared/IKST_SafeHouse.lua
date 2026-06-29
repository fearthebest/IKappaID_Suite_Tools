-- Vanilla SafeHouse API helpers (B42 Java: zombie.iso.areas.SafeHouse).
-- Centralizes correct instance vs static calls for MP sync.

require "IKST_Shared"

IKST_SafeHouse = IKST_SafeHouse or {}

function IKST_SafeHouse.available()
    return SafeHouse ~= nil
end

function IKST_SafeHouse.iter(visitor)
    if not SafeHouse or not SafeHouse.getSafehouseList or not visitor then
        return
    end
    local list = SafeHouse.getSafehouseList()
    if not list then
        return
    end
    if list.iterator then
        local it = list:iterator()
        if it and it.hasNext and it.next then
            while it:hasNext() do
                local sh = it:next()
                if sh then
                    visitor(sh)
                end
            end
        end
        return
    end
    if list.size and list.get then
        for i = 0, list:size() - 1 do
            local sh = list:get(i)
            if sh then
                visitor(sh)
            end
        end
    end
end

function IKST_SafeHouse.bounds(sh)
    if not sh then
        return nil
    end
    local x = sh.getX and sh:getX() or nil
    local y = sh.getY and sh:getY() or nil
    local w = sh.getW and sh:getW() or nil
    local h = sh.getH and sh:getH() or nil
    local owner = sh.getOwner and sh:getOwner() or nil
    if x == nil or y == nil or not w or not h or w < 1 or h < 1 then
        return nil
    end
    return x, y, w, h, owner
end

function IKST_SafeHouse.id(sh)
    if not sh or not sh.getId then
        return nil
    end
    return sh:getId()
end

function IKST_SafeHouse.atSquare(square)
    if not square or not SafeHouse or not SafeHouse.getSafeHouse then
        return nil
    end
    return SafeHouse.getSafeHouse(square)
end

function IKST_SafeHouse.atRect(x, y, z, w, h)
    if not SafeHouse or not SafeHouse.getSafeHouse then
        return nil
    end
    x = math.floor(tonumber(x) or 0)
    y = math.floor(tonumber(y) or 0)
    w = math.floor(tonumber(w) or 1)
    h = math.floor(tonumber(h) or 1)
    if w < 1 then
        w = 1
    end
    if h < 1 then
        h = 1
    end
    if IKST_WorldOps and IKST_WorldOps.getSquare then
        local square = IKST_WorldOps.getSquare(x, y, z or 0)
        if square then
            local atSq = IKST_SafeHouse.atSquare(square)
            if atSq then
                return atSq
            end
        end
    end
    local x2 = x + w - 1
    local y2 = y + h - 1
    if SafeHouse.getSafehouseOverlapping then
        local overlap = SafeHouse.getSafehouseOverlapping(x, y, x2, y2)
        if overlap then
            return overlap
        end
    end
    return SafeHouse.getSafeHouse(x, y, w, h)
end

function IKST_SafeHouse.find(entry, actor)
    if not entry or not IKST_SafeHouse.available() then
        return nil
    end
    local id = tonumber(entry.id)
    if id then
        local byId = nil
        IKST_SafeHouse.iter(function(sh)
            if byId then
                return
            end
            if sh.getId and sh:getId() == id then
                byId = sh
            end
        end)
        if byId then
            return byId
        end
    end
    local x = math.floor(tonumber(entry.x) or 0)
    local y = math.floor(tonumber(entry.y) or 0)
    local w = math.floor(tonumber(entry.w) or 1)
    local h = math.floor(tonumber(entry.h) or 1)
    if w < 1 then
        w = 1
    end
    if h < 1 then
        h = 1
    end
    local byRect = IKST_SafeHouse.atRect(x, y, 0, w, h)
    if byRect then
        return byRect
    end
    actor = IKST.resolvePlayer(actor)
    if actor and actor.getCurrentSquare then
        local atPlayer = IKST_SafeHouse.atSquare(actor:getCurrentSquare())
        if atPlayer then
            local owner = entry.owner
            if not owner or owner == "" then
                return atPlayer
            end
            local shOwner = atPlayer.getOwner and atPlayer:getOwner()
            if IKST_ClaimPolicy and IKST_ClaimPolicy.usernamesEqual(shOwner, owner) then
                return atPlayer
            end
        end
    end
    local owner = entry.owner
    if owner and owner ~= "" and IKST_ClaimPolicy then
        local found = nil
        IKST_SafeHouse.iter(function(sh)
            if found then
                return
            end
            local shOwner = sh.getOwner and sh:getOwner()
            if not IKST_ClaimPolicy.usernamesEqual(shOwner, owner) then
                return
            end
            local sx, sy, sw, shh = IKST_SafeHouse.bounds(sh)
            if sx and sy and sw and shh and IKST_SafehouseClaim
                and IKST_SafehouseClaim.pointInside(x, y, sx, sy, sw, shh) then
                found = sh
            elseif not found then
                found = sh
            end
        end)
        return found
    end
    return nil
end

function IKST_SafeHouse.addRect(x, y, w, h, username)
    if not SafeHouse or not SafeHouse.addSafeHouse or not username or username == "" then
        return nil
    end
    x = math.floor(tonumber(x) or 0)
    y = math.floor(tonumber(y) or 0)
    w = math.floor(tonumber(w) or 1)
    h = math.floor(tonumber(h) or 1)
    if w < 1 then
        w = 1
    end
    if h < 1 then
        h = 1
    end
    return SafeHouse.addSafeHouse(x, y, w, h, username)
end

function IKST_SafeHouse.addBuilding(square, player)
    if not SafeHouse or not SafeHouse.addSafeHouse or not square or not player then
        return nil
    end
    return SafeHouse.addSafeHouse(square, player)
end

function IKST_SafeHouse.remove(sh, actor, force)
    if not sh or not SafeHouse or not SafeHouse.removeSafeHouse then
        return false
    end
    SafeHouse.removeSafeHouse(sh)
    return true
end

function IKST_SafeHouse.sync(sh)
    if SafeHouse and SafeHouse.updateSafehousePlayersConnected then
        SafeHouse.updateSafehousePlayersConnected()
    end
end

function IKST_SafeHouse.notifyPlayer(sh, player)
    if sh and player and sh.updateSafehouse then
        sh:updateSafehouse(player)
    end
end

function IKST_SafeHouse.afterMutation(sh, player)
    IKST_SafeHouse.sync(sh)
    if player then
        IKST_SafeHouse.notifyPlayer(sh, player)
    end
    if IKST_GuardOps and IKST_GuardOps.broadcastSafehouseChange then
        IKST_GuardOps.broadcastSafehouseChange(player)
    end
end
