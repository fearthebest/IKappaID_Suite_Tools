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
require "IKST_CommandQueue"
require "IKST_VehicleOps_Spawn"

IKST_VehicleOps = IKST_VehicleOps or {}

IKST_VehicleOps.forEachVehicle = IKST_VehicleUtil.forEachVehicle
IKST_VehicleOps.getVehiclesFromCell = IKST_VehicleUtil.getVehiclesFromCell
IKST_VehicleOps.getVehicle = IKST_VehicleUtil.getVehicle
IKST_VehicleOps.listNearby = IKST_VehicleUtil.listNearby
IKST_VehicleOps.nearestId = IKST_VehicleUtil.nearestId

function IKST_VehicleOps.mayMutateVehicle()
    return IKST.mayMutateWorldState and IKST.mayMutateWorldState()
end

function IKST_VehicleOps.vehiclePolicyBlocked(player, x, y, z)
    if not player then
        return false, nil
    end
    if not IKST_Policy then
        require "IKST_Policy"
    end
    local allowed, reason = IKST_Policy.locationAllowedAtCoord(player, x, y, z, "vehicles")
    if allowed == true then
        return false, nil
    end
    return true, reason or "square protected"
end

function IKST_VehicleOps.vehiclePolicyBlockedForVehicle(player, vehicle)
    if not vehicle or type(vehicle.getX) ~= "function" or type(vehicle.getY) ~= "function" then
        return false, nil
    end
    local vz = 0
    if type(vehicle.getZ) == "function" then
        vz = vehicle:getZ() or 0
    end
    return IKST_VehicleOps.vehiclePolicyBlocked(player, vehicle:getX(), vehicle:getY(), vz)
end

function IKST_VehicleOps.adminVehicleNearOk(player, vehicleId, opts)
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
    local vz = type(v.getZ) == "function" and v:getZ() or 0
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
    if type(v.shutOff) == "function" then
        v:shutOff()
    end
    local maxSeats = 8
    if type(v.getMaxPassengers) == "function" then
        local seatCount = v:getMaxPassengers()
        if seatCount and seatCount > 0 then
            maxSeats = seatCount
        end
    end
    for seat = 0, maxSeats - 1 do
        local chr = nil
        if type(v.getCharacter) == "function" then
            chr = v:getCharacter(seat)
        end
        if chr and v.exit then
            local exitSeat = seat
            if type(v.getSeat) == "function" then
                local resolved = v:getSeat(chr)
                if resolved ~= nil then
                    exitSeat = resolved
                end
            end
            v:exit(chr)
            if type(v.setCharacterPosition) == "function" then
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
    if type(v.getVehicleEngineQuality) == "function" then
        return v:getVehicleEngineQuality() or 100
    end
    return 100
end

function IKST_VehicleOps.transmitVehicle(v)
    if not v then
        return
    end
    if not IKST.runsOnServerJvm or not IKST.runsOnServerJvm() then
        return
    end
    if type(v.updatePhysicsNetwork) == "function" then
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
    if type(v.getAngleY) == "function" then
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
    oldVehicleId = tonumber(oldVehicleId)
    newVehicleId = tonumber(newVehicleId)
    if oldVehicleId ~= nil and newVehicleId ~= nil and oldVehicleId == newVehicleId then
        IKST_VehicleOps.syncVehicleToClients(newVehicleId, { relocated = true })
        return
    end
    if oldVehicleId ~= nil then
        IKST_VehicleOps.syncVehicleToClients(oldVehicleId, { deleted = true, relocated = true })
    end
    if newVehicleId ~= nil then
        IKST_VehicleOps.syncVehicleToClients(newVehicleId, { relocated = true })
    end
end

function IKST_VehicleOps.validateRelocateDestination(vehicle, x, y, z)
    local ignoreId = nil
    if vehicle and vehicle.getId and vehicle.getX and vehicle.getY then
        local vx = math.floor(vehicle:getX())
        local vy = math.floor(vehicle:getY())
        local vz = vehicle:getZ() or 0
        if vx == math.floor(tonumber(x) or 0) and vy == math.floor(tonumber(y) or 0) and vz == (tonumber(z) or vz) then
            ignoreId = vehicle:getId()
        end
    end
    local scriptName = IKST_VehicleOps.vehicleScriptName(vehicle)
    return IKST_VehicleOps.isRelocateDestinationClear(scriptName, x, y, z, ignoreId)
end

function IKST_VehicleOps.spawnFromSnapshot(snap, x, y, z, angle, playerObj, ignoreVehicleId)
    if type(snap) ~= "table" or not snap.scriptName or snap.scriptName == "" then
        return nil, "invalid snapshot"
    end
    if not IKST_VehicleOps.scriptExists(snap.scriptName) then
        return nil, "invalid script"
    end
    local scriptName = snap.scriptName
    local clearOk, clearMsg = IKST_VehicleOps.isRelocateDestinationClear(scriptName, x, y, z, ignoreVehicleId)
    if not clearOk then
        return nil, clearMsg or "invalid spot"
    end
    local skinIndex = snap.skinIndex
    if skinIndex == nil or skinIndex < 0 then
        skinIndex = -1
    end
    local dir = IKST_VehicleOps.spawnDirection(playerObj)
    local vehicle = IKST_VehicleOps.createVehicleAt(scriptName, x, y, z, skinIndex, dir)
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
    local liveOk, liveMsg, liveVehicle, liveId = IKST_VehicleOps.verifyLiveVehicle(vehicle, x, y, z)
    if not liveOk then
        IKST_VehicleOps.removeVehicleFromWorld(vehicle)
        return nil, liveMsg or "spawn invalid"
    end
    return liveVehicle or vehicle, "spawned", liveId
end

function IKST_VehicleOps.relocate(vehicleId, x, y, z, angle, playerObj)
    if not IKST_VehicleOps.mayMutateVehicle() then
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
    local blocked, reason = IKST_VehicleOps.vehiclePolicyBlockedForVehicle(playerObj, vehicle)
    if blocked then
        return false, reason or "square protected", nil
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
    blocked, reason = IKST_VehicleOps.vehiclePolicyBlocked(playerObj, x, y, z)
    if blocked then
        return false, reason or "square protected", nil
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
        angle = type(vehicle.getAngleY) == "function" and vehicle:getAngleY() or nil,
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
            return false, "respawn failed (restored at origin)", nil
        end
        return false, (spawnMsg or "respawn failed") .. " — stored backup kept", nil
    end
    local newId = type(newVehicle.getId) == "function" and newVehicle:getId() or nil
    if newId == nil then
        IKST_VehicleOps.removeVehicleFromWorld(newVehicle)
        local restored = IKST_VehicleRelocateBackup.restoreAtOrigin(oldId, playerObj)
        if restored then
            return false, "respawn missing id (restored at origin)", nil
        end
        return false, "respawn missing id — stored backup kept", nil
    end
    if IKST_VehicleClaim and IKST_VehicleClaim.remapVehicleId then
        IKST_VehicleClaim.remapVehicleId(oldId, newId, { x = x, y = y, z = z })
    end
    IKST_VehicleRelocateBackup.clear(oldId)
    local resultMsg = "relocated"
    if newVehicle and newVehicle.getModData then
        local md = newVehicle:getModData()
        if md and md.IKST_relocateKeysInvalid then
            resultMsg = "relocated_keys_invalid"
            md.IKST_relocateKeysInvalid = nil
        end
    end
    return true, resultMsg, newVehicle, oldId, newId
end

function IKST_VehicleOps.move(vehicleId, x, y, z, angle, playerObj)
    local ok, msg, newVehicle, oldId, newId = IKST_VehicleOps.relocate(vehicleId, x, y, z, angle, playerObj)
    if not ok then
        return false, msg
    end
    return true, msg, newVehicle, oldId, newId
end

function IKST_VehicleOps.delete(vehicleId, player)
    if not IKST_VehicleOps.mayMutateVehicle() then
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
    local blocked, reason = IKST_VehicleOps.vehiclePolicyBlockedForVehicle(player, v)
    if blocked then
        return false, reason or "square protected"
    end
    IKST_VehicleOps.ejectOccupants(v)
    if type(v.permanentlyRemove) == "function" then
        v:permanentlyRemove()
    elseif removeVehicle then
        removeVehicle(nil, v)
    elseif type(v.removeFromWorld) == "function" then
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
    if type(v.breakConstraint) == "function" then
        v:breakConstraint(true, false)
    end
    if type(v.getVehicleTowedBy) == "function" then
        local by = v:getVehicleTowedBy()
        if by and by.breakConstraint then
            by:breakConstraint(true, false)
        end
    end
end

function IKST_VehicleOps.flip(vehicleId, player)
    if not IKST_VehicleOps.mayMutateVehicle() then
        return false, "server only"
    end
    local v = IKST_VehicleOps.getVehicle(vehicleId)
    if not v then
        return false, "vehicle not found"
    end
    local blocked, reason = IKST_VehicleOps.vehiclePolicyBlockedForVehicle(player, v)
    if blocked then
        return false, reason or "square protected"
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
    local vz = type(v.getZ) == "function" and v:getZ() or 0
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
    local ok, msg = IKST_VehicleOps.flip(vehicleId, player)
    if ok then
        IKST_VehicleOps.syncVehicleToClients(vehicleId, { flipped = true })
    end
    return ok, msg
end

function IKST_VehicleOps.repair(vehicleId, player)
    local v = IKST_VehicleOps.getVehicle(vehicleId)
    if not v then
        return false, "vehicle not found"
    end
    local blocked, reason = IKST_VehicleOps.vehiclePolicyBlockedForVehicle(player, v)
    if blocked then
        return false, reason or "square protected"
    end
    IKST_VehicleOps.fullyRepair(v)
    return true, "repaired"
end

function IKST_VehicleOps.refuel(vehicleId, player)
    local v = IKST_VehicleOps.getVehicle(vehicleId)
    if not v then
        return false, "vehicle not found"
    end
    local blocked, reason = IKST_VehicleOps.vehiclePolicyBlockedForVehicle(player, v)
    if blocked then
        return false, reason or "square protected"
    end
    local part = nil
    if type(v.getGasTank) == "function" then
        part = v:getGasTank()
    end
    if not part and type(v.getPartById) == "function" then
        part = v:getPartById("GasTank")
    end
    if not part then
        return false, "no gas tank"
    end
    local cap = nil
    if type(part.getContainerCapacity) == "function" then
        cap = part:getContainerCapacity()
    end
    if not cap or cap < 1 then
        return false, "no capacity"
    end
    if type(part.setContainerContentAmount) ~= "function" then
        return false, "cannot set fuel"
    end
    part:setContainerContentAmount(cap)
    if type(v.transmitPartItem) == "function" then
        v:transmitPartItem(part)
    end
    IKST_VehicleOps.transmitVehicle(v)
    return true, "refueled"
end

function IKST_VehicleOps.refuelNearest(player)
    local v = IKST_VehicleOps.resolveNearVehicle(player)
    if not v then
        return false, "no vehicle"
    end
    local vehicleId = nil
    if type(v.getId) == "function" then
        vehicleId = v:getId()
    end
    if vehicleId == nil then
        return false, "no vehicle id"
    end
    return IKST_VehicleOps.refuel(vehicleId, player)
end

function IKST_VehicleOps.resolveNearVehicle(player, radius)
    if not player then
        return nil
    end
    radius = tonumber(radius) or IKST.getVehicleNearRadius()
    local inVehicle = type(player.getVehicle) == "function" and player:getVehicle()
    if inVehicle then
        return inVehicle
    end
    local near = type(player.getNearVehicle) == "function" and player:getNearVehicle()
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
    if type(v.createVehicleKey) == "function" then
        key = v:createVehicleKey()
    end
    if key and player and player.getInventory then
        local inv = player:getInventory()
        if inv and type(inv.AddItem) == "function" and inv:AddItem(key) then
            if key.syncKeyId and v.getKeyId then
                key:syncKeyId(v:getKeyId())
            end
            if sendAddItemToContainer then
                sendAddItemToContainer(inv, key)
            end
            if inv.setDrawDirty then
                inv:setDrawDirty(true)
            end
            return true
        end
    end
    if type(v.addKeyToGloveBox) == "function" then
        v:addKeyToGloveBox()
        if v.getPartById and v.transmitPartItem then
            local part = v:getPartById("GloveBox")
            if part then
                v:transmitPartItem(part)
            end
        end
        return true
    end
    if type(v.createKeyInGloveBox) == "function" then
        v:createKeyInGloveBox()
        if v.getPartById and v.transmitPartItem then
            local part = v:getPartById("GloveBox")
            if part then
                v:transmitPartItem(part)
            end
        end
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

function IKST_VehicleOps.deleteCell(cellX, cellY, player)
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
            local vid = type(v.getId) == "function" and v:getId()
            if IKST_TileProtect and IKST_TileProtect.isVehicleProtected(vid) then
                return
            end
            if IKST_VehicleClaim and IKST_VehicleClaim.get(vid) then
                return
            end
            local blocked = IKST_VehicleOps.vehiclePolicyBlockedForVehicle(player, v)
            if blocked then
                return
            end
            toRemove[#toRemove + 1] = v
        end
    end)
    for _, v in ipairs(toRemove) do
        local vid = type(v.getId) == "function" and v:getId()
        if IKST_TileProtect and IKST_TileProtect.isVehicleProtected(vid) then
            -- skip
        else
            IKST_VehicleOps.ejectOccupants(v)
            if removeVehicle then
                removeVehicle(nil, v)
                removed = removed + 1
            elseif type(v.removeFromWorld) == "function" then
                v:removeFromWorld()
                removed = removed + 1
            end
        end
    end
    return removed
end

local function mapCellXY(x, y)
    return math.floor((tonumber(x) or 0) / 300), math.floor((tonumber(y) or 0) / 300)
end

local function vehicleInPruneArea(v, x, y, radius, cellX, cellY)
    if not v or type(v.getX) ~= "function" or type(v.getY) ~= "function" then
        return false
    end
    if cellX ~= nil and cellY ~= nil then
        local cx, cy = mapCellXY(v:getX(), v:getY())
        return cx == cellX and cy == cellY
    end
    return IKST.distance2d(x, y, v:getX(), v:getY()) <= (tonumber(radius) or 0)
end

function IKST_VehicleOps.prune(x, y, z, radius, conditionPct, burntOnly, player, cellX, cellY)
    local removed = 0
    local skipped = 0
    local vehicles = IKST_VehicleOps.getVehiclesFromCell()
    if not vehicles then
        return removed, skipped
    end
    local toRemove = {}
    IKST_VehicleOps.forEachVehicle(vehicles, function(v)
        if not vehicleInPruneArea(v, x, y, radius, cellX, cellY) then
            return
        end
        local vid = v:getId()
        if IKST_TileProtect and IKST_TileProtect.isVehicleProtected(vid) then
            skipped = skipped + 1
            return
        end
        if IKST_VehicleClaim and IKST_VehicleClaim.get(vid) then
            skipped = skipped + 1
            return
        end
        local blocked = IKST_VehicleOps.vehiclePolicyBlockedForVehicle(player, v)
        if blocked then
            skipped = skipped + 1
            return
        end
        local script = nil
        if type(v.getScript) == "function" then
            script = v:getScript()
        end
        local name = ""
        if script and type(script.getName) == "function" then
            name = script:getName() or ""
        end
        if burntOnly and not string.find(string.lower(name), "burnt") and not string.find(string.lower(name), "wreck") then
            skipped = skipped + 1
            return
        end
        local cond = IKST_VehicleOps.vehicleConditionPct(v)
        if cond <= conditionPct then
            toRemove[#toRemove + 1] = v
        else
            skipped = skipped + 1
        end
    end)
    for _, v in ipairs(toRemove) do
        IKST_VehicleOps.ejectOccupants(v)
        if removeVehicle then
            removeVehicle(nil, v)
        elseif type(v.removeFromWorld) == "function" then
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
    local blocked, reason = IKST_VehicleOps.vehiclePolicyBlockedForVehicle(player, v)
    if blocked then
        return false, reason or "square protected"
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
    if type(v.updateSkin) == "function" then
        v:updateSkin()
    end
    if type(v.transmitSkinIndex) == "function" then
        v:transmitSkinIndex()
    end
    return true, "skin " .. tostring(idx + 1) .. "/" .. tostring(count)
end

function IKST_VehicleOps.unlockTrunk(player, vehicleId)
    local v = IKST_VehicleOps.vehicleByIdOrNear(player, vehicleId)
    if not v then
        return false, "no vehicle"
    end
    if type(v.setTrunkLocked) == "function" then
        v:setTrunkLocked(false)
        return true, "trunk unlocked"
    end
    if type(v.getPartById) == "function" then
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
            if part and type(part.getDoor) == "function" and part:getDoor() then
                v:toggleLockedDoor(part, player, false)
                if type(v.transmitPartDoor) == "function" then
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
    if type(v.haveOneDoorUnlocked) == "function" and v:haveOneDoorUnlocked() then
        return true, "door already open"
    end
    return false, "no doors unlocked"
end

function IKST_VehicleOps.sendList(player, list)
    IKST.deliverClientCommand(player, IKST.CMD.vehicleListResult, { vehicles = list })
end

function IKST_VehicleOps.handle(command, player, args)
    args = args or {}
    if command == IKST.CMD.vehicleList then
        local x = IKST_Args.readCoord(args, "x") or math.floor(player:getX())
        local y = IKST_Args.readCoord(args, "y") or math.floor(player:getY())
        local z = IKST_Args.readCoord(args, "z") or player:getZ()
        local radius = tonumber(args.radius) or IKST.getVehicleListRadius()
        IKST_VehicleOps.sendList(player, IKST_VehicleOps.listNearby(x, y, z, radius))
        return true, "listed"
    end
    if command == IKST.CMD.vehicleRelocateBackupList then
        if not IKST_VehicleOps.mayMutateVehicle() then
            return false, "server only"
        end
        local backups = {}
        if IKST_VehicleRelocateBackup and IKST_VehicleRelocateBackup.listEntries then
            backups = IKST_VehicleRelocateBackup.listEntries()
        end
        if IKST.deliverClientCommand then
            IKST.deliverClientCommand(player, IKST.CMD.vehicleRelocateBackupListResult, { backups = backups })
        end
        return true, #backups .. " stored"
    end
    if command == IKST.CMD.vehicleRelocateRestore then
        if not IKST_VehicleOps.mayMutateVehicle() then
            return false, "server only"
        end
        local backupId = args.backupId or args.vehicleId
        if backupId == nil then
            return false, "select a backup"
        end
        local mode = args.restoreMode or "origin"
        local rx = IKST_Args.readCoord(args, "x")
        local ry = IKST_Args.readCoord(args, "y")
        local rz = IKST_Args.readCoord(args, "z")
        if mode == "here" then
            rx = rx or math.floor(player:getX())
            ry = ry or math.floor(player:getY())
            rz = rz or player:getZ()
        end
        if not IKST_VehicleRelocateBackup or not IKST_VehicleRelocateBackup.restore then
            return false, "backup unavailable"
        end
        local ok, msg, newId = IKST_VehicleRelocateBackup.restore(
            backupId, mode, player, rx, ry, rz, args.angle)
        if ok and newId then
            args.newVehicleId = newId
            args.vehicleId = newId
        end
        return ok, msg
    end
    if command == IKST.CMD.vehicleSpawn then
        if not IKST_VehicleOps.mayMutateVehicle() then
            return false, "server only"
        end
        local x = IKST_Args.readCoord(args, "x") or math.floor(player:getX())
        local y = IKST_Args.readCoord(args, "y") or math.floor(player:getY())
        local z = IKST_Args.readCoord(args, "z") or player:getZ()
        if IKST.runsOnServerJvm and IKST.runsOnServerJvm() then
            if not (IKST_Access and IKST_Access.staffRemoteAdmin and IKST_Access.staffRemoteAdmin()) then
                if not IKST_Args or type(IKST_Args.actorNearCoord) ~= "function"
                    or not IKST_Args.actorNearCoord(player, x, y, z, IKST.getVehicleListRadius()) then
                    return false, "too far"
                end
            end
        end
        local _, msg, sx, sy, sz = IKST_VehicleOps.spawn(args.script, x, y, z, args.angle, args.repaired, args.withKey, player)
        if msg == "spawned" then
            if sx then
                args.x, args.y, args.z = sx, sy, sz
            end
            if IKST_StaffHistory and type(IKST_StaffHistory.record) == "function" then
                IKST_StaffHistory.record(player, "spawn", tostring(args.script or "?")
                    .. " @" .. tostring(args.x) .. "," .. tostring(args.y), true)
            end
        end
        return msg == "spawned", msg
    end
    if command == IKST.CMD.vehicleMove then
        if not IKST_VehicleOps.mayMutateVehicle() then
            return false, "server only"
        end
        if not args.vehicleId then
            return false, "select a vehicle"
        end
        local tx = IKST_Args.readCoord(args, "x")
        local ty = IKST_Args.readCoord(args, "y")
        local tz = IKST_Args.readCoord(args, "z")
        if not IKST_VehicleOps.adminVehicleNearOk(player, args.vehicleId, {
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
            args.newVehicleId = newId
            args.vehicleId = newId
        end
        return ok, msg
    end
    if command == IKST.CMD.vehicleDelete then
        if not IKST_VehicleOps.mayMutateVehicle() then
            return false, "server only"
        end
        if not IKST_VehicleOps.adminVehicleNearOk(player, args.vehicleId, { listRadius = true }) then
            return false, "too far from vehicle"
        end
        local ok, msg = IKST_VehicleOps.delete(args.vehicleId, player)
        if ok then
            IKST_VehicleOps.syncVehicleToClients(args.vehicleId, { deleted = true })
        end
        return ok, msg
    end
    if command == IKST.CMD.vehicleDeleteCell then
        if not IKST_VehicleOps.mayMutateVehicle() then
            return false, "server only"
        end
        local cellX = IKST_Args.readCoord(args, "cellX")
        local cellY = IKST_Args.readCoord(args, "cellY")
        if cellX == nil or cellY == nil then
            return false, "bad coords"
        end
        local centerX = cellX * 300 + 150
        local centerY = cellY * 300 + 150
        local z = player and player:getZ() or 0
        if not IKST_Args.requireNearOrRemoteAdmin(player, centerX, centerY, z, 80) then
            return false, "too far"
        end
        local vehicles = IKST_VehicleOps.getVehiclesFromCell()
        local toRemove = {}
        if vehicles then
            IKST_VehicleOps.forEachVehicle(vehicles, function(v)
                local cx = math.floor(v:getX() / 300)
                local cy = math.floor(v:getY() / 300)
                if cx == cellX and cy == cellY then
                    local vid = type(v.getId) == "function" and v:getId()
                    if IKST_TileProtect and IKST_TileProtect.isVehicleProtected(vid) then
                        return
                    end
                    if IKST_VehicleClaim and IKST_VehicleClaim.get(vid) then
                        return
                    end
                    if IKST_VehicleOps.vehiclePolicyBlockedForVehicle(player, v) then
                        return
                    end
                    toRemove[#toRemove + 1] = v
                end
            end)
        end
        if #toRemove == 0 then
            return true, "removed 0"
        end
        if #toRemove <= (IKST_CommandQueue and IKST_CommandQueue.OPS_PER_TICK or 8) then
            local n = 0
            for _, v in ipairs(toRemove) do
                IKST_VehicleOps.ejectOccupants(v)
                if removeVehicle then
                    removeVehicle(nil, v)
                    n = n + 1
                elseif type(v.removeFromWorld) == "function" then
                    v:removeFromWorld()
                    n = n + 1
                end
            end
            return true, "removed " .. n
        end
        args._deferResult = true
        local removed = { n = 0 }
        IKST.enqueueWorldOp(player, "vehicle delete cell", toRemove, function(v)
            IKST_VehicleOps.ejectOccupants(v)
            if removeVehicle then
                removeVehicle(nil, v)
                removed.n = removed.n + 1
                return true, "ok"
            elseif type(v.removeFromWorld) == "function" then
                v:removeFromWorld()
                removed.n = removed.n + 1
                return true, "ok"
            end
            return false, "remove failed"
        end, function()
            if IKST_WorldOps and IKST_WorldOps.sendResult then
                IKST_WorldOps.sendResult(player, true, "removed " .. removed.n, args.x, args.y, args.z, command)
            end
        end)
        return true, "queued"
    end
    if command == IKST.CMD.vehicleFlip then
        if not IKST_VehicleOps.mayMutateVehicle() then
            return false, "server only"
        end
        if not IKST_VehicleOps.adminVehicleNearOk(player, args.vehicleId, { listRadius = true }) then
            return false, "too far from vehicle"
        end
        local ok, msg = IKST_VehicleOps.flip(args.vehicleId, player)
        if ok then
            IKST_VehicleOps.syncVehicleToClients(args.vehicleId, { flipped = true })
        end
        return ok, msg
    end
    if command == IKST.CMD.vehicleRepair then
        if not IKST_VehicleOps.mayMutateVehicle() then
            return false, "server only"
        end
        if not IKST_VehicleOps.adminVehicleNearOk(player, args.vehicleId, { listRadius = true }) then
            return false, "too far from vehicle"
        end
        return IKST_VehicleOps.repair(args.vehicleId, player)
    end
    if command == IKST.CMD.vehicleRefuel then
        if not IKST_VehicleOps.mayMutateVehicle() then
            return false, "server only"
        end
        if not IKST_VehicleOps.adminVehicleNearOk(player, args.vehicleId, { listRadius = true }) then
            return false, "too far from vehicle"
        end
        return IKST_VehicleOps.refuel(args.vehicleId, player)
    end
    if command == IKST.CMD.vehicleKey then
        if not IKST_VehicleOps.mayMutateVehicle() then
            return false, "server only"
        end
        if not IKST_VehicleOps.adminVehicleNearOk(player, args.vehicleId, { listRadius = true }) then
            return false, "too far from vehicle"
        end
        return IKST_VehicleOps.addKey(args.vehicleId, player)
    end
    if command == IKST.CMD.vehiclePrune then
        if not IKST_VehicleOps.mayMutateVehicle() then
            return false, "server only"
        end
        local cellScope = IKST_Args.readBool(args.cell) == true
        local x = math.floor(player:getX())
        local y = math.floor(player:getY())
        local z = player:getZ() or 0
        if not cellScope then
            x = IKST_Args.readCoord(args, "x") or x
            y = IKST_Args.readCoord(args, "y") or y
            z = IKST_Args.readCoord(args, "z") or z
        end
        local radius = IKST.clampRadius(args.radius)
        local cellX, cellY
        if cellScope then
            cellX, cellY = mapCellXY(x, y)
            local centerX = cellX * 300 + 150
            local centerY = cellY * 300 + 150
            if not IKST_Args.requireNearOrRemoteAdmin(player, centerX, centerY, z, 80) then
                return false, "too far"
            end
        else
            if not IKST_Args.requireNearOrRemoteAdmin(player, x, y, z, radius + 4) then
                return false, "too far"
            end
        end
        local conditionPct = tonumber(args.conditionPct) or 40
        if conditionPct < 0 then
            conditionPct = 0
        elseif conditionPct > 100 then
            conditionPct = 100
        end
        local burntOnly = IKST_Args.readBool(args.burntOnly) == true
        local vehicles = IKST_VehicleOps.getVehiclesFromCell()
        local toRemove = {}
        local skipped = 0
        if vehicles then
            IKST_VehicleOps.forEachVehicle(vehicles, function(v)
                if not vehicleInPruneArea(v, x, y, radius, cellX, cellY) then
                    return
                end
                local vid = v:getId()
                if IKST_TileProtect and IKST_TileProtect.isVehicleProtected(vid) then
                    skipped = skipped + 1
                    return
                end
                if IKST_VehicleClaim and IKST_VehicleClaim.get(vid) then
                    skipped = skipped + 1
                    return
                end
                if IKST_VehicleOps.vehiclePolicyBlockedForVehicle(player, v) then
                    skipped = skipped + 1
                    return
                end
                local script = nil
                if type(v.getScript) == "function" then
                    script = v:getScript()
                end
                local name = ""
                if script and type(script.getName) == "function" then
                    name = script:getName() or ""
                end
                if burntOnly and not string.find(string.lower(name), "burnt") and not string.find(string.lower(name), "wreck") then
                    skipped = skipped + 1
                    return
                end
                local cond = IKST_VehicleOps.vehicleConditionPct(v)
                if cond <= conditionPct then
                    toRemove[#toRemove + 1] = v
                else
                    skipped = skipped + 1
                end
            end)
        end
        if #toRemove == 0 then
            return true, "pruned 0, skipped " .. skipped
        end
        if #toRemove <= (IKST_CommandQueue and IKST_CommandQueue.OPS_PER_TICK or 8) then
            local removed, skip2 = IKST_VehicleOps.prune(x, y, z, radius, conditionPct, burntOnly, player, cellX, cellY)
            return true, "pruned " .. removed .. ", skipped " .. skip2
        end
        args._deferResult = true
        local removed = { n = 0 }
        local skipCount = skipped
        IKST.enqueueWorldOp(player, "vehicle prune", toRemove, function(v)
            IKST_VehicleOps.ejectOccupants(v)
            if removeVehicle then
                removeVehicle(nil, v)
            elseif type(v.removeFromWorld) == "function" then
                v:removeFromWorld()
            else
                return false, "remove failed"
            end
            removed.n = removed.n + 1
            return true, "ok"
        end, function()
            if IKST_WorldOps and IKST_WorldOps.sendResult then
                IKST_WorldOps.sendResult(player, true,
                    "pruned " .. removed.n .. ", skipped " .. skipCount,
                    x, y, z, command)
            end
        end)
        return true, "queued"
    end
    if command == IKST.CMD.vehicleRepairNear then
        if not IKST_VehicleOps.mayMutateVehicle() then
            return false, "server only"
        end
        return IKST_VehicleOps.repairNearest(player)
    end
    if command == IKST.CMD.vehicleRefuelNear then
        if not IKST_VehicleOps.mayMutateVehicle() then
            return false, "server only"
        end
        return IKST_VehicleOps.refuelNearest(player)
    end
    if command == IKST.CMD.vehicleKeyNear then
        if not IKST_VehicleOps.mayMutateVehicle() then
            return false, "server only"
        end
        return IKST_VehicleOps.keyNearest(player)
    end
    if command == IKST.CMD.vehicleSkinNext then
        if not IKST_VehicleOps.mayMutateVehicle() then
            return false, "server only"
        end
        if not IKST_VehicleOps.adminVehicleNearOk(player, args.vehicleId, { listRadius = true }) then
            return false, "too far"
        end
        return IKST_VehicleOps.skinStep(player, args.vehicleId, 1)
    end
    if command == IKST.CMD.vehicleSkinPrev then
        if not IKST_VehicleOps.mayMutateVehicle() then
            return false, "server only"
        end
        if not IKST_VehicleOps.adminVehicleNearOk(player, args.vehicleId, { listRadius = true }) then
            return false, "too far"
        end
        return IKST_VehicleOps.skinStep(player, args.vehicleId, -1)
    end
    if command == IKST.CMD.vehicleUnlockTrunk then
        if not IKST_VehicleOps.mayMutateVehicle() then
            return false, "server only"
        end
        if not IKST_VehicleOps.adminVehicleNearOk(player, args.vehicleId, { listRadius = true }) then
            return false, "too far"
        end
        return IKST_VehicleOps.unlockTrunk(player, args.vehicleId)
    end
    if command == IKST.CMD.vehicleUnlockDoors then
        if not IKST_VehicleOps.mayMutateVehicle() then
            return false, "server only"
        end
        if not IKST_VehicleOps.adminVehicleNearOk(player, args.vehicleId, { listRadius = true }) then
            return false, "too far"
        end
        return IKST_VehicleOps.unlockDoors(player, args.vehicleId)
    end
    if command == IKST.CMD.vehicleFieldRecovery then
        return IKST_VehicleOps.fieldRecovery(player, args.vehicleId)
    end
    return false, "unknown vehicle command"
end
