-- Client mirror for server-authoritative safehouse claim ModData (MP).
-- Bootstrap/rev for enforcement; applyMirror for incremental UI rows.

require "IKST_Shared"

IKST_SafehouseClaimMirror = IKST_SafehouseClaimMirror or {}

require "IKST_SafehouseClaim"
IKST_SafehouseClaimMirror.byKey = IKST_SafehouseClaimMirror.byKey or {}
IKST_SafehouseClaimMirror.rev = 0
IKST_SafehouseClaimMirror.count = 0
IKST_SafehouseClaimMirror.ready = false

function IKST_SafehouseClaimMirror.usesMirror()
    return IKST.isRemoteClient and IKST.isRemoteClient()
end

function IKST_SafehouseClaimMirror.copyEntry(entry)
    if IKST_SafehouseClaim and IKST_SafehouseClaim.copyEntryPlain then
        return IKST_SafehouseClaim.copyEntryPlain(entry)
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

function IKST_SafehouseClaimMirror.reset()
    IKST_SafehouseClaimMirror.byKey = {}
    IKST_SafehouseClaimMirror.rev = 0
    IKST_SafehouseClaimMirror.count = 0
    IKST_SafehouseClaimMirror.ready = false
end

function IKST_SafehouseClaimMirror.isReady()
    if not IKST_SafehouseClaimMirror.usesMirror() then
        return true
    end
    return IKST_SafehouseClaimMirror.ready == true
end

function IKST_SafehouseClaimMirror.getRev()
    return tonumber(IKST_SafehouseClaimMirror.rev) or 0
end

function IKST_SafehouseClaimMirror.getCount()
    return tonumber(IKST_SafehouseClaimMirror.count) or 0
end

function IKST_SafehouseClaimMirror.countEntries()
    local n = 0
    for _ in pairs(IKST_SafehouseClaimMirror.byKey) do
        n = n + 1
    end
    return n
end

function IKST_SafehouseClaimMirror.verifyCount(expected)
    expected = tonumber(expected)
    if expected == nil then
        return true
    end
    return IKST_SafehouseClaimMirror.countEntries() == expected
end

function IKST_SafehouseClaimMirror.get(claimKey)
    if claimKey == nil then
        return nil
    end
    return IKST_SafehouseClaimMirror.byKey[tostring(claimKey)]
end

function IKST_SafehouseClaimMirror.getForBounds(x, y, w, h)
    if x == nil or y == nil or not w or not h then
        return nil
    end
    local key = IKST_SafehouseClaim.keyFor(x, y, w, h)
    return IKST_SafehouseClaimMirror.get(key)
end

function IKST_SafehouseClaimMirror.markClientReady()
    if IKST_SafehouseClaimClient then
        IKST_SafehouseClaimClient.listBootstrapped = true
        if IKST_SafehouseClaimClient.syncFromMirroredStore then
            IKST_SafehouseClaimClient.syncFromMirroredStore()
        end
    end
end

function IKST_SafehouseClaimMirror.applyBootstrap(args)
    if not IKST_SafehouseClaimMirror.usesMirror() then
        return
    end
    if not args or type(args) ~= "table" then
        return
    end
    local rev = tonumber(args.rev) or 0
    if rev < IKST_SafehouseClaimMirror.getRev() then
        return
    end
    local claims = args.claims
    if type(claims) ~= "table" then
        claims = {}
    end
    local byKey = {}
    for k, entry in pairs(claims) do
        if type(entry) == "table" then
            byKey[tostring(k)] = IKST_SafehouseClaimMirror.copyEntry(entry)
        end
    end
    IKST_SafehouseClaimMirror.byKey = byKey
    IKST_SafehouseClaimMirror.rev = rev
    IKST_SafehouseClaimMirror.count = tonumber(args.count) or IKST_SafehouseClaimMirror.countEntries()
    if not IKST_SafehouseClaimMirror.verifyCount(IKST_SafehouseClaimMirror.count) then
        IKST_SafehouseClaimMirror.ready = false
        return
    end
    IKST_SafehouseClaimMirror.ready = true
    IKST_SafehouseClaimMirror.markClientReady()
end

function IKST_SafehouseClaimMirror.applyPatch(args)
    if not IKST_SafehouseClaimMirror.usesMirror() then
        return
    end
    if not args or type(args) ~= "table" then
        return
    end
    local rev = tonumber(args.rev) or 0
    if rev <= IKST_SafehouseClaimMirror.getRev() then
        return
    end
    local op = tostring(args.op or "")
    local claimKey = args.claimKey and tostring(args.claimKey) or nil
    if op == "clear" and claimKey then
        IKST_SafehouseClaimMirror.byKey[claimKey] = nil
    elseif op == "set" and claimKey and type(args.entry) == "table" then
        IKST_SafehouseClaimMirror.byKey[claimKey] = IKST_SafehouseClaimMirror.copyEntry(args.entry)
    else
        return
    end
    IKST_SafehouseClaimMirror.rev = rev
    if args.count ~= nil then
        IKST_SafehouseClaimMirror.count = tonumber(args.count) or IKST_SafehouseClaimMirror.count
    end
    if IKST_SafehouseClaimMirror.verifyCount(IKST_SafehouseClaimMirror.count) then
        IKST_SafehouseClaimMirror.ready = true
        IKST_SafehouseClaimMirror.markClientReady()
    else
        IKST_SafehouseClaimMirror.ready = false
    end
end

function IKST_SafehouseClaimMirror.onPingResult(args)
    if not IKST_SafehouseClaimMirror.usesMirror() then
        return
    end
    if not args or type(args) ~= "table" then
        return
    end
    local serverRev = tonumber(args.rev) or 0
    if serverRev == IKST_SafehouseClaimMirror.getRev()
        and IKST_SafehouseClaimMirror.verifyCount(args.count) then
        IKST_SafehouseClaimMirror.ready = true
        IKST_SafehouseClaimMirror.markClientReady()
    end
end

function IKST_SafehouseClaimMirror.requestResync(player, reason)
    if not IKST_SafehouseClaimMirror.usesMirror() then
        return
    end
    if not player or not IKST.dispatchCommand then
        return
    end
    IKST_SafehouseClaimMirror._lastPingMs = IKST_SafehouseClaimMirror._lastPingMs or 0
    local now = 0
    if getTimestampMs then
        now = getTimestampMs()
    elseif getTimeInMillis then
        now = getTimeInMillis()
    end
    if now > 0 and (now - IKST_SafehouseClaimMirror._lastPingMs) < 2000 then
        return
    end
    IKST_SafehouseClaimMirror._lastPingMs = now
    IKST.dispatchCommand(player, IKST.CMD.safehouseClaimPing, {
        rev = IKST_SafehouseClaimMirror.getRev(),
        count = IKST_SafehouseClaimMirror.getCount(),
        reason = reason or "",
    })
end

function IKST_SafehouseClaimMirror.syncEntryToMirror(key, entry)
    if not IKST_SafehouseClaimMirror.usesMirror() then
        return
    end
    if entry then
        IKST_SafehouseClaimMirror.byKey[key] = IKST_SafehouseClaimMirror.copyEntry(entry)
    else
        IKST_SafehouseClaimMirror.byKey[key] = nil
    end
    IKST_SafehouseClaimMirror.ready = true
end

function IKST_SafehouseClaimMirror.applyMirror(args)
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
    local x = math.floor(tonumber(args.x) or 0)
    local y = math.floor(tonumber(args.y) or 0)
    local w = math.floor(tonumber(args.w) or 0)
    local h = math.floor(tonumber(args.h) or 0)
    if w < 1 or h < 1 then
        return false
    end
    local data = IKST_SafehouseClaim.store()
    local key = IKST_SafehouseClaim.keyFor(x, y, w, h)
    if args.action == "remove" then
        data.byKey[key] = nil
        IKST_SafehouseClaimMirror.syncEntryToMirror(key, nil)
        return true
    end
    if args.action == "set" and type(args.entry) == "table" then
        local entry = args.entry
        IKST_SafehouseClaim.ensureEntryShape(entry)
        entry.key = key
        entry.x = x
        entry.y = y
        entry.w = w
        entry.h = h
        data.byKey[key] = entry
        IKST_SafehouseClaimMirror.syncEntryToMirror(key, entry)
        return true
    end
    return false
end

function IKST_SafehouseClaimMirror.installClient()
    if IKST_SafehouseClaimMirror.clientInstalled then
        return
    end
    if not IKST_SafehouseClaimMirror.usesMirror() then
        return
    end
    if not Events then
        return
    end
    local function onGameStart()
        IKST_SafehouseClaimMirror.reset()
        if IKST_SafehouseClaimClient then
            IKST_SafehouseClaimClient.listBootstrapped = false
        end
        local player = getPlayer and getPlayer() or nil
        if not player and getSpecificPlayer then
            player = getSpecificPlayer(0)
        end
        if player then
            IKST_SafehouseClaimMirror.requestResync(player, "gameStart")
        end
    end
    if Events.OnGameStart and Events.OnGameStart.Add then
        Events.OnGameStart.Add(onGameStart)
    end
    local function onPlayerUpdate(player)
        if not player or not player.isLocalPlayer or not player:isLocalPlayer() then
            return
        end
        if IKST_SafehouseClaimMirror.ready then
            return
        end
        IKST_SafehouseClaimMirror._waitTicks = (IKST_SafehouseClaimMirror._waitTicks or 0) + 1
        if IKST_SafehouseClaimMirror._waitTicks % 60 ~= 0 then
            return
        end
        IKST_SafehouseClaimMirror.requestResync(player, "notReady")
    end
    if Events.OnPlayerUpdate and Events.OnPlayerUpdate.Add then
        Events.OnPlayerUpdate.Add(onPlayerUpdate)
    end
    IKST_SafehouseClaimMirror.clientInstalled = true
end

if IKST_SafehouseClaimMirror.usesMirror() then
    IKST_SafehouseClaimMirror.installClient()
end
