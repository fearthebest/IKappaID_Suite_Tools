-- Design: MP item moves are Java ItemTransaction — Lua cannot cancel mid-packet.
-- Enforce IKST_TransferRules on the server JVM by fingerprinting protected containers
-- near players (shops, locks, claim loot), allowlisting server-authorized removals
-- (vendBuy), and reversing unauthorized takes/deposits. Fail closed + audit.
-- SP keeps client TransferRules / Enforcement only.

if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end

require "IKST_Shared"
require "IKST_TransferRules"
require "IKST_ClaimPolicy"

IKST_TransferServer = IKST_TransferServer or {}

IKST_TransferServer.ALLOW_TTL_MS = 8000
IKST_TransferServer.SCAN_INTERVAL_MS = 1000
IKST_TransferServer.NEAR_RADIUS = 16
IKST_TransferServer.SCAN_RADIUS = 8
IKST_TransferServer._allow = IKST_TransferServer._allow or {}
IKST_TransferServer._prints = IKST_TransferServer._prints or {}
IKST_TransferServer._lastScan = 0
IKST_TransferServer._busy = false
IKST_TransferServer._posCache = IKST_TransferServer._posCache or {}
IKST_TransferServer._scanOut = IKST_TransferServer._scanOut or {}
IKST_TransferServer._scanSeen = IKST_TransferServer._scanSeen or {}

local function nowMs()
    if getTimestampMs then
        return getTimestampMs()
    end
    return 0
end

local function containerKey(container)
    if not container then
        return nil
    end
    if type(container.getID) == "function" then
        local id = container:getID()
        if id ~= nil then
            return "c:" .. tostring(id)
        end
    end
    local parent = type(container.getParent) == "function" and container:getParent() or nil
    local sq = nil
    if parent and type(parent.getSquare) == "function" then
        sq = parent:getSquare()
    end
    if not sq and type(container.getSourceGrid) == "function" then
        sq = container:getSourceGrid()
    end
    if not sq then
        return nil
    end
    return "s:" .. tostring(sq:getX()) .. "," .. tostring(sq:getY()) .. "," .. tostring(sq:getZ())
end

function IKST_TransferServer.active()
    if type(IKST.isMultiplayerSession) ~= "function" or not IKST.isMultiplayerSession() then
        return false
    end
    if type(IKST.runsOnServerJvm) ~= "function" or not IKST.runsOnServerJvm() then
        return false
    end
    return true
end

function IKST_TransferServer.purgeExpiredAllows()
    local now = nowMs()
    if now <= 0 then
        return
    end
    for id, untilMs in pairs(IKST_TransferServer._allow) do
        if not untilMs or untilMs <= now then
            IKST_TransferServer._allow[id] = nil
        end
    end
end

function IKST_TransferServer.allowItem(item, ttlMs)
    if not item or type(item.getID) ~= "function" then
        return
    end
    local id = item:getID()
    if id == nil then
        return
    end
    ttlMs = tonumber(ttlMs) or IKST_TransferServer.ALLOW_TTL_MS
    local now = nowMs()
    IKST_TransferServer._allow[id] = (now > 0 and (now + ttlMs)) or 1
end

function IKST_TransferServer.consumeAllow(itemId)
    if itemId == nil then
        return false
    end
    IKST_TransferServer.purgeExpiredAllows()
    local untilMs = IKST_TransferServer._allow[itemId]
    if not untilMs then
        return false
    end
    local now = nowMs()
    if now > 0 and untilMs > 0 and untilMs < now then
        IKST_TransferServer._allow[itemId] = nil
        return false
    end
    IKST_TransferServer._allow[itemId] = nil
    return true
end

function IKST_TransferServer.coordsForContainer(container)
    if IKST_ContainerRules and type(IKST_ContainerRules.coordsForContainer) == "function" then
        local x, y, z = IKST_ContainerRules.coordsForContainer(container)
        if x then
            return x, y, z
        end
    end
    if IKST_VehicleClaim and type(IKST_VehicleClaim.vehicleFromContainer) == "function" then
        local vehicle = IKST_VehicleClaim.vehicleFromContainer(container)
        if vehicle and type(vehicle.getX) == "function" then
            return vehicle:getX(), vehicle:getY(), vehicle:getZ() or 0
        end
    end
    if IKST_Economy and type(IKST_Economy.containerShopSquare) == "function" then
        local sq = IKST_Economy.containerShopSquare(container)
        if sq and type(sq.getX) == "function" then
            return sq:getX(), sq:getY(), sq:getZ()
        end
    end
    local parent = type(container.getParent) == "function" and container:getParent() or nil
    if parent and type(parent.getSquare) == "function" then
        local sq = parent:getSquare()
        if sq and type(sq.getX) == "function" then
            return sq:getX(), sq:getY(), sq:getZ()
        end
    end
    if type(container.getSourceGrid) == "function" then
        local sq = container:getSourceGrid()
        if sq and type(sq.getX) == "function" then
            return sq:getX(), sq:getY(), sq:getZ()
        end
    end
    return nil
end

function IKST_TransferServer.claimsEnabled()
    return IKST_ClaimPolicy ~= nil
end

function IKST_TransferServer.containerNeedsGuard(container)
    if not container then
        return false
    end
    if IKST_Economy and type(IKST_Economy.shopObjectForContainer) == "function" then
        local shop = IKST_Economy.shopObjectForContainer(container)
        if shop and IKST_Economy.shopProtectEnabled and IKST_Economy.shopProtectEnabled() then
            return true
        end
    end

    if IKST_TransferServer.claimsEnabled() and IKST_VehicleClaim
        and type(IKST_VehicleClaim.vehicleFromContainer) == "function"
        and type(IKST_VehicleClaim.get) == "function" then
        local vehicle = IKST_VehicleClaim.vehicleFromContainer(container)
        if vehicle and type(vehicle.getId) == "function" then
            local entry = select(1, IKST_VehicleClaim.getForVehicle(vehicle))
            if entry then
                return true
            end
        end
    end

    local x, y, z = IKST_TransferServer.coordsForContainer(container)
    if not x then
        return false
    end

    if IKST_TransferServer.claimsEnabled() and IKST_SafehouseClaim then
        local square = nil
        if getCell and getCell() and getCell().getGridSquare then
            square = getCell():getGridSquare(math.floor(x), math.floor(y), math.floor(z or 0))
        end
        if square and type(IKST_SafehouseClaim.entryForSquare) == "function" then
            local entry = IKST_SafehouseClaim.entryForSquare(square)
            if entry then
                return true
            end
        end
    end

    if IKST_TileProtect then
        if type(IKST_TileProtect.isReadonly) == "function" and IKST_TileProtect.isReadonly(x, y, z) then
            return true
        end
        if type(IKST_TileProtect.getDropboxOwner) == "function" then
            local owner = IKST_TileProtect.getDropboxOwner(x, y, z)
            if owner and owner ~= "" then
                return true
            end
        end
    end
    if IKST_Locks and type(IKST_Locks.isLocked) == "function" and IKST_Locks.isLocked(x, y, z) then
        return true
    end
    return false
end

function IKST_TransferServer.readItemIds(container)
    local ids = {}
    if not container or type(container.getItems) ~= "function" then
        return ids
    end
    local items = container:getItems()
    if not items or not items.size or not items.get then
        return ids
    end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and type(item.getID) == "function" then
            local id = item:getID()
            if id ~= nil then
                ids[id] = true
            end
        end
    end
    return ids
end

function IKST_TransferServer.findItemInContainer(container, itemId)
    if not container or itemId == nil or type(container.getItems) ~= "function" then
        return nil
    end
    local items = container:getItems()
    if not items or not items.size or not items.get then
        return nil
    end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and type(item.getID) == "function" and item:getID() == itemId then
            return item
        end
    end
    return nil
end

function IKST_TransferServer.findItemOnPlayer(player, itemId)
    if not player or itemId == nil or type(player.getInventory) ~= "function" then
        return nil, nil
    end
    local inv = player:getInventory()
    if not inv then
        return nil, nil
    end
    if type(inv.getItemById) == "function" then
        local item = inv:getItemById(itemId)
        if item then
            return item, inv
        end
    end
    if type(inv.getItems) == "function" then
        local items = inv:getItems()
        if items and items.size and items.get then
            for i = 0, items:size() - 1 do
                local item = items:get(i)
                if item and type(item.getID) == "function" and item:getID() == itemId then
                    return item, inv
                end
            end
        end
    end
    return nil, nil
end

function IKST_TransferServer.syncAdd(inv, item)
    if item and sendAddItemToContainer then
        sendAddItemToContainer(inv, item)
    end
end

function IKST_TransferServer.syncRemove(inv, item)
    if item and sendRemoveItemFromContainer then
        sendRemoveItemFromContainer(inv, item)
    end
end

function IKST_TransferServer.returnItem(container, player, item, inv)
    if not container or not player or not item or not inv then
        return false
    end
    if type(inv.Remove) == "function" then
        inv:Remove(item)
        IKST_TransferServer.syncRemove(inv, item)
    end
    if type(container.AddItem) == "function" then
        container:AddItem(item)
        IKST_TransferServer.syncAdd(container, item)
    end
    if inv.setDrawDirty then
        inv:setDrawDirty(true)
    end
    if container.setDrawDirty then
        container:setDrawDirty(true)
    end
    return true
end

function IKST_TransferServer.removeFromContainerToPlayer(container, player, item)
    if not container or not player or not item then
        return false
    end
    local inv = type(player.getInventory) == "function" and player:getInventory() or nil
    if not inv then
        return false
    end
    if type(container.Remove) == "function" then
        container:Remove(item)
        IKST_TransferServer.syncRemove(container, item)
    end
    if type(inv.AddItem) == "function" then
        inv:AddItem(item)
        IKST_TransferServer.syncAdd(inv, item)
    end
    return true
end

function IKST_TransferServer.logDeny(player, reason, container)
    if IKST_AuditLog and type(IKST_AuditLog.record) == "function" then
        local args = {}
        local key = containerKey(container)
        if key then
            args.container = key
        end
        IKST_AuditLog.record(player, "transferGuard", args, false, reason or "transfer denied")
    end
    if type(IKST_Debug) == "table" and IKST_Debug.logDeny then
        IKST_Debug.logDeny("transferGuard", player, reason or "transfer denied", nil)
    end
end

function IKST_TransferServer.eachOnlinePlayer(visitor)
    if not visitor or not getOnlinePlayers then
        return
    end
    local list = getOnlinePlayers()
    if not list or type(list.size) ~= "function" or type(list.get) ~= "function" then
        return
    end
    for i = 0, list:size() - 1 do
        local p = list:get(i)
        if p then
            visitor(p)
        end
    end
end

function IKST_TransferServer.eachNearbyPlayer(cx, cy, cz, radius, visitor)
    if not visitor or cx == nil or cy == nil then
        return
    end
    radius = tonumber(radius) or IKST_TransferServer.NEAR_RADIUS
    IKST_TransferServer.eachOnlinePlayer(function(p)
        if type(p.getX) ~= "function" then
            return
        end
        local dx = p:getX() - cx
        local dy = p:getY() - cy
        local dz = (p:getZ() or 0) - (cz or 0)
        if (dx * dx + dy * dy) <= (radius * radius) and math.abs(dz) <= 2 then
            visitor(p)
        end
    end)
end

function IKST_TransferServer.containerSquare(container)
    return IKST_TransferServer.coordsForContainer(container)
end

function IKST_TransferServer.reconcileContainer(container)
    if not container or not IKST_TransferServer.containerNeedsGuard(container) then
        return
    end
    local key = containerKey(container)
    if not key then
        return
    end
    local current = IKST_TransferServer.readItemIds(container)
    local prev = IKST_TransferServer._prints[key]
    if not prev then
        IKST_TransferServer._prints[key] = current
        return
    end

    local cx, cy, cz = IKST_TransferServer.containerSquare(container)
    if not cx then
        IKST_TransferServer._prints[key] = current
        return
    end

    for itemId, _ in pairs(prev) do
        if not current[itemId] then
            if IKST_TransferServer.consumeAllow(itemId) then
                -- authorized (e.g. vendBuy)
            else
                local resolved = false
                IKST_TransferServer.eachOnlinePlayer(function(player)
                    if resolved then
                        return
                    end
                    local item, inv = IKST_TransferServer.findItemOnPlayer(player, itemId)
                    if not item or not inv then
                        return
                    end
                    local allowed = true
                    if IKST_TransferRules and type(IKST_TransferRules.transferAllowed) == "function" then
                        allowed = IKST_TransferRules.transferAllowed(item, container, inv, player, true) == true
                    end
                    if not allowed then
                        if IKST_TransferServer.returnItem(container, player, item, inv) then
                            resolved = true
                            current[itemId] = true
                            IKST_TransferServer.logDeny(player, "unauthorized container take reversed", container)
                            if IKST.notify then
                                IKST.notify(player, IKST.text("IGUI_IKST_Transfer_Denied", "That transfer is not allowed."), false)
                            end
                        end
                    else
                        resolved = true
                    end
                end)
                if not resolved then
                    current[itemId] = true
                end
            end
        end
    end

    for itemId, _ in pairs(current) do
        if not prev[itemId] then
            local item = IKST_TransferServer.findItemInContainer(container, itemId)
            if item then
                local keep = false
                local fallbackPlayer = nil
                IKST_TransferServer.eachNearbyPlayer(cx, cy, cz, IKST_TransferServer.NEAR_RADIUS, function(player)
                    local inv = type(player.getInventory) == "function" and player:getInventory() or nil
                    if not inv then
                        return
                    end
                    local allowed = true
                    if IKST_TransferRules and type(IKST_TransferRules.transferAllowed) == "function" then
                        allowed = IKST_TransferRules.transferAllowed(item, inv, container, player, true) == true
                    end
                    if allowed then
                        keep = true
                    elseif not fallbackPlayer then
                        fallbackPlayer = player
                    end
                end)
                if not keep and fallbackPlayer then
                    if IKST_TransferServer.removeFromContainerToPlayer(container, fallbackPlayer, item) then
                        current[itemId] = nil
                        IKST_TransferServer.logDeny(fallbackPlayer, "unauthorized container deposit reversed", container)
                        if IKST.notify then
                            IKST.notify(fallbackPlayer, IKST.text("IGUI_IKST_Transfer_Denied", "That transfer is not allowed."), false)
                        end
                    end
                end
            end
        end
    end

    IKST_TransferServer._prints[key] = current
end

function IKST_TransferServer.addGuardedContainer(container, out, seen)
    if not container or not IKST_TransferServer.containerNeedsGuard(container) then
        return
    end
    local key = containerKey(container)
    if not key or seen[key] then
        return
    end
    seen[key] = true
    out[#out + 1] = container
end

function IKST_TransferServer.collectVehicleContainers(vehicle, out, seen)
    if not vehicle then
        return
    end
    if type(vehicle.getPartCount) == "function" and type(vehicle.getPartByIndex) == "function" then
        local n = vehicle:getPartCount()
        if n then
            for i = 0, n - 1 do
                local part = vehicle:getPartByIndex(i)
                if part and type(part.getItemContainer) == "function" then
                    IKST_TransferServer.addGuardedContainer(part:getItemContainer(), out, seen)
                end
            end
        end
    end
end

function IKST_TransferServer.collectNearContainers(player, out, seen)
    if not player or type(player.getX) ~= "function" then
        return
    end
    local px = math.floor(player:getX())
    local py = math.floor(player:getY())
    local pz = math.floor(player:getZ() or 0)
    local id = 0
    if type(player.getOnlineID) == "function" then
        id = player:getOnlineID() or 0
    end
    local vid = 0
    if type(player.getVehicle) == "function" then
        local vehicle = player:getVehicle()
        if vehicle and type(vehicle.getId) == "function" then
            vid = vehicle:getId() or 0
        end
    end
    local cache = IKST_TransferServer._posCache[id]
    if cache and cache.x == px and cache.y == py and cache.z == pz and cache.vid == vid and cache.list then
        for i = 1, #cache.list do
            IKST_TransferServer.addGuardedContainer(cache.list[i], out, seen)
        end
        return
    end

    local gathered = {}
    local gatheredSeen = {}
    if type(player.getVehicle) == "function" then
        IKST_TransferServer.collectVehicleContainers(player:getVehicle(), gathered, gatheredSeen)
    end

    local cell = getCell and getCell()
    if cell and type(cell.getGridSquare) == "function" then
        local r = IKST_TransferServer.SCAN_RADIUS or 8
        for x = px - r, px + r do
            for y = py - r, py + r do
                local sq = cell:getGridSquare(x, y, pz)
                if sq and type(sq.getObjects) == "function" then
                    local objects = sq:getObjects()
                    if objects and type(objects.size) == "function" and type(objects.get) == "function" then
                        for i = 0, objects:size() - 1 do
                            local obj = objects:get(i)
                            if obj and type(obj.getContainer) == "function" then
                                IKST_TransferServer.addGuardedContainer(obj:getContainer(), gathered, gatheredSeen)
                            end
                            if obj and type(obj.getContainerCount) == "function" and type(obj.getContainerByIndex) == "function" then
                                local count = obj:getContainerCount()
                                if count and count > 0 then
                                    for j = 0, count - 1 do
                                        IKST_TransferServer.addGuardedContainer(obj:getContainerByIndex(j), gathered, gatheredSeen)
                                    end
                                end
                            end
                        end
                    end
                end
                if sq and type(sq.getVehicleContainer) == "function" then
                    IKST_TransferServer.collectVehicleContainers(sq:getVehicleContainer(), gathered, gatheredSeen)
                end
            end
        end
    end
    IKST_TransferServer._posCache[id] = { x = px, y = py, z = pz, vid = vid, list = gathered }
    for i = 1, #gathered do
        IKST_TransferServer.addGuardedContainer(gathered[i], out, seen)
    end
end

function IKST_TransferServer.onTick()
    if not IKST_TransferServer.active() then
        return
    end
    if IKST_TransferServer._busy then
        return
    end
    local now = nowMs()
    if now > 0 and (now - (IKST_TransferServer._lastScan or 0)) < IKST_TransferServer.SCAN_INTERVAL_MS then
        return
    end
    IKST_TransferServer._lastScan = now
    IKST_TransferServer._busy = true
    IKST_TransferServer.purgeExpiredAllows()

    local list = getOnlinePlayers and getOnlinePlayers()
    if not list or type(list.size) ~= "function" or type(list.get) ~= "function" then
        IKST_TransferServer._busy = false
        return
    end
    local containers = IKST_TransferServer._scanOut
    local seen = IKST_TransferServer._scanSeen
    for i = #containers, 1, -1 do
        containers[i] = nil
    end
    for k in pairs(seen) do
        seen[k] = nil
    end
    local liveIds = {}
    for i = 0, list:size() - 1 do
        local player = list:get(i)
        if player then
            if type(player.getOnlineID) == "function" then
                liveIds[player:getOnlineID() or 0] = true
            end
            IKST_TransferServer.collectNearContainers(player, containers, seen)
        end
    end
    for id in pairs(IKST_TransferServer._posCache) do
        if not liveIds[id] then
            IKST_TransferServer._posCache[id] = nil
        end
    end
    for _, container in ipairs(containers) do
        IKST_TransferServer.reconcileContainer(container)
    end
    IKST_TransferServer._busy = false
end

function IKST_TransferServer.init()
    if IKST_TransferServer._inited then
        return
    end
    IKST_TransferServer._inited = true
    if Events and Events.OnTick and Events.OnTick.Add then
        Events.OnTick.Add(IKST_TransferServer.onTick)
    end
end

IKST_TransferServer.init()
