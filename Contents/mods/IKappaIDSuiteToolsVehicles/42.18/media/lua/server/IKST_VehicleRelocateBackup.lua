-- Server-only relocate safety net: ModData stash + restore at origin on failure.
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

function IKST_VehicleRelocateBackup.restoreAtOrigin(vehicleId, playerObj)
    if not mayMutate() then
        return false, "server only"
    end
    local entry = IKST_VehicleRelocateBackup.get(vehicleId)
    if not entry or type(entry.snap) ~= "table" then
        return false, "no backup"
    end
    local snap = entry.snap
    local origin = snap.origin
    if type(origin) ~= "table" then
        return false, "no origin"
    end
    local oldId = tonumber(origin.vehicleId) or tonumber(vehicleId)
    if oldId and getVehicleById and getVehicleById(oldId) then
        IKST_VehicleRelocateBackup.clear(vehicleId)
        return true, "vehicle still present"
    end
    if not IKST_VehicleOps or not IKST_VehicleOps.spawnFromSnapshot then
        return false, "spawn unavailable"
    end
    local restored, restoreMsg = IKST_VehicleOps.spawnFromSnapshot(
        snap,
        origin.x,
        origin.y,
        origin.z,
        origin.angle,
        playerObj,
        nil)
    if not restored then
        return false, restoreMsg or "restore spawn failed"
    end
    IKST_VehicleRelocateBackup.clear(vehicleId)
    IKST_VehicleRelocateBackup.logRestore("vid=" .. tostring(vehicleId)
        .. " @" .. tostring(origin.x) .. "," .. tostring(origin.y))
    return true, "restored"
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
        if oldId and getVehicleById and getVehicleById(oldId) then
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
