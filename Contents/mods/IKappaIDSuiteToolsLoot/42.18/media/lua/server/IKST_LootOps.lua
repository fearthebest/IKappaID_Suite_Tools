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

if IKST.runsOnServerJvm and IKST.runsOnServerJvm() and IKST_LootOps.ensureLootPickerReady then
    IKST_LootOps.ensureLootPickerReady()
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
    local _, container = IKST_LootOps.resolveLootTarget(x, y, z, objectIndex, containerIndex)
    return container
end

function IKST_LootOps.shouldPushClientRefresh()
    if not IKST.isMultiplayerSession or not IKST.isMultiplayerSession() then
        return false
    end
    if not IKST.deliverClientCommand then
        return false
    end
    return true
end

function IKST_LootOps.pushContainerRefresh(player, payloads)
    if not IKST_LootOps.shouldPushClientRefresh() or not player then
        return
    end
    if type(payloads) ~= "table" or #payloads < 1 then
        return
    end
    if #payloads == 1 then
        IKST.deliverClientCommand(player, IKST.CMD.lootContainerRefresh, payloads[1])
        return
    end
    IKST.deliverClientCommand(player, IKST.CMD.lootContainerRefresh, { entries = payloads })
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

-- rollItem on dedicated uses the admin player; never fillContainer on MP (duplicate crates).
function IKST_LootOps.fillCharacter(player)
    return player
end

function IKST_LootOps.syncContainerItemsToClients(container)
    if not container then
        return
    end
    if container.getItems then
        local items = container:getItems()
        if items then
            for i = 0, items:size() - 1 do
                local item = items:get(i)
                if item and item.syncItemFields and type(item.syncItemFields) == "function" then
                    item:syncItemFields()
                end
            end
        end
    end
    if container.sendContentsToRemoteContainer and type(container.sendContentsToRemoteContainer) == "function" then
        container:sendContentsToRemoteContainer()
        return
    end
    if container.sendContentsToClients and type(container.sendContentsToClients) == "function" then
        container:sendContentsToClients()
    end
end

function IKST_LootOps.syncContainerAfterFill(container, parent)
    if container and container.setDrawDirty then
        container:setDrawDirty(true)
    end
    if parent and parent.setDrawDirty then
        parent:setDrawDirty(true)
    end
    if IKST.isMultiplayerSession and IKST.isMultiplayerSession() then
        IKST_LootOps.syncContainerItemsToClients(container)
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

function IKST_LootOps.squareLootBlocked(x, y, z, player)
    -- Staff loot tool is already gated by canUseLoot; do not refuse protected/readonly tiles for admins.
    if player then
        if not IKST_Access then
            require "IKST_Access"
        end
        if IKST_Access and type(IKST_Access.canUseLoot) == "function" and IKST_Access.canUseLoot(player) then
            return false
        end
    end
    if IKST.Plugins and IKST.Plugins.isActive("tiles") and not IKST_TileProtect then
        require "IKST_TileProtect"
    end
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

function IKST_LootOps.containerSquareBlocked(container, player)
    if not container or not container.getSourceGrid then
        return false
    end
    local square = container:getSourceGrid()
    if not square then
        return false
    end
    return IKST_LootOps.squareLootBlocked(square:getX(), square:getY(), square:getZ(), player)
end

-- Match vanilla emptyTrash / admin refill: network-remove then local wipe (clear alone does not sync MP).
function IKST_LootOps.clearContainerContents(container)
    if not IKST_LootOps.mayMutateWorldLoot() then
        return false
    end
    if not container then
        return false
    end
    if type(container.removeItemsFromProcessItems) == "function" then
        container:removeItemsFromProcessItems()
    end
    local items = type(container.getItems) == "function" and container:getItems() or nil
    if items and type(isServer) == "function" and isServer()
        and type(sendRemoveItemsFromContainer) == "function" then
        sendRemoveItemsFromContainer(container, items)
    end
    local guard = 0
    while items and type(items.size) == "function" and items:size() > 0 and guard < 5000 do
        guard = guard + 1
        local item = items:get(0)
        if not item then
            break
        end
        if type(container.DoRemoveItem) == "function" then
            container:DoRemoveItem(item)
        elseif type(container.Remove) == "function" then
            container:Remove(item)
        else
            break
        end
    end
    if type(container.clear) == "function" then
        container:clear()
    elseif type(container.emptyIt) == "function" then
        container:emptyIt()
    end
    return IKST_LootOps.containerItemCount(container) == 0
end

function IKST_LootOps.repopulateContainer(container, player, squareKeep, refreshList)
    if not IKST_LootOps.mayMutateWorldLoot() then
        return false, "server only"
    end
    if not IKST_LootOps.containerReady(container) then
        return false, "not ready"
    end
    if IKST_LootOps.containerSquareBlocked(container, player) then
        return false, "blocked"
    end
    if not ItemPicker then
        return false, "no picker"
    end

    -- Never wipe player storage / unknown furniture before confirming a loot table exists.
    IKST_LootOps.prepareContainerForLootFill(container)
    local roomName = IKST_LootOps.roomNameFromContainer(container)
    local mainDist = IKST_LootOps.resolveContainerDistribution(container, roomName, false)
    local junkDist = IKST_LootOps.resolveContainerDistribution(container, roomName, true)
    local hadDist = mainDist ~= nil or junkDist ~= nil
    if not hadDist then
        return false, "no distribution"
    end

    if IKST_LootOps.clearBeforeFill() then
        IKST_LootOps.clearContainerContents(container)
    end

    local parent = type(container.getParent) == "function" and container:getParent()
    local square = type(container.getSourceGrid) == "function" and container:getSourceGrid()
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
        if beforeCount < 1 and type(parent.getContainer) == "function" and parent:getContainer() then
            beforeCount = 1
        end
    end

    local rollOk, rollHadDist = IKST_LootOps.rollItemsIntoExistingContainer(container, IKST_LootOps.fillCharacter(player))
    if not rollOk then
        if IKST_Debug and IKST_Debug.log then
            IKST_Debug.log("loot", "rollItemsIntoExistingContainer failed type=" .. tostring(type(container.getType) == "function" and container:getType())
                .. " hadDist=" .. tostring(rollHadDist == true or hadDist == true))
        end
        -- Cleared + valid table but rolled zero items still counts as a successful admin refill attempt.
        if hadDist and IKST_LootOps.clearBeforeFill() and IKST_LootOps.containerItemCount(container) == 0 then
            IKST_LootOps.syncContainerAfterFill(container, parent)
            if refreshList and IKST_LootOps.buildRefreshPayload then
                local payload = IKST_LootOps.buildRefreshPayload(container)
                if payload then
                    refreshList[#refreshList + 1] = payload
                end
            end
            return true
        end
        if rollHadDist ~= true and hadDist ~= true then
            return false, "no distribution"
        end
        return false, "repopulate failed"
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
        if IKST_LootOps.countLootObjectsOnSquare(square) > maxKeep then
            IKST_LootOps.trimExcessLootObjectsOnSquare(square, parent, maxKeep)
        end
    end

    IKST_LootOps.syncContainerAfterFill(container, parent)
    if refreshList and IKST_LootOps.buildRefreshPayload then
        local payload = IKST_LootOps.buildRefreshPayload(container)
        if payload then
            refreshList[#refreshList + 1] = payload
        end
    end
    return true
end

function IKST_LootOps.repopulateZone(player, x, y, z, scope, args)
    local squares = IKST_LootOps.squaresForScope(x, y, z, scope, args)
    if #squares == 0 then
        return false, "no area"
    end
    local containers = IKST_LootOps.collectContainersFromSquares(squares, {}, {}, true)
    if #containers == 0 then
        return false, "no containers"
    end
    local squareKeep = {}
    local refreshList = {}
    local count = 0
    local skipped = 0
    local lastFailReason = "repopulate failed"
    local noDistCount = 0
    for i = 1, #containers do
        local container = containers[i]
        if IKST_LootOps.containerSquareBlocked(container, player) then
            skipped = skipped + 1
            lastFailReason = "blocked"
            if IKST_Debug and type(IKST_Debug.enabled) == "function" and IKST_Debug.enabled() then
                IKST_Debug.log("loot", "skip container index " .. tostring(i) .. " reason=blocked")
            end
        else
            local ok, reason = IKST_LootOps.repopulateContainer(container, player, squareKeep, refreshList)
            if ok then
                count = count + 1
            else
                skipped = skipped + 1
                lastFailReason = reason or "repopulate failed"
                if lastFailReason == "no distribution" then
                    noDistCount = noDistCount + 1
                end
                if IKST_Debug and type(IKST_Debug.enabled) == "function" and IKST_Debug.enabled() then
                    IKST_Debug.log("loot", "skip container index " .. tostring(i) .. " reason=" .. tostring(lastFailReason))
                end
            end
        end
    end
    if count == 0 then
        if noDistCount == #containers then
            return false, "no distribution"
        end
        return false, lastFailReason
    end
    IKST_LootOps.pushContainerRefresh(player, refreshList)
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
        if IKST_LootOps.squareLootBlocked(x, y, z, player) then
            return false, "square protected"
        end
        local container = IKST_LootOps.containerAt(x, y, z, args.objectIndex, args.containerIndex)
        if not container then
            return false, "no container"
        end
        local refreshList = {}
        local ok, reason = IKST_LootOps.repopulateContainer(container, player, nil, refreshList)
        if not ok then
            return false, reason or "repopulate failed"
        end
        IKST_LootOps.pushContainerRefresh(player, refreshList)
        return true, IKST_LootOps.containerLabel(container) .. " repopulated"
    end

    if command == IKST.CMD.lootRepopulateZone then
        if IKST_LootOps.squareLootBlocked(x, y, z, player) then
            return false, "square protected"
        end
        local scope = args.scope or IKST.CLEANUP_SCOPES.single
        return IKST_LootOps.repopulateZone(player, x, y, z, scope, args)
    end

    return false, "unknown loot command"
end
