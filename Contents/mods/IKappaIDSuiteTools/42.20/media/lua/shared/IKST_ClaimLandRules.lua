-- Self-claim land safety rules (sandbox-tunable). Patterns only — not third-party code.
-- Applied to player self-claim; not to staff-approved claim requests (any land).

require "IKST_ClaimPolicy"

IKST_ClaimLandRules = IKST_ClaimLandRules or {}

local function floorTexName(sq)
    if not sq or type(sq.getFloor) ~= "function" then
        return nil
    end
    local floor = sq:getFloor()
    if not floor or type(floor.getTextureName) ~= "function" then
        return nil
    end
    return floor:getTextureName()
end

function IKST_ClaimLandRules.isRoadTexture(tex)
    if type(tex) ~= "string" or tex == "" then
        return false
    end
    -- Street blends used by the map for driveable roads / parking.
    if string.find(tex, "blends_street", 1, true) then
        return true
    end
    if string.find(tex, "street_traffic", 1, true) then
        return true
    end
    return false
end

function IKST_ClaimLandRules.blockRoadsEnabled()
    return IKST_ClaimPolicy.sandboxBool("ClaimSelfBlockRoads", true)
end

function IKST_ClaimLandRules.blockNearSafehouseEnabled()
    return IKST_ClaimPolicy.sandboxBool("ClaimSelfBlockNearSafehouse", true)
end

function IKST_ClaimLandRules.requireSquareEnabled()
    return IKST_ClaimPolicy.sandboxBool("ClaimSelfRequireSquare", false)
end

function IKST_ClaimLandRules.minTiles()
    return IKST_ClaimPolicy.sandboxInt("ClaimSelfMinTiles", 16, 1, 1000)
end

function IKST_ClaimLandRules.maxTiles()
    return IKST_ClaimPolicy.sandboxInt("ClaimSelfMaxTiles", 400, 10, 5000)
end

function IKST_ClaimLandRules.nearSafehouseTiles()
    return IKST_ClaimPolicy.sandboxInt("ClaimSelfNearSafehouseTiles", 8, 0, 64)
end

-- Scan claim rect (+ optional buffer) for street tiles.
function IKST_ClaimLandRules.rectHitsRoad(x, y, z, w, h)
    x = math.floor(tonumber(x) or 0)
    y = math.floor(tonumber(y) or 0)
    z = math.floor(tonumber(z) or 0)
    w = math.floor(tonumber(w) or 0)
    h = math.floor(tonumber(h) or 0)
    if w < 1 or h < 1 then
        return false
    end
    local cell = getCell and getCell() or nil
    if not cell or type(cell.getGridSquare) ~= "function" then
        return false
    end
    local x2 = x + w - 1
    local y2 = y + h - 1
    for sx = x, x2 do
        for sy = y, y2 do
            local sq = cell:getGridSquare(sx, sy, z)
            local tex = floorTexName(sq)
            if IKST_ClaimLandRules.isRoadTexture(tex) then
                return true
            end
        end
    end
    return false
end

-- True if any safehouse overlaps the rect expanded by buffer tiles.
function IKST_ClaimLandRules.rectNearOtherSafehouse(x, y, z, w, h, buffer)
    buffer = math.max(0, math.floor(tonumber(buffer) or 0))
    x = math.floor(tonumber(x) or 0) - buffer
    y = math.floor(tonumber(y) or 0) - buffer
    z = math.floor(tonumber(z) or 0)
    w = math.floor(tonumber(w) or 0) + (buffer * 2)
    h = math.floor(tonumber(h) or 0) + (buffer * 2)
    if w < 1 or h < 1 then
        return false
    end
    if not SafeHouse or type(SafeHouse.getSafeHouse) ~= "function" then
        return false
    end
    local cell = getCell and getCell() or nil
    if not cell or type(cell.getGridSquare) ~= "function" then
        return false
    end
    local x2 = x + w - 1
    local y2 = y + h - 1
    -- Sample perimeter + center (full fill is expensive on large buffers).
    local function hit(sx, sy)
        local sq = cell:getGridSquare(sx, sy, z)
        if sq and SafeHouse.getSafeHouse(sq) then
            return true
        end
        return false
    end
    if hit(x + math.floor(w / 2), y + math.floor(h / 2)) then
        return true
    end
    for sx = x, x2 do
        if hit(sx, y) or hit(sx, y2) then
            return true
        end
    end
    for sy = y + 1, y2 - 1 do
        if hit(x, sy) or hit(x2, sy) then
            return true
        end
    end
    return false
end

-- Player self-claim only. Returns ok, errKey.
function IKST_ClaimLandRules.validateSelfClaimRect(x, y, z, w, h)
    w = math.floor(tonumber(w) or 0)
    h = math.floor(tonumber(h) or 0)
    if w < 1 or h < 1 then
        return false, "invalid zone"
    end
    local tiles = w * h
    local minT = IKST_ClaimLandRules.minTiles()
    local maxT = IKST_ClaimLandRules.maxTiles()
    if maxT < minT then
        maxT = minT
    end
    if tiles < minT then
        return false, "claim too small"
    end
    if tiles > maxT then
        return false, "claim too large"
    end
    if IKST_ClaimLandRules.requireSquareEnabled() then
        local diff = math.abs(w - h)
        if diff > 2 then
            return false, "claim must be square"
        end
    end
    if IKST_ClaimLandRules.blockRoadsEnabled() then
        if IKST_ClaimLandRules.rectHitsRoad(x, y, z, w, h) then
            return false, "claim on road"
        end
    end
    if IKST_ClaimLandRules.blockNearSafehouseEnabled() then
        local buf = IKST_ClaimLandRules.nearSafehouseTiles()
        if IKST_ClaimLandRules.rectNearOtherSafehouse(x, y, z, w, h, buf) then
            return false, "too close to safehouse"
        end
    end
    return true, nil
end
