-- Server-only relocate safety net: ModData stash + restore on failure.

-- Used only after the source vehicle is removed (never two vehicles in world).

-- Not synced to clients (operator recovery only).

if type(isClient) == "function" and isClient()

    and type(isServer) == "function" and not isServer() then

    return

end

require "IKST_Shared"

require "IKST_Authority"

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

function IKST_VehicleRelocateBackup.stash(vehicleId, snap, target)

    if not mayMutate() or vehicleId == nil or type(snap) ~= "table" then

        return false

    end

    local key = tostring(vehicleId)

    local data = store()

    data.byId[key] = {

        snap = copyValue(snap),

        target = target,

        stashedAt = (os and os.time and os.time()) or 0,

    }

    return true

end

function IKST_VehicleRelocateBackup.get(vehicleId)

    if vehicleId == nil then

        return nil

    end

    return store().byId[tostring(vehicleId)]

end

function IKST_VehicleRelocateBackup.clear(vehicleId)

    if not mayMutate() or vehicleId == nil then

        return

    end

    store().byId[tostring(vehicleId)] = nil

end

function IKST_VehicleRelocateBackup.logRestore(detail)

    if not IKST_Debug then

        require "IKST_Debug"

    end

    if IKST_Debug and IKST_Debug.logEffect then

        IKST_Debug.logEffect("vehicle", "relocateRestore", detail, nil)

    end

end

function IKST_VehicleRelocateBackup.vehicleAtOrigin(oldId, origin)

    if oldId == nil or type(origin) ~= "table" or not getVehicleById then

        return nil

    end

    local existing = getVehicleById(oldId)

    if not existing or not existing.getX or not existing.getY then

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

            local origin = snap.origin

            local target = entry.target

            out[#out + 1] = {

                backupId = tonumber(key) or key,

                scriptName = snap.scriptName,

                origin = origin,

                target = target,

                stashedAt = entry.stashedAt,

            }

        end

    end

    table.sort(out, function(a, b)

        return (a.stashedAt or 0) > (b.stashedAt or 0)

    end)

    return out

end

function IKST_VehicleRelocateBackup.finishRestore(backupId, newVehicle, oldClaimId)

    if not newVehicle or not newVehicle.getId then

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

    local oldClaimId = origin and origin.vehicleId or vehicleId

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

    local oldId = tonumber(origin.vehicleId) or tonumber(vehicleId)

    if IKST_VehicleRelocateBackup.vehicleAtOrigin(oldId, origin) then

        IKST_VehicleRelocateBackup.clear(vehicleId)

        return true, "vehicle still present", oldId

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

        local oldId = origin and origin.vehicleId

        if oldId and IKST_VehicleRelocateBackup.vehicleAtOrigin(oldId, origin) then

            data.byId[key] = nil

        elseif origin then

            local ok, _ = IKST_VehicleRelocateBackup.restoreAtOrigin(oldId or key, nil)

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
