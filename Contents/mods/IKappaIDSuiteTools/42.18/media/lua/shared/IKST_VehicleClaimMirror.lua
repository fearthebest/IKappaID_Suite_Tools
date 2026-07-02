-- Client mirror for server-authoritative vehicle claims (MP).
-- Bootstrap/rev for enforcement; applyMirror for incremental ModData + UI rows.

require "IKST_Shared"
require "IKST_VehicleClaim"

IKST_VehicleClaimMirror = IKST_VehicleClaimMirror or {}
IKST_VehicleClaimMirror.byId = IKST_VehicleClaimMirror.byId or {}
IKST_VehicleClaimMirror.rev = 0
IKST_VehicleClaimMirror.count = 0
IKST_VehicleClaimMirror.ready = false

function IKST_VehicleClaimMirror.usesMirror()
    return IKST.isRemoteClient and IKST.isRemoteClient()
end

function IKST_VehicleClaimMirror.copyEntry(entry)
    if IKST_VehicleClaim and IKST_VehicleClaim.copyEntryPlain then
        return IKST_VehicleClaim.copyEntryPlain(entry)
    end
    if not entry or type(entry) ~= "table" then
        return nil
    end
    local out = {}
    for k, v in pairs(entry) do
        out[k] = v
    end
    return out
end

function IKST_VehicleClaimMirror.reset()
    IKST_VehicleClaimMirror.byId = {}
    IKST_VehicleClaimMirror.rev = 0
    IKST_VehicleClaimMirror.count = 0
    IKST_VehicleClaimMirror.ready = false
end

function IKST_VehicleClaimMirror.isReady()
    if not IKST_VehicleClaimMirror.usesMirror() then
        return true
    end
    return IKST_VehicleClaimMirror.ready == true
end

function IKST_VehicleClaimMirror.getRev()
    return tonumber(IKST_VehicleClaimMirror.rev) or 0
end

function IKST_VehicleClaimMirror.getCount()
    return tonumber(IKST_VehicleClaimMirror.count) or 0
end

function IKST_VehicleClaimMirror.countEntries()
    local n = 0
    for _ in pairs(IKST_VehicleClaimMirror.byId) do
        n = n + 1
    end
    return n
end

function IKST_VehicleClaimMirror.verifyCount(expected)
    expected = tonumber(expected)
    if expected == nil then
        return true
    end
    return IKST_VehicleClaimMirror.countEntries() == expected
end

function IKST_VehicleClaimMirror.get(vehicleId)
    if vehicleId == nil then
        return nil
    end
    return IKST_VehicleClaimMirror.byId[tostring(vehicleId)]
end

function IKST_VehicleClaimMirror.markClientReady()
    if IKST_VehicleClaimClient then
        IKST_VehicleClaimClient.listBootstrapped = true
        if IKST_VehicleClaimClient.syncFromMirroredStore then
            IKST_VehicleClaimClient.syncFromMirroredStore()
        end
    end
end

function IKST_VehicleClaimMirror.applyBootstrap(args)
    if not IKST_VehicleClaimMirror.usesMirror() then
        return
    end
    if not args or type(args) ~= "table" then
        return
    end
    local rev = tonumber(args.rev) or 0
    if rev < IKST_VehicleClaimMirror.getRev() then
        return
    end
    local claims = args.claims
    if type(claims) ~= "table" then
        claims = {}
    end
    local byId = {}
    for k, entry in pairs(claims) do
        if type(entry) == "table" then
            byId[tostring(k)] = IKST_VehicleClaimMirror.copyEntry(entry)
        end
    end
    IKST_VehicleClaimMirror.byId = byId
    IKST_VehicleClaimMirror.rev = rev
    IKST_VehicleClaimMirror.count = tonumber(args.count) or IKST_VehicleClaimMirror.countEntries()
    if not IKST_VehicleClaimMirror.verifyCount(IKST_VehicleClaimMirror.count) then
        IKST_VehicleClaimMirror.ready = false
        return
    end
    IKST_VehicleClaimMirror.ready = true
    IKST_VehicleClaimMirror.markClientReady()
end

function IKST_VehicleClaimMirror.applyPatch(args)
    if not IKST_VehicleClaimMirror.usesMirror() then
        return
    end
    if not args or type(args) ~= "table" then
        return
    end
    local rev = tonumber(args.rev) or 0
    if rev <= IKST_VehicleClaimMirror.getRev() then
        return
    end
    local op = tostring(args.op or "")
    local vid = args.vehicleId and tostring(args.vehicleId) or nil
    if op == "clear" and vid then
        IKST_VehicleClaimMirror.byId[vid] = nil
    elseif op == "set" and vid and type(args.entry) == "table" then
        IKST_VehicleClaimMirror.byId[vid] = IKST_VehicleClaimMirror.copyEntry(args.entry)
    else
        return
    end
    IKST_VehicleClaimMirror.rev = rev
    if args.count ~= nil then
        IKST_VehicleClaimMirror.count = tonumber(args.count) or IKST_VehicleClaimMirror.count
    end
    if IKST_VehicleClaimMirror.verifyCount(IKST_VehicleClaimMirror.count) then
        IKST_VehicleClaimMirror.ready = true
        IKST_VehicleClaimMirror.markClientReady()
    else
        IKST_VehicleClaimMirror.ready = false
    end
end

function IKST_VehicleClaimMirror.onPingResult(args)
    if not IKST_VehicleClaimMirror.usesMirror() then
        return
    end
    if not args or type(args) ~= "table" then
        return
    end
    local serverRev = tonumber(args.rev) or 0
    if serverRev == IKST_VehicleClaimMirror.getRev()
        and IKST_VehicleClaimMirror.verifyCount(args.count) then
        IKST_VehicleClaimMirror.ready = true
        IKST_VehicleClaimMirror.markClientReady()
    end
end

function IKST_VehicleClaimMirror.requestResync(player, reason)
    if not IKST_VehicleClaimMirror.usesMirror() then
        return
    end
    if not player or not IKST.dispatchCommand then
        return
    end
    IKST_VehicleClaimMirror._lastPingMs = IKST_VehicleClaimMirror._lastPingMs or 0
    local now = 0
    if getTimestampMs then
        now = getTimestampMs()
    elseif getTimeInMillis then
        now = getTimeInMillis()
    end
    if now > 0 and (now - IKST_VehicleClaimMirror._lastPingMs) < 2000 then
        return
    end
    IKST_VehicleClaimMirror._lastPingMs = now
    IKST.dispatchCommand(player, IKST.CMD.vehicleClaimPing, {
        rev = IKST_VehicleClaimMirror.getRev(),
        count = IKST_VehicleClaimMirror.getCount(),
        reason = reason or "",
    })
end

function IKST_VehicleClaimMirror.syncEntryToMirror(key, entry)
    if not IKST_VehicleClaimMirror.usesMirror() then
        return
    end
    if entry then
        IKST_VehicleClaimMirror.byId[key] = IKST_VehicleClaimMirror.copyEntry(entry)
    else
        IKST_VehicleClaimMirror.byId[key] = nil
    end
    IKST_VehicleClaimMirror.ready = true
end

function IKST_VehicleClaimMirror.applyMirror(args)
    if not args then
        return false
    end
    if type(isClient) == "function" and not isClient() then
        return false
    end
    if IKST.isMultiplayerSession and IKST.isMultiplayerSession() then
        if IKST.runsOnServerJvm and IKST.runsOnServerJvm() and type(isClient) == "function" and not isClient() then
            return false
        end
    end
    local data = IKST_VehicleClaim.store()
    if args.action == "remove" then
        local vid = tonumber(args.vehicleId)
        if not vid then
            return false
        end
        local key = tostring(vid)
        local entry = data.byId[key]
        if entry and entry.owner then
            IKST_VehicleClaim.removeFromOwnerList(entry.owner, key)
        end
        data.byId[key] = nil
        IKST_VehicleClaimMirror.syncEntryToMirror(key, nil)
        return true
    end
    if args.action == "set" and type(args.entry) == "table" then
        local entry = args.entry
        local key = tostring(entry.id or args.vehicleId)
        if key == "" or key == "nil" then
            return false
        end
        IKST_VehicleClaim.ensureEntryShape(entry)
        data.byId[key] = entry
        if entry.owner then
            IKST_VehicleClaim.addToOwnerList(entry.owner, key)
        end
        IKST_VehicleClaimMirror.syncEntryToMirror(key, entry)
        return true
    end
    return false
end

function IKST_VehicleClaimMirror.installClient()
    if IKST_VehicleClaimMirror.clientInstalled then
        return
    end
    if not IKST_VehicleClaimMirror.usesMirror() then
        return
    end
    if not Events then
        return
    end
    local function onGameStart()
        IKST_VehicleClaimMirror.reset()
        if IKST_VehicleClaimClient then
            IKST_VehicleClaimClient.listBootstrapped = false
        end
        local player = getPlayer and getPlayer() or nil
        if not player and getSpecificPlayer then
            player = getSpecificPlayer(0)
        end
        if player then
            IKST_VehicleClaimMirror.requestResync(player, "gameStart")
        end
    end
    if Events.OnGameStart and Events.OnGameStart.Add then
        Events.OnGameStart.Add(onGameStart)
    end
    local function onPlayerUpdate(player)
        if not player or not player.isLocalPlayer or not player:isLocalPlayer() then
            return
        end
        if IKST_VehicleClaimMirror.ready then
            return
        end
        IKST_VehicleClaimMirror._waitTicks = (IKST_VehicleClaimMirror._waitTicks or 0) + 1
        if IKST_VehicleClaimMirror._waitTicks % 60 ~= 0 then
            return
        end
        IKST_VehicleClaimMirror.requestResync(player, "notReady")
    end
    if Events.OnPlayerUpdate and Events.OnPlayerUpdate.Add then
        Events.OnPlayerUpdate.Add(onPlayerUpdate)
    end
    IKST_VehicleClaimMirror.clientInstalled = true
end

if IKST_VehicleClaimMirror.usesMirror() then
    IKST_VehicleClaimMirror.installClient()
end
