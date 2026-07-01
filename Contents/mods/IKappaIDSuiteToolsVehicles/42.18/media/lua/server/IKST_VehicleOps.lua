if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end
require "IKST_Shared"
require "IKST_Utility"
require "IKST_Grid"
require "IKST_TileProtect"
require "IKST_VehicleClaim"
require "IKST_Catalog"
require "IKST_VehicleUtil"
require "IKST_Access"
require "IKST_Args"
require "IKST_VehicleSnapshot"
require "IKST_VehicleRelocateBackup"

IKST_VehicleOps = IKST_VehicleOps or {}

IKST_VehicleOps.forEachVehicle = IKST_VehicleUtil.forEachVehicle
IKST_VehicleOps.getVehiclesFromCell = IKST_VehicleUtil.getVehiclesFromCell
IKST_VehicleOps.getVehicle = IKST_VehicleUtil.getVehicle
IKST_VehicleOps.listNearby = IKST_VehicleUtil.listNearby
IKST_VehicleOps.nearestId = IKST_VehicleUtil.nearestId

local function mayMutateVehicle()
    return IKST.mayMutateWorldState and IKST.mayMutateWorldState()
end

local function adminVehicleNearOk(player, vehicleId, opts)
    opts = opts or {}
    if not player then
        return false
    end
    if not IKST.runsOnServerJvm or not IKST.runsOnServerJvm() then
        return true
    end
    if IKST_Access and IKST_Access.staffRemoteAdmin and IKST_Access.staffRemoteAdmin() then
        return true
    end
    if not IKST_Args then
        require "IKST_Args"
    end
    if not IKST_Access then
        require "IKST_Access"
    end
    local v = IKST_VehicleOps.getVehicle(vehicleId)
    if not v then
        return false
    end
    local vz = v.getZ and v:getZ() or 0
    local nearR = opts.listRadius and IKST.getVehicleListRadius() or IKST.getVehicleNearRadius()
    if not IKST_Args.actorNearCoord(player, v:getX(), v:getY(), vz, nearR) then
        return false
    end
    if opts.targetX ~= nil and opts.targetY ~= nil and opts.checkTarget ~= false then
        if not IKST_Args.actorNearCoord(player, opts.targetX, opts.targetY, opts.targetZ or vz, nearR) then
            return false
        end
    end
    return true
end

function IKST_VehicleOps.ejectOccupants(v)
    if not v then
        return
    end
    if v.shutOff then
        v:shutOff()
    end
    local maxSeats = 8
    if v.getMaxPassengers then
        local seatCount = v:getMaxPassengers()
        if seatCount and seatCount > 0 then
            maxSeats = seatCount
        end
    end
    for seat = 0, maxSeats - 1 do
        local chr = nil
        if v.getCharacter then
            chr = v:getCharacter(seat)
        end
        if chr and v.exit then
            local exitSeat = seat
            if v.getSeat then
                local resolved = v:getSeat(chr)
                if resolved ~= nil then
                    exitSeat = resolved
                end
            end
            v:exit(chr)
            if v.setCharacterPosition then
                v:setCharacterPosition(chr, exitSeat, "outside")
            end
        end
    end
    if not IKST_Debug then
        require "IKST_Debug"
    end
    if IKST_Debug and IKST_Debug.logEffect and v.getId then
        IKST_Debug.logEffect("vehicle", "eject", "vid=" .. tostring(v:getId()), nil)
    end
end

function IKST_VehicleOps.vehicleConditionPct(v)
    if not v then
        return 100
    end
    if v.getPartCount and v.getPartByIndex then
        local count = v:getPartCount()
        if count and count > 0 then
            local total = 0
            local parts = 0
            for i = 0, count - 1 do
                local part = v:getPartByIndex(i)
                if part and part.getCondition then
                    total = total + (part:getCondition() or 0)
                    parts = parts + 1
                end
            end
            if parts > 0 then
                return total / parts
            end
        end
    end
    if v.getVehicleEngineQuality then
        return v:getVehicleEngineQuality() or 100
    end
    return 100
end

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
            local vid = obj.getId and obj:getId()
            if vid == nil or tonumber(vid) ~= tonumber(ignoreVehicleId) then
                return true
            end
        end
    end
    return false
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
    if vehicle.permanentlyRemove then
        vehicle:permanentlyRemove()
        return true
    end
    if removeVehicle then
        removeVehicle(nil, vehicle)
        return true
    end
    if vehicle.removeFromWorld then
        vehicle:removeFromWorld()
    end
    if vehicle.removeFromSquare then
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
    if vehicle.repair then
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
    if not mayMutateVehicle() then
        return nil, "server only"
    end
    local script = IKST_VehicleOps.resolveSpawnScript(scriptName, repaired)
    if not script or not IKST_VehicleOps.scriptExists(script) then
        return nil, "invalid script"
    end
    local square = IKST_VehicleOps.getSpawnSquare(x, y, z)
    local vehicle = nil
    local dir = IKST_VehicleOps.spawnDirection(playerObj)
    if addVehicleDebug and square and dir then
        vehicle = addVehicleDebug(script, dir, -1, square)
    end
    if not vehicle and addVehicle then
        vehicle = addVehicle(script, x, y, z)
    end
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
    return vehicle, "spawned"
end

function IKST_VehicleOps.transmitVehicle(v)
    if not v then
        return
    end
    if not IKST.runsOnServerJvm or not IKST.runsOnServerJvm() then
        return
    end
    if v.updatePhysicsNetwork then
        v:updatePhysicsNetwork()
    end
end

function IKST_VehicleOps.buildVehicleSyncPayload(vehicleId, extra)
    local v = IKST_VehicleOps.getVehicle(vehicleId)
    if not v then
        return nil
    end
    local payload = {
        vehicleId = vehicleId,
        x = v:getX(),
        y = v:getY(),
        z = v:getZ(),
    }
    if v.getAngleY then
        payload.angle = v:getAngleY()
    end
    if extra then
        for key, value in pairs(extra) do
            payload[key] = value
        end
    end
    return payload
end

function IKST_VehicleOps.syncVehicleToClients(vehicleId, extra)
    if vehicleId == nil or not IKST.deliverClientCommand then
        return
    end
    if not IKST.isMultiplayerSession or not IKST.isMultiplayerSession() then
        return
    end
    if not IKST.runsOnServerJvm or not IKST.runsOnServerJvm() then
        return
    end
    local payload = IKST_VehicleOps.buildVehicleSyncPayload(vehicleId, extra)
    if not payload then
        return
    end
    if not IKST_StaffOps then
        require "IKST_StaffOps"
    end
    if IKST_StaffOps and IKST_StaffOps.forEachOnline then
        IKST_StaffOps.forEachOnline(function(onlinePlayer)
            IKST.deliverClientCommand(onlinePlayer, IKST.CMD.applyVehicleSync, payload)
        end)
    end
    if not IKST_Debug then
        require "IKST_Debug"
    end
    if IKST_Debug and IKST_Debug.logEffect then
        local detail = "vid=" .. tostring(vehicleId)
        if payload.x then
            detail = detail .. " @" .. tostring(math.floor(payload.x)) .. "," .. tostring(math.floor(payload.y))
        end
        IKST_Debug.logEffect("vehicle", "broadcastPose", detail, nil)
    end
end

function IKST_VehicleOps.syncVehicleToClient(player, vehicleId, extra)
    IKST_VehicleOps.syncVehicleToClients(vehicleId, extra)
end

function IKST_VehicleOps.broadcastRelocate(oldVehicleId, newVehicleId)
    if oldVehicleId ~= nil then
        IKST_VehicleOps.syncVehicleToClients(oldVehicleId, { deleted = true, relocated = true })
    end
    if newVehicleId ~= nil then
        IKST_VehicleOps.syncVehicleToClients(newVehicleId, { relocated = true })
    end
end

function IKST_VehicleOps.validateRelocateDestination(vehicle, x, y, z)
    local square = IKST_VehicleOps.getSpawnSquare(x, y, z)
    if not square then
        return false, "no square"
    end
    local ignoreId = nil
    if vehicle and vehicle.getId and vehicle.getX and vehicle.getY then
        local vx = math.floor(vehicle:getX())
        local vy = math.floor(vehicle:getY())
        local vz = vehicle:getZ() or 0
        if vx == math.floor(tonumber(x) or 0) and vy == math.floor(tonumber(y) or 0) and vz == (tonumber(z) or vz) then
            ignoreId = vehicle:getId()
        end
    end
    return IKST_VehicleOps.isSpawnSquareFree(square, ignoreId)
end

function IKST_VehicleOps.spawnFromSnapshot(snap, x, y, z, angle, playerObj, ignoreVehicleId)
    if type(snap) ~= "table" or not snap.scriptName or snap.scriptName == "" then
        return nil, "invalid snapshot"
    end
    if not IKST_VehicleOps.scriptExists(snap.scriptName) then
        return nil, "invalid script"
    end
    local square = IKST_VehicleOps.getSpawnSquare(x, y, z)
    local freeOk, freeMsg = IKST_VehicleOps.isSpawnSquareFree(square, ignoreVehicleId)
    if not freeOk then
        return nil, freeMsg or "invalid spot"
    end
    local skinIndex = snap.skinIndex
    if skinIndex == nil or skinIndex < 0 then
        skinIndex = -1
    end
    local dir = IKST_VehicleOps.spawnDirection(playerObj)
    local vehicle = nil
    if addVehicleDebug and square and dir then
        vehicle = addVehicleDebug(snap.scriptName, dir, skinIndex, square)
    end
    if not vehicle and addVehicle then
        vehicle = addVehicle(snap.scriptName, x + 0.5, y + 0.5, z)
    end
    if not vehicle then
        return nil, "spawn failed"
    end
    if angle and vehicle.setAngles then
        vehicle:setAngles(0, angle, 0)
    end
    if IKST_VehicleSnapshot and IKST_VehicleSnapshot.apply then
        IKST_VehicleSnapshot.apply(vehicle, snap)
    end
    IKST_VehicleOps.transmitVehicle(vehicle)
    return vehicle, "spawned"
end

function IKST_VehicleOps.relocate(vehicleId, x, y, z, angle, playerObj)
    if not mayMutateVehicle() then
        return false, "server only", nil
    end
    if not IKST_VehicleRelocateBackup then
        require "IKST_VehicleRelocateBackup"
    end
    local oldId = tonumber(vehicleId)
    if oldId == nil then
        return false, "select a vehicle", nil
    end
    if IKST_TileProtect and IKST_TileProtect.isVehicleProtected(oldId) then
        return false, "vehicle protected", nil
    end
    local vehicle = IKST_VehicleOps.getVehicle(oldId)
    if not vehicle then
        return false, "vehicle not found", nil
    end
    x = math.floor(tonumber(x) or vehicle:getX())
    y = math.floor(tonumber(y) or vehicle:getY())
    z = tonumber(z)
    if z == nil then
        z = vehicle:getZ() or 0
    end
    local destOk, destMsg = IKST_VehicleOps.validateRelocateDestination(vehicle, x, y, z)
    if not destOk then
        return false, destMsg or "invalid spot", nil
    end
    local snap = IKST_VehicleSnapshot and IKST_VehicleSnapshot.capture(vehicle)
    if not snap or not snap.scriptName or snap.scriptName == "" then
        return false, "snapshot failed", nil
    end
    if not IKST_VehicleOps.scriptExists(snap.scriptName) then
        return false, "invalid script", nil
    end
    snap.origin = {
        vehicleId = oldId,
        x = math.floor(vehicle:getX()),
        y = math.floor(vehicle:getY()),
        z = vehicle:getZ() or 0,
        angle = vehicle.getAngleY and vehicle:getAngleY() or nil,
    }
    IKST_VehicleRelocateBackup.stash(oldId, snap, { x = x, y = y, z = z })
    IKST_VehicleOps.ejectOccupants(vehicle)
    IKST_VehicleOps.detachTrailersForFlip(vehicle)
    -- Never keep old + new in world (dupe risk). Delete only after destination validated.
    IKST_VehicleOps.removeVehicleFromWorld(vehicle)
    local newVehicle, spawnMsg = IKST_VehicleOps.spawnFromSnapshot(
        snap, x, y, z, angle, playerObj, nil)
    if not newVehicle then
        local restored = IKST_VehicleRelocateBackup.restoreAtOrigin(oldId, playerObj)
        if restored then
            return false, "respawn failed (restored)", nil
        end
        return false, spawnMsg or "respawn failed", nil
    end
    local newId = newVehicle.getId and newVehicle:getId() or nil
    if newId == nil then
        IKST_VehicleOps.removeVehicleFromWorld(newVehicle)
        local restored = IKST_VehicleRelocateBackup.restoreAtOrigin(oldId, playerObj)
        if restored then
            return false, "respawn missing id (restored)", nil
        end
        return false, "respawn missing id", nil
    end
    if IKST_VehicleClaim and IKST_VehicleClaim.remapVehicleId then
        IKST_VehicleClaim.remapVehicleId(oldId, newId, { x = x, y = y, z = z })
    end
    IKST_VehicleRelocateBackup.clear(oldId)
    return true, "relocated", newVehicle, oldId, newId
end

function IKST_VehicleOps.move(vehicleId, x, y, z, angle, playerObj)
    local ok, msg, newVehicle, oldId, newId = IKST_VehicleOps.relocate(vehicleId, x, y, z, angle, playerObj)
    if not ok then
        return false, msg
    end
    return true, msg, newVehicle, oldId, newId
end

function IKST_VehicleOps.delete(vehicleId)
    if not mayMutateVehicle() then
        return false, "server only"
    end
    if IKST_TileProtect and IKST_TileProtect.isVehicleProtected(vehicleId) then
        return false, "vehicle protected"
    end
    if IKST_VehicleClaim and IKST_VehicleClaim.get(vehicleId) then
        return false, "vehicle claimed"
    end
    local v = IKST_VehicleOps.getVehicle(vehicleId)
    if not v then
        return false, "vehicle not found"
    end
    IKST_VehicleOps.ejectOccupants(v)
    if v.permanentlyRemove then
        v:permanentlyRemove()
    elseif removeVehicle then
        removeVehicle(nil, v)
    elseif v.removeFromWorld then
        v:removeFromWorld()
    end
    return true, "deleted"
end

function IKST_VehicleOps.uprightDot(v)
    if not v or not v.getUpVectorDot then
        return 1
    end
    return v:getUpVectorDot()
end

function IKST_VehicleOps.needsFlip(v)
    return IKST_VehicleOps.uprightDot(v) < 0.5
end

function IKST_VehicleOps.flipReady(v)
    if not v then
        return false, "no vehicle"
    end
    if not IKST_VehicleOps.needsFlip(v) then
        return false, "already upright"
    end
    if v.isStopped and not v:isStopped() then
        return false, "vehicle moving"
    end
    return true, nil
end

function IKST_VehicleOps.detachTrailersForFlip(v)
    if not v then
        return
    end
    -- Vanilla VehicleCommands.detachTrailer uses breakConstraint(true, false).
    if v.breakConstraint then
        v:breakConstraint(true, false)
    end
    if v.getVehicleTowedBy then
        local by = v:getVehicleTowedBy()
        if by and by.breakConstraint then
            by:breakConstraint(true, false)
        end
    end
end

function IKST_VehicleOps.flip(vehicleId)
    if not mayMutateVehicle() then
        return false, "server only"
    end
    local v = IKST_VehicleOps.getVehicle(vehicleId)
    if not v then
        return false, "vehicle not found"
    end
    if v.isStopped and not v:isStopped() then
        return false, "vehicle moving"
    end
    local wasTipped = IKST_VehicleOps.needsFlip(v)
    local keepX = v:getX()
    local keepY = v:getY()
    local keepZ = v:getZ()
    IKST_VehicleOps.ejectOccupants(v)
    IKST_VehicleOps.detachTrailersForFlip(v)
    if not v.flipUpright then
        return false, "flip unavailable"
    end
    v:flipUpright()
    -- Vanilla flipUpright can snap the vehicle back to an old tipped cell on dedicated MP.
    if v.setX and math.abs(v:getX() - keepX) > 1.5 then
        v:setX(keepX)
    end
    if v.setY and math.abs(v:getY() - keepY) > 1.5 then
        v:setY(keepY)
    end
    if v.setZ and keepZ ~= nil and math.abs((v:getZ() or 0) - keepZ) > 0.5 then
        v:setZ(keepZ)
    end
    IKST_VehicleOps.transmitVehicle(v)
    if IKST_VehicleOps.needsFlip(v) then
        return false, "flip failed"
    end
    if wasTipped then
        return true, "flipped"
    end
    -- Server was already upright; transmit fixes MP client visual desync.
    return true, "synced upright"
end

function IKST_VehicleOps.vehiclesSandbox()
    return SandboxVars and SandboxVars.IKappaIDSuiteToolsVehicles or nil
end

function IKST_VehicleOps.fieldRecoveryEnabled()
    local sv = IKST_VehicleOps.vehiclesSandbox()
    if not sv or sv.FieldRecoveryEnabled == false then
        return false
    end
    return IKST.isModEnabled()
end

function IKST_VehicleOps.fieldRecoveryDistance()
    local sv = IKST_VehicleOps.vehiclesSandbox()
    local v = sv and sv.FieldRecoveryDistance
    v = tonumber(v) or 10
    if v < 3 then
        v = 3
    end
    if v > 20 then
        v = 20
    end
    return v
end

function IKST_VehicleOps.fieldRecovery(player, vehicleId)
    if not IKST_VehicleOps.fieldRecoveryEnabled() then
        return false, "field recovery disabled"
    end
    if not player then
        return false, "no player"
    end
    local v = IKST_VehicleOps.getVehicle(vehicleId)
    if not v then
        return false, "vehicle not found"
    end
    local maxDist = IKST_VehicleOps.fieldRecoveryDistance()
    local vz = v.getZ and v:getZ() or 0
    if not IKST_Args.actorNearCoord(player, v:getX(), v:getY(), vz, maxDist) then
        return false, "too far"
    end
    local entry = IKST_VehicleClaim.get(vehicleId)
    local username = IKST_VehicleClaim.playerUsername(player)
    local allowed = false
    if entry and not IKST_VehicleClaim.isEntryExpired(entry) then
        if IKST_VehicleClaim.isOwner(entry, username) or IKST_VehicleClaim.playerMayEdit(entry, player) then
            allowed = true
        end
    end
    if not allowed and IKST_VehicleUtil.playerHasVehicleKey(player, v) then
        allowed = true
    end
    if not allowed then
        return false, "not authorized"
    end
    local ok, msg = IKST_VehicleOps.flip(vehicleId)
    if ok then
        IKST_VehicleOps.syncVehicleToClients(vehicleId, { flipped = true })
    end
    return ok, msg
end

function IKST_VehicleOps.repair(vehicleId)
    local v = IKST_VehicleOps.getVehicle(vehicleId)
    if not v then
        return false, "vehicle not found"
    end
    IKST_VehicleOps.fullyRepair(v)
    return true, "repaired"
end

function IKST_VehicleOps.resolveNearVehicle(player, radius)
    if not player then
        return nil
    end
    radius = tonumber(radius) or IKST.getVehicleNearRadius()
    local inVehicle = player.getVehicle and player:getVehicle()
    if inVehicle then
        return inVehicle
    end
    local near = player.getNearVehicle and player:getNearVehicle()
    if near then
        return near
    end
    local x, y, z = player:getX(), player:getY(), player:getZ()
    local list = IKST_VehicleOps.listNearby(x, y, z, radius)
    if list[1] then
        return IKST_VehicleOps.getVehicle(list[1].id)
    end
    return nil
end

function IKST_VehicleOps.giveVehicleKey(v, player)
    if not v then
        return false
    end
    local key = nil
    if v.createVehicleKey then
        key = v:createVehicleKey()
    end
    if key and player and player.getInventory then
        local inv = player:getInventory()
        if inv and inv.AddItem then
            inv:AddItem(key)
            if key.syncKeyId and v.getKeyId then
                key:syncKeyId(v:getKeyId())
            end
            return true
        end
    end
    if v.addKeyToGloveBox then
        v:addKeyToGloveBox()
        return true
    end
    if v.createKeyInGloveBox then
        v:createKeyInGloveBox()
        return true
    end
    if key and v.putKeyInIgnition then
        v:putKeyInIgnition(key, 0)
        return true
    end
    return false
end

function IKST_VehicleOps.addKey(vehicleId, player)
    local v = IKST_VehicleOps.getVehicle(vehicleId)
    if not v then
        return false, "vehicle not found"
    end
    if IKST_VehicleOps.giveVehicleKey(v, player) then
        return true, "key given"
    end
    return false, "key unavailable"
end

function IKST_VehicleOps.playerFacingAngle(player)
    if not player then
        return nil
    end
    if player.getDirectionAngle then
        return player:getDirectionAngle()
    end
    if player.getForwardDirection then
        local dir = player:getForwardDirection()
        if dir and dir.getDirectionAngle then
            return dir:getDirectionAngle()
        end
    end
    return nil
end

function IKST_VehicleOps.deleteCell(cellX, cellY)
    local vehicles = IKST_VehicleOps.getVehiclesFromCell()
    local removed = 0
    if not vehicles then
        return 0
    end
    local toRemove = {}
    IKST_VehicleOps.forEachVehicle(vehicles, function(v)
        local cx = math.floor(v:getX() / 300)
        local cy = math.floor(v:getY() / 300)
        if cx == cellX and cy == cellY then
            local vid = v.getId and v:getId()
            if IKST_TileProtect and IKST_TileProtect.isVehicleProtected(vid) then
                return
            end
            if IKST_VehicleClaim and IKST_VehicleClaim.get(vid) then
                return
            end
            toRemove[#toRemove + 1] = v
        end
    end)
    for _, v in ipairs(toRemove) do
        local vid = v.getId and v:getId()
        if IKST_TileProtect and IKST_TileProtect.isVehicleProtected(vid) then
            -- skip
        else
            IKST_VehicleOps.ejectOccupants(v)
            if removeVehicle then
                removeVehicle(nil, v)
                removed = removed + 1
            elseif v.removeFromWorld then
                v:removeFromWorld()
                removed = removed + 1
            end
        end
    end
    return removed
end

function IKST_VehicleOps.prune(x, y, z, radius, conditionPct, burntOnly)
    local removed = 0
    local skipped = 0
    local vehicles = IKST_VehicleOps.getVehiclesFromCell()
    if not vehicles then
        return removed, skipped
    end
    local toRemove = {}
    IKST_VehicleOps.forEachVehicle(vehicles, function(v)
        local dist = IKST.distance2d(x, y, v:getX(), v:getY())
        if dist <= radius then
            local vid = v:getId()
            if IKST_TileProtect and IKST_TileProtect.isVehicleProtected(vid) then
                skipped = skipped + 1
                return
            end
            if IKST_VehicleClaim and IKST_VehicleClaim.get(vid) then
                skipped = skipped + 1
                return
            end
            local script = v.getScript and v:getScript()
            local name = script and script:getName() or ""
            if burntOnly and not string.find(string.lower(name), "burnt") and not string.find(string.lower(name), "wreck") then
                skipped = skipped + 1
            else
                local cond = IKST_VehicleOps.vehicleConditionPct(v)
                if cond <= conditionPct then
                    toRemove[#toRemove + 1] = v
                else
                    skipped = skipped + 1
                end
            end
        end
    end)
    for _, v in ipairs(toRemove) do
        IKST_VehicleOps.ejectOccupants(v)
        if removeVehicle then
            removeVehicle(nil, v)
        elseif v.removeFromWorld then
            v:removeFromWorld()
        end
        removed = removed + 1
    end
    return removed, skipped
end

function IKST_VehicleOps.keyNearest(player)
    if not player then
        return false, "no player"
    end
    local v = IKST_VehicleOps.resolveNearVehicle(player)
    if not v then
        return false, "stand next to a vehicle"
    end
    if IKST_VehicleOps.giveVehicleKey(v, player) then
        return true, "key in glovebox"
    end
    return false, "key unavailable"
end

function IKST_VehicleOps.repairNearest(player)
    if not player then
        return false, "no player"
    end
    local v = IKST_VehicleOps.resolveNearVehicle(player)
    if not v then
        return false, "stand next to a vehicle"
    end
    IKST_VehicleOps.fullyRepair(v)
    return true, "repaired nearest"
end

function IKST_VehicleOps.vehicleByIdOrNear(player, vehicleId)
    if vehicleId then
        return IKST_VehicleOps.getVehicle(vehicleId)
    end
    return IKST_VehicleOps.resolveNearVehicle(player)
end

function IKST_VehicleOps.skinStep(player, vehicleId, delta)
    local v = IKST_VehicleOps.vehicleByIdOrNear(player, vehicleId)
    if not v or not v.getSkinCount or not v.getSkinIndex or not v.setSkinIndex then
        return false, "no vehicle"
    end
    local count = v:getSkinCount()
    if count <= 1 then
        return false, "no extra skins"
    end
    local idx = v:getSkinIndex() + (tonumber(delta) or 1)
    while idx < 0 do
        idx = idx + count
    end
    while idx >= count do
        idx = idx - count
    end
    v:setSkinIndex(idx)
    if v.updateSkin then
        v:updateSkin()
    end
    if v.transmitSkinIndex then
        v:transmitSkinIndex()
    end
    return true, "skin " .. tostring(idx + 1) .. "/" .. tostring(count)
end

function IKST_VehicleOps.unlockTrunk(player, vehicleId)
    local v = IKST_VehicleOps.vehicleByIdOrNear(player, vehicleId)
    if not v then
        return false, "no vehicle"
    end
    if v.setTrunkLocked then
        v:setTrunkLocked(false)
        return true, "trunk unlocked"
    end
    if v.getPartById then
        local trunk = v:getPartById("TrunkDoor") or v:getPartById("Trunk")
        if trunk and trunk.setDoorLocked then
            trunk:setDoorLocked(false)
            return true, "trunk unlocked"
        end
    end
    return false, "trunk API unavailable"
end

function IKST_VehicleOps.unlockDoors(player, vehicleId)
    local v = IKST_VehicleOps.vehicleByIdOrNear(player, vehicleId)
    if not v or not player then
        return false, "no vehicle"
    end
    local unlocked = 0
    if v.getPartCount and v.getPartByIndex and v.toggleLockedDoor then
        local count = v:getPartCount()
        for i = 0, count - 1 do
            local part = v:getPartByIndex(i)
            if part and part.getDoor and part:getDoor() then
                v:toggleLockedDoor(part, player, false)
                if v.transmitPartDoor then
                    v:transmitPartDoor(part)
                end
                unlocked = unlocked + 1
            end
        end
    end
    if unlocked > 0 then
        IKST_VehicleOps.transmitVehicle(v)
        return true, unlocked .. " door(s) unlocked"
    end
    if v.haveOneDoorUnlocked and v:haveOneDoorUnlocked() then
        return true, "door already open"
    end
    return false, "no doors unlocked"
end

function IKST_VehicleOps.sendList(player, list)
    IKST.deliverClientCommand(player, IKST.CMD.vehicleListResult, { vehicles = list })
end

local function readCoord(args, key)
    if not args then
        return nil
    end
    local v = tonumber(args[key])
    if v == nil then
        return nil
    end
    return math.floor(v)
end

function IKST_VehicleOps.handle(command, player, args)
    args = args or {}
    if command == IKST.CMD.vehicleList then
        local x = readCoord(args, "x") or math.floor(player:getX())
        local y = readCoord(args, "y") or math.floor(player:getY())
        local z = readCoord(args, "z") or player:getZ()
        local radius = tonumber(args.radius) or IKST.getVehicleListRadius()
        IKST_VehicleOps.sendList(player, IKST_VehicleOps.listNearby(x, y, z, radius))
        return true, "listed"
    end
    if command == IKST.CMD.vehicleSpawn then
        local x = readCoord(args, "x") or math.floor(player:getX())
        local y = readCoord(args, "y") or math.floor(player:getY())
        local z = readCoord(args, "z") or player:getZ()
        local _, msg = IKST_VehicleOps.spawn(args.script, x, y, z, args.angle, args.repaired, args.withKey, player)
        return msg == "spawned", msg
    end
    if command == IKST.CMD.vehicleMove then
        if not mayMutateVehicle() then
            return false, "server only"
        end
        if not args.vehicleId then
            return false, "select a vehicle"
        end
        local tx = readCoord(args, "x")
        local ty = readCoord(args, "y")
        local tz = readCoord(args, "z")
        if not adminVehicleNearOk(player, args.vehicleId, {
            listRadius = true,
            targetX = tx,
            targetY = ty,
            targetZ = tz,
            checkTarget = true,
        }) then
            return false, "too far"
        end
        local ok, msg, _, oldId, newId = IKST_VehicleOps.move(
            args.vehicleId, tx, ty, tz, args.angle, player)
        if ok and oldId and newId then
            IKST_VehicleOps.broadcastRelocate(oldId, newId)
            args.relocateMeta = {
                oldVehicleId = oldId,
                newVehicleId = newId,
            }
            args.vehicleId = newId
        end
        return ok, msg
    end
    if command == IKST.CMD.vehicleDelete then
        if not mayMutateVehicle() then
            return false, "server only"
        end
        if not adminVehicleNearOk(player, args.vehicleId) then
            return false, "too far from vehicle"
        end
        local ok, msg = IKST_VehicleOps.delete(args.vehicleId)
        if ok then
            IKST_VehicleOps.syncVehicleToClients(args.vehicleId, { deleted = true })
        end
        return ok, msg
    end
    if command == IKST.CMD.vehicleDeleteCell then
        local n = IKST_VehicleOps.deleteCell(readCoord(args, "cellX"), readCoord(args, "cellY"))
        return true, "removed " .. n
    end
    if command == IKST.CMD.vehicleFlip then
        if not mayMutateVehicle() then
            return false, "server only"
        end
        if not adminVehicleNearOk(player, args.vehicleId) then
            return false, "too far from vehicle"
        end
        local ok, msg = IKST_VehicleOps.flip(args.vehicleId)
        if ok then
            IKST_VehicleOps.syncVehicleToClients(args.vehicleId, { flipped = true })
        end
        return ok, msg
    end
    if command == IKST.CMD.vehicleRepair then
        if not adminVehicleNearOk(player, args.vehicleId) then
            return false, "too far from vehicle"
        end
        return IKST_VehicleOps.repair(args.vehicleId)
    end
    if command == IKST.CMD.vehicleKey then
        if not adminVehicleNearOk(player, args.vehicleId) then
            return false, "too far from vehicle"
        end
        return IKST_VehicleOps.addKey(args.vehicleId, player)
    end
    if command == IKST.CMD.vehiclePrune then
        local x = readCoord(args, "x") or math.floor(player:getX())
        local y = readCoord(args, "y") or math.floor(player:getY())
        local z = readCoord(args, "z") or player:getZ()
        local removed, skipped = IKST_VehicleOps.prune(x, y, z, IKST.clampRadius(args.radius), tonumber(args.conditionPct) or 40, args.burntOnly)
        return true, "pruned " .. removed .. ", skipped " .. skipped
    end
    if command == IKST.CMD.vehicleRepairNear then
        return IKST_VehicleOps.repairNearest(player)
    end
    if command == IKST.CMD.vehicleKeyNear then
        return IKST_VehicleOps.keyNearest(player)
    end
    if command == IKST.CMD.vehicleSkinNext then
        if not adminVehicleNearOk(player, args.vehicleId) then
            return false, "too far"
        end
        return IKST_VehicleOps.skinStep(player, args.vehicleId, 1)
    end
    if command == IKST.CMD.vehicleSkinPrev then
        if not adminVehicleNearOk(player, args.vehicleId) then
            return false, "too far"
        end
        return IKST_VehicleOps.skinStep(player, args.vehicleId, -1)
    end
    if command == IKST.CMD.vehicleUnlockTrunk then
        if not adminVehicleNearOk(player, args.vehicleId) then
            return false, "too far"
        end
        return IKST_VehicleOps.unlockTrunk(player, args.vehicleId)
    end
    if command == IKST.CMD.vehicleUnlockDoors then
        if not adminVehicleNearOk(player, args.vehicleId) then
            return false, "too far"
        end
        return IKST_VehicleOps.unlockDoors(player, args.vehicleId)
    end
    if command == IKST.CMD.vehicleFieldRecovery then
        return IKST_VehicleOps.fieldRecovery(player, args.vehicleId)
    end
    return false, "unknown vehicle command"
end
