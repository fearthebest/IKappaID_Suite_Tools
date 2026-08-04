require "IKST_Shared"
require "IKST_Grid"

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
    local parent = container.getParent and container:getParent()
    if parent and instanceof and instanceof(parent, "IsoPlayer") then
        return false
    end
    return true
end

function IKST_LootOps.containersFromObject(obj)
    local out = {}
    if not obj then
        return out
    end
    if obj.getContainerCount and obj:getContainerCount() > 0 then
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
    local objects = square.getObjects and square:getObjects()
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
    if not IKST_LootOps.isWorldLootContainer(container) then
        return false
    end
    local roomName = IKST_LootOps.roomNameFromContainer(container)
    if IKST_LootOps.resolveContainerDistribution(container, roomName, false) then
        return true
    end
    if IKST_LootOps.resolveContainerDistribution(container, roomName, true) then
        return true
    end
    return false
end

function IKST_LootOps.collectContainersOnSquare(square, out, seen, refillableOnly)
    out = out or {}
    seen = seen or {}
    if not square then
        return out
    end
    local objects = square.getObjects and square:getObjects()
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
                    if refillableOnly == true and not IKST_LootOps.containerHasLootDistribution(container) then
                        -- Skip player crates / non-loot furniture so they do not consume the zone cap.
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
        return IKST_Grid.squaresInRadius(x, y, z, args.radius or IKST.RADIUS_PRESETS.M)
    end
    if scope == IKST.CLEANUP_SCOPES.room then
        local square = IKST_Grid.getSquare(x, y, z)
        return IKST_Grid.squaresInRoomFromSquare(square)
    end
    if scope == IKST.CLEANUP_SCOPES.building then
        local square = IKST_Grid.getSquare(x, y, z)
        return IKST_Grid.squaresInBuildingFromSquare(square)
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
    local containerType = container.getType and container:getType() or "container"
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
    return preview
end

function IKST_LootOps.formatResultMessage(msg)
    local code = tostring(msg or "")
    if code == "no containers" then
        return IKST.text("IGUI_IKST_Loot_NoContainers", "No loot containers in that area")
    end
    if code == "no area" then
        return IKST.text("IGUI_IKST_Loot_NoArea", "No valid area for that scope")
    end
    if code == "repopulate failed" then
        return IKST.text("IGUI_IKST_Loot_RepopFailed", "Could not repopulate any containers")
    end
    if code == "no distribution" then
        return IKST.text("IGUI_IKST_Loot_NoDistribution", "No loot distribution for that container")
    end
    if code == "blocked" or code == "square protected" then
        return IKST.text("IGUI_IKST_Loot_Blocked", "Container square is protected or readonly")
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
    local objects = square.getObjects and square:getObjects()
    if not objects then
        return 0
    end
    local floor = square.getFloor and square:getFloor()
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
    local floor = square.getFloor and square:getFloor()
    local guard = 0
    while IKST_LootOps.countLootObjectsOnSquare(square) > maxKeep and guard < 32 do
        guard = guard + 1
        local objects = square.getObjects and square:getObjects()
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
    local containerType = container.getType and container:getType()
    if not procedural or not containerType then
        return
    end
    if procedural.remove then
        procedural:remove(containerType)
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
    if container.setHasBeenLooted then
        container:setHasBeenLooted(false)
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
    local parent = container and container.getParent and container:getParent()
    if not parent then
        return nil
    end
    if parent.getSprite and parent:getSprite() and parent:getSprite().getName then
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
    local square = container and container.getSourceGrid and container:getSourceGrid()
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

-- fillContainer on dedicated server only (trim + contents-only sync prevents MP ghost crate).
function IKST_LootOps.mayUseFillContainerFallback()
    if not IKST_LootOps.mayMutateWorldLoot() then
        return false
    end
    if IKST.isMultiplayerSession and IKST.isMultiplayerSession() then
        if IKST.isClient and IKST.isClient() then
            return false
        end
        return IKST.runsOnServerJvm and IKST.runsOnServerJvm()
    end
    return true
end

function IKST_LootOps.tryFillContainerFallback(container, character, parent, beforeCount)
    if not IKST_LootOps.mayMutateWorldLoot() then
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
    if parent then
        IKST_LootOps.trimDuplicateContainers(parent, beforeCount)
    end
    return IKST_LootOps.containerItemCount(container) > beforeItems
end

function IKST_LootOps.resolveContainerDistribution(container, roomName, junk)
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

function IKST_LootOps.rollLootDistribution(containerDist, container, character, roomDist, doItemContainer)
    if not IKST_LootOps.mayMutateWorldLoot() then
        return false
    end
    if not containerDist or not container or not ItemPicker then
        return false
    end
    if type(ItemPicker.rollItem) == "function" then
        ItemPicker.rollItem(containerDist, container, doItemContainer == true, character, roomDist)
        return true
    end
    if type(ItemPicker.doRollItem) == "function" then
        local density = 0
        if type(ItemPicker.getZombieDensityFactor) == "function" then
            density = ItemPicker.getZombieDensityFactor(containerDist, container) or 0
        end
        ItemPicker.doRollItem(containerDist, container, density, character, doItemContainer == true, false, roomDist)
        return true
    end
    return false
end

-- Refill the existing container only (never spawn new crate IsoObjects; doItemContainer always false).
-- Returns success, hadDistribution (true if any loot table matched, even when roll added zero items).
function IKST_LootOps.rollItemsIntoExistingContainer(container, character)
    if not IKST_LootOps.mayMutateWorldLoot() then
        return false, false
    end
    if not container or not ItemPicker then
        return false, false
    end
    IKST_LootOps.ensureLootPickerReady()
    IKST_LootOps.prepareContainerForLootFill(container)
    local beforeItems = IKST_LootOps.containerItemCount(container)
    local roomName = IKST_LootOps.roomNameFromContainer(container)
    local mainDist = IKST_LootOps.resolveContainerDistribution(container, roomName, false)
    local junkDist = IKST_LootOps.resolveContainerDistribution(container, roomName, true)
    local hadDist = mainDist ~= nil or junkDist ~= nil
    if mainDist then
        IKST_LootOps.rollLootDistribution(mainDist, container, character, nil, false)
    end
    if IKST_LootOps.containerItemCount(container) > beforeItems then
        return true, hadDist
    end
    if junkDist and junkDist ~= mainDist then
        IKST_LootOps.rollLootDistribution(junkDist, container, character, nil, false)
    end
    if IKST_LootOps.containerItemCount(container) > beforeItems then
        return true, hadDist
    end
    local parent = container.getParent and container:getParent()
    local beforeCount = 0
    if parent and parent.getContainerCount then
        beforeCount = parent:getContainerCount()
        if beforeCount < 1 and parent.getContainer and parent:getContainer() then
            beforeCount = 1
        end
    end
    if IKST_LootOps.tryFillContainerFallback(container, character, parent, beforeCount) then
        return true, true
    end
    if IKST_Debug and IKST_Debug.log then
        local containerType = container.getType and container:getType() or "?"
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
    if obj.getSprite and obj:getSprite() and obj:getSprite().getName then
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
    local objects = square.getObjects and square:getObjects()
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
    local parent = container.getParent and container:getParent()
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
    local parent = container.getParent and container:getParent()
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
    if not args then
        return nil
    end
    local value = tonumber(args[key])
    if value == nil then
        return nil
    end
    return math.floor(value)
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
                    if container and not seen[container] then
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
