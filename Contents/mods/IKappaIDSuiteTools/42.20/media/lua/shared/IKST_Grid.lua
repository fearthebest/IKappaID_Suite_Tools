require "IKST_Shared"

IKST_Grid = IKST_Grid or {}

function IKST_Grid.getSquare(x, y, z)
    if not getCell then
        return nil
    end
    return getCell():getGridSquare(x, y, z)
end

function IKST_Grid.squareFromObject(obj)
    if not obj then
        return nil
    end
    if obj.getSquare then
        return obj:getSquare()
    end
    if obj.getCell and obj.getX and obj.getY and obj.getZ then
        local cell = obj:getCell()
        if cell and cell.getGridSquare then
            return cell:getGridSquare(obj:getX(), obj:getY(), obj:getZ())
        end
    end
    return nil
end

function IKST_Grid.squareFromWorldObjects(worldobjects, player)
    if not worldobjects then
        return nil
    end
    player = IKST.resolvePlayer(player)
    local playerZ = player and math.floor(player:getZ()) or 0
    local best, bestDist = nil, -1
    for i = 1, #worldobjects do
        local sq = IKST_Grid.squareFromObject(worldobjects[i])
        if sq and sq.getZ then
            local dist = math.abs(sq:getZ() - playerZ)
            if best == nil or dist < bestDist or (dist == bestDist and sq:getZ() > best:getZ()) then
                bestDist = dist
                best = sq
            end
        end
    end
    return best
end

function IKST_Grid.getMaxZ()
    if getCell then
        local cell = getCell()
        if cell and cell.getMaxZ then
            return cell:getMaxZ()
        end
    end
    return 7
end

function IKST_Grid.getMinZ()
    if getCell then
        local cell = getCell()
        if cell and cell.getMinZ then
            return cell:getMinZ()
        end
    end
    return -32
end

function IKST_Grid.isRoofObject(obj)
    if not obj then
        return false
    end
    if IsoObjectType and obj.getType then
        local objType = obj:getType()
        if objType == IsoObjectType.WestRoofB
            or objType == IsoObjectType.WestRoofM
            or objType == IsoObjectType.WestRoofT then
            return true
        end
    end
    if not obj.getSprite then
        return false
    end
    local sprite = obj:getSprite()
    if not sprite then
        return false
    end
    if type(sprite.getRoofProperties) == "function" and sprite:getRoofProperties() then
        return true
    end
    if sprite.getName then
        local name = string.lower(sprite:getName() or "")
        if string.find(name, "roofs_", 1, true)
            or string.find(name, "fixtures_roof", 1, true)
            or string.find(name, "roof_", 1, true)
            or string.find(name, "_roof", 1, true)
            or string.find(name, "eave", 1, true) then
            return true
        end
    end
    return false
end

function IKST_Grid.squareHasRoof(square)
    if not square then
        return false
    end
    if type(square.HasSlopedRoof) == "function" and square:HasSlopedRoof() then
        return true
    end
    if type(square.haveRoofFull) == "function" and square:haveRoofFull() then
        return true
    end
    local floor = type(square.getFloor) == "function" and square:getFloor()
    if floor and IKST_Grid.isRoofObject(floor) then
        return true
    end
    local objects = type(square.getObjects) == "function" and square:getObjects()
    if not objects then
        return false
    end
    for i = 0, objects:size() - 1 do
        if IKST_Grid.isRoofObject(objects:get(i)) then
            return true
        end
    end
    return false
end

function IKST_Grid.scoreSquareForPick(square, playerZ)
    if not square then
        return -1
    end
    local z = square:getZ()
    local score = -math.abs(z - playerZ) * 100
    if IKST_Grid.squareHasRoof(square) then
        score = score + 500
    end
    local floor = type(square.getFloor) == "function" and square:getFloor()
    if floor then
        score = score + 5
        if IKST_Grid.isRoofObject(floor) then
            score = score + 300
        end
    end
    local objects = type(square.getObjects) == "function" and square:getObjects()
    if objects then
        score = score + objects:size()
    end
    return score
end

function IKST_Grid.getMouseScreenXY()
    if type(getMouseX) == "function" and type(getMouseY) == "function" then
        return getMouseX(), getMouseY()
    end
    return nil, nil
end

-- DiggingUtil / ISPlace3DItemCursor: unscaled mouse + screenToIso*.
function IKST_Grid.worldXYFromScreen(screenX, screenY, player, z)
    player = IKST.resolvePlayer(player)
    if not player then
        return nil, nil
    end
    z = z or math.floor(player:getZ())
    local mx, my = screenX, screenY
    if mx == nil or my == nil then
        mx, my = IKST_Grid.getMouseScreenXY()
    end
    if mx == nil or my == nil then
        return nil, nil
    end
    if type(screenToIsoX) ~= "function" or type(screenToIsoY) ~= "function" then
        return nil, nil
    end
    local playerNum = 0
    if type(player.getIndex) == "function" then
        playerNum = player:getIndex() or 0
    elseif type(player.getPlayerNum) == "function" then
        playerNum = player:getPlayerNum() or 0
    end
    return screenToIsoX(playerNum, mx, my, z), screenToIsoY(playerNum, mx, my, z)
end

function IKST_Grid.bestSquareAtWorldXY(wx, wy, player)
    player = IKST.resolvePlayer(player)
    if not player or wx == nil or wy == nil then
        return nil
    end
    local ix = math.floor(wx + 0.5)
    local iy = math.floor(wy + 0.5)
    local playerZ = math.floor(player:getZ())
    local minZ = IKST_Grid.getMinZ()
    local maxZ = IKST_Grid.getMaxZ()
    local best, bestScore = nil, -1

    for z = minZ, maxZ do
        local sq = IKST_Grid.getSquare(ix, iy, z)
        if sq then
            local score = IKST_Grid.scoreSquareForPick(sq, playerZ)
            if score > bestScore then
                bestScore = score
                best = sq
            end
        end
    end
    if best then
        return best
    end
    return IKST_Grid.getSquare(ix, iy, playerZ)
end

function IKST_Grid.squareFromScreen(screenX, screenY, player)
    player = IKST.resolvePlayer(player)
    if not player then
        return nil
    end
    local mx, my = screenX, screenY
    if mx == nil or my == nil then
        mx, my = IKST_Grid.getMouseScreenXY()
    end
    if mx == nil or my == nil then
        return nil
    end
    local playerZ = math.floor(player:getZ())
    local wx, wy = IKST_Grid.worldXYFromScreen(mx, my, player, playerZ)
    if wx == nil or wy == nil then
        return nil
    end
    local sq = IKST_Grid.getSquare(math.floor(wx + 0.5), math.floor(wy + 0.5), playerZ)
    if sq then
        return sq
    end
    return IKST_Grid.bestSquareAtWorldXY(wx, wy, player)
end

-- Loaded squares in the 300-tile map cell (same grid as vehicleDeleteCell).
-- Uses IsoCell:getChunk ([JavaDoc](https://projectzomboid.com/modding/zombie/iso/IsoCell.html));
-- vanilla chunks are 10 tiles. Unloaded chunks are skipped.
function IKST_Grid.squaresInLoadedMapCell(cx, cy, cz)
    local result = {}
    if type(getCell) ~= "function" then
        return result
    end
    local cell = getCell()
    if not cell or type(cell.getChunk) ~= "function" then
        return result
    end
    cx = math.floor(tonumber(cx) or 0)
    cy = math.floor(tonumber(cy) or 0)
    cz = math.floor(tonumber(cz) or 0)
    local mapX = math.floor(cx / 300)
    local mapY = math.floor(cy / 300)
    local minX = mapX * 300
    local minY = mapY * 300
    local maxX = minX + 299
    local maxY = minY + 299
    local CHUNK = 10
    local wx0 = math.floor(minX / CHUNK)
    local wy0 = math.floor(minY / CHUNK)
    local wx1 = math.floor(maxX / CHUNK)
    local wy1 = math.floor(maxY / CHUNK)
    for wx = wx0, wx1 do
        for wy = wy0, wy1 do
            local chunk = cell:getChunk(wx, wy)
            if chunk then
                local x0 = math.max(minX, wx * CHUNK)
                local y0 = math.max(minY, wy * CHUNK)
                local x1 = math.min(maxX, wx * CHUNK + CHUNK - 1)
                local y1 = math.min(maxY, wy * CHUNK + CHUNK - 1)
                for gx = x0, x1 do
                    for gy = y0, y1 do
                        local sq = IKST_Grid.getSquare(gx, gy, cz)
                        if sq then
                            result[#result + 1] = sq
                        end
                    end
                end
            end
        end
    end
    if #result == 0 then
        local radius = 50
        if IKST.clampLootRadius then
            radius = IKST.clampLootRadius(200)
        elseif IKST.clampRadius then
            radius = IKST.clampRadius(50)
        end
        local around = IKST_Grid.squaresInRadius(cx, cy, cz, radius)
        for i = 1, #around do
            local sq = around[i]
            if sq and type(sq.getX) == "function" and type(sq.getY) == "function" then
                if math.floor(sq:getX() / 300) == mapX and math.floor(sq:getY() / 300) == mapY then
                    result[#result + 1] = sq
                end
            end
        end
        return result
    end
    return IKST_Grid.sortNearest(result, cx, cy)
end

function IKST_Grid.squaresInRadius(cx, cy, cz, radius)
    local result = {}
    radius = IKST.clampRadius(radius)
    local r2 = radius * radius
    for dx = -radius, radius do
        for dy = -radius, radius do
            if (dx * dx + dy * dy) <= r2 then
                local sq = IKST_Grid.getSquare(cx + dx, cy + dy, cz)
                if sq then
                    result[#result + 1] = sq
                end
            end
        end
    end
    return result
end

function IKST_Grid.squaresInCube(cx, cy, cz, halfExtent)
    local result = {}
    halfExtent = IKST.clampCubeHalf(halfExtent)
    for dz = -halfExtent, halfExtent do
        for dy = -halfExtent, halfExtent do
            for dx = -halfExtent, halfExtent do
                local sq = IKST_Grid.getSquare(cx + dx, cy + dy, cz + dz)
                if sq then
                    result[#result + 1] = sq
                end
            end
        end
    end
    return result
end

function IKST_Grid.sortNearest(squares, ox, oy)
    table.sort(squares, function(a, b)
        local da = IKST.distance2d(a:getX(), a:getY(), ox, oy)
        local db = IKST.distance2d(b:getX(), b:getY(), ox, oy)
        return da < db
    end)
    return squares
end

function IKST_Grid.squaresInRoomFromSquare(square)
    local result = {}
    if not square then
        return result
    end
    local room = type(square.getRoom) == "function" and square:getRoom()
    if not room and square.getRoomDef then
        local roomDef = square:getRoomDef()
        if roomDef and roomDef.getIsoRoom then
            room = roomDef:getIsoRoom()
        end
    end
    if not room or not room.getSquares then
        return result
    end
    local list = room:getSquares()
    if not list then
        return result
    end
    for i = 0, list:size() - 1 do
        result[#result + 1] = list:get(i)
    end
    return result
end

function IKST_Grid.squaresInBuildingFromSquare(square)
    local result = {}
    local seen = {}
    if not square then
        return result
    end

    local function addSquare(sq)
        if not sq then
            return
        end
        local key = sq:getX() .. ":" .. sq:getY() .. ":" .. sq:getZ()
        if seen[key] then
            return
        end
        seen[key] = true
        result[#result + 1] = sq
    end

    local function addRoom(room)
        if not room or not room.getSquares then
            return
        end
        local list = room:getSquares()
        if not list then
            return
        end
        for i = 0, list:size() - 1 do
            addSquare(list:get(i))
        end
    end

    local building = type(square.getBuilding) == "function" and square:getBuilding()
    if not building or not building.getDef then
        return result
    end
    local def = building:getDef()
    if not def or not def.getRooms then
        return result
    end
    local rooms = def:getRooms()
    if not rooms then
        return result
    end

    for i = 0, rooms:size() - 1 do
        local roomDef = rooms:get(i)
        if roomDef and roomDef.getIsoRoom then
            addRoom(roomDef:getIsoRoom())
        elseif roomDef and roomDef.getFreeSquare then
            local freeSq = roomDef:getFreeSquare()
            if freeSq and freeSq.getRoom then
                addRoom(freeSq:getRoom())
            end
        end
    end
    return result
end

function IKST_Grid.toCoords(squares)
    local coords = {}
    for _, sq in ipairs(squares) do
        coords[#coords + 1] = { x = sq:getX(), y = sq:getY(), z = sq:getZ() }
    end
    return coords
end

function IKST_Grid.fromCoords(coords)
    local squares = {}
    for _, c in ipairs(coords) do
        local sq = IKST_Grid.getSquare(c.x, c.y, c.z)
        if sq then
            squares[#squares + 1] = sq
        end
    end
    return squares
end

function IKST_Grid.isWorldContainer(container)
    if not container then
        return false
    end
    if type(container.getType) == "function" then
        local containerType = container:getType()
        if containerType == "floor" then
            return false
        end
    end
    local parent = type(container.getParent) == "function" and container:getParent()
    if parent and instanceof and instanceof(parent, "IsoPlayer") then
        return false
    end
    return true
end

function IKST_Grid.objectContainerOnSquare(square)
    if not square or type(square.getObjects) ~= "function" then
        return nil, nil
    end
    local objects = square:getObjects()
    if not objects then
        return nil, nil
    end
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj then
            if type(obj.getContainerCount) == "function" and obj:getContainerCount() > 0 then
                for j = 0, obj:getContainerCount() - 1 do
                    if type(obj.getContainerByIndex) == "function" then
                        local container = obj:getContainerByIndex(j)
                        if IKST_Grid.isWorldContainer(container) then
                            return obj, container
                        end
                    end
                end
            elseif type(obj.getContainer) == "function" then
                local container = obj:getContainer()
                if IKST_Grid.isWorldContainer(container) then
                    return obj, container
                end
            end
        end
    end
    return nil, nil
end

function IKST_Grid.containerFromWorldObjects(worldobjects)
    if not worldobjects then
        return nil, nil, nil
    end
    for i = 1, #worldobjects do
        local obj = worldobjects[i]
        if obj then
            local sq = IKST_Grid.squareFromObject(obj)
            if type(obj.getContainerCount) == "function" and obj:getContainerCount() > 0 then
                for j = 0, obj:getContainerCount() - 1 do
                    if type(obj.getContainerByIndex) == "function" then
                        local container = obj:getContainerByIndex(j)
                        if IKST_Grid.isWorldContainer(container) then
                            return obj, container, sq
                        end
                    end
                end
            elseif type(obj.getContainer) == "function" then
                local container = obj:getContainer()
                if IKST_Grid.isWorldContainer(container) then
                    return obj, container, sq
                end
            end
        end
    end
    return nil, nil, nil
end

function IKST_Grid.containerNearPlayer(player, radius)
    if not player or type(player.getSquare) ~= "function" then
        return nil, nil, nil
    end
    local sq = player:getSquare()
    if not sq then
        return nil, nil, nil
    end
    radius = tonumber(radius) or 1
    if radius < 0 then
        radius = 0
    end
    local px, py = player:getX(), player:getY()
    local pz = math.floor(player:getZ())
    local squares = IKST_Grid.squaresInRadius(sq:getX(), sq:getY(), pz, radius)
    IKST_Grid.sortNearest(squares, px, py)
    for i = 1, #squares do
        local obj, container = IKST_Grid.objectContainerOnSquare(squares[i])
        if container then
            return obj, container, squares[i]
        end
    end
    return nil, nil, nil
end
