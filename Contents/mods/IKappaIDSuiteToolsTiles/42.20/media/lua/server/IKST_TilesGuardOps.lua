if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end
require "IKST_Shared"
require "IKST_Grid"
require "IKST_TileProtect"
require "IKST_WorldOps"
require "IKST_TilesWorldOps"
require "IKST_WorldRules"
require "IKST_AutomationOps"
require "IKST_CommandQueue"
require "IKST_StaffOps"
require "IKST_Locks"
require "IKST_Access"
require "IKST_Policy"
require "IKST_SafehouseClaim"

IKST_TilesGuardOps = IKST_TilesGuardOps or {}

function IKST_TilesGuardOps.guardUsername(player)
    if not player then
        return nil
    end
    if player.getUsername then
        local name = player:getUsername()
        if name and name ~= "" then
            return name
        end
    end
    if player.getDisplayName then
        local name = player:getDisplayName()
        if name and name ~= "" then
            return name
        end
    end
    return "Player"
end

function IKST_TilesGuardOps.farmRevitalize(player, cx, cy, cz, radius)
    local squares = IKST_Grid.squaresInRadius(cx, cy, cz, radius)
    local n = 0
    for _, sq in ipairs(squares) do
        n = n + IKST_AutomationOps.waterPlantsOnSquare(sq, player)
        local objects = sq:getObjects()
        if objects then
            for i = 0, objects:size() - 1 do
                local obj = objects:get(i)
                if obj and obj.setHealth and obj.getHealth then
                    if obj.setMaxHealth and obj.getMaxHealth then
                        obj:setHealth(obj:getMaxHealth())
                    else
                        obj:setHealth(100)
                    end
                    n = n + 1
                end
            end
        end
    end
    return true, "revitalized " .. n
end

function IKST_TilesGuardOps.farmHarvest(player, cx, cy, cz, radius)
    local squares = IKST_Grid.squaresInRadius(cx, cy, cz, radius)
    local n = 0
    for _, sq in ipairs(squares) do
        if IKST_AutomationOps.skipProtected(sq, player) then
            -- skip claimed/protected squares
        else
            local objects = sq:getObjects()
            if objects then
                for i = objects:size() - 1, 0, -1 do
                    local obj = objects:get(i)
                    if obj and obj.harvest and type(obj.harvest) == "function" then
                        obj:harvest()
                        n = n + 1
                    end
                end
            end
        end
    end
    return true, "harvested " .. n
end

function IKST_TilesGuardOps.blueprintCopy(player, x1, y1, x2, y2, z)
    local data = ModData.getOrCreate("IKST_Blueprints")
    data.last = data.last or {}
    local tiles = {}
    local minX = math.min(math.floor(x1), math.floor(x2))
    local maxX = math.max(math.floor(x1), math.floor(x2))
    local minY = math.min(math.floor(y1), math.floor(y2))
    local maxY = math.max(math.floor(y1), math.floor(y2))
    z = tonumber(z) or 0
    local maxSpan = IKST.getMaxCleanupRadius and IKST.getMaxCleanupRadius() or 50
    if (maxX - minX) > maxSpan or (maxY - minY) > maxSpan then
        return false, "blueprint area too large"
    end
    for x = minX, maxX do
        for y = minY, maxY do
            local sq = IKST_TilesWorldOps.getSquare(x, y, z)
            if sq then
                local floorName = nil
                local floor = type(sq.getFloor) == "function" and sq:getFloor()
                if floor and type(floor.getSprite) == "function" and floor:getSprite() and floor:getSprite().getName then
                    floorName = floor:getSprite():getName()
                end
                local sprites = {}
                local objects = sq:getObjects()
                if objects then
                    for i = 0, objects:size() - 1 do
                        local obj = objects:get(i)
                        if obj and obj ~= floor and obj.getSprite then
                            local sprite = obj:getSprite()
                            if sprite and sprite.getName then
                                sprites[#sprites + 1] = sprite:getName()
                            end
                        end
                    end
                end
                if floorName or #sprites > 0 then
                    tiles[#tiles + 1] = {
                        dx = x - minX,
                        dy = y - minY,
                        floor = floorName,
                        sprites = sprites,
                    }
                end
            end
        end
    end
    data.last = {
        w = maxX - minX + 1,
        h = maxY - minY + 1,
        z = z,
        originX = minX,
        originY = minY,
        tiles = tiles,
        by = IKST_TilesGuardOps.guardUsername(player),
    }
    return true, "copied " .. #tiles .. " squares"
end

function IKST_TilesGuardOps.blueprintPaste(player, x, y, z, resetOrigin)
    local data = ModData.getOrCreate("IKST_Blueprints")
    local bp = data.last
    if not bp or not bp.tiles then
        return false, "no blueprint"
    end
    if not player then
        return false, "no player"
    end
    if resetOrigin == true and bp.originX ~= nil and bp.originY ~= nil then
        x = math.floor(tonumber(bp.originX) or 0)
        y = math.floor(tonumber(bp.originY) or 0)
        z = tonumber(bp.z) or z or 0
    else
        x = math.floor(tonumber(x) or 0)
        y = math.floor(tonumber(y) or 0)
        z = tonumber(z) or bp.z or 0
    end

    local ops = {}
    for _, entry in ipairs(bp.tiles) do
        local tx = x + entry.dx
        local ty = y + entry.dy
        if entry.floor and entry.floor ~= "" then
            ops[#ops + 1] = { x = tx, y = ty, z = z, sprite = entry.floor, floor = true }
        end
        for _, spriteName in ipairs(entry.sprites or {}) do
            ops[#ops + 1] = { x = tx, y = ty, z = z, sprite = spriteName, floor = false }
        end
    end
    if #ops == 0 then
        return false, "empty blueprint"
    end

    local placed = 0
    IKST_CommandQueue.enqueue(player, "blueprint paste", ops, function(op)
        local blocked = IKST_TilesWorldOps.locationMutationBlocked(player, op.x, op.y, op.z)
        if blocked then
            return false, "square protected"
        end
        local sq = IKST_TilesWorldOps.getSquare(op.x, op.y, op.z)
        if not sq or not op.sprite or op.sprite == "" then
            return false, "skip"
        end
        local ok
        if op.floor then
            ok = IKST_TilesWorldOps.replaceFloorSprite(sq, op.sprite, player)
        else
            ok = IKST_TilesWorldOps.placeSprite(sq, op.sprite, player)
        end
        if ok then
            placed = placed + 1
        end
        return ok, op.sprite
    end, function()
        IKST_WorldOps.sendResult(player, true, "placed " .. placed .. " sprites", x, y, z, IKST.CMD.blueprintPaste)
        IKST.pushLog(player, "blueprint placed " .. placed)
    end)

    return true, "paste started (" .. #ops .. ")"
end

local function normalizeBlueprintName(name)
    if not name or type(name) ~= "string" then
        return nil
    end
    name = string.gsub(name, "^%s*(.-)%s*$", "%1")
    if name == "" then
        return nil
    end
    if #name > 48 then
        name = string.sub(name, 1, 48)
    end
    return name
end

local function cloneBlueprint(bp)
    if not bp or not bp.tiles then
        return nil
    end
    local tiles = {}
    for i = 1, #bp.tiles do
        local e = bp.tiles[i]
        local sprites = {}
        if e.sprites then
            for j = 1, #e.sprites do
                sprites[j] = e.sprites[j]
            end
        end
        tiles[i] = {
            dx = e.dx,
            dy = e.dy,
            floor = e.floor,
            sprites = sprites,
        }
    end
    return {
        w = bp.w,
        h = bp.h,
        z = bp.z,
        originX = bp.originX,
        originY = bp.originY,
        tiles = tiles,
        by = bp.by,
        name = bp.name,
    }
end

function IKST_TilesGuardOps.blueprintSaveNamed(player, name)
    name = normalizeBlueprintName(name)
    if not name then
        return false, "enter a name"
    end
    local data = ModData.getOrCreate("IKST_Blueprints")
    if not data.last or not data.last.tiles then
        return false, "copy a blueprint first"
    end
    data.named = data.named or {}
    local saved = cloneBlueprint(data.last)
    saved.name = name
    saved.by = IKST_TilesGuardOps.guardUsername(player)
    data.named[name] = saved
    if IKST_StaffHistory and type(IKST_StaffHistory.record) == "function" then
        IKST_StaffHistory.record(player, "blueprint", "save " .. name, true)
    end
    return true, "saved blueprint '" .. name .. "'"
end

function IKST_TilesGuardOps.blueprintLoadNamed(player, name)
    name = normalizeBlueprintName(name)
    if not name then
        return false, "enter a name"
    end
    local data = ModData.getOrCreate("IKST_Blueprints")
    data.named = data.named or {}
    local bp = data.named[name]
    if not bp or not bp.tiles then
        return false, "blueprint not found"
    end
    data.last = cloneBlueprint(bp)
    data.last.name = name
    if IKST_StaffHistory and type(IKST_StaffHistory.record) == "function" then
        IKST_StaffHistory.record(player, "blueprint", "load " .. name, true)
    end
    return true, "loaded '" .. name .. "' (" .. #bp.tiles .. " squares)"
end

function IKST_TilesGuardOps.blueprintDeleteNamed(player, name)
    name = normalizeBlueprintName(name)
    if not name then
        return false, "enter a name"
    end
    local data = ModData.getOrCreate("IKST_Blueprints")
    data.named = data.named or {}
    if not data.named[name] then
        return false, "blueprint not found"
    end
    data.named[name] = nil
    if IKST_StaffHistory and type(IKST_StaffHistory.record) == "function" then
        IKST_StaffHistory.record(player, "blueprint", "delete " .. name, true)
    end
    return true, "deleted '" .. name .. "'"
end

function IKST_TilesGuardOps.blueprintListNamed()
    local data = ModData.getOrCreate("IKST_Blueprints")
    data.named = data.named or {}
    local names = {}
    for name, bp in pairs(data.named) do
        if bp and bp.tiles then
            names[#names + 1] = {
                name = name,
                tiles = #bp.tiles,
                w = bp.w,
                h = bp.h,
                by = bp.by,
            }
        end
    end
    table.sort(names, function(a, b)
        return tostring(a.name) < tostring(b.name)
    end)
    return names
end

function IKST_TilesGuardOps.snapshotPlayer(player)
    if not player then
        return false, "no player"
    end
    local username = IKST_TilesGuardOps.guardUsername(player)
    if not username then
        return false, "no username"
    end
    local data = ModData.getOrCreate("IKST_Restore")
    data.snapshots = data.snapshots or {}
    local snap = {
        time = getGameTime and getGameTime():getWorldAgeHours() or 0,
        x = player:getX(), y = player:getY(), z = player:getZ(),
    }
    if player.getModData then
        local md = player:getModData()
        snap.caught = md.IKST_caught
    end
    if player.getBodyDamage then
        local bd = player:getBodyDamage()
        snap.health = type(bd.getOverallBodyHealth) == "function" and bd:getOverallBodyHealth() or 100
        snap.infected = type(bd.IsInfected) == "function" and bd:IsInfected() or false
    end
    if player.getStats then
        local st = player:getStats()
        if st and CharacterStat and st.get then
            snap.hunger = st:get(CharacterStat.HUNGER) or 0
            snap.thirst = st:get(CharacterStat.THIRST) or 0
        end
    end
    data.snapshots[username] = snap
    return true, "snapshot saved"
end

function IKST_TilesGuardOps.restoreSnapshot(player)
    if not player then
        return false, "no player"
    end
    local username = IKST_TilesGuardOps.guardUsername(player)
    local data = ModData.getOrCreate("IKST_Restore")
    local snap = username and data.snapshots and data.snapshots[username]
    if not snap then
        return false, "no snapshot"
    end
    IKST_StaffOps.heal(player)
    IKST_StaffOps.feed(player)
    if snap.infected then
        IKST_StaffOps.cure(player)
    end
    if snap.x then
        IKST_StaffOps.teleportPlayer(player, snap.x, snap.y, snap.z or 0)
    end
    return true, "restored snapshot"
end

function IKST_TilesGuardOps.setLockPassword(x, y, z, password)
    if password and password ~= "" then
        IKST_Locks.setPassword(x, y, z, password)
        if IKST_Locks.setClearanceZone then
            IKST_Locks.setClearanceZone(x, y, z, nil)
        end
        return true, "lock set"
    end
    IKST_Locks.setPassword(x, y, z, nil)
    if IKST_Locks.setClearanceZone then
        IKST_Locks.setClearanceZone(x, y, z, nil)
    end
    return true, "lock cleared"
end

function IKST_TilesGuardOps.setClearanceLock(x, y, z, zoneId, player)
    if not IKST_Locks or not IKST_Locks.setClearanceZone then
        return false, "locks unavailable"
    end
    if not IKST_Locks.setClearanceZone(x, y, z, zoneId) then
        return false, "failed"
    end
    if player then
        IKST_Locks.markUnlocked(player, x, y, z)
        IKST_TilesGuardOps.syncLockUnlock(player, x, y, z)
    end
    return true, "clearance lock set"
end

function IKST_TilesGuardOps.findItemById(player, itemId)
    if not player or not itemId or not player.getInventory then
        return nil
    end
    local inv = player:getInventory()
    if not inv or not inv.getItemById then
        return nil
    end
    return inv:getItemById(itemId)
end

function IKST_TilesGuardOps.findContainerAt(x, y, z)
    local sq = IKST_Grid.getSquare(x, y, z)
    if not sq or not sq.getObjects then
        return nil, nil
    end
    local objects = sq:getObjects()
    if not objects then
        return nil, nil
    end
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj and type(obj.getContainer) == "function" then
            local container = obj:getContainer()
            if container then
                return obj, container
            end
        end
    end
    return nil, nil
end

function IKST_TilesGuardOps.playerMayInstallLock(player, x, y, z)
    if not player then
        return false, "no player"
    end
    if IKST_Access and type(IKST_Access.canUseTools) == "function" and IKST_Access.canUseTools(player) then
        return true
    end
    local square = IKST_Grid.getSquare(x, y, z)
    if not square then
        return false, "no_square"
    end
    if IKST_Economy and type(IKST_Economy.isProtectedShopObject) == "function"
        and type(IKST_Economy.playerMayManageShopStock) == "function"
        and type(square.getObjects) == "function" then
        local objects = square:getObjects()
        if objects and type(objects.size) == "function" and type(objects.get) == "function" then
            for i = 0, objects:size() - 1 do
                local obj = objects:get(i)
                if obj and IKST_Economy.isProtectedShopObject(obj)
                    and IKST_Economy.playerMayManageShopStock(obj, player) then
                    return true
                end
            end
        end
    end
    if IKST_SafehouseClaim and type(IKST_SafehouseClaim.entryForSquare) == "function" then
        local entry = select(1, IKST_SafehouseClaim.entryForSquare(square))
        if entry then
            if type(IKST_SafehouseClaim.isEntryExpired) == "function"
                and IKST_SafehouseClaim.isEntryExpired(entry) then
                return false, "not_your_claim"
            end
            if type(IKST_SafehouseClaim.isOwner) == "function" and IKST_SafehouseClaim.isOwner(entry, player) then
                return true
            end
            return false, "not_your_claim"
        end
    end
    return false, "not_your_claim"
end

function IKST_TilesGuardOps.installKeypad(player, x, y, z, password, itemId)
    if not player then
        return false, "no player"
    end
    local _, container = IKST_TilesGuardOps.findContainerAt(x, y, z)
    if not container then
        return false, "no container"
    end
    local mayLock, lockReason = IKST_TilesGuardOps.playerMayInstallLock(player, x, y, z)
    if not mayLock then
        return false, lockReason or "not_your_claim"
    end
    if IKST_Locks.isLocked(x, y, z) then
        local isStaff = IKST_Access and IKST_Access.canUseTools and IKST_Access.canUseTools(player)
        local hasUnlock = IKST_Locks.playerUnlocked(player, x, y, z)
        if not isStaff and not hasUnlock then
            return false, "lock already set"
        end
    end
    local item = IKST_TilesGuardOps.findItemById(player, itemId)
    if not item or type(item.getFullType) ~= "function" or item:getFullType() ~= IKST.KEYPAD_KIT_TYPE then
        return false, "no keypad kit"
    end
    if not password or password == "" then
        return false, "no password"
    end
    IKST_Locks.setPassword(x, y, z, password)
    IKST_Locks.markUnlocked(player, x, y, z)
    local inv = player:getInventory()
    if inv and type(inv.Remove) == "function" then
        inv:Remove(item)
    end
    IKST_TilesGuardOps.syncLockUnlock(player, x, y, z)
    return true, "keypad installed"
end

function IKST_TilesGuardOps.syncLockUnlock(player, x, y, z)
    if not player then
        return
    end
    if IKST.deliverClientCommand then
        IKST.deliverClientCommand(player, IKST.CMD.lockUnlockSync, {
            x = math.floor(tonumber(x) or 0),
            y = math.floor(tonumber(y) or 0),
            z = tonumber(z) or 0,
        })
    end
end

function IKST_TilesGuardOps.tryUnlock(player, x, y, z, password)
    local ok, msg = IKST_Locks.tryUnlock(player, x, y, z, password)
    if ok then
        IKST_TilesGuardOps.syncLockUnlock(player, x, y, z)
    end
    return ok, msg
end

function IKST_TilesGuardOps.tryClearance(player, x, y, z)
    local ok, msg = IKST_Locks.tryClearanceUnlock(player, x, y, z)
    if ok then
        IKST_TilesGuardOps.syncLockUnlock(player, x, y, z)
    end
    return ok, msg
end

function IKST_TilesGuardOps.handle(command, admin, args)
    args = args or {}
    local ax = math.floor(tonumber(args.x) or (admin and admin:getX()) or 0)
    local ay = math.floor(tonumber(args.y) or (admin and admin:getY()) or 0)
    local az = tonumber(args.z) or (admin and admin:getZ()) or 0
    local radius = IKST.clampRadius(args.radius)

    if command == IKST.CMD.setWorldRule then
        if IKST_WorldRules.setRule(args.rule, args.on) then
            IKST.transmitModData(IKST.ModDataKeys.WorldRules)
            return true, args.rule .. " " .. (args.on and "ON" or "OFF")
        end
        return false, "unknown rule"
    end

    if command == IKST.CMD.addSpriteBlacklist then
        if IKST_WorldRules.addSpriteBlacklist(args.sprite) then
            IKST.transmitModData(IKST.ModDataKeys.WorldRules)
            return true, "blacklisted"
        end
        return false, "invalid sprite"
    end

    if command == IKST.CMD.farmRevitalize then
        return IKST_TilesGuardOps.farmRevitalize(player, ax, ay, az, radius)
    end

    if command == IKST.CMD.farmHarvestAll then
        return IKST_TilesGuardOps.farmHarvest(player, ax, ay, az, radius)
    end

    if command == IKST.CMD.blueprintCopy then
        return IKST_TilesGuardOps.blueprintCopy(admin, args.x1, args.y1, args.x2, args.y2, az)
    end

    if command == IKST.CMD.blueprintPaste then
        return IKST_TilesGuardOps.blueprintPaste(admin, ax, ay, az, args.reset == true)
    end

    if command == IKST.CMD.blueprintSave then
        return IKST_TilesGuardOps.blueprintSaveNamed(admin, args and args.name)
    end

    if command == IKST.CMD.blueprintLoad then
        return IKST_TilesGuardOps.blueprintLoadNamed(admin, args and args.name)
    end

    if command == IKST.CMD.blueprintDelete then
        return IKST_TilesGuardOps.blueprintDeleteNamed(admin, args and args.name)
    end

    if command == IKST.CMD.blueprintList then
        local names = IKST_TilesGuardOps.blueprintListNamed()
        if IKST.deliverClientCommand then
            IKST.deliverClientCommand(admin, IKST.CMD.blueprintListResult, { blueprints = names })
        end
        return true, #names .. " blueprint(s)"
    end

    if command == IKST.CMD.createSnapshot then
        local target = args.target and IKST_StaffOps.findPlayerByOnlineID(args.target) or admin
        return IKST_TilesGuardOps.snapshotPlayer(target)
    end

    if command == IKST.CMD.restoreSnapshot then
        local target = args.target and IKST_StaffOps.findPlayerByOnlineID(args.target) or admin
        return IKST_TilesGuardOps.restoreSnapshot(target)
    end

    if command == IKST.CMD.lockSetPassword then
        return IKST_TilesGuardOps.setLockPassword(ax, ay, az, args.password)
    end

    if command == IKST.CMD.lockClear then
        return IKST_TilesGuardOps.setLockPassword(ax, ay, az, nil)
    end

    if command == IKST.CMD.lockTryUnlock then
        return IKST_TilesGuardOps.tryUnlock(admin, ax, ay, az, args.password)
    end

    if command == IKST.CMD.lockTryClearance then
        return IKST_TilesGuardOps.tryClearance(admin, ax, ay, az)
    end

    if command == IKST.CMD.clearanceSetLock then
        local zoneId = IKST_Args and IKST_Args.readZoneId(args, "zoneId")
        if not zoneId then
            return false, "invalid zone id"
        end
        return IKST_TilesGuardOps.setClearanceLock(ax, ay, az, zoneId, admin)
    end

    if command == IKST.CMD.lockInstallKeypad then
        return IKST_TilesGuardOps.installKeypad(admin, ax, ay, az, args.password, args.itemId)
    end

    return nil
end
