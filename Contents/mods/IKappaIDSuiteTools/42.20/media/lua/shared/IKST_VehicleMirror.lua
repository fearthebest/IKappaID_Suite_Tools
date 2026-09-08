-- Remote MP + listen-host client JVM: mirror server-committed vehicle pose only (IKFRVP trunk pattern).
-- Server mutates in IKST_VehicleOps; clients never move/flip/delete on their own authority.

require "IKST_Shared"

IKST_VehicleMirror = IKST_VehicleMirror or {}
IKST_VehicleMirror._lastSyncKey = IKST_VehicleMirror._lastSyncKey or {}
IKST_VehicleMirror._pinnedPose = IKST_VehicleMirror._pinnedPose or {}
IKST_VehicleMirror.PIN_SECONDS = 20

function IKST_VehicleMirror.shouldMirror()
    if IKST_Authority and IKST_Authority.usesVehicleMirrorClient then
        return IKST_Authority.usesVehicleMirrorClient()
    end
    if type(isClient) ~= "function" or not isClient() then
        return false
    end
    if IKST.isMultiplayerSession and IKST.isMultiplayerSession() then
        return IKST.isRemoteClient() or IKST.isListenHostClient()
    end
    return IKST.clientExecutesServerMirror and IKST.clientExecutesServerMirror()
end

function IKST_VehicleMirror.resolveVehicle(vehicleId)
    vehicleId = tonumber(vehicleId)
    if vehicleId == nil then
        return nil
    end
    if getVehicleById then
        local v = getVehicleById(vehicleId)
        if v then
            return v
        end
    end
    return nil
end

function IKST_VehicleMirror.uprightDot(v)
    if not v or not v.getUpVectorDot then
        return 1
    end
    return v:getUpVectorDot()
end

function IKST_VehicleMirror.needsFlip(v)
    return IKST_VehicleMirror.uprightDot(v) < 0.5
end

function IKST_VehicleMirror.coordsMatch(v, x, y, z, angle)
    if not v or x == nil or y == nil then
        return false
    end
    local tol = 1.25
    if math.abs(v:getX() - x) > tol then
        return false
    end
    if math.abs(v:getY() - y) > tol then
        return false
    end
    if z ~= nil and v.getZ then
        if math.abs((v:getZ() or 0) - z) > 0.6 then
            return false
        end
    end
    if angle ~= nil and v.getAngleY then
        local live = v:getAngleY()
        local diff = math.abs(live - angle)
        if diff > 180 then
            diff = 360 - diff
        end
        if diff > 8 then
            return false
        end
    end
    return true
end

function IKST_VehicleMirror.syncKey(args)
    if not args or args.vehicleId == nil then
        return nil
    end
    return tostring(args.vehicleId) .. "|"
        .. tostring(args.x) .. "," .. tostring(args.y) .. "," .. tostring(args.z) .. "|"
        .. tostring(args.angle) .. "|"
        .. tostring(args.flipped == true) .. "|"
        .. tostring(args.deleted == true) .. "|"
        .. tostring(args.relocated == true)
end

function IKST_VehicleMirror.applyServerState(args)
    if not IKST_VehicleMirror.shouldMirror() then
        return false
    end
    if not args or type(args) ~= "table" then
        return false
    end
    local vehicleId = tonumber(args.vehicleId)
    if vehicleId == nil then
        return false
    end
    local syncKey = IKST_VehicleMirror.syncKey(args)
    if syncKey and IKST_VehicleMirror._lastSyncKey[vehicleId] == syncKey then
        return true
    end
    local v = IKST_VehicleMirror.resolveVehicle(vehicleId)
    if args.deleted == true then
        IKST_VehicleMirror._lastSyncKey[vehicleId] = syncKey
        IKST_VehicleMirror.clearPin(vehicleId)
        if v and v.removeFromWorld then
            v:removeFromWorld()
        end
        if not IKST_Debug then
            require "IKST_Debug"
        end
        if IKST_Debug and IKST_Debug.logEffect then
            IKST_Debug.logEffect("vehicle", "clientMirrorDelete", "vid=" .. tostring(vehicleId), nil)
        end
        return true
    end
    if not v then
        return false
    end
    local x = tonumber(args.x)
    local y = tonumber(args.y)
    local z = tonumber(args.z)
    local angle = tonumber(args.angle)
    local flipped = args.flipped == true
    if not flipped and x and y and IKST_VehicleMirror.coordsMatch(v, x, y, z, angle) then
        IKST_VehicleMirror.storePin(vehicleId, x, y, z, angle, flipped)
        IKST_VehicleMirror._lastSyncKey[vehicleId] = syncKey
        return true
    end
    if flipped and IKST_VehicleMirror.needsFlip(v) and v.flipUpright then
        v:flipUpright()
    end
    if x and v.setX then
        v:setX(x)
    end
    if y and v.setY then
        v:setY(y)
    end
    if z ~= nil and v.setZ then
        v:setZ(z)
    end
    if angle and v.setAngles then
        v:setAngles(0, angle, 0)
    end
    if v.updatePhysicsNetwork then
        v:updatePhysicsNetwork()
    end
    if x and y then
        IKST_VehicleMirror.storePin(vehicleId, x, y, z, angle, flipped)
    end
    IKST_VehicleMirror._lastSyncKey[vehicleId] = syncKey
    if not IKST_Debug then
        require "IKST_Debug"
    end
    if IKST_Debug and IKST_Debug.logEffect then
        local detail = "vid=" .. tostring(vehicleId)
        if x then
            detail = detail .. " @" .. tostring(math.floor(x)) .. "," .. tostring(math.floor(y))
        end
        if flipped then
            detail = detail .. " flipped"
        end
        IKST_Debug.logEffect("vehicle", "clientMirrorPose", detail, nil)
    end
    return true
end

function IKST_VehicleMirror.pinExpiresAt()
    local now = 0
    if getTimestampMs then
        now = getTimestampMs() / 1000
    elseif getGameTime and getGameTime() and getGameTime().getWorldAgeHours then
        now = getGameTime():getWorldAgeHours() * 3600
    end
    return now + (IKST_VehicleMirror.PIN_SECONDS or 20)
end

function IKST_VehicleMirror.storePin(vehicleId, x, y, z, angle, flipped)
    vehicleId = tonumber(vehicleId)
    if vehicleId == nil or x == nil or y == nil then
        return
    end
    IKST_VehicleMirror._pinnedPose[vehicleId] = {
        x = x,
        y = y,
        z = z,
        angle = angle,
        flipped = flipped == true,
        expiresAt = IKST_VehicleMirror.pinExpiresAt(),
    }
end

function IKST_VehicleMirror.clearPin(vehicleId)
    vehicleId = tonumber(vehicleId)
    if vehicleId ~= nil then
        IKST_VehicleMirror._pinnedPose[vehicleId] = nil
    end
end

function IKST_VehicleMirror.applyPose(v, x, y, z, angle, flipped)
    if not v or x == nil or y == nil then
        return false
    end
    if flipped and IKST_VehicleMirror.needsFlip(v) and v.flipUpright then
        v:flipUpright()
    end
    if v.setX then
        v:setX(x)
    end
    if v.setY then
        v:setY(y)
    end
    if z ~= nil and v.setZ then
        v:setZ(z)
    end
    if angle and v.setAngles then
        v:setAngles(0, angle, 0)
    end
    if v.updatePhysicsNetwork then
        v:updatePhysicsNetwork()
    end
    return true
end

function IKST_VehicleMirror.repinVehicle(vehicleId)
    if not IKST_VehicleMirror.shouldMirror() then
        return false
    end
    vehicleId = tonumber(vehicleId)
    if vehicleId == nil then
        return false
    end
    local pin = IKST_VehicleMirror._pinnedPose[vehicleId]
    if not pin then
        return false
    end
    local now = 0
    if getTimestampMs then
        now = getTimestampMs() / 1000
    elseif getGameTime and getGameTime() and getGameTime().getWorldAgeHours then
        now = getGameTime():getWorldAgeHours() * 3600
    end
    if pin.expiresAt and now > pin.expiresAt then
        IKST_VehicleMirror._pinnedPose[vehicleId] = nil
        return false
    end
    local v = IKST_VehicleMirror.resolveVehicle(vehicleId)
    if not v then
        return false
    end
    if IKST_VehicleMirror.coordsMatch(v, pin.x, pin.y, pin.z, pin.angle)
        and (not pin.flipped or not IKST_VehicleMirror.needsFlip(v)) then
        return true
    end
    IKST_VehicleMirror.applyPose(v, pin.x, pin.y, pin.z, pin.angle, pin.flipped)
    if IKST_Debug and IKST_Debug.logEffect then
        IKST_Debug.logEffect("vehicle", "clientMirrorRepin", "vid=" .. tostring(vehicleId), nil)
    end
    return true
end

function IKST_VehicleMirror.onEnterVehicle(character)
    if not IKST_VehicleMirror.shouldMirror() or not character or not character.getVehicle then
        return
    end
    local v = character:getVehicle()
    if not v or not v.getId then
        return
    end
    IKST_VehicleMirror.repinVehicle(v:getId())
end
