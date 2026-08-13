-- Server push sync for vehicle claims (bootstrap + revisioned patches + ping).

if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end

require "IKST_Shared"
require "IKST_VehicleClaim"
require "IKST_VehicleClaimMirror"
require "IKST_Access"

IKST_VehicleClaimSync = IKST_VehicleClaimSync or {}

function IKST_VehicleClaimSync.active()
    return IKST.runsOnServerJvm and IKST.runsOnServerJvm()
        and IKST.isMultiplayerSession and IKST.isMultiplayerSession()
end

function IKST_VehicleClaimSync.getRev()
    local data = IKST_VehicleClaim.store()
    return tonumber(data.syncRev) or 0
end

function IKST_VehicleClaimSync.bumpRev()
    local data = IKST_VehicleClaim.store()
    data.syncRev = (tonumber(data.syncRev) or 0) + 1
    return data.syncRev
end

function IKST_VehicleClaimSync.buildClaimsMap(viewer)
    IKST_VehicleClaim.purgeExpired()
    local data = IKST_VehicleClaim.store()
    local claims = {}
    local count = 0
    for k, entry in pairs(data.byId) do
        if type(entry) == "table" then
            local plain
            if viewer and type(IKST_VehicleClaim.copyEntryForViewer) == "function" then
                plain = IKST_VehicleClaim.copyEntryForViewer(entry, viewer)
            else
                plain = IKST_VehicleClaimMirror.copyEntry(entry)
            end
            if plain then
                claims[k] = plain
                count = count + 1
            end
        end
    end
    return claims, count
end

function IKST_VehicleClaimSync.bootstrapPayload(viewer)
    local claims, count = IKST_VehicleClaimSync.buildClaimsMap(viewer)
    return {
        rev = IKST_VehicleClaimSync.getRev(),
        count = count,
        claims = claims,
    }
end

function IKST_VehicleClaimSync.sendBootstrap(player)
    if not IKST_VehicleClaimSync.active() or not player then
        return
    end
    IKST.deliverClientCommand(player, IKST.CMD.vehicleClaimBootstrap, IKST_VehicleClaimSync.bootstrapPayload(player))
end

function IKST_VehicleClaimSync.broadcastBootstrap()
    if not IKST_VehicleClaimSync.active() then
        return
    end
    if not getOnlinePlayers or type(getOnlinePlayers) ~= "function" then
        return
    end
    local list = getOnlinePlayers()
    if not list or type(list.size) ~= "function" then
        return
    end
    for i = 0, list:size() - 1 do
        local p = list:get(i)
        if p then
            IKST_VehicleClaimSync.sendBootstrap(p)
        end
    end
end

function IKST_VehicleClaimSync.broadcastPatch(payload)
    if not IKST_VehicleClaimSync.active() or not payload then
        return
    end
    if not getOnlinePlayers or type(getOnlinePlayers) ~= "function" then
        return
    end
    local list = getOnlinePlayers()
    if not list or type(list.size) ~= "function" then
        return
    end
    local rawEntry = payload.entry
    for i = 0, list:size() - 1 do
        local p = list:get(i)
        if p then
            local out = {
                rev = payload.rev,
                op = payload.op,
                vehicleId = payload.vehicleId,
                count = payload.count,
            }
            if rawEntry and type(IKST_VehicleClaim.copyEntryForViewer) == "function" then
                out.entry = IKST_VehicleClaim.copyEntryForViewer(rawEntry, p)
            elseif rawEntry then
                out.entry = IKST_VehicleClaimMirror.copyEntry(rawEntry)
            end
            -- Per-viewer filtered count for mirror verify.
            local _, viewerCount = IKST_VehicleClaimSync.buildClaimsMap(p)
            out.count = viewerCount
            IKST.deliverClientCommand(p, IKST.CMD.vehicleClaimPatch, out)
        end
    end
end

function IKST_VehicleClaimSync.afterMutate(op, vehicleId, entry)
    if not IKST_VehicleClaimSync.active() then
        return
    end
    op = tostring(op or "set")
    if op == "purge" or op == "bootstrap" then
        IKST_VehicleClaimSync.bumpRev()
        IKST_VehicleClaimSync.broadcastBootstrap()
        return
    end
    local rev = IKST_VehicleClaimSync.bumpRev()
    local payload = {
        rev = rev,
        op = op,
        vehicleId = vehicleId and tostring(vehicleId) or nil,
        entry = entry,
    }
    IKST_VehicleClaimSync.broadcastPatch(payload)
end

function IKST_VehicleClaimSync.handlePing(player, args)
    if not IKST_VehicleClaimSync.active() or not player then
        return
    end
    args = args or {}
    local serverRev = IKST_VehicleClaimSync.getRev()
    local _, count = IKST_VehicleClaimSync.buildClaimsMap(player)
    local clientRev = tonumber(args.rev) or 0
    local clientCount = tonumber(args.count)
    if clientRev ~= serverRev or (clientCount ~= nil and clientCount ~= count) then
        IKST_VehicleClaimSync.sendBootstrap(player)
        return
    end
    IKST.deliverClientCommand(player, IKST.CMD.vehicleClaimPingResult, {
        rev = serverRev,
        count = count,
    })
end

function IKST_VehicleClaimSync.onPlayerConnect(player)
    if not IKST_VehicleClaimSync.active() then
        return
    end
    IKST_VehicleClaimSync.sendBootstrap(player)
end

local function resolvePlayer(index)
    if getSpecificPlayer then
        return getSpecificPlayer(index)
    end
    return nil
end

local function onCreatePlayer(playerIndex)
    local player = resolvePlayer(playerIndex)
    IKST_VehicleClaimSync.onPlayerConnect(player)
end

local function onConnected(player)
    IKST_VehicleClaimSync.onPlayerConnect(player)
end

if Events then
    if Events.OnCreatePlayer and Events.OnCreatePlayer.Add then
        Events.OnCreatePlayer.Add(onCreatePlayer)
    end
    if Events.OnConnected and Events.OnConnected.Add then
        Events.OnConnected.Add(onConnected)
    end
end
