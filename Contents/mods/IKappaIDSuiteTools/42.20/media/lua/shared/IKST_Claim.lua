-- Shared safehouse / claim geometry (client preview + server claim).

require "IKST_Shared"

require "IKST_Grid"

IKST_Claim = IKST_Claim or {}

IKST_Claim.MODE = {

    square = "square",

    building = "building",

}

IKST_Claim.MIN_DIM = 5

IKST_Claim.MAX_DIM = 75

function IKST_Claim.clampDimension(value, fallback)

    local n = math.floor(tonumber(value) or tonumber(fallback) or 13)

    if n < IKST_Claim.MIN_DIM then

        n = IKST_Claim.MIN_DIM

    elseif n > IKST_Claim.MAX_DIM then

        n = IKST_Claim.MAX_DIM

    end

    return n

end

-- Back-compat: square presets use one dimension for both axes.

function IKST_Claim.clampSize(size)

    return IKST_Claim.clampDimension(size, 13)

end

function IKST_Claim.resolveDimensions(size, w, h)

    if w ~= nil or h ~= nil then

        local rw = IKST_Claim.clampDimension(w, size or 13)

        local rh = IKST_Claim.clampDimension(h, rw)

        return rw, rh

    end

    local s = IKST_Claim.clampSize(size)

    return s, s

end

function IKST_Claim.claimBounds(cx, cy, size)

    local w, h = IKST_Claim.resolveDimensions(size, nil, nil)

    return IKST_Claim.claimBoundsRect(cx, cy, w, h)

end

function IKST_Claim.claimBoundsRect(cx, cy, w, h)

    w, h = IKST_Claim.resolveDimensions(nil, w, h)

    cx = math.floor(tonumber(cx) or 0)

    cy = math.floor(tonumber(cy) or 0)

    local halfW = math.floor(w / 2)

    local halfH = math.floor(h / 2)

    return cx - halfW, cy - halfH, w, h

end

function IKST_Claim.squareHasBuilding(square)

    if not square or not square.getBuilding then

        return false

    end

    return square:getBuilding() ~= nil

end

function IKST_Claim.buildingBoundsFromSquare(square)

    if not square then

        return nil

    end

    local squares = IKST_Grid.squaresInBuildingFromSquare(square)

    if #squares == 0 then

        return nil

    end

    local z = square:getZ()

    local minX, minY, maxX, maxY

    for _, sq in ipairs(squares) do

        if sq and sq:getZ() == z then

            local sx, sy = sq:getX(), sq:getY()

            if not minX then

                minX, minY, maxX, maxY = sx, sy, sx, sy

            else

                if sx < minX then minX = sx end

                if sy < minY then minY = sy end

                if sx > maxX then maxX = sx end

                if sy > maxY then maxY = sy end

            end

        end

    end

    if not minX then

        return nil

    end

    return minX, minY, maxX - minX + 1, maxY - minY + 1, z

end

function IKST_Claim.isIndoorsAt(x, y, z)

    local square = IKST_Grid.getSquare(math.floor(tonumber(x) or 0), math.floor(tonumber(y) or 0), tonumber(z) or 0)

    return IKST_Claim.squareHasBuilding(square)

end

function IKST_Claim.resolveClaimMode(x, y, z, requestedMode)

    if not IKST_Claim.isIndoorsAt(x, y, z) then

        return IKST_Claim.MODE.square

    end

    if requestedMode == IKST_Claim.MODE.building then

        return IKST_Claim.MODE.building

    end

    return IKST_Claim.MODE.square

end

function IKST_Claim.safehousePreviewRect(x, y, z, size, claimMode, w, h)

    x = math.floor(tonumber(x) or 0)

    y = math.floor(tonumber(y) or 0)

    z = tonumber(z) or 0

    local square = IKST_Grid.getSquare(x, y, z)

    local indoors = IKST_Claim.squareHasBuilding(square)

    claimMode = IKST_Claim.resolveClaimMode(x, y, z, claimMode)

    if indoors and claimMode == IKST_Claim.MODE.building then

        local bx, by, bw, bh, bz = IKST_Claim.buildingBoundsFromSquare(square)

        if bx then

            return bx, by, bw, bh, bz, true, IKST_Claim.MODE.building

        end

    end

    local rw, rh = IKST_Claim.resolveDimensions(size, w, h)

    local cx, cy, pw, ph = IKST_Claim.claimBoundsRect(x, y, rw, rh)

    return cx, cy, pw, ph, z, indoors, IKST_Claim.MODE.square

end

function IKST_Claim.formatRectLabel(x, y, w, h, kind)

    kind = kind or IKST_Claim.MODE.square

    if kind == IKST_Claim.MODE.building then

        return "building " .. tostring(w) .. "x" .. tostring(h) .. " @ " .. tostring(x) .. "," .. tostring(y)

    end

    return "square " .. tostring(w) .. "x" .. tostring(h) .. " @ " .. tostring(x) .. "," .. tostring(y)

end

function IKST_Claim.sizeRangeLabel()

    return tostring(IKST_Claim.MIN_DIM) .. "–" .. tostring(IKST_Claim.MAX_DIM)

end

-- Axis-aligned zone from two corners (player-marked A and B). Does not claim.
function IKST_Claim.rectFromCorners(x1, y1, x2, y2)
    x1 = math.floor(tonumber(x1) or 0)
    y1 = math.floor(tonumber(y1) or 0)
    x2 = math.floor(tonumber(x2) or 0)
    y2 = math.floor(tonumber(y2) or 0)
    local x = math.min(x1, x2)
    local y = math.min(y1, y2)
    local w = math.abs(x2 - x1) + 1
    local h = math.abs(y2 - y1) + 1
    return x, y, w, h
end

-- Vanilla IsoBuilding:isResidential() (B42 JavaDoc). Fail closed if the method is missing.
function IKST_Claim.isResidentialBuilding(building)
    if not building then
        return false
    end
    if type(building.isResidential) == "function" then
        return building:isResidential() == true
    end
    if type(building.getDef) == "function" then
        local def = building:getDef()
        if def and type(def.isResidential) == "function" then
            return def:isResidential() == true
        end
    end
    return false
end

function IKST_Claim.buildingAt(x, y, z)
    local square = IKST_Grid.getSquare(math.floor(tonumber(x) or 0), math.floor(tonumber(y) or 0), tonumber(z) or 0)
    if not square or type(square.getBuilding) ~= "function" then
        return nil, nil
    end
    return square:getBuilding(), square
end

function IKST_Claim.buildingDefContains(def, x, y)
    if not def or type(def.getX) ~= "function" or type(def.getY) ~= "function" then
        return false
    end
    if type(def.getX2) ~= "function" or type(def.getY2) ~= "function" then
        return false
    end
    x = math.floor(tonumber(x) or 0)
    y = math.floor(tonumber(y) or 0)
    local x1 = def:getX()
    local y1 = def:getY()
    local x2 = def:getX2()
    local y2 = def:getY2()
    local minX = math.min(x1, x2)
    local maxX = math.max(x1, x2)
    local minY = math.min(y1, y2)
    local maxY = math.max(y1, y2)
    return x >= minX and x <= maxX and y >= minY and y <= maxY
end

function IKST_Claim.rectFromBuildingDef(def, z)
    if not def or type(def.getX) ~= "function" then
        return nil
    end
    local x = def:getX()
    local y = def:getY()
    local w, h
    if type(def.getW) == "function" and type(def.getH) == "function" then
        w = def:getW()
        h = def:getH()
    elseif type(def.getX2) == "function" and type(def.getY2) == "function" then
        w = math.abs(def:getX2() - x)
        h = math.abs(def:getY2() - y)
    else
        return nil
    end
    if w < 1 then
        w = 1
    end
    if h < 1 then
        h = 1
    end
    return x, y, w, h, tonumber(z) or 0
end

-- Player land claims: same residential house. Returns ok, err, rect fields.
function IKST_Claim.playerResidentialRect(x1, y1, z1, x2, y2, z2)
    local b2, sq2 = IKST_Claim.buildingAt(x2, y2, z2)
    if not b2 or not IKST_Claim.isResidentialBuilding(b2) then
        return false, "residential buildings only"
    end
    local def = nil
    if type(b2.getDef) == "function" then
        def = b2:getDef()
    end
    local b1 = IKST_Claim.buildingAt(x1, y1, z1)
    if b1 then
        local id1, id2 = nil, nil
        if type(b1.getID) == "function" then
            id1 = b1:getID()
        end
        if type(b2.getID) == "function" then
            id2 = b2:getID()
        end
        if id1 ~= nil and id2 ~= nil and id1 ~= id2 then
            return false, "stay in the same house"
        end
        if (id1 == nil or id2 == nil) and def and not IKST_Claim.buildingDefContains(def, x1, y1) then
            return false, "stay in the same house"
        end
        if not IKST_Claim.isResidentialBuilding(b1) then
            return false, "residential buildings only"
        end
    elseif def then
        if not IKST_Claim.buildingDefContains(def, x1, y1) then
            return false, "stay in the same house"
        end
    else
        return false, "stay in the same house"
    end
    local x, y, w, h, z
    if def then
        x, y, w, h, z = IKST_Claim.rectFromBuildingDef(def, z2)
    end
    if not x and sq2 then
        x, y, w, h, z = IKST_Claim.buildingBoundsFromSquare(sq2)
    end
    if not x then
        return false, "residential buildings only"
    end
    return true, nil, x, y, w, h, z
end
