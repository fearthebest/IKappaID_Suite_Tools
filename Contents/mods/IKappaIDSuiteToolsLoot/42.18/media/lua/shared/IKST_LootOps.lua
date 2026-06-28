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

function IKST_LootOps.collectContainersOnSquare(square, out, seen)
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
                    out[#out + 1] = container
                    if #out >= IKST_LootOps.maxContainers() then
                        return out
                    end
                end
            end
        end
    end
    return out
end

function IKST_LootOps.collectContainersFromSquares(squares, out, seen)
    out = out or {}
    seen = seen or {}
    for i = 1, #squares do
        IKST_LootOps.collectContainersOnSquare(squares[i], out, seen)
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
