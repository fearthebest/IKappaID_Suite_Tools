-- Server push sync for safehouse claims (bootstrap + revisioned patches + ping).

if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end

require "IKST_Shared"
require "IKST_SafehouseClaim"
require "IKST_SafehouseClaimMirror"
require "IKST_Access"

IKST_SafehouseClaimSync = IKST_SafehouseClaimSync or {}

function IKST_SafehouseClaimSync.active()
    return IKST.runsOnServerJvm and IKST.runsOnServerJvm()
        and IKST.isMultiplayerSession and IKST.isMultiplayerSession()
end

function IKST_SafehouseClaimSync.getRev()
    local data = IKST_SafehouseClaim.store()
    return tonumber(data.syncRev) or 0
end

function IKST_SafehouseClaimSync.bumpRev()
    local data = IKST_SafehouseClaim.store()
    data.syncRev = (tonumber(data.syncRev) or 0) + 1
    return data.syncRev
end

function IKST_SafehouseClaimSync.buildClaimsMap(viewer)
    local data = IKST_SafehouseClaim.store()
    local claims = {}
    local count = 0
    for k, entry in pairs(data.byKey or {}) do
        if type(entry) == "table" then
            local plain
            if viewer and type(IKST_SafehouseClaim.copyEntryForViewer) == "function" then
                plain = IKST_SafehouseClaim.copyEntryForViewer(entry, viewer)
            else
                plain = IKST_SafehouseClaim.copyEntryPlain(entry)
            end
            if plain then
                claims[k] = plain
                count = count + 1
            end
        end
    end
    return claims, count
end

function IKST_SafehouseClaimSync.bootstrapPayload(viewer)
    local claims, count = IKST_SafehouseClaimSync.buildClaimsMap(viewer)
    return {
        rev = IKST_SafehouseClaimSync.getRev(),
        count = count,
        claims = claims,
    }
end

function IKST_SafehouseClaimSync.sendBootstrap(player)
    if not IKST_SafehouseClaimSync.active() or not player then
        return
    end
    IKST.deliverClientCommand(player, IKST.CMD.safehouseClaimBootstrap, IKST_SafehouseClaimSync.bootstrapPayload(player))
end

function IKST_SafehouseClaimSync.broadcastBootstrap()
    if not IKST_SafehouseClaimSync.active() then
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
            IKST_SafehouseClaimSync.sendBootstrap(p)
        end
    end
end

function IKST_SafehouseClaimSync.broadcastPatch(payload)
    if not IKST_SafehouseClaimSync.active() or not payload then
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
                claimKey = payload.claimKey,
            }
            if rawEntry and type(IKST_SafehouseClaim.copyEntryForViewer) == "function" then
                out.entry = IKST_SafehouseClaim.copyEntryForViewer(rawEntry, p)
            elseif rawEntry then
                out.entry = IKST_SafehouseClaim.copyEntryPlain(rawEntry)
            end
            local _, viewerCount = IKST_SafehouseClaimSync.buildClaimsMap(p)
            out.count = viewerCount
            IKST.deliverClientCommand(p, IKST.CMD.safehouseClaimPatch, out)
        end
    end
end

function IKST_SafehouseClaimSync.afterMutate(op, claimKey, entry)
    if not IKST_SafehouseClaimSync.active() then
        return
    end
    op = tostring(op or "set")
    if op == "purge" or op == "bootstrap" then
        IKST_SafehouseClaimSync.bumpRev()
        IKST_SafehouseClaimSync.broadcastBootstrap()
        return
    end
    local rev = IKST_SafehouseClaimSync.bumpRev()
    IKST_SafehouseClaimSync.broadcastPatch({
        rev = rev,
        op = op,
        claimKey = claimKey and tostring(claimKey) or nil,
        entry = entry,
    })
end

function IKST_SafehouseClaimSync.handlePing(player, args)
    if not IKST_SafehouseClaimSync.active() or not player then
        return
    end
    args = args or {}
    local serverRev = IKST_SafehouseClaimSync.getRev()
    local _, count = IKST_SafehouseClaimSync.buildClaimsMap(player)
    local clientRev = tonumber(args.rev) or 0
    local clientCount = tonumber(args.count)
    if clientRev ~= serverRev or (clientCount ~= nil and clientCount ~= count) then
        IKST_SafehouseClaimSync.sendBootstrap(player)
        return
    end
    IKST.deliverClientCommand(player, IKST.CMD.safehouseClaimPingResult, {
        rev = serverRev,
        count = count,
    })
end

function IKST_SafehouseClaimSync.onPlayerConnect(player)
    if not IKST_SafehouseClaimSync.active() then
        return
    end
    IKST_SafehouseClaimSync.sendBootstrap(player)
end

local function resolvePlayer(index)
    if getSpecificPlayer then
        return getSpecificPlayer(index)
    end
    return nil
end

local function onCreatePlayer(playerIndex)
    local player = resolvePlayer(playerIndex)
    IKST_SafehouseClaimSync.onPlayerConnect(player)
end

local function onConnected(player)
    IKST_SafehouseClaimSync.onPlayerConnect(player)
end

if Events then
    if Events.OnCreatePlayer and Events.OnCreatePlayer.Add then
        Events.OnCreatePlayer.Add(onCreatePlayer)
    end
    if Events.OnConnected and Events.OnConnected.Add then
        Events.OnConnected.Add(onConnected)
    end
end
