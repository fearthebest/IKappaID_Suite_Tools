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

function IKST_TilesGuardOps.farmRevitalize(cx, cy, cz, radius)
    local squares = IKST_Grid.squaresInRadius(cx, cy, cz, radius)
    local n = 0
    for _, sq in ipairs(squares) do
        n = n + IKST_AutomationOps.waterPlantsOnSquare(sq)
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

function IKST_TilesGuardOps.farmHarvest(cx, cy, cz, radius)
    local squares = IKST_Grid.squaresInRadius(cx, cy, cz, radius)
    local n = 0
    for _, sq in ipairs(squares) do
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
                local floor = sq.getFloor and sq:getFloor()
                if floor and floor.getSprite and floor:getSprite() and floor:getSprite().getName then
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
        tiles = tiles,
        by = IKST_TilesGuardOps.guardUsername(player),
    }
    return true, "copied " .. #tiles .. " squares"
end

function IKST_TilesGuardOps.blueprintPaste(player, x, y, z)
    local data = ModData.getOrCreate("IKST_Blueprints")
    local bp = data.last
    if not bp or not bp.tiles then
        return false, "no blueprint"
    end
    if not player then
        return false, "no player"
    end
    x = math.floor(tonumber(x) or 0)
    y = math.floor(tonumber(y) or 0)
    z = tonumber(z) or bp.z or 0

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
        local sq = IKST_TilesWorldOps.getSquare(op.x, op.y, op.z)
        if not sq or not op.sprite or op.sprite == "" then
            return false, "skip"
        end
        local ok
        if op.floor then
            ok = IKST_TilesWorldOps.replaceFloorSprite(sq, op.sprite)
        else
            ok = IKST_TilesWorldOps.placeSprite(sq, op.sprite)
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
        snap.health = bd.getOverallBodyHealth and bd:getOverallBodyHealth() or 100
        snap.infected = bd.IsInfected and bd:IsInfected() or false
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
    IKST_Locks.setPassword(x, y, z, password)
    if password and password ~= "" then
        return true, "lock set"
    end
    return true, "lock cleared"
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

function IKST_TilesGuardOps.installKeypad(player, x, y, z, password, itemId)
    if not player then
        return false, "no player"
    end
    local item = IKST_TilesGuardOps.findItemById(player, itemId)
    if not item or not item.getFullType or item:getFullType() ~= IKST.KEYPAD_KIT_TYPE then
        return false, "no keypad kit"
    end
    if not password or password == "" then
        return false, "no password"
    end
    IKST_Locks.setPassword(x, y, z, password)
    IKST_Locks.markUnlocked(player, x, y, z)
    local inv = player:getInventory()
    if inv and inv.Remove then
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
        return IKST_TilesGuardOps.farmRevitalize(ax, ay, az, radius)
    end

    if command == IKST.CMD.farmHarvestAll then
        return IKST_TilesGuardOps.farmHarvest(ax, ay, az, radius)
    end

    if command == IKST.CMD.blueprintCopy then
        return IKST_TilesGuardOps.blueprintCopy(admin, args.x1, args.y1, args.x2, args.y2, az)
    end

    if command == IKST.CMD.blueprintPaste then
        return IKST_TilesGuardOps.blueprintPaste(admin, ax, ay, az)
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

    if command == IKST.CMD.lockInstallKeypad then
        return IKST_TilesGuardOps.installKeypad(admin, ax, ay, az, args.password, args.itemId)
    end

    return nil
end
