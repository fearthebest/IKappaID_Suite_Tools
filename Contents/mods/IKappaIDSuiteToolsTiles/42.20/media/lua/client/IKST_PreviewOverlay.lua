if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Grid"
require "IKST_Chrome"
require "ISUI/ISPanel"

IKST_PreviewOverlay = IKST_PreviewOverlay or {}
IKST_PreviewOverlay.batchSquares = {}
IKST_PreviewOverlay._batchHighlightedSquares = {}
IKST_PreviewOverlay._batchHighlightedObjects = {}
IKST_PreviewOverlay._hoverKey = nil
IKST_PreviewOverlay._hoverCacheAtMs = 0
IKST_PreviewOverlay.PREVIEW_TTL_MS = 400
IKST_PreviewOverlay.HL_EVERY_N = 5
IKST_PreviewOverlay._hlFrame = 0
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

-- JavaDoc: setHighlighted(highlight, renderOnce). renderOnce=false keeps the
-- highlight; the one-arg call is render-once and flickers every frame.
local function persistHighlight(obj, r, g, b, a)
    if not obj or type(obj.setHighlighted) ~= "function" then
        return nil
    end
    obj:setHighlighted(true, false)
    if type(obj.setHighlightColor) == "function" then
        obj:setHighlightColor(r, g, b, a)
    end
    return { obj = obj, r = r, g = g, b = b, a = a }
end

local function highlightObj(entry)
    if type(entry) == "table" and entry.obj then
        return entry.obj
    end
    return entry
end

local function clearHighlightList(list)
    if not list then
        return
    end
    for _, entry in ipairs(list) do
        local obj = highlightObj(entry)
        if obj and type(obj.setHighlighted) == "function" then
            obj:setHighlighted(false)
        end
    end
end

local function reapplyHighlightList(list, fr, fg, fb, fa)
    if not list then
        return
    end
    for _, entry in ipairs(list) do
        if type(entry) == "table" and entry.obj then
            persistHighlight(entry.obj, entry.r, entry.g, entry.b, entry.a)
        else
            persistHighlight(entry, fr, fg, fb, fa)
        end
    end
end

local function applySquareHighlight(sq, r, g, b, a)
    if not sq or type(sq.getFloor) ~= "function" then
        return nil
    end
    return persistHighlight(sq:getFloor(), r, g, b, a)
end

local function applyObjectHighlight(obj, r, g, b, a)
    return persistHighlight(obj, r, g, b, a)
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
    clearHighlightList(squareStore)
    clearHighlightList(objectStore)
    squareStore = {}
    objectStore = {}

    if highlightFloors ~= false then
        local sr, sg, sb, sa = squareColor()
        for _, sq in ipairs(squares) do
            local entry = applySquareHighlight(sq, sr, sg, sb, sa)
            if entry then
                squareStore[#squareStore + 1] = entry
            end
        end
    end

    local or_, og, ob, oa = objectColor()
    for _, obj in ipairs(objects) do
        local entry = applyObjectHighlight(obj, or_, og, ob, oa)
        if entry then
            objectStore[#objectStore + 1] = entry
        end
    end
    return squareStore, objectStore
end

local function clearHoverHighlights()
    clearHighlightList(IKST_PreviewOverlay._hoverHighlightedSquares)
    clearHighlightList(IKST_PreviewOverlay._hoverHighlightedObjects)
    IKST_PreviewOverlay._hoverHighlightedSquares = {}
    IKST_PreviewOverlay._hoverHighlightedObjects = {}
end

local function clearBatchHighlights()
    clearHighlightList(IKST_PreviewOverlay._batchHighlightedSquares)
    clearHighlightList(IKST_PreviewOverlay._batchHighlightedObjects)
    IKST_PreviewOverlay._batchHighlightedSquares = {}
    IKST_PreviewOverlay._batchHighlightedObjects = {}
end

local function clearJobHighlights()
    clearHighlightList(IKST_PreviewOverlay._jobHighlightedSquares)
    clearHighlightList(IKST_PreviewOverlay._jobHighlightedObjects)
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

IKST_PreviewOverlay._jobKey = ""

local function startJob(key)
    if key and key ~= "" and key == IKST_PreviewOverlay._jobKey then
        if #IKST_PreviewOverlay._jobHighlightedSquares > 0
            or #IKST_PreviewOverlay._jobHighlightedObjects > 0 then
            return false
        end
    end
    clearJobHighlights()
    IKST_PreviewOverlay._jobKey = key or ""
    return true
end

function IKST_PreviewOverlay.clearJob()
    clearJobHighlights()
    IKST_PreviewOverlay._jobKey = ""
end

function IKST_PreviewOverlay.clearBatch()
    clearBatchHighlights()
    IKST_PreviewOverlay.batchSquares = {}
end

function IKST_PreviewOverlay.highlightSquareFloors(squares, colorKey, alpha, store)
    store = store or IKST_PreviewOverlay._jobHighlightedSquares
    local r, g, b, a = previewRGBA(colorKey, alpha)
    for _, sq in ipairs(squares) do
        local entry = applySquareHighlight(sq, r, g, b, a)
        if entry then
            store[#store + 1] = entry
        end
    end
end

function IKST_PreviewOverlay.setJobSquare(square, colorKey)
    if not square then
        IKST_PreviewOverlay.clearJob()
        return
    end
    colorKey = colorKey or "accent"
    local zx = type(square.getX) == "function" and square:getX() or 0
    local zy = type(square.getY) == "function" and square:getY() or 0
    local zz = type(square.getZ) == "function" and square:getZ() or 0
    if not startJob("sq|" .. tostring(zx) .. "|" .. tostring(zy) .. "|" .. tostring(zz) .. "|" .. colorKey) then
        return
    end
    IKST_PreviewOverlay.highlightSquareFloors({ square }, colorKey, 0.70)
end

function IKST_PreviewOverlay.setJobRectBorder(x, y, w, h, z, colorKey)
    colorKey = colorKey or "claim"
    x = math.floor(tonumber(x) or 0)
    y = math.floor(tonumber(y) or 0)
    w = math.floor(tonumber(w) or 1)
    h = math.floor(tonumber(h) or 1)
    z = math.floor(tonumber(z) or 0)
    if not startJob("border|" .. x .. "|" .. y .. "|" .. w .. "|" .. h .. "|" .. z .. "|" .. colorKey) then
        return
    end
    local squares = IKST_PreviewOverlay.rectPerimeterSquares(x, y, w, h, z)
    IKST_PreviewOverlay.highlightSquareFloors(squares, colorKey, 0.65)
end

function IKST_PreviewOverlay.setJobRects(rects)
    if not rects then
        IKST_PreviewOverlay.clearJob()
        return
    end
    local parts = { "rects" }
    for _, rect in ipairs(rects) do
        if rect and rect.x and rect.y and rect.w and rect.h then
            parts[#parts + 1] = tostring(math.floor(rect.x)) .. "," .. tostring(math.floor(rect.y))
                .. "," .. tostring(math.floor(rect.w)) .. "," .. tostring(math.floor(rect.h))
                .. "," .. tostring(math.floor(rect.z or 0)) .. "," .. tostring(rect.color or "claim")
        end
    end
    if not startJob(table.concat(parts, "|")) then
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
    radius = IKST.clampRadius(radius)
    cx = math.floor(tonumber(cx) or 0)
    cy = math.floor(tonumber(cy) or 0)
    cz = math.floor(tonumber(cz) or 0)
    colorKey = colorKey or "protect"
    if not startJob("radius|" .. cx .. "|" .. cy .. "|" .. cz .. "|" .. radius .. "|" .. colorKey) then
        return
    end
    local squares = IKST_Grid.squaresInRadius(cx, cy, cz, radius)
    IKST_PreviewOverlay.highlightSquareFloors(squares, colorKey, 0.40)
end

function IKST_PreviewOverlay.setJobVehicle(vehicleId, colorKey)
    colorKey = colorKey or "claim"
    if not startJob("veh|" .. tostring(vehicleId) .. "|" .. colorKey) then
        return
    end
    local v = IKST_PreviewOverlay.findVehicleById(vehicleId)
    if not v then
        IKST_PreviewOverlay.clearJob()
        return
    end
    local r, g, b, a = previewRGBA(colorKey, 0.85)
    local entry = applyObjectHighlight(v, r, g, b, a)
    if entry then
        IKST_PreviewOverlay._jobHighlightedObjects[#IKST_PreviewOverlay._jobHighlightedObjects + 1] = entry
    end
    local vx = math.floor(v:getX())
    local vy = math.floor(v:getY())
    local vz = type(v.getZ) == "function" and math.floor(v:getZ() or 0) or 0
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
    IKST_PreviewOverlay.highlightSquareFloors(squares, colorKey, 0.50, IKST_PreviewOverlay._jobHighlightedSquares)
end

function IKST_PreviewOverlay.setLootJobPreview(preview, hoverSquare)
    local key = "loot|" .. tostring(preview and preview.count or 0)
    if preview and preview.squares and preview.squares[1] and type(preview.squares[1].getX) == "function" then
        key = key .. "|" .. tostring(preview.squares[1]:getX()) .. "," .. tostring(preview.squares[1]:getY())
    end
    if hoverSquare and type(hoverSquare.getX) == "function" then
        key = key .. "|h" .. tostring(hoverSquare:getX()) .. "," .. tostring(hoverSquare:getY())
    end
    if not startJob(key) then
        return
    end
    if preview and preview.count > 0 then
        if preview.squares and #preview.squares > 0 then
            IKST_PreviewOverlay.highlightSquareFloors(preview.squares, "accent", 0.42)
        end
        return
    end
    if hoverSquare then
        IKST_PreviewOverlay.highlightSquareFloors({ hoverSquare }, "warn", 0.22)
    end
end

function IKST_PreviewOverlay.setContainerTarget(obj, colorKey)
    colorKey = colorKey or "accent"
    if not obj then
        IKST_PreviewOverlay.clearJob()
        return
    end
    if not startJob("obj|" .. tostring(obj) .. "|" .. colorKey) then
        return
    end
    local r, g, b, a = previewRGBA(colorKey, 0.92)
    local entry = applyObjectHighlight(obj, r, g, b, a)
    if entry then
        IKST_PreviewOverlay._jobHighlightedObjects[#IKST_PreviewOverlay._jobHighlightedObjects + 1] = entry
    end
end

function IKST_PreviewOverlay.clearHover()
    clearHoverHighlights()
    IKST_PreviewOverlay._hoverKey = nil
    IKST_PreviewOverlay._hoverCacheAtMs = 0
end

function IKST_PreviewOverlay.invalidateHoverCache()
    IKST_PreviewOverlay._hoverKey = nil
    IKST_PreviewOverlay._hoverCacheAtMs = 0
end

function IKST_PreviewOverlay.previewNowMs()
    if getTimestampMs then
        return getTimestampMs()
    end
    if getTimeInMillis then
        return getTimeInMillis()
    end
    return 0
end

function IKST_PreviewOverlay.setCleanupPreview(square, state, batchScope)
    local key = IKST_PreviewOverlay.makePreviewKey(square, state, batchScope)
    local nowMs = IKST_PreviewOverlay.previewNowMs()
    if key == IKST_PreviewOverlay._hoverKey
        and (nowMs - (IKST_PreviewOverlay._hoverCacheAtMs or 0)) < IKST_PreviewOverlay.PREVIEW_TTL_MS then
        return
    end
    IKST_PreviewOverlay._hoverKey = key
    IKST_PreviewOverlay._hoverCacheAtMs = nowMs

    clearHoverHighlights()
    local squares = select(1, IKST_PreviewOverlay.resolvePreviewScope(square, state, batchScope))
    IKST_PreviewOverlay._hoverHighlightedSquares, IKST_PreviewOverlay._hoverHighlightedObjects =
        applyHighlights(squares, {}, {}, {}, true)
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
        local entry = applySquareHighlight(sq, sr, sg, sb, sa)
        if entry then
            IKST_PreviewOverlay._batchHighlightedSquares[#IKST_PreviewOverlay._batchHighlightedSquares + 1] = entry
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
    reapplyHighlightList(IKST_PreviewOverlay._batchHighlightedSquares, sr, sg, sb, sa)
    reapplyHighlightList(IKST_PreviewOverlay._batchHighlightedObjects, or_, og, ob, oa)
    reapplyHighlightList(IKST_PreviewOverlay._hoverHighlightedSquares, sr, sg, sb, sa)
    reapplyHighlightList(IKST_PreviewOverlay._hoverHighlightedObjects, or_, og, ob, oa)
    local jr, jg, jb, ja = previewRGBA("accent", 0.55)
    reapplyHighlightList(IKST_PreviewOverlay._jobHighlightedSquares, jr, jg, jb, ja)
    reapplyHighlightList(IKST_PreviewOverlay._jobHighlightedObjects, jr, jg, jb, 0.85)
end

local function ensureCrosshairPanel()
    if IKST_PreviewOverlay._crosshairPanel then
        return IKST_PreviewOverlay._crosshairPanel
    end
    local p = ISPanel:new(0, 0, 16, 16)
    p:initialise()
    p:instantiate()
    p.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    p.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    p.render = function(self)
        local r, g, b, a = previewRGBA("accent", 0.95)
        self:drawRect(0, 7, 16, 2, a, r, g, b)
        self:drawRect(7, 0, 2, 16, a, r, g, b)
    end
    p:addToUIManager()
    p:setVisible(false)
    IKST_PreviewOverlay._crosshairPanel = p
    return p
end

local function updateArmedCrosshair()
    local player = getPlayer and getPlayer() or nil
    local armed = false
    if player and IKST and IKST.getPlayerState then
        local state = IKST.getPlayerState(player)
        armed = state and state.armed == true
    end
    local panel = ensureCrosshairPanel()
    if not armed then
        panel:setVisible(false)
        return false
    end
    local mx = getMouseXScaled and getMouseXScaled() or (getMouseX and getMouseX() or 0)
    local my = getMouseYScaled and getMouseYScaled() or (getMouseY and getMouseY() or 0)
    panel:setX(mx - 8)
    panel:setY(my - 8)
    panel:setVisible(true)
    return true
end

local function onRenderTick()
    local armed = updateArmedCrosshair()
    if #IKST_PreviewOverlay._batchHighlightedSquares == 0
        and #IKST_PreviewOverlay._batchHighlightedObjects == 0
        and #IKST_PreviewOverlay._hoverHighlightedSquares == 0
        and #IKST_PreviewOverlay._hoverHighlightedObjects == 0
        and #IKST_PreviewOverlay._jobHighlightedSquares == 0
        and #IKST_PreviewOverlay._jobHighlightedObjects == 0 then
        if not armed then
            return
        end
        return
    end
    IKST_PreviewOverlay._hlFrame = (IKST_PreviewOverlay._hlFrame or 0) + 1
    if (IKST_PreviewOverlay._hlFrame % (IKST_PreviewOverlay.HL_EVERY_N or 5)) ~= 0 then
        return
    end
    refreshHighlights()
end

if Events and Events.OnRenderTick then
    Events.OnRenderTick.Add(onRenderTick)
end
