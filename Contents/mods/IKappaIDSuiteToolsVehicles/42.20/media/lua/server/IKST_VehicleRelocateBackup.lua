-- Server-only relocate safety net: ModData stash + restore on failure.
-- Keyed by durable IKST_vkey (session getId() recycles after restart).
-- Used only after the source vehicle is removed (never two vehicles in world).
-- Not synced to clients (operator recovery only).

if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end

require "IKST_Shared"
require "IKST_Authority"
require "IKST_VehicleIdentity"
require "IKST_VehicleUtil"

IKST_VehicleRelocateBackup = IKST_VehicleRelocateBackup or {}

local BACKUP_KEY = "IKST_VehicleRelocateBackup"

local function mayMutate()
    return IKST.mayMutateWorldState and IKST.mayMutateWorldState()
end

local function store()
    if not ModData or not ModData.getOrCreate then
        return { byId = {} }
    end
    local data = ModData.getOrCreate(BACKUP_KEY)
    data.byId = data.byId or {}
    return data
end

local function copyValue(value)
    local t = type(value)
    if t == "string" or t == "number" or t == "boolean" then
        return value
    end
    if t ~= "table" then
        return nil
    end
    local out = {}
    for key, child in pairs(value) do
        local copied = copyValue(child)
        if copied ~= nil or type(child) == "table" then
            out[key] = copied
        end
    end
    return out
end

local function findVehicleByStamp(stamp)
    if not stamp or not IKST_VehicleUtil or type(IKST_VehicleUtil.forEachVehicle) ~= "function" then
        return nil
    end
    local found = nil
    local vehicles = IKST_VehicleUtil.getVehiclesFromCell and IKST_VehicleUtil.getVehiclesFromCell()
    if not vehicles then
        return nil
    end
    IKST_VehicleUtil.forEachVehicle(vehicles, function(v)
        if found or not v then
            return
        end
        if IKST_VehicleIdentity and type(IKST_VehicleIdentity.readKey) == "function"
            and IKST_VehicleIdentity.readKey(v) == stamp then
            found = v
        end
    end)
    return found
end

function IKST_VehicleRelocateBackup.stash(stampKey, snap, target, runtimeId)
    if not mayMutate() or stampKey == nil or type(snap) ~= "table" then
        return false
    end
    local key = tostring(stampKey)
    local data = store()
    data.byId[key] = {
        snap = copyValue(snap),
        target = target,
        runtimeId = runtimeId,
        stashedAt = (os and os.time and os.time()) or 0,
    }
    return true
end

function IKST_VehicleRelocateBackup.get(id)
    if id == nil then
        return nil, nil
    end
    local data = store()
    local key = tostring(id)
    if data.byId[key] then
        return data.byId[key], key
    end
    for k, entry in pairs(data.byId) do
        if entry and tostring(entry.runtimeId or "") == key then
            return entry, k
        end
        local origin = entry and entry.snap and entry.snap.origin
        if origin and tostring(origin.claimKey or "") == key then
            return entry, k
        end
    end
    return nil, nil
end

function IKST_VehicleRelocateBackup.clear(id)
    if not mayMutate() or id == nil then
        return
    end
    local _, storeKey = IKST_VehicleRelocateBackup.get(id)
    if storeKey then
        store().byId[storeKey] = nil
    end
end

function IKST_VehicleRelocateBackup.logRestore(detail)
    if not IKST_Debug then
        require "IKST_Debug"
    end
    if IKST_Debug and IKST_Debug.logEffect then
        IKST_Debug.logEffect("vehicle", "relocateRestore", detail, nil)
    end
end

-- Match stamp on the live car, then coords. Never trust a recycled session id alone.
function IKST_VehicleRelocateBackup.vehicleAtOrigin(stamp, runtimeId, origin)
    if type(origin) ~= "table" then
        return nil
    end
    local existing = nil
    if stamp then
        existing = findVehicleByStamp(stamp)
    end
    if not existing and runtimeId ~= nil and getVehicleById then
        existing = getVehicleById(runtimeId)
        if existing and stamp and IKST_VehicleIdentity and type(IKST_VehicleIdentity.readKey) == "function" then
            if IKST_VehicleIdentity.readKey(existing) ~= stamp then
                existing = nil
            end
        end
    end
    if not existing or type(existing.getX) ~= "function" or type(existing.getY) ~= "function" then
        return nil
    end
    local ox = tonumber(origin.x)
    local oy = tonumber(origin.y)
    if ox == nil or oy == nil then
        return nil
    end
    if math.abs(existing:getX() - ox) > 2.5 or math.abs(existing:getY() - oy) > 2.5 then
        return nil
    end
    return existing
end

function IKST_VehicleRelocateBackup.listEntries()
    local out = {}
    for key, entry in pairs(store().byId) do
        local snap = entry and entry.snap
        if type(snap) == "table" then
            out[#out + 1] = {
                backupId = key,
                scriptName = snap.scriptName,
                origin = snap.origin,
                target = entry.target,
                stashedAt = entry.stashedAt,
                runtimeId = entry.runtimeId,
            }
        end
    end
    table.sort(out, function(a, b)
        return (a.stashedAt or 0) > (b.stashedAt or 0)
    end)
    return out
end

function IKST_VehicleRelocateBackup.finishRestore(backupId, newVehicle, oldClaimId)
    if not newVehicle or type(newVehicle.getId) ~= "function" then
        return nil
    end
    local newId = newVehicle:getId()
    if newId == nil then
        return nil
    end
    local entry = IKST_VehicleRelocateBackup.get(backupId)
    local target = entry and entry.target
    if IKST_VehicleClaim and IKST_VehicleClaim.remapVehicleId and oldClaimId then
        IKST_VehicleClaim.remapVehicleId(oldClaimId, newId, target)
    end
    IKST_VehicleRelocateBackup.clear(backupId)
    if IKST_VehicleOps and IKST_VehicleOps.syncVehicleToClients then
        IKST_VehicleOps.syncVehicleToClients(newId, { relocated = true })
    end
    IKST_VehicleRelocateBackup.logRestore("backup=" .. tostring(backupId) .. " newVid=" .. tostring(newId))
    return newId
end

function IKST_VehicleRelocateBackup.restoreAtCoords(vehicleId, x, y, z, angle, playerObj)
    if not mayMutate() then
        return false, "server only", nil
    end
    local entry = IKST_VehicleRelocateBackup.get(vehicleId)
    if not entry or type(entry.snap) ~= "table" then
        return false, "no backup", nil
    end
    if not IKST_VehicleOps or not IKST_VehicleOps.spawnFromSnapshot then
        return false, "spawn unavailable", nil
    end
    local snap = entry.snap
    local origin = snap.origin
    local oldClaimId = (origin and (origin.claimKey or origin.vehicleId)) or vehicleId
    local restored, restoreMsg = IKST_VehicleOps.spawnFromSnapshot(
        snap, x, y, z, angle, playerObj, nil)
    if not restored then
        return false, restoreMsg or "restore spawn failed", nil
    end
    local newId = IKST_VehicleRelocateBackup.finishRestore(vehicleId, restored, oldClaimId)
    if newId == nil then
        if IKST_VehicleOps.removeVehicleFromWorld then
            IKST_VehicleOps.removeVehicleFromWorld(restored)
        end
        return false, "restore missing id", nil
    end
    return true, "restored", newId
end

function IKST_VehicleRelocateBackup.restoreAtOrigin(vehicleId, playerObj)
    if not mayMutate() then
        return false, "server only", nil
    end
    local entry = IKST_VehicleRelocateBackup.get(vehicleId)
    if not entry or type(entry.snap) ~= "table" then
        return false, "no backup", nil
    end
    local snap = entry.snap
    local origin = snap.origin
    if type(origin) ~= "table" then
        return false, "no origin", nil
    end
    local stamp = origin.claimKey or vehicleId
    local runtimeId = entry.runtimeId or origin.vehicleId
    local present = IKST_VehicleRelocateBackup.vehicleAtOrigin(stamp, runtimeId, origin)
    if present then
        IKST_VehicleRelocateBackup.clear(vehicleId)
        local stillId = type(present.getId) == "function" and present:getId() or runtimeId
        return true, "vehicle still present", stillId
    end
    local ok, msg, newId = IKST_VehicleRelocateBackup.restoreAtCoords(
        vehicleId, origin.x, origin.y, origin.z, origin.angle, playerObj)
    if ok then
        return true, msg, newId
    end
    return false, msg, nil
end

function IKST_VehicleRelocateBackup.restoreAtTarget(vehicleId, playerObj)
    local entry = IKST_VehicleRelocateBackup.get(vehicleId)
    local target = entry and entry.target
    if type(target) ~= "table" then
        return false, "no target saved", nil
    end
    return IKST_VehicleRelocateBackup.restoreAtCoords(
        vehicleId, target.x, target.y, target.z, nil, playerObj)
end

function IKST_VehicleRelocateBackup.restore(vehicleId, mode, playerObj, x, y, z, angle)
    mode = tostring(mode or "origin")
    if mode == "target" then
        return IKST_VehicleRelocateBackup.restoreAtTarget(vehicleId, playerObj)
    end
    if mode == "here" then
        if x == nil or y == nil then
            return false, "no coords", nil
        end
        return IKST_VehicleRelocateBackup.restoreAtCoords(vehicleId, x, y, z, angle, playerObj)
    end
    return IKST_VehicleRelocateBackup.restoreAtOrigin(vehicleId, playerObj)
end

function IKST_VehicleRelocateBackup.recoverOrphaned()
    if not mayMutate() then
        return 0
    end
    local data = store()
    local recovered = 0
    local keys = {}
    for key in pairs(data.byId) do
        keys[#keys + 1] = key
    end
    for _, key in ipairs(keys) do
        local entry = data.byId[key]
        local snap = entry and entry.snap
        local origin = snap and snap.origin
        local stamp = origin and origin.claimKey or key
        local runtimeId = entry and entry.runtimeId or (origin and origin.vehicleId)
        if origin and IKST_VehicleRelocateBackup.vehicleAtOrigin(stamp, runtimeId, origin) then
            data.byId[key] = nil
        elseif origin then
            local ok, _ = IKST_VehicleRelocateBackup.restoreAtOrigin(key, nil)
            if ok then
                recovered = recovered + 1
            end
        else
            data.byId[key] = nil
        end
    end
    return recovered
end

local function installStartupRecovery()
    if IKST_VehicleRelocateBackup.startupInstalled then
        return
    end
    if not IKST.runsOnServerJvm or not IKST.runsOnServerJvm() then
        return
    end
    if not Events or not Events.OnServerStarted or not Events.OnServerStarted.Add then
        return
    end
    Events.OnServerStarted.Add(function()
        local n = IKST_VehicleRelocateBackup.recoverOrphaned()
        if n > 0 then
            IKST_VehicleRelocateBackup.logRestore("startup recovered=" .. tostring(n))
        end
    end)
    IKST_VehicleRelocateBackup.startupInstalled = true
end

installStartupRecovery()
