if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Grid"
require "IKST_Chrome"

IKST_PreviewOverlay = IKST_PreviewOverlay or {}
IKST_PreviewOverlay.batchSquares = {}
IKST_PreviewOverlay._batchHighlightedSquares = {}
IKST_PreviewOverlay._batchHighlightedObjects = {}
IKST_PreviewOverlay._hoverKey = nil
IKST_PreviewOverlay._hoverHighlightedSquares = {}
IKST_PreviewOverlay._hoverHighlightedObjects = {}
IKST_PreviewOverlay._jobHighlightedSquares = {}
IKST_PreviewOverlay._jobHighlightedObjects = {}

local PREVIEW_COLORS = {
    accent = "accent",
    claim = "accent",
    protect = "accentDim",
    warn = "danger",
}

local function previewRGBA(colorKey, alpha)
    local name = PREVIEW_COLORS[colorKey] or "accent"
    local c = IKST_Chrome.colors[name] or IKST_Chrome.colors.accent
    return c.r, c.g, c.b, alpha or 0.55
end

local function squareColor()
    local c = IKST_Chrome.colors.accent
    return c.r, c.g, c.b, 0.55
end

local function objectColor()
    local c = IKST_Chrome.colors.danger
    return c.r, c.g, c.b, 0.90
end

local function applySquareHighlight(sq, r, g, b, a)
    if not sq then
        return false
    end
    local floor = sq.getFloor and sq:getFloor()
    if not floor or not floor.setHighlighted then
        return false
    end
    floor:setHighlighted(true)
    if floor.setHighlightColor then
        floor:setHighlightColor(r, g, b, a)
    end
    return true
end

local function applyObjectHighlight(obj, r, g, b, a)
    if not obj or not obj.setHighlighted then
        return false
    end
    obj:setHighlighted(true)
    if obj.setHighlightColor then
        obj:setHighlightColor(r, g, b, a)
    end
    return true
end

local function clearSquareList(list)
    if not list then
        return
    end
    for _, entry in ipairs(list) do
        if entry and entry.setHighlighted then
            entry:setHighlighted(false)
        end
    end
end

local function clearObjectList(list)
    if not list then
        return
    end
    for _, obj in ipairs(list) do
        if obj and obj.setHighlighted then
            obj:setHighlighted(false)
        end
    end
end

local function isRemovableObject(obj, floor)
    if not obj then
        return false
    end
    if floor and obj == floor then
        return false
    end
    if instanceof(obj, "IsoPlayer") then
        return false
    end
    if instanceof(obj, "IsoDeadBody") then
        return false
    end
    if instanceof(obj, "IsoZombie") then
        return false
    end
    return true
end

local function isVegetationObject(obj, square)
    return IKST.isVegetationObject(obj, square)
end

function IKST_PreviewOverlay.findTopRemovableObject(square)
    if not square then
        return nil
    end
    local objects = square:getObjects()
    if not objects then
        return nil
    end
    local floor = square:getFloor()
    for i = objects:size() - 1, 0, -1 do
        local obj = objects:get(i)
        if IKST_Grid.isRoofObject(obj) and isRemovableObject(obj, floor) then
            return obj
        end
    end
    for i = objects:size() - 1, 0, -1 do
        local obj = objects:get(i)
        if isRemovableObject(obj, floor) and not isVegetationObject(obj, square) then
            return obj
        end
    end
    return nil
end

function IKST_PreviewOverlay.resolveCleanupTargets(square, mode)
    local targets = {}
    if not square then
        return targets
    end
    local objects = square:getObjects()
    if not objects then
        return targets
    end
    local floor = square:getFloor()

    if mode == IKST.CLEANUP_MODES.removeTile then
        if floor then
            targets[#targets + 1] = floor
        end
        if IKST_Grid.squareHasRoof(square) then
            for i = 0, objects:size() - 1 do
                local obj = objects:get(i)
                if obj ~= floor and IKST_Grid.isRoofObject(obj) then
                    targets[#targets + 1] = obj
                end
            end
        end
        return targets
    end

    if mode == IKST.CLEANUP_MODES.clearSquare then
        for i = 0, objects:size() - 1 do
            local obj = objects:get(i)
            if isRemovableObject(obj, floor) then
                targets[#targets + 1] = obj
            end
        end
        return targets
    end

    if mode == IKST.CLEANUP_MODES.vegetation then
        return IKST.collectVegetationOnSquare(square)
    end

    local top = IKST_PreviewOverlay.findTopRemovableObject(square)
    if top then
        targets[#targets + 1] = top
    end
    return targets
end

function IKST_PreviewOverlay.resolvePreviewScope(square, state, batchScope)
    local squares = {}
    local objectMode = IKST.CLEANUP_MODES.removeObject
    if not square or not state then
        return squares, objectMode
    end

    local action = IKST.getCleanupAction(state)
    local scope = IKST.getCleanupScope(state)
    local radius = state.cleanupRadius or IKST.RADIUS_PRESETS.M
    local cubeHalf = state.cleanupCubeHalf or IKST.CUBE_PRESETS.M
    local cx, cy, cz = square:getX(), square:getY(), square:getZ()

    if scope == IKST.CLEANUP_SCOPES.room then
        squares = IKST_Grid.squaresInRoomFromSquare(square)
    elseif scope == IKST.CLEANUP_SCOPES.building then
        squares = IKST_Grid.squaresInBuildingFromSquare(square)
    elseif scope == IKST.CLEANUP_SCOPES.radius then
        squares = IKST_Grid.squaresInRadius(cx, cy, cz, radius)
    elseif scope == IKST.CLEANUP_SCOPES.cube then
        squares = IKST_Grid.squaresInCube(cx, cy, cz, cubeHalf)
    else
        squares = { square }
    end

    if #squares == 0 then
        squares = { square }
    end
    return squares, action
end

function IKST_PreviewOverlay.collectObjectsForSquares(squares, objectMode)
    local objects = {}
    local seen = {}
    for _, sq in ipairs(squares) do
        local targets = IKST_PreviewOverlay.resolveCleanupTargets(sq, objectMode)
        for _, obj in ipairs(targets) do
            if not seen[obj] then
                seen[obj] = true
                objects[#objects + 1] = obj
            end
        end
    end
    return objects
end

function IKST_PreviewOverlay.makePreviewKey(square, state, batchScope)
    if not square or not state then
        return ""
    end
    return square:getX() .. ":" .. square:getY() .. ":" .. square:getZ()
        .. "|" .. tostring(IKST.getCleanupAction(state))
        .. "|" .. tostring(IKST.getCleanupScope(state))
        .. "|" .. tostring(state.cleanupRadius)
        .. "|" .. tostring(state.cleanupCubeHalf)
        .. "|" .. tostring(batchScope)
end

local function applyHighlights(squares, objects, squareStore, objectStore, highlightFloors)
    clearSquareList(squareStore)
    clearObjectList(objectStore)
    squareStore = {}
    objectStore = {}

    if highlightFloors ~= false then
        local sr, sg, sb, sa = squareColor()
        for _, sq in ipairs(squares) do
            local floor = sq and sq.getFloor and sq:getFloor()
            if floor and applySquareHighlight(sq, sr, sg, sb, sa) then
                squareStore[#squareStore + 1] = floor
            end
        end
    end

    local or_, og, ob, oa = objectColor()
    for _, obj in ipairs(objects) do
        if applyObjectHighlight(obj, or_, og, ob, oa) then
            objectStore[#objectStore + 1] = obj
        end
    end
    return squareStore, objectStore
end

local function clearHoverHighlights()
    clearSquareList(IKST_PreviewOverlay._hoverHighlightedSquares)
    clearObjectList(IKST_PreviewOverlay._hoverHighlightedObjects)
    IKST_PreviewOverlay._hoverHighlightedSquares = {}
    IKST_PreviewOverlay._hoverHighlightedObjects = {}
end

local function clearBatchHighlights()
    clearSquareList(IKST_PreviewOverlay._batchHighlightedSquares)
    clearObjectList(IKST_PreviewOverlay._batchHighlightedObjects)
    IKST_PreviewOverlay._batchHighlightedSquares = {}
    IKST_PreviewOverlay._batchHighlightedObjects = {}
end

local function clearJobHighlights()
    clearSquareList(IKST_PreviewOverlay._jobHighlightedSquares)
    clearObjectList(IKST_PreviewOverlay._jobHighlightedObjects)
    IKST_PreviewOverlay._jobHighlightedSquares = {}
    IKST_PreviewOverlay._jobHighlightedObjects = {}
end

function IKST_PreviewOverlay.findVehicleById(vehicleId)
    if vehicleId == nil then
        return nil
    end
    local id = tonumber(vehicleId) or vehicleId
    if getVehicleById then
        local v = getVehicleById(id)
        if v then
            return v
        end
    end
    if VehicleManager and VehicleManager.instance and VehicleManager.instance.getVehicleByID then
        return VehicleManager.instance:getVehicleByID(id)
    end
    return nil
end

function IKST_PreviewOverlay.rectPerimeterSquares(x, y, w, h, z)
    local squares = {}
    local seen = {}
    x = math.floor(tonumber(x) or 0)
    y = math.floor(tonumber(y) or 0)
    w = math.floor(tonumber(w) or 1)
    h = math.floor(tonumber(h) or 1)
    z = tonumber(z) or 0
    if w < 1 then
        w = 1
    end
    if h < 1 then
        h = 1
    end
    local function add(sq)
        if sq and not seen[sq] then
            seen[sq] = true
            squares[#squares + 1] = sq
        end
    end
    for dx = 0, w - 1 do
        add(IKST_Grid.getSquare(x + dx, y, z))
        if h > 1 then
            add(IKST_Grid.getSquare(x + dx, y + h - 1, z))
        end
    end
    for dy = 1, h - 2 do
        add(IKST_Grid.getSquare(x, y + dy, z))
        add(IKST_Grid.getSquare(x + w - 1, y + dy, z))
    end
    return squares
end

function IKST_PreviewOverlay.clearJob()
    clearJobHighlights()
end

function IKST_PreviewOverlay.clearBatch()
    clearBatchHighlights()
    IKST_PreviewOverlay.batchSquares = {}
end

function IKST_PreviewOverlay.highlightSquareFloors(squares, colorKey, alpha, store)
    store = store or IKST_PreviewOverlay._jobHighlightedSquares
    local r, g, b, a = previewRGBA(colorKey, alpha)
    for _, sq in ipairs(squares) do
        local floor = sq and sq.getFloor and sq:getFloor()
        if floor and applySquareHighlight(sq, r, g, b, a) then
            store[#store + 1] = floor
        end
    end
end

function IKST_PreviewOverlay.setJobSquare(square, colorKey)
    IKST_PreviewOverlay.clearJob()
    if not square then
        return
    end
    IKST_PreviewOverlay.highlightSquareFloors({ square }, colorKey, 0.70)
end

function IKST_PreviewOverlay.setJobRectBorder(x, y, w, h, z, colorKey)
    IKST_PreviewOverlay.clearJob()
    local squares = IKST_PreviewOverlay.rectPerimeterSquares(x, y, w, h, z)
    IKST_PreviewOverlay.highlightSquareFloors(squares, colorKey or "claim", 0.65)
end

function IKST_PreviewOverlay.setJobRects(rects)
    IKST_PreviewOverlay.clearJob()
    if not rects then
        return
    end
    for _, rect in ipairs(rects) do
        if rect and rect.x and rect.y and rect.w and rect.h then
            local squares = IKST_PreviewOverlay.rectPerimeterSquares(rect.x, rect.y, rect.w, rect.h, rect.z or 0)
            IKST_PreviewOverlay.highlightSquareFloors(squares, rect.color or "claim", 0.65, IKST_PreviewOverlay._jobHighlightedSquares)
        end
    end
end

function IKST_PreviewOverlay.setJobRadius(cx, cy, cz, radius, colorKey)
    IKST_PreviewOverlay.clearJob()
    radius = IKST.clampRadius(radius)
    cx = math.floor(tonumber(cx) or 0)
    cy = math.floor(tonumber(cy) or 0)
    cz = tonumber(cz) or 0
    local squares = IKST_Grid.squaresInRadius(cx, cy, cz, radius)
    IKST_PreviewOverlay.highlightSquareFloors(squares, colorKey or "protect", 0.40)
end

function IKST_PreviewOverlay.setJobVehicle(vehicleId, colorKey)
    IKST_PreviewOverlay.clearJob()
    local v = IKST_PreviewOverlay.findVehicleById(vehicleId)
    if not v then
        return
    end
    local r, g, b, a = previewRGBA(colorKey or "claim", 0.85)
    if v.setHighlighted then
        if applyObjectHighlight(v, r, g, b, a) then
            IKST_PreviewOverlay._jobHighlightedObjects[#IKST_PreviewOverlay._jobHighlightedObjects + 1] = v
        end
    end
    local vx = math.floor(v:getX())
    local vy = math.floor(v:getY())
    local vz = v.getZ and v:getZ() or 0
    local squares = {}
    local seen = {}
    for dx = -1, 1 do
        for dy = -1, 1 do
            local sq = IKST_Grid.getSquare(vx + dx, vy + dy, vz)
            if sq and not seen[sq] then
                seen[sq] = true
                squares[#squares + 1] = sq
            end
        end
    end
    IKST_PreviewOverlay.highlightSquareFloors(squares, colorKey or "claim", 0.50, IKST_PreviewOverlay._jobHighlightedSquares)
end

function IKST_PreviewOverlay.setLootJobPreview(preview)
    IKST_PreviewOverlay.clearJob()
    if not preview or preview.count == 0 then
        return
    end
    if preview.squares and #preview.squares > 0 then
        IKST_PreviewOverlay.highlightSquareFloors(preview.squares, "accent", 0.42)
    end
    if type(preview.containers) ~= "table" then
        return
    end
    local r, g, b, a = previewRGBA("accent", 0.88)
    for _, container in ipairs(preview.containers) do
        local parent = container and container.getParent and container:getParent()
        if parent and applyObjectHighlight(parent, r, g, b, a) then
            IKST_PreviewOverlay._jobHighlightedObjects[#IKST_PreviewOverlay._jobHighlightedObjects + 1] = parent
        end
    end
end

function IKST_PreviewOverlay.clearHover()
    clearHoverHighlights()
    IKST_PreviewOverlay._hoverKey = nil
end

function IKST_PreviewOverlay.setCleanupPreview(square, state, batchScope)
    local key = IKST_PreviewOverlay.makePreviewKey(square, state, batchScope)
    if key == IKST_PreviewOverlay._hoverKey then
        return
    end
    IKST_PreviewOverlay._hoverKey = key

    local squares, objectMode = IKST_PreviewOverlay.resolvePreviewScope(square, state, batchScope)
    local objects = IKST_PreviewOverlay.collectObjectsForSquares(squares, objectMode)
    local highlightFloors = objectMode ~= IKST.CLEANUP_MODES.removeObject
    IKST_PreviewOverlay._hoverHighlightedSquares, IKST_PreviewOverlay._hoverHighlightedObjects =
        applyHighlights(squares, objects, {}, {}, highlightFloors)
end

function IKST_PreviewOverlay.setBatchPreview(square, state, batchScope)
    IKST_PreviewOverlay.clearHover()
    local squares, objectMode = IKST_PreviewOverlay.resolvePreviewScope(square, state, batchScope)
    local objects = IKST_PreviewOverlay.collectObjectsForSquares(squares, objectMode)
    local highlightFloors = objectMode ~= IKST.CLEANUP_MODES.removeObject
    IKST_PreviewOverlay.batchSquares = squares
    IKST_PreviewOverlay._batchHighlightedSquares, IKST_PreviewOverlay._batchHighlightedObjects =
        applyHighlights(squares, objects, {}, {}, highlightFloors)
end

function IKST_PreviewOverlay.setSquares(squares)
    clearBatchHighlights()
    IKST_PreviewOverlay.batchSquares = squares or {}
    local sr, sg, sb, sa = squareColor()
    for _, sq in ipairs(IKST_PreviewOverlay.batchSquares) do
        local floor = sq and sq.getFloor and sq:getFloor()
        if floor and applySquareHighlight(sq, sr, sg, sb, sa) then
            IKST_PreviewOverlay._batchHighlightedSquares[#IKST_PreviewOverlay._batchHighlightedSquares + 1] = floor
        end
    end
end

function IKST_PreviewOverlay.setFromRadius(cx, cy, cz, radius)
    IKST_PreviewOverlay.setJobRadius(cx, cy, cz, radius, "protect")
end

function IKST_PreviewOverlay.clear()
    IKST_PreviewOverlay.clearHover()
    IKST_PreviewOverlay.clearBatch()
    IKST_PreviewOverlay.clearJob()
end

local function refreshHighlights()
    local sr, sg, sb, sa = squareColor()
    local or_, og, ob, oa = objectColor()

    for _, floor in ipairs(IKST_PreviewOverlay._batchHighlightedSquares) do
        if floor and floor.setHighlighted then
            floor:setHighlighted(true)
            if floor.setHighlightColor then
                floor:setHighlightColor(sr, sg, sb, sa)
            end
        end
    end
    for _, obj in ipairs(IKST_PreviewOverlay._batchHighlightedObjects) do
        applyObjectHighlight(obj, or_, og, ob, oa)
    end
    for _, floor in ipairs(IKST_PreviewOverlay._hoverHighlightedSquares) do
        if floor and floor.setHighlighted then
            floor:setHighlighted(true)
            if floor.setHighlightColor then
                floor:setHighlightColor(sr, sg, sb, sa)
            end
        end
    end
    for _, obj in ipairs(IKST_PreviewOverlay._hoverHighlightedObjects) do
        applyObjectHighlight(obj, or_, og, ob, oa)
    end

    for _, floor in ipairs(IKST_PreviewOverlay._jobHighlightedSquares) do
        if floor and floor.setHighlighted then
            local jr, jg, jb = previewRGBA("accent", 0.55)
            floor:setHighlighted(true)
            if floor.setHighlightColor then
                floor:setHighlightColor(jr, jg, jb, 0.55)
            end
        end
    end
    for _, obj in ipairs(IKST_PreviewOverlay._jobHighlightedObjects) do
        local jr, jg, jb, ja = previewRGBA("claim", 0.85)
        applyObjectHighlight(obj, jr, jg, jb, ja)
    end
end

local function onRenderTick()
    if #IKST_PreviewOverlay._batchHighlightedSquares == 0
        and #IKST_PreviewOverlay._batchHighlightedObjects == 0
        and #IKST_PreviewOverlay._hoverHighlightedSquares == 0
        and #IKST_PreviewOverlay._hoverHighlightedObjects == 0
        and #IKST_PreviewOverlay._jobHighlightedSquares == 0
        and #IKST_PreviewOverlay._jobHighlightedObjects == 0 then
        return
    end
    refreshHighlights()
end

if Events and Events.OnRenderTick then
    Events.OnRenderTick.Add(onRenderTick)
end
