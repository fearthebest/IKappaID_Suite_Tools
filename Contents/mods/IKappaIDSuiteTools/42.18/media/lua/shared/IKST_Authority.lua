-- IKST MP authority (IKFRVP physics / trunk pattern).
-- Server JVM computes and mutates; remote + listen-host client JVMs mirror server payloads only.
-- See: https://pzwiki.net/wiki/Networking and https://pzwiki.net/wiki/Mod_data

require "IKST_Shared"

IKST_Authority = IKST_Authority or {}

-- World edits, vehicle pose commits, synced ModData writes (claims, protect, etc.).
function IKST_Authority.mayMutateWorldState()
    if IKST.isRemoteClient and IKST.isRemoteClient() then
        return false
    end
    if IKST.isListenHostClient and IKST.isListenHostClient() then
        return false
    end
    if IKST.isMultiplayerSession and IKST.isMultiplayerSession() then
        return IKST.runsOnServerJvm and IKST.runsOnServerJvm()
    end
    return true
end

function IKST_Authority.mayMutateSyncedModData()
    return IKST_Authority.mayMutateWorldState()
end

-- IKFRVP remote clients: execute server mirror payloads only (no local authority).
function IKST_Authority.usesMirrorExecuteClient()
    return IKST.isRemoteClient and IKST.isRemoteClient()
end

-- IKST vehicle pose mirror: remote MP clients + listen-host client JVM.
function IKST_Authority.usesVehicleMirrorClient()
    if type(isClient) ~= "function" or not isClient() then
        return false
    end
    if IKST.isMultiplayerSession and IKST.isMultiplayerSession() then
        return (IKST.isRemoteClient and IKST.isRemoteClient())
            or (IKST.isListenHostClient and IKST.isListenHostClient())
    end
    return false
end

function IKST_Authority.clientReadsMirroredStateOnly()
    return IKST.isRemoteClient and IKST.isRemoteClient()
end

function IKST_Authority.guardServerMutate()
    return IKST_Authority.mayMutateSyncedModData()
end

-- UI permission flags must come from server list/mirror commands, not local guesses.
function IKST_Authority.uiUsesServerSnapshots()
    return IKST.isMultiplayerSession and IKST.isMultiplayerSession()
end

function IKST_Authority.mpClientEnforcementActive()
    return IKST_Authority.clientReadsMirroredStateOnly()
end

IKST.mayMutateWorldState = IKST_Authority.mayMutateWorldState
IKST.clientExecutesServerMirror = IKST_Authority.usesMirrorExecuteClient
