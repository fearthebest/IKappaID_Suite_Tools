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


