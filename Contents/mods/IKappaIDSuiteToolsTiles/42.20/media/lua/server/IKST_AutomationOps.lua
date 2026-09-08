-- Admin batch automations (one-shot server batches).
if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end

require "IKST_Shared"
require "IKST_Grid"
require "IKST_WorldOps"
require "IKST_TilesWorldOps"
require "IKST_CommandQueue"
require "IKST_TileProtect"
require "IKST_Policy"

IKST_AutomationOps = IKST_AutomationOps or {}

function IKST_AutomationOps.skipProtected(square, player)
    if not square then
        return true
    end
    if not IKST_Policy then
        require "IKST_Policy"
    end
    local allowed = IKST_Policy.locationAllowed(player, square, "tiles")
    return allowed ~= true
end

function IKST_AutomationOps.isTreeObject(obj, square)
    if not obj then
        return false
    end
    local floor = square and type(square.getFloor) == "function" and square:getFloor()
    if floor and obj == floor then
        return false
    end
    if instanceof(obj, "IsoTree") then
        return true
    end
    if not obj.getSprite then
        return false
    end
    local sprite = obj:getSprite()
    if not sprite or not sprite.getName then
        return false
    end
    local name = string.lower(sprite:getName() or "")
    if string.find(name, "floors_", 1, true) or string.find(name, "street", 1, true) then
        return false
    end
    return string.find(name, "tree", 1, true)
end

function IKST_AutomationOps.removeTrees(square, player)
    if not square or IKST_AutomationOps.skipProtected(square, player) then
        return false, "skip", {}
    end
    local sprites = {}
    local tree = type(square.getTree) == "function" and square:getTree()
    if tree then
        local spriteName = IKST_TilesWorldOps.spriteNameOf(tree)
        if spriteName then
            sprites[#sprites + 1] = spriteName
        end
        IKST_TilesWorldOps.removeObjectFromSquare(square, tree, false)
        return true, "1 tree(s)", sprites
    end
    local objects = type(square.getObjects) == "function" and square:getObjects()
    if not objects then
        return false, "empty", {}
    end
    for i = objects:size() - 1, 0, -1 do
        local obj = objects:get(i)
        if IKST_AutomationOps.isTreeObject(obj, square) then
            local spriteName = IKST_TilesWorldOps.spriteNameOf(obj)
            if spriteName then
                sprites[#sprites + 1] = spriteName
            end
            IKST_TilesWorldOps.removeObjectFromSquare(square, obj, false)
        end
    end
    if #sprites > 0 then
        return true, #sprites .. " tree(s)", sprites
    end
    return false, "empty", {}
end

local SOIL_ITEMS = {
    dirt = "Base.Dirtbag",
    sand = "Base.Sandbag",
    gravel = "Base.Gravelbag",
}

function IKST_AutomationOps.soilTypeOnSquare(square)
    if not square or not square.getFloor then
        return nil
    end
    local floor = square:getFloor()
    if not floor or not floor.getSprite then
        return nil
    end
    local sprite = floor:getSprite()
    if not sprite or not sprite.getName then
        return nil
    end
    local name = string.lower(sprite:getName() or "")
    if string.find(name, "gravel", 1, true) then
        return "gravel"
    end
    if string.find(name, "sand", 1, true) then
        return "sand"
    end
    if string.find(name, "dirt", 1, true) or string.find(name, "soil", 1, true) then
        return "dirt"
    end
    return nil
end

function IKST_AutomationOps.gravelSquare(player, square)
    if not square or IKST_AutomationOps.skipProtected(square, player) then
        return false, "skip"
    end
    local soil = IKST_AutomationOps.soilTypeOnSquare(square)
    if not soil then
        return false, "no soil"
    end
    local itemType = SOIL_ITEMS[soil]
    if not itemType or not player or not player.getInventory then
        return false, "no item"
    end
    local inv = player:getInventory()
    if not inv or not inv.AddItem then
        return false, "no inv"
    end
    inv:AddItem(itemType)
    return true, soil
end

function IKST_AutomationOps.moveCorpsesToSquare(fromSquare, toSquare, player)
    if not fromSquare or not toSquare then
        return 0
    end
    if IKST_AutomationOps.skipProtected(fromSquare, player)
        or IKST_AutomationOps.skipProtected(toSquare, player) then
        return 0
    end
    local objects = fromSquare:getObjects()
    if not objects then
        return 0
    end
    local moved = 0
    for i = objects:size() - 1, 0, -1 do
        local obj = objects:get(i)
        if obj and instanceof(obj, "IsoDeadBody") then
            if fromSquare.removeCorpse then
                fromSquare:removeCorpse(obj, false)
            elseif obj.removeFromSquare then
                obj:removeFromSquare()
            end
            if toSquare.addCorpse then
                toSquare:addCorpse(obj, false)
                moved = moved + 1
                if not IKST_Debug then
                    require "IKST_Debug"
                end
                if IKST_Debug and IKST_Debug.logEffect then
                    IKST_Debug.logEffect("tiles", "corpse-move",
                        string.format("%s,%s -> %s,%s", tostring(fromSquare:getX()), tostring(fromSquare:getY()),
                            tostring(toSquare:getX()), tostring(toSquare:getY())), nil)
                end
            end
        end
    end
    return moved
end

function IKST_AutomationOps.waterPlantsOnSquare(square, player)
    if not square or IKST_AutomationOps.skipProtected(square, player) then
        return 0
    end
    local objects = square:getObjects()
    if not objects then
        return 0
    end
    local watered = 0
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj then
            if obj.setWater and obj.getWaterMax then
                local max = obj:getWaterMax()
                if max and max > 0 then
                    obj:setWater(max)
                    watered = watered + 1
                end
            elseif obj.getModData then
                local md = obj:getModData()
                if md and md.waterLvl ~= nil and md.waterNeeded ~= nil then
                    md.waterLvl = md.waterNeeded
                    watered = watered + 1
                end
            end
        end
    end
    return watered
end

function IKST_AutomationOps.unloadContainersOnSquare(square, player)
    if not square or IKST_AutomationOps.skipProtected(square, player) then
        return 0
    end
    local objects = square:getObjects()
    if not objects then
        return 0
    end
    local dropped = 0
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj and obj.getContainer then
            local container = obj:getContainer()
            if container and container.getItems then
                local items = container:getItems()
                if items and items.size then
                    for j = items:size() - 1, 0, -1 do
                        local item = items:get(j)
                        if item and square.AddWorldInventoryItem then
                            square:AddWorldInventoryItem(item, 0.5, 0.5, 0)
                            if container.Remove then
                                container:Remove(item)
                            end
                            dropped = dropped + 1
                        elseif item and container.Remove then
                            container:Remove(item)
                            dropped = dropped + 1
                        end
                    end
                end
            end
        end
    end
    return dropped
end

function IKST_AutomationOps.runRadiusBatch(player, cx, cy, cz, radius, label, perSquareFn, onDone)
    local squares = IKST_Grid.squaresInRadius(cx, cy, cz, radius)
    local coords = {}
    for _, sq in ipairs(squares) do
        coords[#coords + 1] = { x = sq:getX(), y = sq:getY(), z = sq:getZ() }
    end
    IKST_TilesWorldOps.beginBatch()
    IKST_CommandQueue.enqueue(player, label, coords, function(c)
        local sq = IKST_WorldOps.getSquare(c.x, c.y, c.z)
        if not sq then
            return false, "missing"
        end
        return perSquareFn(player, sq)
    end, function(results)
        IKST_TilesWorldOps.endBatch()
        if onDone then
            onDone(results)
        end
    end)
end

function IKST_AutomationOps.gardener(player, args)
    local x, y, z = args.x, args.y, args.z
    local radius = IKST.clampRadius(args.radius)
    IKST_AutomationOps.runRadiusBatch(player, x, y, z, radius, "gardener", function(p, sq)
        if IKST_AutomationOps.skipProtected(sq, p) then
            return false, "skip"
        end
        local ok, msg = IKST_TilesWorldOps.removeVegetation(sq)
        return ok, msg
    end, function(results)
        local okCount = 0
        for _, r in ipairs(results) do
            if r.ok then okCount = okCount + 1 end
        end
        IKST_WorldOps.sendResult(player, true, "gardener " .. okCount .. "/" .. #results, x, y, z, IKST.CMD.autoGardener)
    end)
    return true, "gardener started"
end

function IKST_AutomationOps.lumberjack(player, args)
    local x, y, z = args.x, args.y, args.z
    local radius = IKST.clampRadius(args.radius)
    IKST_AutomationOps.runRadiusBatch(player, x, y, z, radius, "lumberjack", function(p, sq)
        local ok, msg = IKST_AutomationOps.removeTrees(sq, p)
        return ok, msg
    end, function(results)
        local okCount = 0
        for _, r in ipairs(results) do
            if r.ok then okCount = okCount + 1 end
        end
        IKST_WorldOps.sendResult(player, true, "lumberjack " .. okCount .. "/" .. #results, x, y, z, IKST.CMD.autoLumberjack)
    end)
    return true, "lumberjack started"
end

function IKST_AutomationOps.gravel(player, args)
    local x, y, z = args.x, args.y, args.z
    local radius = IKST.clampRadius(args.radius)
    IKST_AutomationOps.runRadiusBatch(player, x, y, z, radius, "gravel", function(p, sq)
        local ok, msg = IKST_AutomationOps.gravelSquare(p, sq)
        return ok, msg
    end, function(results)
        local okCount = 0
        for _, r in ipairs(results) do
            if r.ok then okCount = okCount + 1 end
        end
        IKST_WorldOps.sendResult(player, true, "gravel bags " .. okCount, x, y, z, IKST.CMD.autoGravel)
    end)
    return true, "gravel started"
end

function IKST_AutomationOps.corpseStack(player, args)
    local x, y, z = args.x, args.y, args.z
    local radius = IKST.clampRadius(args.radius)
    local target = IKST_WorldOps.getSquare(x, y, z)
    if not target then
        return false, "invalid square"
    end
    IKST_AutomationOps.runRadiusBatch(player, x, y, z, radius, "corpseStack", function(p, sq)
        if sq:getX() == x and sq:getY() == y and sq:getZ() == z then
            return false, "target"
        end
        local moved = IKST_AutomationOps.moveCorpsesToSquare(sq, target, p)
        if moved > 0 then
            return true, tostring(moved)
        end
        return false, "none"
    end, function(results)
        local moved = 0
        for _, r in ipairs(results) do
            if r.ok then
                moved = moved + (tonumber(r.msg) or 0)
            end
        end
        IKST_WorldOps.sendResult(player, true, "stacked " .. moved .. " corpse(s)", x, y, z, IKST.CMD.autoCorpseStack)
    end)
    return true, "corpse stack started"
end

function IKST_AutomationOps.homeWreck(player, args)
    local x, y, z = args.x, args.y, args.z
    local radius = IKST.clampRadius(args.radius)
    IKST_AutomationOps.runRadiusBatch(player, x, y, z, radius, "homeWreck", function(p, sq)
        if IKST_AutomationOps.skipProtected(sq, p) then
            return false, "protected"
        end
        local ok, msg = IKST_TilesWorldOps.clearSquare(sq)
        return ok, msg
    end, function(results)
        local okCount = 0
        for _, r in ipairs(results) do
            if r.ok then okCount = okCount + 1 end
        end
        IKST_WorldOps.sendResult(player, true, "home wreck " .. okCount .. "/" .. #results, x, y, z, IKST.CMD.autoHomeWreck)
    end)
    return true, "home wreck started"
end

function IKST_AutomationOps.farmer(player, args)
    local x, y, z = args.x, args.y, args.z
    local radius = IKST.clampRadius(args.radius)
    IKST_AutomationOps.runRadiusBatch(player, x, y, z, radius, "farmer", function(p, sq)
        local watered = IKST_AutomationOps.waterPlantsOnSquare(sq, p)
        if watered > 0 then
            return true, tostring(watered)
        end
        return false, "none"
    end, function(results)
        local watered = 0
        for _, r in ipairs(results) do
            if r.ok then
                watered = watered + (tonumber(r.msg) or 0)
            end
        end
        IKST_WorldOps.sendResult(player, true, "watered " .. watered .. " plant(s)", x, y, z, IKST.CMD.autoFarmer)
    end)
    return true, "farmer started"
end

function IKST_AutomationOps.unloadContainers(player, args)
    local x, y, z = args.x, args.y, args.z
    local radius = IKST.clampRadius(args.radius)
    IKST_AutomationOps.runRadiusBatch(player, x, y, z, radius, "unloadContainers", function(p, sq)
        local dropped = IKST_AutomationOps.unloadContainersOnSquare(sq, p)
        if dropped > 0 then
            return true, tostring(dropped)
        end
        return false, "none"
    end, function(results)
        local dropped = 0
        for _, r in ipairs(results) do
            if r.ok then
                dropped = dropped + (tonumber(r.msg) or 0)
            end
        end
        IKST_WorldOps.sendResult(player, true, "dropped " .. dropped .. " item(s)", x, y, z, IKST.CMD.autoUnloadContainers)
    end)
    return true, "unload containers started"
end

function IKST_AutomationOps.handle(command, player, args)
    args = args or {}
    args.x = math.floor(tonumber(args.x) or (player and player:getX()) or 0)
    args.y = math.floor(tonumber(args.y) or (player and player:getY()) or 0)
    args.z = tonumber(args.z) or (player and player:getZ()) or 0

    if command == IKST.CMD.autoGardener then
        return IKST_AutomationOps.gardener(player, args)
    end
    if command == IKST.CMD.autoLumberjack then
        return IKST_AutomationOps.lumberjack(player, args)
    end
    if command == IKST.CMD.autoGravel then
        return IKST_AutomationOps.gravel(player, args)
    end
    if command == IKST.CMD.autoCorpseStack then
        return IKST_AutomationOps.corpseStack(player, args)
    end
    if command == IKST.CMD.autoHomeWreck then
        return IKST_AutomationOps.homeWreck(player, args)
    end
    if command == IKST.CMD.autoFarmer then
        return IKST_AutomationOps.farmer(player, args)
    end
    if command == IKST.CMD.autoUnloadContainers then
        return IKST_AutomationOps.unloadContainers(player, args)
    end
    return false, "unknown automation"
end
