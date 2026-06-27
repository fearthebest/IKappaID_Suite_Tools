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

IKST_VehicleOps = IKST_VehicleOps or {}

IKST_VehicleOps.forEachVehicle = IKST_VehicleUtil.forEachVehicle
IKST_VehicleOps.getVehiclesFromCell = IKST_VehicleUtil.getVehiclesFromCell
IKST_VehicleOps.getVehicle = IKST_VehicleUtil.getVehicle
IKST_VehicleOps.listNearby = IKST_VehicleUtil.listNearby
IKST_VehicleOps.nearestId = IKST_VehicleUtil.nearestId

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
        IKST_VehicleOps.giveVehicleKey(vehicle)
    end
    return vehicle, "spawned"
end

function IKST_VehicleOps.move(vehicleId, x, y, z, angle)
    local v = IKST_VehicleOps.getVehicle(vehicleId)
    if not v then
        return false, "vehicle not found"
    end
    v:setX(x)
    v:setY(y)
    v:setZ(z)
    if angle and v.setAngles then
        v:setAngles(0, angle, 0)
    end
    return true, "moved"
end

function IKST_VehicleOps.delete(vehicleId)
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
    if removeVehicle then
        removeVehicle(nil, v)
    elseif v.removeFromWorld then
        v:removeFromWorld()
    end
    return true, "deleted"
end

function IKST_VehicleOps.flip(vehicleId)
    local v = IKST_VehicleOps.getVehicle(vehicleId)
    if not v then
        return false, "vehicle not found"
    end
    if v.flipUpright then
        v:flipUpright()
        return true, "flipped"
    end
    return false, "flip unavailable"
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

function IKST_VehicleOps.giveVehicleKey(v)
    if not v then
        return false
    end
    if v.addKeyToGloveBox then
        v:addKeyToGloveBox()
        return true
    end
    if v.createKeyInGloveBox then
        v:createKeyInGloveBox()
        return true
    end
    if v.createVehicleKey and v.putKeyInIgnition then
        local key = v:createVehicleKey()
        if key then
            v:putKeyInIgnition(key, 0)
            return true
        end
    end
    return false
end

function IKST_VehicleOps.addKey(vehicleId)
    local v = IKST_VehicleOps.getVehicle(vehicleId)
    if not v then
        return false, "vehicle not found"
    end
    if IKST_VehicleOps.giveVehicleKey(v) then
        return true, "key in glovebox"
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
            toRemove[#toRemove + 1] = v
        end
    end)
    for _, v in ipairs(toRemove) do
        local vid = v.getId and v:getId()
        if IKST_TileProtect and IKST_TileProtect.isVehicleProtected(vid) then
            -- skip
        elseif removeVehicle then
            removeVehicle(nil, v)
            removed = removed + 1
        elseif v.removeFromWorld then
            v:removeFromWorld()
            removed = removed + 1
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
            local script = v.getScript and v:getScript()
            local name = script and script:getName() or ""
            if burntOnly and not string.find(string.lower(name), "burnt") and not string.find(string.lower(name), "wreck") then
                skipped = skipped + 1
            else
                local cond = v.getVehicleEngineQuality and v:getVehicleEngineQuality() or 100
                if cond <= conditionPct then
                    toRemove[#toRemove + 1] = v
                else
                    skipped = skipped + 1
                end
            end
        end
    end)
    for _, v in ipairs(toRemove) do
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
    if IKST_VehicleOps.giveVehicleKey(v) then
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
                unlocked = unlocked + 1
            end
        end
    end
    if unlocked > 0 then
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
        local ok, msg = IKST_VehicleOps.move(args.vehicleId, readCoord(args, "x"), readCoord(args, "y"), readCoord(args, "z"), args.angle)
        return ok, msg
    end
    if command == IKST.CMD.vehicleDelete then
        return IKST_VehicleOps.delete(args.vehicleId)
    end
    if command == IKST.CMD.vehicleDeleteCell then
        local n = IKST_VehicleOps.deleteCell(readCoord(args, "cellX"), readCoord(args, "cellY"))
        return true, "removed " .. n
    end
    if command == IKST.CMD.vehicleFlip then
        return IKST_VehicleOps.flip(args.vehicleId)
    end
    if command == IKST.CMD.vehicleRepair then
        return IKST_VehicleOps.repair(args.vehicleId)
    end
    if command == IKST.CMD.vehicleKey then
        return IKST_VehicleOps.addKey(args.vehicleId)
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
        return IKST_VehicleOps.skinStep(player, args.vehicleId, 1)
    end
    if command == IKST.CMD.vehicleSkinPrev then
        return IKST_VehicleOps.skinStep(player, args.vehicleId, -1)
    end
    if command == IKST.CMD.vehicleUnlockTrunk then
        return IKST_VehicleOps.unlockTrunk(player, args.vehicleId)
    end
    if command == IKST.CMD.vehicleUnlockDoors then
        return IKST_VehicleOps.unlockDoors(player, args.vehicleId)
    end
    return false, "unknown vehicle command"
end
