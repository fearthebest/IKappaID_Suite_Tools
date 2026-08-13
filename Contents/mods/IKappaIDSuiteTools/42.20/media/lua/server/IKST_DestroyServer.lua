-- Vanilla sledge / pickup / grief-build is not an IKST command. Lua cannot cancel
-- the Java action. Fingerprint guarded squares near players and reverse unauthorized
-- sprite loss (restore + strip pickup item) or sprite add (remove).

if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end

require "IKST_Shared"
require "IKST_Grid"
require "IKST_Access"
require "IKST_ServerPlayers"
require "IKST_SafehouseClaim"

IKST_DestroyServer = IKST_DestroyServer or {}

IKST_DestroyServer.ALLOW_TTL_MS = 8000
IKST_DestroyServer.SCAN_INTERVAL_MS = 1000
IKST_DestroyServer.NEAR_RADIUS = 16
IKST_DestroyServer.SCAN_RADIUS = 8
IKST_DestroyServer._allow = IKST_DestroyServer._allow or {}
IKST_DestroyServer._prints = IKST_DestroyServer._prints or {}
IKST_DestroyServer._lastScan = 0
IKST_DestroyServer._busy = false

local function nowMs()
    if getTimestampMs then
        return getTimestampMs()
    end
    return 0
end

local function squareKey(square)
    if not square or type(square.getX) ~= "function" then
        return nil
    end
    return tostring(math.floor(square:getX())) .. ":"
        .. tostring(math.floor(square:getY())) .. ":"
        .. tostring(math.floor(square:getZ() or 0))
end

local function coordKey(x, y, z)
    return tostring(math.floor(tonumber(x) or 0)) .. ":"
        .. tostring(math.floor(tonumber(y) or 0)) .. ":"
        .. tostring(math.floor(tonumber(z) or 0))
end

local function isFloorLike(spriteName)
    if not spriteName or spriteName == "" then
        return true
    end
    local lower = string.lower(spriteName)
    if string.find(lower, "floors_", 1, true) then
        return true
    end
    if string.find(lower, "blends_natural", 1, true) then
        return true
    end
    if string.find(lower, "blends_grassoverlays", 1, true) then
        return true
    end
    return false
end

local function spriteNameOf(object)
    if not object or type(object.getSprite) ~= "function" then
        return nil
    end
    local sprite = object:getSprite()
    if sprite and type(sprite.getName) == "function" then
        return sprite:getName()
    end
    return nil
end

function IKST_DestroyServer.active()
    if type(IKST.isMultiplayerSession) ~= "function" or not IKST.isMultiplayerSession() then
        return false
    end
    if type(IKST.runsOnServerJvm) ~= "function" or not IKST.runsOnServerJvm() then
        return false
    end
    return true
end

function IKST_DestroyServer.purgeExpiredAllows()
    local now = nowMs()
    if now <= 0 then
        return
    end
    for key, untilMs in pairs(IKST_DestroyServer._allow) do
        if not untilMs or untilMs <= now then
            IKST_DestroyServer._allow[key] = nil
        end
    end
end

function IKST_DestroyServer.allowSquare(x, y, z, ttlMs)
    local key = coordKey(x, y, z)
    ttlMs = tonumber(ttlMs) or IKST_DestroyServer.ALLOW_TTL_MS
    local now = nowMs()
    IKST_DestroyServer._allow[key] = (now > 0 and (now + ttlMs)) or 1
end

function IKST_DestroyServer.consumeAllow(x, y, z)
    IKST_DestroyServer.purgeExpiredAllows()
    local key = coordKey(x, y, z)
    local untilMs = IKST_DestroyServer._allow[key]
    if not untilMs then
        return false
    end
    local now = nowMs()
    if now > 0 and untilMs > 0 and untilMs < now then
        IKST_DestroyServer._allow[key] = nil
        return false
    end
    IKST_DestroyServer._allow[key] = nil
    return true
end

function IKST_DestroyServer.squareNeedsGuard(square)
    if not square or type(square.getX) ~= "function" then
        return false
    end
    local x = square:getX()
    local y = square:getY()
    local z = square:getZ() or 0
    if IKST_WorldRules and type(IKST_WorldRules.getRules) == "function" then
        local rules = IKST_WorldRules.getRules()
        if rules and rules.disableDestroy then
            return true
        end
    end
    if IKST_TileProtect and type(IKST_TileProtect.isTileProtected) == "function" then
        if IKST_TileProtect.isTileProtected(x, y, z) then
            return true
        end
    end
    if IKST_SafehouseClaim and type(IKST_SafehouseClaim.entryForSquare) == "function" then
        local entry = IKST_SafehouseClaim.entryForSquare(square)
        if entry then
            return true
        end
    end
    return false
end

function IKST_DestroyServer.playerNearSquare(player, square, radius)
    if not player or not square or type(player.getX) ~= "function" then
        return false
    end
    radius = tonumber(radius) or IKST_DestroyServer.NEAR_RADIUS
    local dx = player:getX() - square:getX()
    local dy = player:getY() - square:getY()
    local dz = (player:getZ() or 0) - (square:getZ() or 0)
    return (dx * dx + dy * dy) <= (radius * radius) and math.abs(dz) <= 2
end

function IKST_DestroyServer.someoneMay(square, action)
    if not square or not action then
        return false
    end
    if action == "destroy" and IKST_WorldRules and type(IKST_WorldRules.getRules) == "function" then
        local rules = IKST_WorldRules.getRules()
        if rules and rules.disableDestroy then
            return false
        end
    end
    local tileProtected = false
    if IKST_TileProtect and type(IKST_TileProtect.isTileProtected) == "function" then
        tileProtected = IKST_TileProtect.isTileProtected(square:getX(), square:getY(), square:getZ() or 0) == true
    end
    local allowed = false
    if IKST_ServerPlayers and type(IKST_ServerPlayers.foreachOnlinePlayer) == "function" then
        IKST_ServerPlayers.foreachOnlinePlayer(function(player)
            if allowed then
                return
            end
            if not IKST_DestroyServer.playerNearSquare(player, square, IKST_DestroyServer.NEAR_RADIUS) then
                return
            end
            if IKST_Access and type(IKST_Access.canUseTools) == "function" and IKST_Access.canUseTools(player) then
                allowed = true
                return
            end
            if tileProtected then
                return
            end
            if IKST_SafehouseClaim and type(IKST_SafehouseClaim.canAtSquare) == "function" then
                if IKST_SafehouseClaim.canAtSquare(player, square, action) == true then
                    allowed = true
                end
            end
        end)
    end
    return allowed
end

function IKST_DestroyServer.someoneMayDestroy(square)
    return IKST_DestroyServer.someoneMay(square, "destroy")
end

function IKST_DestroyServer.readSprites(square)
    local counts = {}
    if not square or type(square.getObjects) ~= "function" then
        return counts
    end
    local objs = square:getObjects()
    if not objs or type(objs.size) ~= "function" or type(objs.get) ~= "function" then
        return counts
    end
    for i = 0, objs:size() - 1 do
        local name = spriteNameOf(objs:get(i))
        if name and not isFloorLike(name) then
            counts[name] = (counts[name] or 0) + 1
        end
    end
    return counts
end

function IKST_DestroyServer.restoreSprite(square, spriteName)
    if not square or not spriteName or spriteName == "" then
        return false
    end
    if IsoObject and type(IsoObject.new) == "function" and type(square.AddSpecialObject) == "function" then
        local obj = IsoObject.new(square, spriteName, nil, false)
        if obj then
            square:AddSpecialObject(obj)
            if type(obj.transmitCompleteItemToClients) == "function" then
                obj:transmitCompleteItemToClients()
            elseif type(square.transmitAddObjectToSquare) == "function" and type(obj.getObjectIndex) == "function" then
                square:transmitAddObjectToSquare(obj, obj:getObjectIndex())
            end
            return true
        end
    end
    if type(square.addTileObject) == "function" then
        square:addTileObject(spriteName)
        return true
    end
    return false
end

function IKST_DestroyServer.itemMatchesSprite(item, spriteName)
    if not item or not spriteName then
        return false
    end
    if type(item.getWorldSprite) == "function" then
        local worldSprite = item:getWorldSprite()
        if worldSprite == spriteName then
            return true
        end
    end
    if type(item.getSpriteName) == "function" then
        if item:getSpriteName() == spriteName then
            return true
        end
    end
    return false
end

function IKST_DestroyServer.stripMatchingPickup(square, spriteName)
    if not square or not spriteName then
        return
    end
    if not IKST_ServerPlayers or type(IKST_ServerPlayers.foreachOnlinePlayer) ~= "function" then
        return
    end
    IKST_ServerPlayers.foreachOnlinePlayer(function(player)
        if not IKST_DestroyServer.playerNearSquare(player, square, IKST_DestroyServer.NEAR_RADIUS) then
            return
        end
        local inv = type(player.getInventory) == "function" and player:getInventory() or nil
        if not inv or type(inv.getItems) ~= "function" then
            return
        end
        local items = inv:getItems()
        if not items or type(items.size) ~= "function" or type(items.get) ~= "function" then
            return
        end
        local i = 0
        while i < items:size() do
            local item = items:get(i)
            if IKST_DestroyServer.itemMatchesSprite(item, spriteName) then
                if type(inv.Remove) == "function" then
                    inv:Remove(item)
                end
                if sendRemoveItemFromContainer then
                    sendRemoveItemFromContainer(inv, item)
                end
                return
            end
            i = i + 1
        end
    end)
end

function IKST_DestroyServer.removeOneSprite(square, spriteName)
    if not square or not spriteName or type(square.getObjects) ~= "function" then
        return false
    end
    local objs = square:getObjects()
    if not objs or type(objs.size) ~= "function" or type(objs.get) ~= "function" then
        return false
    end
    local i = objs:size() - 1
    while i >= 0 do
        local obj = objs:get(i)
        if spriteNameOf(obj) == spriteName then
            if type(square.transmitRemoveItemFromSquare) == "function" then
                square:transmitRemoveItemFromSquare(obj)
            end
            if type(square.RemoveTileObject) == "function" then
                square:RemoveTileObject(obj)
            end
            return true
        end
        i = i - 1
    end
    return false
end

function IKST_DestroyServer.reconcileSquare(square)
    if not square or not IKST_DestroyServer.squareNeedsGuard(square) then
        return
    end
    local key = squareKey(square)
    if not key then
        return
    end
    local current = IKST_DestroyServer.readSprites(square)
    local prev = IKST_DestroyServer._prints[key]
    if not prev then
        IKST_DestroyServer._prints[key] = current
        return
    end
    if IKST_DestroyServer.consumeAllow(square:getX(), square:getY(), square:getZ() or 0) then
        IKST_DestroyServer._prints[key] = current
        return
    end
    local mayDestroy = IKST_DestroyServer.someoneMay(square, "destroy")
        or IKST_DestroyServer.someoneMay(square, "loot")
    local mayBuild = IKST_DestroyServer.someoneMay(square, "build")
    local changed = false
    if not mayDestroy then
        for name, prevCount in pairs(prev) do
            local nowCount = current[name] or 0
            if nowCount < prevCount then
                local missing = prevCount - nowCount
                local n = 1
                while n <= missing do
                    if IKST_DestroyServer.restoreSprite(square, name) then
                        IKST_DestroyServer.stripMatchingPickup(square, name)
                        current[name] = (current[name] or 0) + 1
                        changed = true
                    end
                    n = n + 1
                end
            end
        end
    end
    if not mayBuild then
        for name, nowCount in pairs(current) do
            local prevCount = prev[name] or 0
            if nowCount > prevCount then
                local extra = nowCount - prevCount
                local n = 1
                while n <= extra do
                    if IKST_DestroyServer.removeOneSprite(square, name) then
                        current[name] = (current[name] or 0) - 1
                        if current[name] <= 0 then
                            current[name] = nil
                        end
                        changed = true
                    end
                    n = n + 1
                end
            end
        end
    end
    if changed then
        if IKST_AuditLog and type(IKST_AuditLog.record) == "function" then
            IKST_AuditLog.record(nil, "destroyReverse", {
                x = square:getX(),
                y = square:getY(),
                z = square:getZ(),
            }, true, "unauthorized tile change reversed")
        end
    end
    IKST_DestroyServer._prints[key] = current
end

function IKST_DestroyServer.collectNearSquares(player, out, seen)
    if not player or type(player.getX) ~= "function" then
        return
    end
    local px = math.floor(player:getX())
    local py = math.floor(player:getY())
    local pz = math.floor(player:getZ() or 0)
    local r = IKST_DestroyServer.SCAN_RADIUS
    local x = px - r
    while x <= px + r do
        local y = py - r
        while y <= py + r do
            local sq = IKST_Grid.getSquare(x, y, pz)
            if sq and IKST_DestroyServer.squareNeedsGuard(sq) then
                local key = squareKey(sq)
                if key and not seen[key] then
                    seen[key] = true
                    out[#out + 1] = sq
                end
            end
            y = y + 1
        end
        x = x + 1
    end
end

function IKST_DestroyServer.onTick()
    if not IKST_DestroyServer.active() then
        return
    end
    if IKST_DestroyServer._busy then
        return
    end
    local now = nowMs()
    if now > 0 and (now - (IKST_DestroyServer._lastScan or 0)) < IKST_DestroyServer.SCAN_INTERVAL_MS then
        return
    end
    IKST_DestroyServer._lastScan = now
    IKST_DestroyServer._busy = true
    IKST_DestroyServer.purgeExpiredAllows()

    local squares = {}
    local seen = {}
    if IKST_ServerPlayers and type(IKST_ServerPlayers.foreachOnlinePlayer) == "function" then
        IKST_ServerPlayers.foreachOnlinePlayer(function(player)
            IKST_DestroyServer.collectNearSquares(player, squares, seen)
        end)
    end
    local i = 1
    while i <= #squares do
        IKST_DestroyServer.reconcileSquare(squares[i])
        i = i + 1
    end
    IKST_DestroyServer._busy = false
end

function IKST_DestroyServer.onDestroyThumpable(object)
    if not IKST_DestroyServer.active() or not object then
        return
    end
    local sq = nil
    if type(object.getSquare) == "function" then
        sq = object:getSquare()
    end
    if not sq and type(object.getX) == "function" and type(object.getY) == "function" then
        sq = IKST_Grid.getSquare(math.floor(object:getX()), math.floor(object:getY()), math.floor(object:getZ() or 0))
    end
    if sq then
        IKST_DestroyServer.reconcileSquare(sq)
    end
end

function IKST_DestroyServer.init()
    if IKST_DestroyServer._inited then
        return
    end
    IKST_DestroyServer._inited = true
    if Events and Events.OnTick and Events.OnTick.Add then
        Events.OnTick.Add(IKST_DestroyServer.onTick)
    end
    if Events and Events.OnDestroyIsoThumpable and Events.OnDestroyIsoThumpable.Add then
        Events.OnDestroyIsoThumpable.Add(IKST_DestroyServer.onDestroyThumpable)
    end
    if Events and Events.OnObjectAdded and Events.OnObjectAdded.Add then
        Events.OnObjectAdded.Add(IKST_DestroyServer.onDestroyThumpable)
    end
end

IKST_DestroyServer.init()
