if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end

require "IKST_Shared"
require "IKST_Grid"
require "IKST_LootOps"

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
                if containerIndex ~= nil and obj.getContainerByIndex then
                    containerIndex = math.floor(tonumber(containerIndex) or 0)
                    local container = obj:getContainerByIndex(containerIndex)
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
        containerIndex = math.floor(tonumber(containerIndex) or 0)
        for i = 0, objects:size() - 1 do
            local obj = objects:get(i)
            if obj and obj.getContainerByIndex then
                local container = obj:getContainerByIndex(containerIndex)
                if IKST_LootOps.isWorldLootContainer(container) then
                    return container
                end
            end
        end
    end
    local list = {}
    IKST_LootOps.collectContainersOnSquare(square, list, {})
    return list[1]
end

function IKST_LootOps.roomKeyFromContainer(container)
    if not container or not container.getSourceGrid then
        return nil
    end
    local square = container:getSourceGrid()
    if not square or not square.getRoom then
        return nil
    end
    local room = square:getRoom()
    if not room or not room.getRoomDef then
        return nil
    end
    local roomDef = room:getRoomDef()
    if not roomDef then
        return nil
    end
    if roomDef.getID then
        return tostring(roomDef:getID())
    end
    return tostring(roomDef)
end

function IKST_LootOps.clearRoomProceduralSpawnOnce(container, roomCleared)
    if not container then
        return
    end
    local key = IKST_LootOps.roomKeyFromContainer(container)
    if not key then
        return
    end
    if roomCleared and roomCleared[key] then
        return
    end
    local square = container.getSourceGrid and container:getSourceGrid()
    if not square or not square.getRoom then
        return
    end
    local room = square:getRoom()
    if not room or not room.getRoomDef then
        return
    end
    local roomDef = room:getRoomDef()
    if not roomDef or not roomDef.getProceduralSpawnedContainer then
        return
    end
    local procedural = roomDef:getProceduralSpawnedContainer()
    if procedural and procedural.clear then
        procedural:clear()
    end
    if roomCleared then
        roomCleared[key] = true
    end
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
        -- Dedicated server: do not RemoveContainer — causes Java NPE on some furniture.
        if IKST.runsOnServerJvm and IKST.runsOnServerJvm() then
            break
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
    if parent and ItemPicker and ItemPicker.updateOverlaySprite then
        ItemPicker.updateOverlaySprite(parent)
    end
    if parent and parent.transmitCompleteItemToClients then
        parent:transmitCompleteItemToClients()
    end
    if container and container.setDrawDirty then
        container:setDrawDirty(true)
    end
end

function IKST_LootOps.repopulateContainer(container, player, roomCleared)
    if not IKST_LootOps.containerReady(container) then
        return false
    end
    if not ItemPicker or not ItemPicker.fillContainer then
        return false
    end

    if roomCleared then
        IKST_LootOps.clearRoomProceduralSpawnOnce(container, roomCleared)
    else
        IKST_LootOps.clearRoomProceduralSpawnOnce(container, nil)
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
    local beforeCount = 0
    if parent and parent.getContainerCount then
        beforeCount = parent:getContainerCount()
        if beforeCount < 1 and parent.getContainer and parent:getContainer() then
            beforeCount = 1
        end
    end

    ItemPicker.fillContainer(container, IKST_LootOps.fillCharacter(player))

    if parent and IKST.runsOnServerJvm and IKST.runsOnServerJvm() then
        local afterCount = parent:getContainerCount()
        if afterCount > beforeCount then
            if container.clear then
                container:clear()
            end
            if container.removeItemsFromProcessItems then
                container:removeItemsFromProcessItems()
            end
            IKST_LootOps.trimDuplicateContainers(parent, beforeCount)
            return false
        end
    end

    if parent then
        IKST_LootOps.trimDuplicateContainers(parent, beforeCount)
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
    local roomCleared = {}
    local count = 0
    local skipped = 0
    for i = 1, #containers do
        local container = containers[i]
        if IKST_LootOps.repopulateContainer(container, player, roomCleared) then
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
    args = args or {}
    local x = readCoord(args, "x")
    local y = readCoord(args, "y")
    local z = readCoord(args, "z")
    if x == nil or y == nil or z == nil then
        return false, "bad coords"
    end

    if command == IKST.CMD.lootRepopulateContainer then
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
        local scope = args.scope or IKST.CLEANUP_SCOPES.single
        return IKST_LootOps.repopulateZone(player, x, y, z, scope, args)
    end

    return false, "unknown loot command"
end
