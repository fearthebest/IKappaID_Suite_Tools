-- Shared loot engine (resolve, fill, world objects).
-- Server command handlers: media/lua/server/IKST_LootOps.lua (same IKST_LootOps table).
require "IKST_Shared"
require "IKST_Grid"
require "IKST_Args"

IKST_LootOps = IKST_LootOps or {}

IKST_LootOps.MAX_CONTAINERS = 80

function IKST_LootOps.maxContainers()
    local sv = SandboxVars and SandboxVars.IKappaIDSuiteToolsLoot
    if sv and sv.LootMaxContainers ~= nil then
        local n = math.floor(tonumber(sv.LootMaxContainers) or IKST_LootOps.MAX_CONTAINERS)
        if n < 1 then
            n = 1
        end
        if n > 500 then
            n = 500
        end
        return n
    end
    return IKST_LootOps.MAX_CONTAINERS
end

function IKST_LootOps.clearBeforeFill()
    local sv = SandboxVars and SandboxVars.IKappaIDSuiteToolsLoot
    if sv and sv.LootClearBeforeFill ~= nil then
        return sv.LootClearBeforeFill == true
    end
    return true
end

function IKST_LootOps.mayMutateWorldLoot()
    if not IKST.mayMutateWorldState then
        require "IKST_Authority"
    end
    return IKST.mayMutateWorldState and IKST.mayMutateWorldState()
end

function IKST_LootOps.isWorldLootContainer(container)
    if not container or not container.getType then
        return false
    end
    local containerType = container:getType()
    if not containerType or containerType == "" then
        return false
    end
    if containerType == "floor" then
        return false
    end
    local parent = type(container.getParent) == "function" and container:getParent()
    if parent and instanceof and instanceof(parent, "IsoPlayer") then
        return false
    end
    return true
end

function IKST_LootOps.containerParentObject(container)
    if container and type(container.getParent) == "function" then
        return container:getParent()
    end
    return nil
end

-- SP runs loot preview + mutations locally. MP: server JVM mutates; remote clients request only.
function IKST_LootOps.isSinglePlayerSession()
    if IKST.isMultiplayerSession then
        return not IKST.isMultiplayerSession()
    end
    if type(isMultiplayer) == "function" then
        return not isMultiplayer()
    end
    return true
end

function IKST_LootOps.runtimeKind()
    if not IKST_Policy then
        require "IKST_Policy"
    end
    local role = IKST_Policy.sessionRole()
    if role == IKST_Policy.SESSION.sp then
        return "sp"
    end
    if IKST.runsOnServerJvm and IKST.runsOnServerJvm() then
        return "mp_server"
    end
    return "mp_client"
end

function IKST_LootOps.mayResolveLootDistributions()
    if not ItemPicker then
        return false
    end
    if IKST_LootOps.isSinglePlayerSession() then
        return true
    end
    return IKST_LootOps.mayMutateWorldLoot()
end

function IKST_LootOps.parentModDataString(parent, key)
    if not parent or type(parent.getModData) ~= "function" or not key then
        return nil
    end
    local md = parent:getModData()
    if not md then
        return nil
    end
    local v = md[key]
    if v == nil or v == "" then
        return nil
    end
    return tostring(v)
end

function IKST_LootOps.resolveContainerDistributions(container, roomName)
    if not container or not ItemPicker then
        return nil, nil, false
    end
    IKST_LootOps.ensureLootPickerReady()
    roomName = roomName or IKST_LootOps.roomNameFromContainer(container)
    local mainDist = IKST_LootOps.resolveContainerDistribution(container, roomName, false, true)
    local junkDist = IKST_LootOps.resolveContainerDistribution(container, roomName, true, true)
    if mainDist or junkDist then
        return mainDist, junkDist, true
    end
    mainDist = IKST_LootOps.resolveContainerDistribution(container, roomName, false, false)
    junkDist = IKST_LootOps.resolveContainerDistribution(container, roomName, true, false)
    return mainDist, junkDist, (mainDist ~= nil or junkDist ~= nil)
end

function IKST_LootOps.containerHasMapLootDistribution(container)
    if not container or not ItemPicker then
        return false
    end
    local _, _, hadDist = IKST_LootOps.resolveContainerDistributions(container)
    return hadDist == true
end

-- Player-built / moved furniture is not map loot. Map military crates are often IsoThumpable.
function IKST_LootOps.isPlayerPlacedLootContainer(container)
    if not IKST_LootOps.isWorldLootContainer(container) then
        return false
    end
    local parent = IKST_LootOps.containerParentObject(container)
    if not parent then
        return false
    end
    if instanceof and instanceof(parent, "IsoWorldInventoryObject") then
        return true
    end
    if type(parent.isMovedThumpable) == "function" and parent:isMovedThumpable() then
        return true
    end
    if IKST_LootOps.parentModDataString(parent, "builtBy") then
        return true
    end
    if instanceof and instanceof(parent, "IsoThumpable") then
        if type(parent.isDismantable) == "function" and parent:isDismantable() then
            if not IKST_LootOps.containerHasMapLootDistribution(container) then
                return true
            end
        end
    end
    return false
end

function IKST_LootOps.isRepopulateCandidate(container)
    if not IKST_LootOps.isWorldLootContainer(container) then
        return false
    end
    if IKST_LootOps.isPlayerPlacedLootContainer(container) then
        return false
    end
    return true
end

function IKST_LootOps.containerSquareCoords(container)
    if not container or type(container.getSourceGrid) ~= "function" then
        return nil, nil, nil
    end
    local square = container:getSourceGrid()
    if not square or type(square.getX) ~= "function" then
        return nil, nil, nil
    end
    local z = 0
    if type(square.getZ) == "function" then
        z = square:getZ() or 0
    end
    return square:getX(), square:getY(), z
end

function IKST_LootOps.passesLootFilters(container, player, args)
    if not container then
        return false, "no container"
    end
    args = args or {}
    if args.onlyEmpty == true then
        if IKST_LootOps.containerItemCount(container) > 0 then
            return false, "not_empty"
        end
    end
    if args.preserveExisting == true and args.onlyEmpty ~= true then
        if IKST_LootOps.containerItemCount(container) > 0 then
            return false, "preserve"
        end
    end
    if args.skipLocked == true and IKST_Locks and type(IKST_Locks.isLocked) == "function" then
        local x, y, z = IKST_LootOps.containerSquareCoords(container)
        if x and IKST_Locks.isLocked(x, y, z) then
            return false, "locked"
        end
    end
    if args.skipClaimed == true and IKST_LootOps.containerLocationBlocked then
        local blocked = select(1, IKST_LootOps.containerLocationBlocked(container, player))
        if blocked then
            return false, "claimed"
        end
    end
    return true, nil
end

function IKST_LootOps.containersFromObject(obj)
    local out = {}
    if not obj then
        return out
    end
    if type(obj.getContainerCount) == "function" and obj:getContainerCount() > 0 then
        for j = 0, obj:getContainerCount() - 1 do
            local container = obj:getContainerByIndex(j)
            if IKST_LootOps.isWorldLootContainer(container) then
                out[#out + 1] = { container = container, containerIndex = j }
            end
        end
    elseif obj.getContainer then
        local container = obj:getContainer()
        if IKST_LootOps.isWorldLootContainer(container) then
            out[#out + 1] = { container = container, containerIndex = 0 }
        end
    end
    return out
end

function IKST_LootOps.resolveObjectIndex(square, obj)
    if not square or not obj then
        return nil
    end
    if obj.getObjectIndex then
        local index = obj:getObjectIndex()
        if index ~= nil then
            return index
        end
    end
    local objects = type(square.getObjects) == "function" and square:getObjects()
    if not objects then
        return nil
    end
    for i = 0, objects:size() - 1 do
        if objects:get(i) == obj then
            return i
        end
    end
    return nil
end

function IKST_LootOps.containerHasLootDistribution(container)
    if not IKST_LootOps.isRepopulateCandidate(container) then
        return false
    end
    local _, _, hadDist = IKST_LootOps.resolveContainerDistributions(container)
    return hadDist == true
end

function IKST_LootOps.invalidatePreviewCache()
    IKST_LootOps._previewCache = nil
end

function IKST_LootOps.shouldIncludeInLootPreview(container, refillableOnly)
    if not IKST_LootOps.isRepopulateCandidate(container) then
        return false
    end
    if refillableOnly ~= true then
        return true
    end
    if not IKST_LootOps.mayResolveLootDistributions() then
        return true
    end
    return IKST_LootOps.containerHasLootDistribution(container)
end

function IKST_LootOps.collectContainersOnSquare(square, out, seen, refillableOnly)
    out = out or {}
    seen = seen or {}
    if not square then
        return out
    end
    local objects = type(square.getObjects) == "function" and square:getObjects()
    if not objects then
        return out
    end
    for i = 0, objects:size() - 1 do
        if #out >= IKST_LootOps.maxContainers() then
            return out
        end
        local obj = objects:get(i)
        if obj then
            local entries = IKST_LootOps.containersFromObject(obj)
            for j = 1, #entries do
                local container = entries[j].container
                if container and not seen[container] then
                    seen[container] = true
                    if not IKST_LootOps.shouldIncludeInLootPreview(container, refillableOnly) then
                        -- Skip floor drops / player storage / non-refillable furniture.
                    else
                        out[#out + 1] = container
                        if #out >= IKST_LootOps.maxContainers() then
                            return out
                        end
                    end
                end
            end
        end
    end
    return out
end

function IKST_LootOps.collectContainersFromSquares(squares, out, seen, refillableOnly)
    out = out or {}
    seen = seen or {}
    for i = 1, #squares do
        IKST_LootOps.collectContainersOnSquare(squares[i], out, seen, refillableOnly)
        if #out >= IKST_LootOps.maxContainers() then
            break
        end
    end
    return out
end

function IKST_LootOps.squaresForScope(x, y, z, scope, args)
    args = args or {}
    if scope == IKST.CLEANUP_SCOPES.radius then
        local radius = args.radius or IKST.RADIUS_PRESETS.M
        if IKST.clampLootRadius then
            radius = IKST.clampLootRadius(radius)
        elseif IKST.clampRadius then
            radius = IKST.clampRadius(radius)
        end
        return IKST_Grid.squaresInRadius(x, y, z, radius)
    end
    if scope == IKST.CLEANUP_SCOPES.room then
        local square = IKST_Grid.getSquare(x, y, z)
        return IKST_Grid.squaresInRoomFromSquare(square)
    end
    if scope == IKST.CLEANUP_SCOPES.building then
        local square = IKST_Grid.getSquare(x, y, z)
        return IKST_Grid.squaresInBuildingFromSquare(square)
    end
    if scope == IKST.CLEANUP_SCOPES.cell then
        return IKST_Grid.squaresInLoadedMapCell(x, y, z)
    end
    local square = IKST_Grid.getSquare(x, y, z)
    if square then
        return { square }
    end
    return {}
end

function IKST_LootOps.containerLabel(container)
    if not container then
        return "container"
    end
    local containerType = type(container.getType) == "function" and container:getType() or "container"
    if getText and containerType ~= "" then
        local key = "IGUI_ContainerTitle_" .. containerType
        local label = getText(key)
        if label and label ~= "" and label ~= key then
            return label
        end
    end
    return containerType
end

function IKST_LootOps.previewZone(x, y, z, scope, args)
    args = args or {}
    local radius = tonumber(args.radius) or 0
    local cacheKey = tostring(x) .. "," .. tostring(y) .. "," .. tostring(z)
        .. "," .. tostring(scope) .. "," .. tostring(radius)
    local nowMs = 0
    if getTimestampMs then
        nowMs = getTimestampMs()
    elseif getTimeInMillis then
        nowMs = getTimeInMillis()
    end
    local cached = IKST_LootOps._previewCache
    if cached and cached.key == cacheKey and (nowMs - cached.atMs) < 400 then
        return cached.preview
    end
    IKST_LootOps.ensureLootPickerReady()
    local squares = IKST_LootOps.squaresForScope(x, y, z, scope, args)
    local containers = IKST_LootOps.collectContainersFromSquares(squares, {}, {}, true)
    local labels = {}
    local squareSet = {}
    local maxLabels = 6
    for i = 1, #containers do
        local container = containers[i]
        if container and container.getSourceGrid then
            local sq = container:getSourceGrid()
            if sq then
                squareSet[sq] = true
            end
        end
        if i <= maxLabels then
            labels[#labels + 1] = IKST_LootOps.containerLabel(container)
        end
    end
    local highlightSquares = {}
    for sq in pairs(squareSet) do
        highlightSquares[#highlightSquares + 1] = sq
    end
    local preview = {
        count = #containers,
        labels = labels,
        squares = highlightSquares,
        capped = #containers >= IKST_LootOps.maxContainers(),
    }
    if #containers > 0 and #containers <= 24 then
        preview.containers = containers
    end
    IKST_LootOps._previewCache = { key = cacheKey, atMs = nowMs, preview = preview }
    return preview
end

function IKST_LootOps.formatResultMessage(msg, extra)
    local code = tostring(msg or "")
    extra = extra or {}
    if code == "no containers" then
        return IKST.text("IGUI_IKST_Loot_NoContainers", "No loot containers in that area")
    end
    if code == "no area" then
        return IKST.text("IGUI_IKST_Loot_NoArea", "No valid area for that scope")
    end
    if code == "repopulate failed" then
        return IKST.text("IGUI_IKST_Loot_RepopFailed", "Could not repopulate any containers")
    end
    if code == "roll empty" then
        return IKST.text("IGUI_IKST_Loot_RollEmpty", "Loot roll came up empty; previous items kept")
    end
    if code == "repopulate_ok" then
        local fmt = IKST.text("IGUI_IKST_Loot_RepopulateOk", "%1 containers repopulated%2")
        fmt = string.gsub(fmt, "%%1", tostring(extra.resultCount or 0))
        return string.gsub(fmt, "%%2", tostring(extra.resultSuffix or ""))
    end
    if code == "container_repopulate_ok" then
        local label = tostring(extra.resultLabel or "")
        local fmt = IKST.text("IGUI_IKST_Loot_ContainerRepopulateOk", "%1 repopulated")
        return string.gsub(fmt, "%%1", label)
    end
    if code == "no distribution" then
        return IKST.text("IGUI_IKST_Loot_NoDistribution", "No loot distribution for that container")
    end
    if code == "player_placed" then
        return IKST.text("IGUI_IKST_Loot_PlayerPlaced", "That container was placed or moved by a player")
    end
    if code == "not_your_claim" then
        return IKST.text("IGUI_IKST_Loot_NotYourClaim", "That location is inside another player's claimed safe area")
    end
    if code == "blocked" or code == "square protected" then
        return IKST.text("IGUI_IKST_Loot_Blocked", "Container square is protected or readonly")
    end
    if code == "tile_readonly" then
        return IKST.text("IGUI_IKST_Policy_TileReadonly", "That square has storage lock (readonly) on")
    end
    if code == "tile protected" then
        return IKST.text("IGUI_IKST_Policy_TileProtected", "That square is tile-protected")
    end
    if code == "too_far" then
        return IKST.text("IGUI_IKST_Loot_TooFar", "Too far from that location")
    end
    if code == "server only" then
        return IKST.text("IGUI_IKST_ServerOnly", "Server only")
    end
    return code
end

function IKST_LootOps.previewSummary(preview)
    if not preview then
        return ""
    end
    if preview.count == 0 then
        return IKST.text("IGUI_IKST_Loot_Preview_None", "No containers in scope")
    end
    local line = tostring(preview.count) .. " "
        .. IKST.text("IGUI_IKST_Loot_Preview_Containers", "container(s)")
    if #preview.labels > 0 then
        line = line .. ": " .. table.concat(preview.labels, ", ")
        if preview.count > #preview.labels then
            line = line .. " ..."
        end
    end
    if preview.capped then
        line = line .. " (" .. IKST.text("IGUI_IKST_Loot_Preview_Cap", "cap") .. ")"
    end
    return line
end

function IKST_LootOps.isLootObject(obj, floor)
    if not obj or obj == floor then
        return false
    end
    return #IKST_LootOps.containersFromObject(obj) > 0
end

function IKST_LootOps.countLootObjectsOnSquare(square)
    if not square then
        return 0
    end
    local objects = type(square.getObjects) == "function" and square:getObjects()
    if not objects then
        return 0
    end
    local floor = type(square.getFloor) == "function" and square:getFloor()
    local count = 0
    for i = 0, objects:size() - 1 do
        if IKST_LootOps.isLootObject(objects:get(i), floor) then
            count = count + 1
        end
    end
    return count
end

function IKST_LootOps.removeLootObjectFromSquare(square, obj)
    if not IKST_LootOps.mayMutateWorldLoot() then
        return false
    end
    if not square or not obj then
        return false
    end
    if IKST.runsOnServerJvm and IKST.runsOnServerJvm() then
        if not IKST_TilesWorldOps then
            require "IKST_TilesWorldOps"
        end
        if IKST_TilesWorldOps and IKST_TilesWorldOps.removeObjectFromSquare then
            return IKST_TilesWorldOps.removeObjectFromSquare(square, obj, false) == true
        end
    end
    if obj.removeFromSquare then
        obj:removeFromSquare()
        return true
    end
    if square.RemoveTileObject then
        square:RemoveTileObject(obj, false)
        return true
    end
    return false
end

function IKST_LootOps.trimExcessLootObjectsOnSquare(square, keepObj, maxKeep)
    if not IKST_LootOps.mayMutateWorldLoot() then
        return
    end
    if not square or maxKeep == nil then
        return
    end
    maxKeep = math.floor(tonumber(maxKeep) or 0)
    if maxKeep < 0 then
        maxKeep = 0
    end
    local floor = type(square.getFloor) == "function" and square:getFloor()
    local guard = 0
    while IKST_LootOps.countLootObjectsOnSquare(square) > maxKeep and guard < 32 do
        guard = guard + 1
        local objects = type(square.getObjects) == "function" and square:getObjects()
        if not objects or objects:size() < 1 then
            break
        end
        local removed = false
        for i = objects:size() - 1, 0, -1 do
            local obj = objects:get(i)
            if obj and obj ~= keepObj and IKST_LootOps.isLootObject(obj, floor) then
                if IKST_LootOps.removeLootObjectFromSquare(square, obj) then
                    removed = true
                    if IKST_Debug and IKST_Debug.logVerbose then
                        IKST_Debug.logVerbose("loot", "trim duplicate " .. IKST_LootOps.describeLootObject(obj))
                    end
                    break
                end
            end
        end
        if not removed then
            break
        end
    end
    if IKST.runsOnServerJvm and IKST.runsOnServerJvm() and IKST_TilesWorldOps and IKST_TilesWorldOps.syncSquare then
        IKST_TilesWorldOps.syncSquare(square)
    end
end

function IKST_LootOps.squareKey(square)
    if not square then
        return nil
    end
    return tostring(square:getX()) .. "," .. tostring(square:getY()) .. "," .. tostring(square:getZ())
end

function IKST_LootOps.roomNameFromContainer(container)
    if not container or not container.getSourceGrid then
        return nil
    end
    local square = container:getSourceGrid()
    if not square then
        return nil
    end
    if square.getRoom then
        local room = square:getRoom()
        if room and room.getName then
            local name = room:getName()
            if name and name ~= "" then
                return name
            end
        end
    end
    if square.getRoomDef then
        local roomDef = square:getRoomDef()
        if roomDef and roomDef.getName then
            local name = roomDef:getName()
            if name and name ~= "" then
                return name
            end
        end
    end
    if ItemPicker and ItemPicker.getSquareBuildingName then
        return ItemPicker.getSquareBuildingName(square)
    end
    return nil
end

-- Let ItemPicker treat this container as unfilled (vanilla marks types in room procedural map).
-- Only remove this container type — never procedural:clear() for the whole room (zone repop
-- would wipe sibling types and leave later containers empty after clear-before-fill).
function IKST_LootOps.clearRoomProceduralSpawnForContainer(container)
    if not IKST_LootOps.mayMutateWorldLoot() then
        return
    end
    if not container or not container.getSourceGrid then
        return
    end
    local square = container:getSourceGrid()
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
    local containerType = type(container.getType) == "function" and container:getType()
    if not procedural or not containerType then
        return
    end
    if type(procedural.remove) == "function" then
        procedural:remove(containerType)
    end
end

function IKST_LootOps.markContainerFilled(container)
    if not container then
        return
    end
    if type(container.setExplored) == "function" then
        container:setExplored(true)
    end
end

function IKST_LootOps.prepareContainerForLootFill(container)
    if not container then
        return
    end
    IKST_LootOps.clearRoomProceduralSpawnForContainer(container)
    if container.setExplored then
        container:setExplored(false)
    end
end

function IKST_LootOps.ensureLootPickerReady()
    if IKST_LootOps._pickerReady then
        return
    end
    if ItemPicker and ItemPicker.InitSandboxLootSettings then
        ItemPicker.InitSandboxLootSettings()
    end
    IKST_LootOps._pickerReady = true
end

function IKST_LootOps.containerItemCount(container)
    if not container or not container.getItems then
        return 0
    end
    local items = container:getItems()
    if not items or not items.size then
        return 0
    end
    return items:size()
end

function IKST_LootOps.proceduralNameFromContainer(container)
    local parent = container and type(container.getParent) == "function" and container:getParent()
    if not parent then
        return nil
    end
    if type(parent.getSprite) == "function" and parent:getSprite() and parent:getSprite().getName then
        local name = parent:getSprite():getName()
        if name and name ~= "" then
            return name
        end
    end
    if parent.getObjectName then
        local name = parent:getObjectName()
        if name and name ~= "" then
            return tostring(name)
        end
    end
    return nil
end

function IKST_LootOps.isDistributionTable(dist)
    if not dist or type(dist) ~= "table" then
        return false
    end
    if type(dist.items) ~= "table" or dist.rolls == nil then
        return false
    end
    return true
end

function IKST_LootOps.suburbsContainerDist(roomName, containerType)
    if not SuburbsDistributions or not roomName or roomName == "" or not containerType or containerType == "" then
        return nil
    end
    local roomDist = SuburbsDistributions[roomName]
    if not roomDist or type(roomDist) ~= "table" then
        return nil
    end
    local entry = roomDist[containerType]
    if IKST_LootOps.isDistributionTable(entry) then
        return entry
    end
    return nil
end

function IKST_LootOps.proceduralListDist(name)
    if not name or name == "" then
        return nil
    end
    if not ProceduralDistributions or not ProceduralDistributions.list then
        return nil
    end
    local entry = ProceduralDistributions.list[name]
    if IKST_LootOps.isDistributionTable(entry) then
        return entry
    end
    return nil
end

function IKST_LootOps.roomNameFromSquare(square)
    if not square then
        return nil
    end
    if square.getRoom then
        local room = square:getRoom()
        if room and room.getName then
            local name = room:getName()
            if name and name ~= "" then
                return name
            end
        end
    end
    if square.getRoomDef then
        local roomDef = square:getRoomDef()
        if roomDef and roomDef.getName then
            local name = roomDef:getName()
            if name and name ~= "" then
                return name
            end
        end
    end
    if ItemPicker and ItemPicker.getSquareBuildingName then
        return ItemPicker.getSquareBuildingName(square)
    end
    return nil
end

function IKST_LootOps.roomNamesForContainer(container)
    local names = {}
    local seen = {}
    local function add(name)
        if name and name ~= "" and not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end
    end
    add(IKST_LootOps.roomNameFromContainer(container))
    local square = container and type(container.getSourceGrid) == "function" and container:getSourceGrid()
    if not square then
        return names
    end
    local x = square:getX()
    local y = square:getY()
    local z = square:getZ()
    local offsets = {
        { 0, 0 }, { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 },
        { 1, 1 }, { -1, -1 }, { 1, -1 }, { -1, 1 },
    }
    for i = 1, #offsets do
        local nx = x + offsets[i][1]
        local ny = y + offsets[i][2]
        local neighbor = IKST_Grid.getSquare(nx, ny, z)
        if neighbor then
            add(IKST_LootOps.roomNameFromSquare(neighbor))
        end
    end
    return names
end

function IKST_LootOps.mayUseFillContainerFallback()
    if not IKST_LootOps.mayMutateWorldLoot() then
        return false
    end
    -- MP: never ItemPicker.fillContainer — spawns duplicate crate IsoObjects on the square.
    if IKST.isMultiplayerSession and IKST.isMultiplayerSession() then
        return false
    end
    return true
end

-- Vanilla fillContainer for map loot only; never for player-placed storage.
function IKST_LootOps.tryFillContainerFallback(container, character, parent, beforeCount)
    if IKST_LootOps.isPlayerPlacedLootContainer(container) then
        return false
    end
    if not IKST_LootOps.mayUseFillContainerFallback() then
        return false
    end
    if not container or not ItemPicker or not ItemPicker.fillContainer then
        return false
    end
    local beforeItems = IKST_LootOps.containerItemCount(container)
    ItemPicker.fillContainer(container, character)
    if parent and IKST_LootOps.trimDuplicateContainers then
        IKST_LootOps.trimDuplicateContainers(parent, beforeCount)
    end
    return IKST_LootOps.containerItemCount(container) > beforeItems
end

function IKST_LootOps.resolveContainerDistribution(container, roomName, junk, strict)
    if not container or not container.getType or not ItemPicker then
        return nil
    end
    IKST_LootOps.ensureLootPickerReady()
    local containerType = container:getType()
    if not containerType or containerType == "" then
        return nil
    end
    local proceduralName = IKST_LootOps.proceduralNameFromContainer(container)
    if type(ItemPicker.getItemContainer) ~= "function" then
        return nil
    end
    local function try(room, procedural)
        if not room or room == "" or procedural == nil then
            return nil
        end
        return ItemPicker.getItemContainer(room, containerType, procedural, junk == true)
    end
    local roomNames = {}
    local roomSeen = {}
    local function addRoom(name)
        if name and name ~= "" and not roomSeen[name] then
            roomSeen[name] = true
            roomNames[#roomNames + 1] = name
        end
    end
    addRoom(roomName)
    if container then
        local candidates = IKST_LootOps.roomNamesForContainer(container)
        for i = 1, #candidates do
            addRoom(candidates[i])
        end
    end
    for i = 1, #roomNames do
        local candidate = roomNames[i]
        local dist = try(candidate, proceduralName)
        if dist then
            return dist
        end
        dist = IKST_LootOps.suburbsContainerDist(candidate, containerType)
        if dist then
            return dist
        end
        dist = try(candidate, "")
        if dist then
            return dist
        end
    end
    if proceduralName then
        local dist = try(nil, proceduralName)
        if dist then
            return dist
        end
        dist = IKST_LootOps.proceduralListDist(proceduralName)
        if dist then
            return dist
        end
    end
    if strict == true then
        return nil
    end
    local dist = try(nil, containerType)
    if dist then
        return dist
    end
    dist = IKST_LootOps.proceduralListDist(containerType)
    if dist then
        return dist
    end
    dist = try(nil, nil)
    if dist then
        return dist
    end
    return nil
end

function IKST_LootOps.staffRollDensity(_container)
    -- Staff refill must beat rare sandbox empty rolls (vanilla stress UI uses ~4–12).
    return 8
end

function IKST_LootOps.distLuaItems(dist)
    if not dist then
        return nil
    end
    if type(dist) == "table" and type(dist.items) == "table" then
        return dist.items
    end
    if dist.items and type(dist.items.size) == "function" then
        return dist.items
    end
    return nil
end

function IKST_LootOps.distProcList(dist)
    if not dist then
        return nil
    end
    if dist.procedural == true or (type(dist) == "table" and dist.procList) then
        return dist.procList
    end
    return nil
end

function IKST_LootOps.doStaffRollItem(containerDist, container, character, roomDist, doItemContainer, isJunk)
    if not containerDist or not container or not ItemPicker then
        return false
    end
    local before = IKST_LootOps.containerItemCount(container)
    local luaItems = IKST_LootOps.distLuaItems(containerDist)
    -- Java ItemPickerContainer wrappers: rollItem expands procedural. Lua dist tables: doRollItem only.
    if not luaItems and type(ItemPicker.rollItem) == "function" then
        ItemPicker.rollItem(containerDist, container, doItemContainer == true, character, roomDist)
        if IKST_LootOps.containerItemCount(container) > before then
            return true
        end
    end
    -- B42.20 ItemPickerJava.doRollItem: (containerDist, container, density, character, doItemContainer, roomDist)
    -- isJunk is Lua-only (which dist table we pass); it is not a Java arg.
    local density = IKST_LootOps.staffRollDensity(container)
    if type(ItemPicker.doRollItem) == "function" then
        ItemPicker.doRollItem(
            containerDist,
            container,
            density,
            character,
            doItemContainer == true,
            roomDist
        )
        return true
    end
    if type(ItemPicker.rollItem) == "function" then
        ItemPicker.rollItem(containerDist, container, doItemContainer == true, character, roomDist)
        return true
    end
    return false
end

-- Expand procedural wrappers (procList → named ProceduralDistributions) like LootZed / ItemPicker.rollItem.
function IKST_LootOps.rollProceduralProcList(procList, container, character, roomDist, doItemContainer)
    if not procList or not container then
        return false
    end
    local before = IKST_LootOps.containerItemCount(container)
    local function rollNamed(name)
        if not name or name == "" or not ProceduralDistributions or not ProceduralDistributions.list then
            return
        end
        local list = ProceduralDistributions.list[name]
        if not list then
            return
        end
        if list.junk then
            IKST_LootOps.doStaffRollItem(list.junk, container, character, roomDist, doItemContainer, true)
        end
        IKST_LootOps.doStaffRollItem(list, container, character, roomDist, doItemContainer, false)
    end
    if type(procList.size) == "function" and type(procList.get) == "function" then
        for i = 0, procList:size() - 1 do
            rollNamed(IKST_LootOps.procEntryName(procList:get(i)))
            if IKST_LootOps.containerItemCount(container) > before then
                return true
            end
        end
        return IKST_LootOps.containerItemCount(container) > before
    end
    if type(procList) == "table" then
        for i = 1, #procList do
            rollNamed(IKST_LootOps.procEntryName(procList[i]))
            if IKST_LootOps.containerItemCount(container) > before then
                return true
            end
        end
    end
    return IKST_LootOps.containerItemCount(container) > before
end

function IKST_LootOps.rollLootDistribution(containerDist, container, character, roomDist, doItemContainer, isJunk)
    if not IKST_LootOps.mayMutateWorldLoot() then
        return false
    end
    if not containerDist or not container or not ItemPicker then
        return false
    end
    local procList = IKST_LootOps.distProcList(containerDist)
    if procList then
        return IKST_LootOps.rollProceduralProcList(procList, container, character, roomDist, doItemContainer)
    end
    if not isJunk and containerDist.junk then
        IKST_LootOps.doStaffRollItem(containerDist.junk, container, character, roomDist, doItemContainer, true)
    end
    return IKST_LootOps.doStaffRollItem(containerDist, container, character, roomDist, doItemContainer, isJunk == true)
end

function IKST_LootOps.forceAddFromItemsList(container, items)
    if not IKST_LootOps.mayMutateWorldLoot() then
        return false
    end
    if not container or not items or type(container.AddItem) ~= "function" then
        return false
    end
    local before = IKST_LootOps.containerItemCount(container)
    local function tryName(itemName)
        if type(itemName) ~= "string" or itemName == "" then
            return false
        end
        -- Prefer AddItem. Avoid tryAddItemToContainer(nil dist) — it can no-op.
        container:AddItem(itemName)
        return IKST_LootOps.containerItemCount(container) > before
    end
    if type(items.size) == "function" and type(items.get) == "function" then
        local n = items:size()
        for i = 0, n - 1, 2 do
            if tryName(items:get(i)) then
                return true
            end
        end
        return false
    end
    if type(items) ~= "table" then
        return false
    end
    for i = 1, #items, 2 do
        if tryName(items[i]) then
            return true
        end
    end
    return false
end

-- Guaranteed staff fill when RNG rolls empty (rare sandbox / sparse tables).
function IKST_LootOps.procEntryName(entry)
    if entry == nil then
        return nil
    end
    if type(entry) == "string" then
        return entry
    end
    if type(entry) == "table" and entry.name then
        return entry.name
    end
    if entry.name then
        return entry.name
    end
    if type(entry.getName) == "function" then
        return entry:getName()
    end
    return nil
end

function IKST_LootOps.forceStaffFill(container, character, mainDist, junkDist, roomDist)
    if not IKST_LootOps.mayMutateWorldLoot() or not container then
        return false
    end
    local before = IKST_LootOps.containerItemCount(container)
    local function bump()
        return IKST_LootOps.containerItemCount(container) > before
    end
    for _ = 1, 12 do
        if mainDist then
            IKST_LootOps.rollLootDistribution(mainDist, container, character, roomDist, false, false)
        end
        if bump() then
            return true
        end
        if junkDist and junkDist ~= mainDist then
            IKST_LootOps.rollLootDistribution(junkDist, container, character, roomDist, false, true)
        end
        if bump() then
            return true
        end
    end
    local function forceDist(dist)
        if not dist then
            return false
        end
        local procList = IKST_LootOps.distProcList(dist)
        if procList then
            if type(procList.size) == "function" and type(procList.get) == "function" then
                for i = 0, procList:size() - 1 do
                    local name = IKST_LootOps.procEntryName(procList:get(i))
                    if name and ProceduralDistributions and ProceduralDistributions.list then
                        local list = ProceduralDistributions.list[name]
                        if list and IKST_LootOps.forceAddFromItemsList(container, IKST_LootOps.distLuaItems(list)) then
                            return true
                        end
                    end
                end
            elseif type(procList) == "table" then
                for i = 1, #procList do
                    local name = IKST_LootOps.procEntryName(procList[i])
                    if name and ProceduralDistributions and ProceduralDistributions.list then
                        local list = ProceduralDistributions.list[name]
                        if list and IKST_LootOps.forceAddFromItemsList(container, IKST_LootOps.distLuaItems(list)) then
                            return true
                        end
                    end
                end
            end
        end
        return IKST_LootOps.forceAddFromItemsList(container, IKST_LootOps.distLuaItems(dist))
    end
    if forceDist(mainDist) or forceDist(junkDist) then
        return true
    end
    return bump()
end

-- Refill the existing container only (never spawn new crate IsoObjects; doItemContainer always false).
-- Returns success, hadDistribution (true if any loot table matched, even when roll added zero items).
-- Optional mainDist/junkDist skip a second ItemPicker lookup when the caller already resolved tables.
function IKST_LootOps.rollItemsIntoExistingContainer(container, character, skipPrepare, mainDist, junkDist)
    if not IKST_LootOps.mayMutateWorldLoot() then
        return false, false
    end
    if not container or not ItemPicker then
        return false, false
    end
    IKST_LootOps.ensureLootPickerReady()
    if skipPrepare ~= true then
        IKST_LootOps.prepareContainerForLootFill(container)
    end
    local beforeItems = IKST_LootOps.containerItemCount(container)
    local hadDist = mainDist ~= nil or junkDist ~= nil
    if not hadDist then
        mainDist, junkDist, hadDist = IKST_LootOps.resolveContainerDistributions(container)
    end
    if not hadDist then
        return false, false
    end
    local roomDist = nil
    if mainDist then
        IKST_LootOps.rollLootDistribution(mainDist, container, character, roomDist, false, false)
    end
    if IKST_LootOps.containerItemCount(container) > beforeItems then
        return true, hadDist
    end
    if junkDist and junkDist ~= mainDist then
        IKST_LootOps.rollLootDistribution(junkDist, container, character, roomDist, false, true)
    end
    if IKST_LootOps.containerItemCount(container) > beforeItems then
        return true, hadDist
    end
    local parent = type(container.getParent) == "function" and container:getParent()
    local beforeCount = 0
    if parent and parent.getContainerCount then
        beforeCount = parent:getContainerCount()
        if beforeCount < 1 and type(parent.getContainer) == "function" and parent:getContainer() then
            beforeCount = 1
        end
    end
    if IKST_LootOps.tryFillContainerFallback(container, character, parent, beforeCount) then
        return true, hadDist
    end
    if IKST_Debug and IKST_Debug.log then
        local containerType = type(container.getType) == "function" and container:getType() or "?"
        local roomName = IKST_LootOps.roomNameFromContainer(container)
        IKST_Debug.log("loot", "no items added room=" .. tostring(roomName or "nil")
            .. " type=" .. tostring(containerType)
            .. " mainDist=" .. tostring(mainDist ~= nil)
            .. " junkDist=" .. tostring(junkDist ~= nil))
    end
    return false, hadDist
end

function IKST_LootOps.describeLootObject(obj)
    if not obj then
        return "loot"
    end
    if type(obj.getSprite) == "function" and obj:getSprite() and obj:getSprite().getName then
        return obj:getSprite():getName()
    end
    if obj.getObjectName then
        return tostring(obj:getObjectName())
    end
    return "loot"
end

function IKST_LootOps.containerByIndexOnObject(obj, containerIndex)
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

function IKST_LootOps.resolveLootTarget(x, y, z, objectIndex, containerIndex)
    x = math.floor(tonumber(x) or -1)
    y = math.floor(tonumber(y) or -1)
    z = math.floor(tonumber(z) or 0)
    if x < 0 or y < 0 then
        return nil, nil, nil
    end
    local square = IKST_Grid.getSquare(x, y, z)
    if not square then
        return nil, nil, nil
    end
    local objects = type(square.getObjects) == "function" and square:getObjects()
    if not objects then
        return nil, nil, nil
    end
    if objectIndex ~= nil then
        objectIndex = math.floor(tonumber(objectIndex) or -1)
        if objectIndex >= 0 and objectIndex < objects:size() then
            local parent = objects:get(objectIndex)
            if parent then
                if containerIndex ~= nil then
                    local container = IKST_LootOps.containerByIndexOnObject(parent, containerIndex)
                    if container then
                        return parent, container, square
                    end
                end
                if parent.getContainer then
                    return parent, parent:getContainer(), square
                end
            end
        end
    end
    if containerIndex ~= nil then
        containerIndex = math.floor(tonumber(containerIndex) or -1)
        if containerIndex >= 0 then
            for i = 0, objects:size() - 1 do
                local parent = objects:get(i)
                if parent then
                    local container = IKST_LootOps.containerByIndexOnObject(parent, containerIndex)
                    if IKST_LootOps.isWorldLootContainer(container) then
                        return parent, container, square
                    end
                end
            end
        end
    end
    local list = {}
    IKST_LootOps.collectContainersOnSquare(square, list, {})
    local container = list[1]
    if not container then
        return nil, nil, square
    end
    local parent = type(container.getParent) == "function" and container:getParent()
    return parent, container, square
end

function IKST_LootOps.containerIndexOnParent(parent, container)
    if not parent or not container or not parent.getContainerCount or not parent.getContainerByIndex then
        return nil
    end
    local count = parent:getContainerCount()
    for i = 0, count - 1 do
        if parent:getContainerByIndex(i) == container then
            return i
        end
    end
    return nil
end

function IKST_LootOps.buildRefreshPayload(container)
    if not container or not container.getSourceGrid then
        return nil
    end
    local square = container:getSourceGrid()
    if not square then
        return nil
    end
    local parent = type(container.getParent) == "function" and container:getParent()
    local objectIndex = nil
    local containerIndex = nil
    if parent then
        objectIndex = IKST_LootOps.resolveObjectIndex(square, parent)
        containerIndex = IKST_LootOps.containerIndexOnParent(parent, container)
    end
    return {
        x = square:getX(),
        y = square:getY(),
        z = square:getZ(),
        objectIndex = objectIndex,
        containerIndex = containerIndex,
    }
end

function IKST_LootOps.readLootCoord(args, key)
    return IKST_Args.readCoord(args, key)
end

function IKST_LootOps.resolveTargetsFromWorldObjects(worldobjects)
    local targets = {}
    local seen = {}
    if not worldobjects then
        return targets
    end
    for i = 1, #worldobjects do
        local obj = worldobjects[i]
        if obj then
            local square = IKST_Grid.squareFromObject(obj)
            if not square and obj.getSquare then
                square = obj:getSquare()
            end
            if square then
                local objectIndex = IKST_LootOps.resolveObjectIndex(square, obj)
                local entries = IKST_LootOps.containersFromObject(obj)
                for j = 1, #entries do
                    local container = entries[j].container
                    if container and not seen[container] and IKST_LootOps.isRepopulateCandidate(container) then
                        seen[container] = true
                        targets[#targets + 1] = {
                            x = square:getX(),
                            y = square:getY(),
                            z = square:getZ(),
                            objectIndex = objectIndex,
                            containerIndex = entries[j].containerIndex,
                            label = IKST_LootOps.containerLabel(container),
                        }
                    end
                end
            end
        end
    end
    return targets
end
