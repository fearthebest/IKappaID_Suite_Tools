-- Vehicle spawn / clear-spot helpers (split from IKST_VehicleOps).
if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end

require "IKST_Shared"
require "IKST_Catalog"
require "IKST_Grid"
require "IKST_VehicleUtil"

IKST_VehicleOps = IKST_VehicleOps or {}

function IKST_VehicleOps.normalizeScriptName(name)
    return IKST_Catalog.normalizeFullId(name, "Base")
end

function IKST_VehicleOps.scriptExists(scriptName)
    return IKST_Catalog.vehicleScriptExists(scriptName)
end

local DAMAGE_SUFFIXES = {
    "SmashedRear",
    "SmashedFront",
    "SmashedLeft",
    "SmashedRight",
    "Smashed",
    "Burnt",
    "Wreck",
    "Trap",
}

function IKST_VehicleOps.resolveSpawnScript(scriptName, repaired)
    scriptName = IKST_VehicleOps.normalizeScriptName(scriptName)
    if not scriptName or repaired ~= true then
        return scriptName
    end
    local base = scriptName
    for _, suffix in ipairs(DAMAGE_SUFFIXES) do
        if #base > #suffix and string.sub(base, -#suffix) == suffix then
            base = string.sub(base, 1, -(#suffix + 1))
            break
        end
    end
    if IKST_VehicleOps.scriptExists(base) then
        return base
    end
    return scriptName
end

function IKST_VehicleOps.getSpawnSquare(x, y, z)
    if not getCell then
        return nil
    end
    local cell = getCell()
    if not cell or not cell.getGridSquare then
        return nil
    end
    return cell:getGridSquare(math.floor(tonumber(x) or 0), math.floor(tonumber(y) or 0), tonumber(z) or 0)
end

function IKST_VehicleOps.squareHasVehicle(square, ignoreVehicleId)
    if not square or not square.getMovingObjects then
        return false
    end
    local moving = square:getMovingObjects()
    if not moving or type(moving.size) ~= "function" then
        return false
    end
    for i = 0, moving:size() - 1 do
        local obj = moving:get(i)
        if obj and instanceof and instanceof(obj, "BaseVehicle") then
            if ignoreVehicleId == nil then
                return true
            end
            local vid = type(obj.getId) == "function" and obj:getId()
            if vid == nil or tonumber(vid) ~= tonumber(ignoreVehicleId) then
                return true
            end
        end
    end
    return false
end

function IKST_VehicleOps.lookupVehicleScript(scriptName)
    if not scriptName or scriptName == "" then
        return nil
    end
    if getVehicleScript then
        return getVehicleScript(scriptName)
    end
    local sm = getScriptManager and getScriptManager()
    if sm and sm.getVehicleScript then
        return sm:getVehicleScript(scriptName)
    end
    return nil
end

function IKST_VehicleOps.vehicleScriptName(vehicle)
    if not vehicle or not vehicle.getScriptName then
        return nil
    end
    return vehicle:getScriptName()
end

function IKST_VehicleOps.squareSupportsVehicle(square)
    if not square then
        return false
    end
    if square.isSolidFloor and not square:isSolidFloor() then
        return false
    end
    if square.getFloor and not square:getFloor() then
        return false
    end
    return true
end

function IKST_VehicleOps.footprintHalfTiles(scriptName)
    local halfW = 1
    local halfL = 2
    local script = IKST_VehicleOps.lookupVehicleScript(scriptName)
    if script and script.getExtents then
        local ext = script:getExtents()
        if ext and ext.x and ext.z then
            halfW = math.max(1, math.ceil(math.abs(ext.x) / 2))
            halfL = math.max(1, math.ceil(math.abs(ext.z) / 2))
        end
    end
    return halfW, halfL
end

function IKST_VehicleOps.isRelocateDestinationClear(scriptName, x, y, z, ignoreVehicleId)
    x = math.floor(tonumber(x) or 0)
    y = math.floor(tonumber(y) or 0)
    z = tonumber(z) or 0
    local halfW, halfL = IKST_VehicleOps.footprintHalfTiles(scriptName)
    for dx = -halfW, halfW do
        for dy = -halfL, halfL do
            local square = IKST_VehicleOps.getSpawnSquare(x + dx, y + dy, z)
            if not square then
                return false, "footprint blocked"
            end
            if not IKST_VehicleOps.squareSupportsVehicle(square) then
                return false, "no floor"
            end
            if IKST_VehicleOps.squareHasVehicle(square, ignoreVehicleId) then
                return false, "tile blocked"
            end
        end
    end
    return true, nil
end

-- Walk outward rings for a clear footprint (does not delete blockers — finds free ground).
-- When playerObj is set, skip candidates that fail vehicle policy (protect / claim gates).
function IKST_VehicleOps.findClearSpawnAt(scriptName, cx, cy, cz, ignoreVehicleId, maxRing, playerObj)
    cx = math.floor(tonumber(cx) or 0)
    cy = math.floor(tonumber(cy) or 0)
    cz = tonumber(cz) or 0
    maxRing = tonumber(maxRing) or 6
    if maxRing < 0 then
        maxRing = 0
    end
    if maxRing > 12 then
        maxRing = 12
    end
    local function candidateOk(tx, ty, tz)
        if not IKST_VehicleOps.isRelocateDestinationClear(scriptName, tx, ty, tz, ignoreVehicleId) then
            return false
        end
        if playerObj then
            local blocked = IKST_VehicleOps.vehiclePolicyBlocked(playerObj, tx, ty, tz)
            if blocked then
                return false
            end
        end
        return true
    end
    if candidateOk(cx, cy, cz) then
        return cx, cy, cz, nil
    end
    for ring = 1, maxRing do
        for dx = -ring, ring do
            for dy = -ring, ring do
                if math.abs(dx) == ring or math.abs(dy) == ring then
                    local tx, ty = cx + dx, cy + dy
                    if candidateOk(tx, ty, cz) then
                        return tx, ty, cz, nil
                    end
                end
            end
        end
    end
    return nil, nil, nil, "no clear spawn nearby"
end

function IKST_VehicleOps.createVehicleAt(scriptName, x, y, z, skinIndex, dir)
    x = math.floor(tonumber(x) or 0)
    y = math.floor(tonumber(y) or 0)
    z = tonumber(z) or 0
    local square = IKST_VehicleOps.getSpawnSquare(x, y, z)
    local vehicle = nil
    -- addVehicle (LuaManager global) tends to work better in tight indoor tiles.
    if addVehicle then
        vehicle = addVehicle(scriptName, x + 0.5, y + 0.5, z)
    end
    if not vehicle and addVehicleDebug and square and dir then
        vehicle = addVehicleDebug(scriptName, dir, skinIndex, square)
    end
    return vehicle
end

function IKST_VehicleOps.verifyLiveVehicle(vehicle, x, y, z)
    if not vehicle then
        return false, "spawn failed", nil, nil
    end
    local id = type(vehicle.getId) == "function" and vehicle:getId() or nil
    if id == nil then
        return false, "no id", nil, nil
    end
    local live = vehicle
    if getVehicleById then
        live = getVehicleById(id)
        if not live then
            return false, "not registered", nil, id
        end
    end
    if x ~= nil and y ~= nil and live.getX and live.getY then
        local tol = 5
        local expectX = math.floor(tonumber(x) or 0) + 0.5
        local expectY = math.floor(tonumber(y) or 0) + 0.5
        if math.abs(live:getX() - expectX) > tol or math.abs(live:getY() - expectY) > tol then
            return false, "spawn misplaced", live, id
        end
    end
    return true, nil, live, id
end

function IKST_VehicleOps.isSpawnSquareFree(square, ignoreVehicleId)
    if not square then
        return false, "no square"
    end
    if IKST_VehicleOps.squareHasVehicle(square, ignoreVehicleId) then
        return false, "tile blocked"
    end
    return true, nil
end

function IKST_VehicleOps.removeVehicleFromWorld(vehicle)
    if not vehicle then
        return false
    end
    if type(vehicle.permanentlyRemove) == "function" then
        vehicle:permanentlyRemove()
        return true
    end
    if removeVehicle then
        removeVehicle(nil, vehicle)
        return true
    end
    if type(vehicle.removeFromWorld) == "function" then
        vehicle:removeFromWorld()
    end
    if type(vehicle.removeFromSquare) == "function" then
        vehicle:removeFromSquare()
    end
    return true
end

function IKST_VehicleOps.spawnDirection(playerObj)
    if playerObj and playerObj.getDir then
        local dir = playerObj:getDir()
        if dir then
            return dir
        end
    end
    if IsoDirections then
        return IsoDirections.S
    end
    return nil
end

function IKST_VehicleOps.fullyRepair(vehicle)
    if not vehicle then
        return
    end
    if type(vehicle.repair) == "function" then
        vehicle:repair()
    end
    if vehicle.getPartCount and vehicle.getPartByIndex then
        local count = vehicle:getPartCount()
        for i = 0, count - 1 do
            local part = vehicle:getPartByIndex(i)
            if part and part.repair then
                part:repair()
            end
        end
    end
end

function IKST_VehicleOps.spawn(scriptName, x, y, z, angle, repaired, withKey, playerObj)
    if not IKST_VehicleOps.mayMutateVehicle() then
        return nil, "server only"
    end
    local blocked, reason = IKST_VehicleOps.vehiclePolicyBlocked(playerObj, x, y, z)
    if blocked then
        return nil, reason or "square protected"
    end
    local script = IKST_VehicleOps.resolveSpawnScript(scriptName, repaired)
    if not script or not IKST_VehicleOps.scriptExists(script) then
        return nil, "invalid script"
    end
    local sx, sy, sz, clearMsg = IKST_VehicleOps.findClearSpawnAt(script, x, y, z, nil, 6, playerObj)
    if not sx then
        return nil, clearMsg or "invalid spot"
    end
    -- Re-check final coords (ring search must not land past protect/claim gates).
    blocked, reason = IKST_VehicleOps.vehiclePolicyBlocked(playerObj, sx, sy, sz)
    if blocked then
        return nil, reason or "square protected"
    end
    x, y, z = sx, sy, sz
    local vehicle = nil
    local dir = IKST_VehicleOps.spawnDirection(playerObj)
    vehicle = IKST_VehicleOps.createVehicleAt(script, x, y, z, -1, dir)
    if not vehicle then
        return nil, "spawn failed"
    end
    if angle and vehicle.setAngles then
        vehicle:setAngles(0, angle, 0)
    end
    if repaired then
        IKST_VehicleOps.fullyRepair(vehicle)
    end
    if withKey then
        IKST_VehicleOps.giveVehicleKey(vehicle, playerObj)
    end
    return vehicle, "spawned", x, y, z
end
