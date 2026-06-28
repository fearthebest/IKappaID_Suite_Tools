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

function IKST_Grid.squareFromWorldObjects(worldobjects)
    if not worldobjects then
        return nil
    end
    local best, bestZ = nil, -1
    for i = 1, #worldobjects do
        local sq = IKST_Grid.squareFromObject(worldobjects[i])
        if sq and sq.getZ and sq:getZ() >= bestZ then
            bestZ = sq:getZ()
            best = sq
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
    if sprite.getRoofProperties and sprite:getRoofProperties() then
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
    if square.HasSlopedRoof and square:HasSlopedRoof() then
        return true
    end
    if square.haveRoofFull and square:haveRoofFull() then
        return true
    end
    local floor = square.getFloor and square:getFloor()
    if floor and IKST_Grid.isRoofObject(floor) then
        return true
    end
    local objects = square.getObjects and square:getObjects()
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
    local score = square:getZ() * 10
    if IKST_Grid.squareHasRoof(square) then
        score = score + 500
    end
    local floor = square.getFloor and square:getFloor()
    if floor then
        score = score + 5
        if IKST_Grid.isRoofObject(floor) then
            score = score + 300
        end
    end
    local objects = square.getObjects and square:getObjects()
    if objects then
        score = score + objects:size()
    end
    if square:getZ() < playerZ then
        score = score - 1000
    end
    return score
end

function IKST_Grid.worldXYFromScreen(screenX, screenY, player, z)
    player = IKST.resolvePlayer(player)
    if not player or screenX == nil or screenY == nil then
        return nil, nil
    end
    z = z or math.floor(player:getZ())
    local mx, my = screenX, screenY

    if getMouseXScaled and getMouseYScaled and screenX == nil and screenY == nil then
        local sx = getMouseXScaled()
        local sy = getMouseYScaled()
        if sx ~= nil and sy ~= nil then
            mx, my = sx, sy
        end
    end
    if mx == nil or my == nil then
        return nil, nil
    end

    local zoom = 1
    local playerNum = player.getPlayerNum and player:getPlayerNum() or 0
    if getCore and getCore() and getCore().getZoom then
        local zv = getCore():getZoom(playerNum)
        if zv and zv > 0 then
            zoom = zv
        end
    end

    local wx, wy = nil, nil
    if ISCoordConversion and ISCoordConversion.ToWorld then
        wx, wy = ISCoordConversion.ToWorld(mx, my, z)
    end

    if (wx == nil or wy == nil) and IsoUtils and IsoUtils.XToIso and IsoUtils.YToIso then
        wx = IsoUtils.XToIso(mx * zoom, my * zoom, z)
        wy = IsoUtils.YToIso(mx * zoom, my * zoom, z)
    end
    return wx, wy
end

function IKST_Grid.bestSquareAtWorldXY(wx, wy, player)
    player = IKST.resolvePlayer(player)
    if not player or wx == nil or wy == nil then
        return nil
    end
    local ix = math.floor(wx + 0.5)
    local iy = math.floor(wy + 0.5)
    local playerZ = math.floor(player:getZ())
    local maxZ = IKST_Grid.getMaxZ()
    local best, bestScore = nil, -1

    for z = playerZ, maxZ do
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

function IKST_Grid.pickSquareFromScreenAtZ(mx, my, player, z)
    local wx, wy = IKST_Grid.worldXYFromScreen(mx, my, player, z)
    if wx == nil or wy == nil then
        return nil
    end
    return IKST_Grid.getSquare(math.floor(wx + 0.5), math.floor(wy + 0.5), z)
end

function IKST_Grid.squareFromScreen(screenX, screenY, player)
    player = IKST.resolvePlayer(player)
    if not player then
        return nil
    end
    local mx, my = screenX, screenY

    if getMouseXScaled and getMouseYScaled then
        local sx = getMouseXScaled()
        local sy = getMouseYScaled()
        if sx ~= nil and sy ~= nil then
            mx, my = sx, sy
        end
    end
    if mx == nil or my == nil then
        if getMouseX and getMouseY then
            mx, my = getMouseX(), getMouseY()
        else
            return nil
        end
    end

    local playerZ = math.floor(player:getZ())
    local maxZ = IKST_Grid.getMaxZ()
    local best, bestScore = nil, -1

    for z = playerZ, maxZ do
        local sq = IKST_Grid.pickSquareFromScreenAtZ(mx, my, player, z)
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
    return IKST_Grid.pickSquareFromScreenAtZ(mx, my, player, playerZ)
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
    local room = square.getRoom and square:getRoom()
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

    local building = square.getBuilding and square:getBuilding()
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
