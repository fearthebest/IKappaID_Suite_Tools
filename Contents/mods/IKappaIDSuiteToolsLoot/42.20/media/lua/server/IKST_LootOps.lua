-- Server loot command handlers. Shared engine: media/lua/shared/IKST_LootOps.lua (same table).
if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end

require "IKST_Shared"
require "IKST_Grid"
require "IKST_Loot"
require "IKST_LootOps"
require "IKST_CommandQueue"
require "IKST_Args"

IKST_LootOps = IKST_LootOps or {}

if not ItemPicker and ItemPickerJava then
    ItemPicker = ItemPickerJava
end

if IKST.runsOnServerJvm and IKST.runsOnServerJvm() and IKST_LootOps.ensureLootPickerReady then
    IKST_LootOps.ensureLootPickerReady()
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
    if not player then
        return nil
    end
    if type(instanceof) == "function" and not instanceof(player, "IsoPlayer") then
        return nil
    end
    return player
end

-- MP: after clear, rollItem adds items server-side only. Network each new item once (no fillContainer).
function IKST_LootOps.networkNewContainerItems(container, startIndex)
    if not container then
        return
    end
    if not IKST.isMultiplayerSession or not IKST.isMultiplayerSession() then
        return
    end
    if type(isServer) ~= "function" or not isServer() then
        return
    end
    if type(container.getItems) ~= "function" or type(sendAddItemToContainer) ~= "function" then
        return
    end
    local items = container:getItems()
    if not items or type(items.size) ~= "function" then
        return
    end
    startIndex = math.floor(tonumber(startIndex) or 0)
    if startIndex < 0 then
        startIndex = 0
    end
    for i = startIndex, items:size() - 1 do
        local item = items:get(i)
        if item then
            if type(item.syncItemFields) == "function" then
                item:syncItemFields()
            end
            sendAddItemToContainer(container, item)
        end
    end
end

function IKST_LootOps.syncContainerItemsToClients(container, newItemsStartIndex)
    if not container then
        return
    end
    if IKST.isMultiplayerSession and IKST.isMultiplayerSession()
        and type(isServer) == "function" and isServer() then
        IKST_LootOps.networkNewContainerItems(container, newItemsStartIndex or 0)
        return
    end
    if container.getItems then
        local items = container:getItems()
        if items then
            for i = 0, items:size() - 1 do
                local item = items:get(i)
                if item and type(item.syncItemFields) == "function" then
                    item:syncItemFields()
                end
            end
        end
    end
    -- SP: local JVM only — do not call sendContentsToClients (MP uses sendAddItemToContainer above).
end

function IKST_LootOps.syncContainerAfterFill(container, parent, newItemsStartIndex)
    if parent and parent.setDrawDirty then
        parent:setDrawDirty(true)
    end
    if IKST.isMultiplayerSession and IKST.isMultiplayerSession() then
        IKST_LootOps.syncContainerItemsToClients(container, newItemsStartIndex)
        -- Do not transmitCompleteItemToClients / sendContentsTo* after per-item adds (duplicate IsoObject risk).
        IKST_LootOps.markContainerFilled(container)
        return
    end
    if parent and ItemPicker and ItemPicker.updateOverlaySprite then
        ItemPicker.updateOverlaySprite(parent)
    end
    if parent and parent.transmitCompleteItemToClients then
        parent:transmitCompleteItemToClients()
    end
    IKST_LootOps.markContainerFilled(container)
end

function IKST_LootOps.squareLootBlocked(x, y, z, player)
    if not IKST_Policy then
        require "IKST_Policy"
    end
    local allowed, reason = IKST_Policy.locationAllowedAtCoord(player, x, y, z, "loot")
    if allowed == true then
        return false, nil
    end
    return true, reason or "blocked"
end

function IKST_LootOps.containerLocationBlocked(container, player)
    if not container or type(container.getSourceGrid) ~= "function" then
        return false, nil
    end
    local square = container:getSourceGrid()
    if not square then
        return false, nil
    end
    if not IKST_Policy then
        require "IKST_Policy"
    end
    local allowed, reason = IKST_Policy.locationAllowed(player, square, "loot")
    if allowed == true then
        return false, nil
    end
    return true, reason or "blocked"
end

function IKST_LootOps.containerSquareBlocked(container, player)
    local blocked = select(1, IKST_LootOps.containerLocationBlocked(container, player))
    return blocked == true
end

-- Snapshot live item refs before clear (for restore if roll fails).
function IKST_LootOps.snapshotContainerItems(container)
    local saved = {}
    if not container or type(container.getItems) ~= "function" then
        return saved
    end
    local items = container:getItems()
    if not items or type(items.size) ~= "function" then
        return saved
    end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            saved[#saved + 1] = item
        end
    end
    return saved
end

function IKST_LootOps.restoreContainerItems(container, saved)
    if not container or type(saved) ~= "table" or #saved < 1 then
        return
    end
    local mpServer = IKST.isMultiplayerSession and IKST.isMultiplayerSession()
        and type(isServer) == "function" and isServer()
        and type(sendAddItemToContainer) == "function"
    for i = 1, #saved do
        local item = saved[i]
        if item and type(container.AddItem) == "function" then
            container:AddItem(item)
            if mpServer then
                if type(item.syncItemFields) == "function" then
                    item:syncItemFields()
                end
                sendAddItemToContainer(container, item)
            end
        end
    end
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

-- RollItem loot can return 0 items; retry so clear-before-fill does not permanently strip rooms.
IKST_LootOps.ROLL_ATTEMPTS = 8

function IKST_LootOps.repopulateContainer(container, player, squareKeep, refreshList, roomName)
    if not IKST_LootOps.mayMutateWorldLoot() then
        return false, "server only"
    end
    if not player then
        return false, "no player"
    end
    if not IKST_LootOps.containerReady(container) then
        return false, "not ready"
    end
    local locBlocked, locReason = IKST_LootOps.containerLocationBlocked(container, player)
    if locBlocked then
        return false, locReason or "blocked"
    end
    if IKST_LootOps.isPlayerPlacedLootContainer(container) then
        return false, "player_placed"
    end
    local mainDist, junkDist, hadDist = IKST_LootOps.resolveContainerDistributions(container, roomName)
    if not hadDist then
        return false, "no distribution"
    end
    if not ItemPicker then
        return false, "no picker"
    end

    IKST_LootOps.ensureLootPickerReady()

    IKST_LootOps.prepareContainerForLootFill(container)

    local fillCharacter = IKST_LootOps.fillCharacter(player)
    if not fillCharacter then
        return false, "no player"
    end

    local parent = type(container.getParent) == "function" and container:getParent()
    local didClear = false
    local savedItems = nil
    local itemCountAfterClear = IKST_LootOps.containerItemCount(container)
    if IKST_LootOps.clearBeforeFill() then
        savedItems = IKST_LootOps.snapshotContainerItems(container)
        IKST_LootOps.clearContainerContents(container)
        itemCountAfterClear = 0
        didClear = true
    end

    local rollOk = false
    local rollHadDist = hadDist
    local attempts = math.floor(tonumber(IKST_LootOps.ROLL_ATTEMPTS) or 8)
    if attempts < 1 then
        attempts = 1
    end
    if attempts > 20 then
        attempts = 20
    end
    for _ = 1, attempts do
        local ok, hd = IKST_LootOps.rollItemsIntoExistingContainer(
            container, fillCharacter, true, mainDist, junkDist)
        if hd == true then
            rollHadDist = true
        end
        if ok == true and IKST_LootOps.containerItemCount(container) >= 1 then
            rollOk = true
            break
        end
    end

    -- One staff force-fill after RNG retries (not inside each attempt).
    if not rollOk and (rollHadDist == true or hadDist == true) then
        if IKST_LootOps.forceStaffFill(container, fillCharacter, mainDist, junkDist, nil) then
            if IKST_LootOps.containerItemCount(container) >= 1 then
                rollOk = true
            end
        end
    end

    if not rollOk then
        if didClear and savedItems and #savedItems > 0 then
            IKST_LootOps.restoreContainerItems(container, savedItems)
        end
        if IKST_Debug and IKST_Debug.log then
            IKST_Debug.log("loot", "rollItemsIntoExistingContainer failed type=" .. tostring(type(container.getType) == "function" and container:getType())
                .. " hadDist=" .. tostring(rollHadDist == true or hadDist == true)
                .. " restored=" .. tostring(didClear and savedItems and #savedItems > 0))
        end
        if rollHadDist ~= true and hadDist ~= true then
            return false, "no distribution"
        end
        if didClear and savedItems and #savedItems > 0 then
            return false, "roll empty"
        end
        return false, "repopulate failed"
    end

    if IKST_LootOps.containerItemCount(container) < 1 then
        if didClear and savedItems and #savedItems > 0 then
            IKST_LootOps.restoreContainerItems(container, savedItems)
            return false, "roll empty"
        end
        return false, "repopulate failed"
    end

    -- Do not trimExcessLootObjectsOnSquare here: that deletes real furniture IsoObjects after
    -- repeated room repops (MP strip). fillContainer duplicate trim stays inside SP fallback only.

    IKST_LootOps.syncContainerAfterFill(container, parent, itemCountAfterClear)
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
    local roomName = nil
    if IKST.lootTableRoomName then
        roomName = IKST.lootTableRoomName(args and args.lootTable)
    end

    -- Small zones stay synchronous; large zones use server command budget.
    if #containers <= (IKST_CommandQueue and IKST_CommandQueue.OPS_PER_TICK or 8) then
        local squareKeep = {}
        local refreshList = {}
        local count = 0
        local skipped = 0
        local lastFailReason = "repopulate failed"
        local noDistCount = 0
        for i = 1, #containers do
            local container = containers[i]
            local locBlocked, locReason = IKST_LootOps.containerLocationBlocked(container, player)
            if locBlocked then
                skipped = skipped + 1
                lastFailReason = locReason or "blocked"
            else
                local passFilter = true
                if IKST_LootOps.passesLootFilters then
                    passFilter = select(1, IKST_LootOps.passesLootFilters(container, player, args))
                end
                if not passFilter then
                    skipped = skipped + 1
                    lastFailReason = "filtered"
                else
                local ok, reason = IKST_LootOps.repopulateContainer(container, player, squareKeep, refreshList, roomName)
                if ok then
                    count = count + 1
                else
                    skipped = skipped + 1
                    lastFailReason = reason or "repopulate failed"
                    if lastFailReason == "no distribution" then
                        noDistCount = noDistCount + 1
                    end
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
            suffix = suffix .. " (cap " .. tostring(IKST_LootOps.maxContainers()) .. ")"
        end
        if args then
            args.resultCount = count
            args.resultSuffix = suffix
        end
        return true, "repopulate_ok"
    end

    if not IKST.enqueueWorldOp then
        require "IKST_CommandQueue"
    end
    if type(IKST.enqueueWorldOp) ~= "function" then
        return false, "queue unavailable"
    end

    local squareKeep = {}
    local refreshList = {}
    local stats = { count = 0, skipped = 0, noDistCount = 0, lastFailReason = "repopulate failed", total = #containers }
    if args then
        args._deferResult = true
    end
    IKST.enqueueWorldOp(player, "loot zone", containers, function(container)
        local locBlocked, locReason = IKST_LootOps.containerLocationBlocked(container, player)
        if locBlocked then
            stats.skipped = stats.skipped + 1
            stats.lastFailReason = locReason or "blocked"
            return false, stats.lastFailReason
        end
        if IKST_LootOps.passesLootFilters then
            local passFilter = select(1, IKST_LootOps.passesLootFilters(container, player, args))
            if not passFilter then
                stats.skipped = stats.skipped + 1
                stats.lastFailReason = "filtered"
                return false, stats.lastFailReason
            end
        end
        local ok, reason = IKST_LootOps.repopulateContainer(container, player, squareKeep, refreshList, roomName)
        if ok then
            stats.count = stats.count + 1
            return true, "ok"
        end
        stats.skipped = stats.skipped + 1
        stats.lastFailReason = reason or "repopulate failed"
        if stats.lastFailReason == "no distribution" then
            stats.noDistCount = stats.noDistCount + 1
        end
        return false, stats.lastFailReason
    end, function()
        IKST_LootOps.pushContainerRefresh(player, refreshList)
        local ok = stats.count > 0
        local msg = "repopulate_ok"
        if not ok then
            if stats.noDistCount == stats.total then
                msg = "no distribution"
            else
                msg = stats.lastFailReason
            end
        end
        local suffix = ""
        if stats.skipped > 0 then
            suffix = suffix .. " (" .. stats.skipped .. " skipped)"
        end
        if stats.total >= IKST_LootOps.maxContainers() then
            suffix = suffix .. " (cap " .. tostring(IKST_LootOps.maxContainers()) .. ")"
        end
        if IKST_WorldOps and IKST_WorldOps.sendResult then
            IKST_WorldOps.sendResult(player, ok, msg, x, y, z, IKST.CMD.lootRepopulateZone, {
                resultCount = stats.count,
                resultSuffix = suffix,
            })
        end
    end)
    return true, "queued"
end

function IKST_LootOps.handle(command, player, args)
    if not IKST_LootOps.mayMutateWorldLoot() then
        return false, "server only"
    end
    args = args or {}
    local x = IKST_Args.readCoord(args, "x")
    local y = IKST_Args.readCoord(args, "y")
    local z = IKST_Args.readCoord(args, "z")
    if x == nil or y == nil or z == nil then
        return false, "bad coords"
    end

    if command == IKST.CMD.lootRepopulateContainer then
        local blocked, blockReason = IKST_LootOps.squareLootBlocked(x, y, z, player)
        if blocked then
            return false, blockReason or "square protected"
        end
        local container = IKST_LootOps.containerAt(x, y, z, args.objectIndex, args.containerIndex)
        if not container then
            return false, "no container"
        end
        local roomName = nil
        if IKST.lootTableRoomName then
            roomName = IKST.lootTableRoomName(args.lootTable)
        end
        local refreshList = {}
        local ok, reason = IKST_LootOps.repopulateContainer(container, player, nil, refreshList, roomName)
        if not ok then
            return false, reason or "repopulate failed"
        end
        IKST_LootOps.pushContainerRefresh(player, refreshList)
        if args then
            args.resultLabel = IKST_LootOps.containerLabel(container)
        end
        return true, "container_repopulate_ok"
    end

    if command == IKST.CMD.lootRepopulateZone then
        local scope = args.scope or IKST.CLEANUP_SCOPES.single
        if scope == IKST.CLEANUP_SCOPES.cell then
            x = math.floor(player:getX())
            y = math.floor(player:getY())
            z = math.floor(player:getZ() or 0)
        end
        local blocked, blockReason = IKST_LootOps.squareLootBlocked(x, y, z, player)
        if blocked then
            return false, blockReason or "square protected"
        end
        return IKST_LootOps.repopulateZone(player, x, y, z, scope, args)
    end

    return false, "unknown loot command"
end
