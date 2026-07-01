if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end
require "IKST_Shared"
require "IKST_Access"
require "IKST_Grid"
require "IKST_WorldOps"
require "IKST_TileProtect"
require "IKST_CommandQueue"
require "IKST_Rewind"
require "IKST_SafehouseClaim"

IKST_TilesWorldOps = IKST_TilesWorldOps or {}
IKST_TilesWorldOps._batchRemoved = IKST_TilesWorldOps._batchRemoved or {}

function IKST_TilesWorldOps.claimEditBlocked(player, x, y, z)
    local sv = SandboxVars and SandboxVars.IKappaIDSuiteToolsTiles
    if not sv or sv.ProtectClaimedSafehouses ~= true then
        return false
    end
    if not IKST_SafehouseClaim or not player then
        return false
    end
    local square = IKST_TilesWorldOps.getSquare(x, y, z)
    if not square then
        return false
    end
    local allowed = IKST_SafehouseClaim.canAtSquare(player, square, "destroy")
    return allowed == false
end

function IKST_TilesWorldOps.paintDistanceOk(player, x, y, z)
    if not player or not player.getX then
        return true
    end
    local maxR = IKST.getMaxPaintRadius and IKST.getMaxPaintRadius() or 25
    local dx = (tonumber(x) or 0) - player:getX()
    local dy = (tonumber(y) or 0) - player:getY()
    return (dx * dx + dy * dy) <= (maxR * maxR)
end

function IKST_TilesWorldOps.beginBatch()
    IKST_TilesWorldOps._batchRemoved = {}
end

function IKST_TilesWorldOps.endBatch()
    IKST_TilesWorldOps._batchRemoved = {}
end

function IKST_TilesWorldOps.syncSquare(square)
    if not square then
        return
    end
    if square.RecalcProperties then
        square:RecalcProperties()
    end
    if IKST.isMultiplayerSession and IKST.isMultiplayerSession() and square.transmitModdata then
        square:transmitModdata()
    end
end

function IKST_TilesWorldOps.transmitRemove(square, obj)
    if not square or not obj then
        return
    end
    if not IKST.isMultiplayerSession or not IKST.isMultiplayerSession() then
        return
    end
    if square.transmitRemoveItemFromSquare then
        square:transmitRemoveItemFromSquare(obj)
    end
end

function IKST_TilesWorldOps.removeMultiTileObject(obj)
    if not obj or not IsoObjectUtils or not IsoObjectUtils.getAllMultiTileObjects or not ArrayList then
        return false
    end
    local list = ArrayList.new()
    if IsoObjectUtils.getAllMultiTileObjects(obj, list) ~= true or list:size() < 1 then
        return false
    end
    IKST_TilesWorldOps._batchRemoved[obj] = true
    for i = 0, list:size() - 1 do
        local part = list:get(i)
        local partSq = part and part.getSquare and part:getSquare()
        if partSq then
            IKST_TilesWorldOps.transmitRemove(partSq, part)
            if partSq.RemoveTileObject then
                partSq:RemoveTileObject(part, false)
            elseif part.removeFromSquare then
                part:removeFromSquare()
            end
        end
    end
    if not IKST_Debug then
        require "IKST_Debug"
    end
    if IKST_Debug and IKST_Debug.logEffect then
        IKST_Debug.logEffect("tiles", "multi-remove", "parts=" .. tostring(list:size()), nil)
    end
    return true
end

function IKST_TilesWorldOps.isVegetationSprite(spriteName)
    if not spriteName or spriteName == "" then
        return false
    end
    local lower = string.lower(spriteName)
    if string.find(lower, "vegetation", 1, true) then
        return true
    end
    if string.find(lower, "trees_", 1, true) then
        return true
    end
    if string.find(lower, "tree_", 1, true) then
        return true
    end
    if string.find(lower, "blends_natural", 1, true) then
        return true
    end
    return false
end

function IKST_TilesWorldOps.isFloorSprite(spriteName)
    if not spriteName or spriteName == "" then
        return false
    end
    local lower = string.lower(spriteName)
    if string.find(lower, "floors_", 1, true) then
        return true
    end
    if string.find(lower, "blends_grassoverlays", 1, true) then
        return true
    end
    return string.find(lower, "blends_natural", 1, true) ~= nil
end

function IKST_TilesWorldOps.restoreKindOf(obj, square)
    if not obj then
        return "object"
    end
    if instanceof(obj, "IsoTree") then
        return "tree"
    end
    if instanceof(obj, "IsoBush") then
        return "bush"
    end
    local floor = square and square.getFloor and square:getFloor()
    if floor and obj == floor then
        return "floor"
    end
    return "object"
end

function IKST_TilesWorldOps.makeRestoreRecord(obj, square)
    local spriteName = IKST_TilesWorldOps.spriteNameOf(obj)
    if not spriteName then
        return nil
    end
    return {
        sprite = spriteName,
        kind = IKST_TilesWorldOps.restoreKindOf(obj, square),
    }
end

function IKST_TilesWorldOps.normalizeRestoreRecord(item)
    if type(item) == "string" then
        local kind = "object"
        if IKST_TilesWorldOps.isVegetationSprite(item) then
            local lower = string.lower(item)
            if string.find(lower, "tree", 1, true) then
                kind = "tree"
            else
                kind = "bush"
            end
        elseif IKST_TilesWorldOps.isFloorSprite(item) then
            kind = "floor"
        end
        return { sprite = item, kind = kind }
    end
    if type(item) == "table" and item.sprite then
        return { sprite = item.sprite, kind = item.kind or "object" }
    end
    return nil
end

function IKST_TilesWorldOps.placeTree(square, spriteName)
    if not square or not spriteName or spriteName == "" then
        return false
    end
    if not IsoTree or not IsoTree.new then
        return IKST_TilesWorldOps.placeSprite(square, spriteName)
    end
    local tree = IsoTree.new(square, spriteName)
    if not tree then
        return false
    end
    if tree.initTree then
        tree:initTree()
    end
    if IKST.isMultiplayerSession and IKST.isMultiplayerSession() and tree.transmitCompleteItemToClients then
        tree:transmitCompleteItemToClients()
    end
    return true
end

function IKST_TilesWorldOps.placeBush(square, spriteName)
    if not square or not spriteName or spriteName == "" then
        return false
    end
    if IsoBush and IsoBush.new then
        local bush = IsoBush.new(square, spriteName)
        if bush then
            if bush.initTree then
                bush:initTree()
            end
            if IKST.isMultiplayerSession and IKST.isMultiplayerSession() and bush.transmitCompleteItemToClients then
                bush:transmitCompleteItemToClients()
            end
            return true
        end
    end
    return IKST_TilesWorldOps.placeSprite(square, spriteName)
end

function IKST_TilesWorldOps.placeRestored(square, item)
    local record = IKST_TilesWorldOps.normalizeRestoreRecord(item)
    if not record then
        return false
    end
    if record.kind == "tree" then
        return IKST_TilesWorldOps.placeTree(square, record.sprite)
    end
    if record.kind == "bush" then
        return IKST_TilesWorldOps.placeBush(square, record.sprite)
    end
    if record.kind == "floor" then
        return IKST_TilesWorldOps.replaceFloorSprite(square, record.sprite)
    end
    return IKST_TilesWorldOps.placeSprite(square, record.sprite)
end

function IKST_TilesWorldOps.isMultiTileObject(obj)
    if not obj or not IsoObjectUtils or not IsoObjectUtils.isObjectMultiSquare then
        return false
    end
    return IsoObjectUtils.isObjectMultiSquare(obj) == true
end

function IKST_TilesWorldOps.multiTilePartsIntact(obj)
    if not IKST_TilesWorldOps.isMultiTileObject(obj) then
        return true
    end
    if not IsoObjectUtils or not IsoObjectUtils.getAllMultiTileObjects or not ArrayList then
        return false
    end
    local list = ArrayList.new()
    if IsoObjectUtils.getAllMultiTileObjects(obj, list) ~= true then
        return false
    end
    if list:size() < 1 then
        return false
    end
    for i = 0, list:size() - 1 do
        local part = list:get(i)
        if not part or not part.getSquare or not part:getSquare() then
            return false
        end
    end
    return true
end

function IKST_TilesWorldOps.shouldUseSafeTileRemove(square, obj, isTile)
    if isTile then
        return true
    end
    if not square or not obj then
        return false
    end
    local floor = square.getFloor and square:getFloor()
    if floor and obj == floor then
        return true
    end
    return IKST_TilesWorldOps.isMultiTileObject(obj)
end

function IKST_TilesWorldOps.getSquare(x, y, z)
    return IKST_Grid.getSquare(x, y, z)
end

function IKST_TilesWorldOps.spriteNameOf(obj)
    if not obj then
        return nil
    end
    local name = IKST_TilesWorldOps.describeObject(obj)
    if not name or name == "object" then
        return nil
    end
    return name
end

function IKST_TilesWorldOps.placeSprite(square, spriteName)
    if not square or not spriteName or spriteName == "" then
        return false
    end
    local lower = string.lower(spriteName)
    local floorLike = string.find(lower, "floors_", 1, true)
        or string.find(lower, "blends_natural", 1, true)
        or string.find(lower, "blends_grassoverlays", 1, true)
    if floorLike and square.addTileObject then
        square:addTileObject(spriteName)
        return true
    end
    if IsoObject and IsoObject.new and square.AddSpecialObject then
        local obj = IsoObject.new(square, spriteName, nil, false)
        if obj then
            square:AddSpecialObject(obj)
            if IKST.isMultiplayerSession and IKST.isMultiplayerSession() then
                if obj.transmitCompleteItemToClients then
                    obj:transmitCompleteItemToClients()
                elseif square.transmitAddObjectToSquare and obj.getObjectIndex then
                    square:transmitAddObjectToSquare(obj, obj:getObjectIndex())
                end
            end
            return true
        end
    end
    if square.addTileObject then
        square:addTileObject(spriteName)
        return true
    end
    if getCell and getCell().addTileObject then
        getCell():addTileObject(square, spriteName)
        return true
    end
    return false
end

function IKST_TilesWorldOps.replaceFloorSprite(square, spriteName)
    if not square or not spriteName or spriteName == "" then
        return false
    end
    local floor = square.getFloor and square:getFloor()
    if floor then
        IKST_TilesWorldOps.removeObjectFromSquare(square, floor, true)
    end
    return IKST_TilesWorldOps.placeSprite(square, spriteName)
end

function IKST_TilesWorldOps.recordRewind(player, label, square, sprites, mode)
    if not player or not square or not sprites or #sprites == 0 then
        return
    end
    IKST_Rewind.recordSquare(player, label, square:getX(), square:getY(), square:getZ(), sprites, mode)
end

function IKST_TilesWorldOps.rewind(player)
    local step = IKST_Rewind.pop(player)
    if not step then
        return false, "nothing to rewind"
    end
    local allowVegetation = step.mode == IKST.CLEANUP_MODES.vegetation
        or step.mode == IKST.CMD.cleanupVegetation
        or step.mode == "vegetation"
    local restored = 0
    for _, entry in ipairs(step.entries) do
        local sq = IKST_TilesWorldOps.getSquare(entry.x, entry.y, entry.z)
        if sq and entry.sprites then
            for i = #entry.sprites, 1, -1 do
                local record = IKST_TilesWorldOps.normalizeRestoreRecord(entry.sprites[i])
                if record then
                    local allow = allowVegetation
                        or (not IKST_TilesWorldOps.isVegetationSprite(record.sprite)
                            and not IKST_TilesWorldOps.isFloorSprite(record.sprite))
                    if allow and IKST_TilesWorldOps.placeRestored(sq, record) then
                        restored = restored + 1
                    end
                end
            end
            IKST_TilesWorldOps.syncSquare(sq)
        end
    end
    return true, "rewound " .. step.label .. " (" .. restored .. " sprites)"
end

function IKST_TilesWorldOps.isRemovableObject(obj, floor)
    if not obj then
        return false
    end
    if floor and obj == floor then
        return false
    end
    if instanceof(obj, "IsoPlayer") then
        return false
    end
    if instanceof(obj, "IsoDeadBody") then
        return false
    end
    if instanceof(obj, "IsoZombie") then
        return false
    end
    return true
end

function IKST_TilesWorldOps.isVegetationObject(obj, square)
    return IKST.isVegetationObject(obj, square)
end

function IKST_TilesWorldOps.describeObject(obj)
    if not obj then
        return "object"
    end
    if obj.getSprite and obj:getSprite() and obj:getSprite():getName() then
        return obj:getSprite():getName()
    end
    if obj.getObjectName then
        return tostring(obj:getObjectName())
    end
    return "object"
end

function IKST_TilesWorldOps.removeObjectFromSquare(square, obj, isTile)
    if not square or not obj then
        return false
    end

    if IKST_TilesWorldOps._batchRemoved[obj] then
        return true
    end

    local safeTileRemove = IKST_TilesWorldOps.shouldUseSafeTileRemove(square, obj, isTile)
    if safeTileRemove and IKST_TilesWorldOps.isMultiTileObject(obj) then
        local objSquare = obj.getSquare and obj:getSquare()
        if objSquare and objSquare ~= square then
            return false
        end
        if not IKST_TilesWorldOps.multiTilePartsIntact(obj) then
            return false
        end
        return IKST_TilesWorldOps.removeMultiTileObject(obj)
    end

    if safeTileRemove then
        IKST_TilesWorldOps._batchRemoved[obj] = true
        IKST_TilesWorldOps.transmitRemove(square, obj)
        if square.RemoveTileObject then
            square:RemoveTileObject(obj, false)
            return true
        end
        if square.DeleteTileObject then
            square:DeleteTileObject(obj)
            return true
        end
    end

    IKST_TilesWorldOps.transmitRemove(square, obj)
    if obj.removeFromSquare then
        obj:removeFromSquare()
    end
    return true
end

function IKST_TilesWorldOps.removeRoofPieces(square)
    if not square then
        return false, "no square", {}
    end
    local sprites = {}
    local label = "roof"
    local objects = square:getObjects()
    if not objects then
        return false, "no roof", {}
    end
    local floor = square:getFloor()
    for i = objects:size() - 1, 0, -1 do
        local obj = objects:get(i)
        if obj ~= floor and IKST_Grid.isRoofObject(obj) then
            local spriteName = IKST_TilesWorldOps.spriteNameOf(obj)
            if spriteName then
                sprites[#sprites + 1] = spriteName
                label = spriteName
            end
            IKST_TilesWorldOps.removeObjectFromSquare(square, obj, true)
        end
    end
    floor = square:getFloor()
    if floor and IKST_Grid.isRoofObject(floor) then
        local spriteName = IKST_TilesWorldOps.spriteNameOf(floor)
        if spriteName then
            sprites[#sprites + 1] = spriteName
            label = spriteName
        end
        IKST_TilesWorldOps.removeObjectFromSquare(square, floor, true)
    end
    if #sprites > 0 then
        return true, label, sprites
    end
    return false, "no roof", {}
end

function IKST_TilesWorldOps.inspectSquare(square)
    local items = {}
    if not square then
        return items
    end
    local objects = square:getObjects()
    if objects then
        for i = 0, objects:size() - 1 do
            local obj = objects:get(i)
            items[#items + 1] = {
                index = i,
                name = IKST_TilesWorldOps.describeObject(obj),
                isFloor = square:getFloor() == obj,
            }
        end
    end
    return items
end

function IKST_TilesWorldOps.removeTopObject(square)
    if not square then
        return false, "no square", {}
    end
    local objects = square:getObjects()
    if not objects then
        return false, "empty", {}
    end
    local floor = square:getFloor()
    if IKST_LootOps and IKST_LootOps.countLootObjectsOnSquare and IKST_LootOps.countLootObjectsOnSquare(square) > 1 then
        for i = objects:size() - 1, 0, -1 do
            local obj = objects:get(i)
            if obj and IKST_LootOps.isLootObject(obj, floor) and IKST_LootOps.removeLootObjectFromSquare(square, obj) then
                local spriteName = IKST_TilesWorldOps.spriteNameOf(obj)
                if spriteName then
                    return true, spriteName, { spriteName }
                end
                return true, "duplicate container", {}
            end
        end
    end
    for i = objects:size() - 1, 0, -1 do
        local obj = objects:get(i)
        if IKST_Grid.isRoofObject(obj) and IKST_TilesWorldOps.isRemovableObject(obj, floor) then
            local spriteName = IKST_TilesWorldOps.spriteNameOf(obj)
            IKST_TilesWorldOps.removeObjectFromSquare(square, obj, true)
            if spriteName then
                return true, spriteName, { spriteName }
            end
            return true, "roof", {}
        end
    end
    for i = objects:size() - 1, 0, -1 do
        local obj = objects:get(i)
        if IKST_TilesWorldOps.isRemovableObject(obj, floor)
            and not IKST_TilesWorldOps.isVegetationObject(obj, square) then
            local spriteName = IKST_TilesWorldOps.spriteNameOf(obj)
            IKST_TilesWorldOps.removeObjectFromSquare(square, obj, false)
            if spriteName then
                return true, spriteName, { spriteName }
            end
            return true, "object", {}
        end
    end
    if IKST_Grid.squareHasRoof(square) then
        return IKST_TilesWorldOps.removeRoofPieces(square)
    end
    return false, "nothing to remove", {}
end

function IKST_TilesWorldOps.removeTile(square)
    if not square then
        return false, "no tile", {}
    end
    return IKST_TilesWorldOps.removeTopObject(square)
end

function IKST_TilesWorldOps.clearSquare(square)
    if not square then
        return false, "no square", {}
    end
    local objects = square:getObjects()
    if not objects then
        return false, "empty", {}
    end
    local floor = square:getFloor()
    local sprites = {}
    for i = objects:size() - 1, 0, -1 do
        local obj = objects:get(i)
        if IKST_TilesWorldOps.isRemovableObject(obj, floor) then
            local record = IKST_TilesWorldOps.makeRestoreRecord(obj, square)
            if record then
                sprites[#sprites + 1] = record
            end
            local isTile = IKST_TilesWorldOps.shouldUseSafeTileRemove(square, obj, false)
            IKST_TilesWorldOps.removeObjectFromSquare(square, obj, isTile)
        end
    end
    if #sprites > 0 then
        return true, #sprites .. " object(s)", sprites
    end
    return false, "empty", {}
end

function IKST_TilesWorldOps.removeVegetation(square)
    if not square then
        return false, "no square", {}
    end
    local targets = IKST.collectVegetationOnSquare(square)
    if #targets == 0 then
        return false, "empty", {}
    end
    local sprites = {}
    local floor = square.getFloor and square:getFloor()
    for i = #targets, 1, -1 do
        local obj = targets[i]
        if floor and obj == floor then
            -- never strip the square floor in vegetation mode
        else
            local record = IKST_TilesWorldOps.makeRestoreRecord(obj, square)
            if record then
                sprites[#sprites + 1] = record
            end
            local isTile = false
            IKST_TilesWorldOps.removeObjectFromSquare(square, obj, isTile)
        end
    end
    if #sprites > 0 then
        return true, #sprites .. " vegetation", sprites
    end
    return false, "empty", {}
end

function IKST_TilesWorldOps.cleanupModeToCommand(mode)
    if mode == IKST.CLEANUP_MODES.removeTile then
        return IKST.CMD.cleanupTile
    end
    if mode == IKST.CLEANUP_MODES.clearSquare then
        return IKST.CMD.cleanupSquare
    end
    if mode == IKST.CLEANUP_MODES.vegetation then
        return "vegetation"
    end
    return IKST.CMD.cleanupObject
end

function IKST_TilesWorldOps.removeObjectAtIndex(square, objectIndex)
    if not square then
        return false, "no square", {}
    end
    local objects = square:getObjects()
    if not objects then
        return false, "empty", {}
    end
    objectIndex = math.floor(tonumber(objectIndex) or -1)
    if objectIndex < 0 or objectIndex >= objects:size() then
        return false, "no object", {}
    end
    local obj = objects:get(objectIndex)
    local floor = square:getFloor()
    if not IKST_TilesWorldOps.isRemovableObject(obj, floor) then
        return false, "protected object", {}
    end
    local spriteName = IKST_TilesWorldOps.spriteNameOf(obj)
    local isTile = IKST_TilesWorldOps.shouldUseSafeTileRemove(square, obj, false)
    IKST_TilesWorldOps.removeObjectFromSquare(square, obj, isTile)
    if spriteName then
        return true, spriteName, { spriteName }
    end
    return true, "object", {}
end

function IKST_TilesWorldOps.applyCleanupOnSquare(square, mode, objectIndex)
    if objectIndex ~= nil and (mode == IKST.CMD.cleanupObject or mode == IKST.CLEANUP_MODES.removeObject) then
        return IKST_TilesWorldOps.removeObjectAtIndex(square, objectIndex)
    end
    if mode == IKST.CMD.cleanupTile or mode == IKST.CLEANUP_MODES.removeTile then
        return IKST_TilesWorldOps.removeTile(square)
    end
    if mode == IKST.CMD.cleanupSquare or mode == IKST.CLEANUP_MODES.clearSquare then
        return IKST_TilesWorldOps.clearSquare(square)
    end
    if mode == "vegetation" or mode == IKST.CLEANUP_MODES.vegetation then
        return IKST_TilesWorldOps.removeVegetation(square)
    end
    return IKST_TilesWorldOps.removeTopObject(square)
end

function IKST_TilesWorldOps.runCleanup(mode, x, y, z, player, rewindLabel, objectIndex)
    if IKST_TileProtect and IKST_TileProtect.isTileProtected(x, y, z) then
        return false, "tile protected"
    end
    if IKST_TilesWorldOps.claimEditBlocked(player, x, y, z) then
        return false, "claim protected"
    end
    local square = IKST_TilesWorldOps.getSquare(x, y, z)
    if not square then
        return false, "invalid square"
    end
    IKST_TilesWorldOps.beginBatch()
    local ok, message, sprites = IKST_TilesWorldOps.applyCleanupOnSquare(square, mode, objectIndex)
    IKST_TilesWorldOps.endBatch()
    IKST_TilesWorldOps.syncSquare(square)
    if ok and player then
        IKST_TilesWorldOps.recordRewind(player, rewindLabel or tostring(mode), square, sprites, mode)
    end
    return ok, message
end

function IKST_TilesWorldOps.runBatch(player, squares, mode, label)
    local coords = {}
    for _, sq in ipairs(squares) do
        coords[#coords + 1] = { x = sq:getX(), y = sq:getY(), z = sq:getZ() }
    end
    local rewindEntries = {}
    IKST_TilesWorldOps.beginBatch()
    IKST_CommandQueue.enqueue(player, label, coords, function(c)
        if IKST_TileProtect and IKST_TileProtect.isTileProtected(c.x, c.y, c.z) then
            return false, "tile protected"
        end
        if IKST_TilesWorldOps.claimEditBlocked(player, c.x, c.y, c.z) then
            return false, "claim protected"
        end
        local sq = IKST_TilesWorldOps.getSquare(c.x, c.y, c.z)
        if not sq then
            return false, "missing"
        end
        local ok, msg, sprites = IKST_TilesWorldOps.applyCleanupOnSquare(sq, mode)
        if ok and sprites and #sprites > 0 then
            rewindEntries[#rewindEntries + 1] = {
                x = c.x, y = c.y, z = c.z, sprites = sprites,
            }
        end
        return ok, msg
    end, function(results)
        IKST_TilesWorldOps.endBatch()
        local okCount = 0
        for _, r in ipairs(results) do
            if r.ok then okCount = okCount + 1 end
        end
        for _, entry in ipairs(rewindEntries) do
            IKST_TilesWorldOps.syncSquare(IKST_TilesWorldOps.getSquare(entry.x, entry.y, entry.z))
        end
        if player and #rewindEntries > 0 then
            IKST_Rewind.push(player, label, rewindEntries, mode)
        end
        IKST_WorldOps.sendResult(player, true, label .. ": " .. okCount .. "/" .. #coords, nil, nil, nil, mode)
        IKST.pushLog(player, label .. " " .. okCount .. "/" .. #coords)
    end)
end

function IKST_TilesWorldOps.paintPlace(x, y, z, spriteName, player)
    if player and not IKST_TilesWorldOps.paintDistanceOk(player, x, y, z) then
        return false, "too far to paint"
    end
    if IKST_TileProtect and IKST_TileProtect.isTileProtected(x, y, z) then
        return false, "tile protected"
    end
    if IKST_TilesWorldOps.claimEditBlocked(player, x, y, z) then
        return false, "claim protected"
    end
    local square = IKST_TilesWorldOps.getSquare(x, y, z)
    if not square or not spriteName or spriteName == "" then
        return false, "invalid"
    end
    if getSprite and not getSprite(spriteName) then
        return false, "sprite not in tile defs: " .. spriteName
    end
    local obj = nil
    if square.addTileObject then
        obj = square:addTileObject(spriteName)
    end
    if not obj and IsoObject and IsoObject.new and square.AddSpecialObject then
        obj = IsoObject.new(square, spriteName, nil, false)
        if obj then
            square:AddSpecialObject(obj)
        end
    end
    if not obj then
        if getCell and getCell().addTileObject then
            getCell():addTileObject(square, spriteName)
            return true, spriteName
        end
        return false, "could not place"
    end
    if obj.createContainersFromSpriteProperties then
        local container = obj.getContainer and obj:getContainer() or nil
        if not container then
            obj:createContainersFromSpriteProperties()
        end
    end
    if obj.transmitCompleteItemToClients and IKST.isMultiplayerSession and IKST.isMultiplayerSession() then
        obj:transmitCompleteItemToClients()
    end
    return true, spriteName
end
