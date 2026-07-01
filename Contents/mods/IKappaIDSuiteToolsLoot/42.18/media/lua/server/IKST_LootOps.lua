if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end

require "IKST_Shared"
require "IKST_Grid"
require "IKST_LootOps"
require "IKST_TileProtect"

IKST_LootOps = IKST_LootOps or {}

if not ItemPicker and ItemPickerJava then
    ItemPicker = ItemPickerJava
end

local function readCoord(args, key)
    if not args then
        return nil
    end
    local value = tonumber(args[key])
    if value == nil then
        return nil
    end
    return math.floor(value)
end

local function containerByIndexOnObject(obj, containerIndex)
    if not obj or not obj.getContainerByIndex then
        return nil
    end
    containerIndex = math.floor(tonumber(containerIndex) or -1)
    if containerIndex < 0 then
        return nil
    end
    if obj.getContainerCount then
        local count = obj:getContainerCount()
        if containerIndex >= count then
            return nil
        end
    end
    return obj:getContainerByIndex(containerIndex)
end

function IKST_LootOps.containerAt(x, y, z, objectIndex, containerIndex)
    local square = IKST_Grid.getSquare(x, y, z)
    if not square then
        return nil
    end
    local objects = square.getObjects and square:getObjects()
    if not objects then
        return nil
    end
    if objectIndex ~= nil then
        objectIndex = math.floor(tonumber(objectIndex) or -1)
        if objectIndex >= 0 and objectIndex < objects:size() then
            local obj = objects:get(objectIndex)
            if obj then
                if containerIndex ~= nil then
                    local container = containerByIndexOnObject(obj, containerIndex)
                    if container then
                        return container
                    end
                end
                if obj.getContainer then
                    return obj:getContainer()
                end
            end
        end
    end
    if containerIndex ~= nil then
        containerIndex = math.floor(tonumber(containerIndex) or -1)
        if containerIndex >= 0 then
            for i = 0, objects:size() - 1 do
                local obj = objects:get(i)
                if obj then
                    local container = containerByIndexOnObject(obj, containerIndex)
                    if IKST_LootOps.isWorldLootContainer(container) then
                        return container
                    end
                end
            end
        end
    end
    local list = {}
    IKST_LootOps.collectContainersOnSquare(square, list, {})
    return list[1]
end

function IKST_LootOps.trimDuplicateContainers(parent, beforeCount)
    if not parent or not parent.getContainerCount then
        return
    end
    beforeCount = math.floor(tonumber(beforeCount) or 0)
    if beforeCount < 1 then
        beforeCount = 1
    end
    local afterCount = parent:getContainerCount()
    while afterCount > beforeCount and afterCount > 1 do
        local extra = parent:getContainerByIndex(afterCount - 1)
        if extra and extra.clear then
            extra:clear()
        end
        if parent.RemoveContainer and extra then
            parent:RemoveContainer(extra)
        elseif parent.removeContainerFromIndex then
            parent:removeContainerFromIndex(afterCount - 1)
        else
            break
        end
        afterCount = parent:getContainerCount()
    end
end

function IKST_LootOps.containerReady(container)
    if not IKST_LootOps.isWorldLootContainer(container) then
        return false
    end
    if not container.getSourceGrid then
        return false
    end
    local square = container:getSourceGrid()
    if not square then
        return false
    end
    return true
end

-- ItemPickerJava on dedicated server: use nil (admin player object can NPE inside fillContainer).
function IKST_LootOps.fillCharacter(player)
    if IKST.runsOnServerJvm and IKST.runsOnServerJvm() then
        return nil
    end
    return player
end

function IKST_LootOps.syncContainerAfterFill(container, parent)
    if container and container.setDrawDirty then
        container:setDrawDirty(true)
    end
    if IKST.isMultiplayerSession and IKST.isMultiplayerSession() then
        -- MP: server owns loot; push contents only (no transmitAddObjectToSquare — avoids double crate on relog).
        if container and container.sendContentsToClients then
            container:sendContentsToClients()
        end
        if parent and parent.transmitCompleteItemToClients then
            parent:transmitCompleteItemToClients()
        end
        return
    end
    if parent and ItemPicker and ItemPicker.updateOverlaySprite then
        ItemPicker.updateOverlaySprite(parent)
    end
    if container and container.sendContentsToClients then
        container:sendContentsToClients()
    end
    if parent and parent.transmitCompleteItemToClients then
        parent:transmitCompleteItemToClients()
    end
end

function IKST_LootOps.squareLootBlocked(x, y, z)
    if not IKST_TileProtect then
        return false
    end
    if IKST_TileProtect.isTileProtected(x, y, z) then
        return true
    end
    if IKST_TileProtect.isReadonly(x, y, z) then
        return true
    end
    return false
end

function IKST_LootOps.containerSquareBlocked(container)
    if not container or not container.getSourceGrid then
        return false
    end
    local square = container:getSourceGrid()
    if not square then
        return false
    end
    return IKST_LootOps.squareLootBlocked(square:getX(), square:getY(), square:getZ())
end

function IKST_LootOps.repopulateContainer(container, player, squareKeep)
    if not IKST_LootOps.mayMutateWorldLoot() then
        return false
    end
    if not IKST_LootOps.containerReady(container) then
        return false
    end
    if IKST_LootOps.containerSquareBlocked(container) then
        return false
    end
    if not ItemPicker then
        return false
    end

    if IKST_LootOps.clearBeforeFill() then
        if container.removeItemsFromProcessItems then
            container:removeItemsFromProcessItems()
        end
        if container.clear then
            container:clear()
        end
    end
    if container.setExplored then
        container:setExplored(true)
    end

    local parent = container.getParent and container:getParent()
    local square = container.getSourceGrid and container:getSourceGrid()
    local sqKey = IKST_LootOps.squareKey(square)
    local lootObjCountBefore = 0
    if square then
        if squareKeep and sqKey and squareKeep[sqKey] ~= nil then
            lootObjCountBefore = squareKeep[sqKey]
        else
            lootObjCountBefore = IKST_LootOps.countLootObjectsOnSquare(square)
            if squareKeep and sqKey then
                squareKeep[sqKey] = lootObjCountBefore
            end
        end
    end
    local beforeCount = 0
    if parent and parent.getContainerCount then
        beforeCount = parent:getContainerCount()
        if beforeCount < 1 and parent.getContainer and parent:getContainer() then
            beforeCount = 1
        end
    end

    if not IKST_LootOps.rollItemsIntoExistingContainer(container, IKST_LootOps.fillCharacter(player)) then
        if IKST_Debug and IKST_Debug.log then
            IKST_Debug.log("loot", "rollItemsIntoExistingContainer failed type=" .. tostring(container.getType and container:getType()))
        end
        return false
    end

    if parent then
        IKST_LootOps.trimDuplicateContainers(parent, beforeCount)
    end
    if square then
        local maxKeep = lootObjCountBefore
        if maxKeep < 1 then
            maxKeep = 1
        end
        IKST_LootOps.trimExcessLootObjectsOnSquare(square, parent, maxKeep)
    end

    IKST_LootOps.syncContainerAfterFill(container, parent)
    return true
end

function IKST_LootOps.repopulateZone(player, x, y, z, scope, args)
    local squares = IKST_LootOps.squaresForScope(x, y, z, scope, args)
    if #squares == 0 then
        return false, "no area"
    end
    local containers = IKST_LootOps.collectContainersFromSquares(squares, {}, {})
    if #containers == 0 then
        return false, "no containers"
    end
    local squareKeep = {}
    local count = 0
    local skipped = 0
    for i = 1, #containers do
        local container = containers[i]
        if IKST_LootOps.containerSquareBlocked(container) then
            skipped = skipped + 1
        elseif IKST_LootOps.repopulateContainer(container, player, squareKeep) then
            count = count + 1
        else
            skipped = skipped + 1
            if IKST_Debug and IKST_Debug.enabled and IKST_Debug.enabled() then
                IKST_Debug.log("loot", "skip container index " .. tostring(i) .. " not ready for fill")
            end
        end
    end
    if count == 0 then
        return false, "repopulate failed"
    end
    local suffix = ""
    if skipped > 0 then
        suffix = suffix .. " (" .. skipped .. " skipped)"
    end
    if #containers >= IKST_LootOps.maxContainers() then
        suffix = " (cap " .. tostring(IKST_LootOps.maxContainers()) .. ")"
    end
    return true, count .. " containers repopulated" .. suffix
end

function IKST_LootOps.handle(command, player, args)
    if not IKST_LootOps.mayMutateWorldLoot() then
        return false, "server only"
    end
    args = args or {}
    local x = readCoord(args, "x")
    local y = readCoord(args, "y")
    local z = readCoord(args, "z")
    if x == nil or y == nil or z == nil then
        return false, "bad coords"
    end

    if command == IKST.CMD.lootRepopulateContainer then
        if IKST_LootOps.squareLootBlocked(x, y, z) then
            return false, "square protected"
        end
        local container = IKST_LootOps.containerAt(x, y, z, args.objectIndex, args.containerIndex)
        if not container then
            return false, "no container"
        end
        if not IKST_LootOps.repopulateContainer(container, player, nil) then
            return false, "repopulate failed"
        end
        return true, IKST_LootOps.containerLabel(container) .. " repopulated"
    end

    if command == IKST.CMD.lootRepopulateZone then
        if IKST_LootOps.squareLootBlocked(x, y, z) then
            return false, "square protected"
        end
        local scope = args.scope or IKST.CLEANUP_SCOPES.single
        return IKST_LootOps.repopulateZone(player, x, y, z, scope, args)
    end

    return false, "unknown loot command"
end
