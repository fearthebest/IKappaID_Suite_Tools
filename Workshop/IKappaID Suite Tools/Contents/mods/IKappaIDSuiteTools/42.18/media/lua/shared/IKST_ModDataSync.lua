-- MP global ModData transmit + client receive ([Mod data](https://pzwiki.net/wiki/Mod_data)).

require "IKST_Shared"

IKST_ModDataSync = IKST_ModDataSync or {}

IKST.ModDataKeys = IKST.ModDataKeys or {
    Protect = "IKST_Protect",
    WorldRules = "IKST_WorldRules",
    VehicleClaim = "IKST_VehicleClaim",
    SafehouseClaim = "IKST_SafehouseClaim",
    Locks = "IKST_Locks",
    Waypoints = "IKST_Waypoints",
}

function IKST.transmitModData(key)
    if not key or not ModData or not ModData.transmit then
        return
    end
    if not IKST.isMultiplayerSession() or not IKST.runsOnServerJvm() then
        return
    end
    ModData.transmit(key)
end

function IKST_ModDataSync.apply(key, data)
    if not key or not data or data == false then
        return
    end
    if ModData and ModData.add then
        ModData.add(key, data)
    end
end

function IKST_ModDataSync.isSyncedKey(key)
    return key == IKST.ModDataKeys.Protect
        or key == IKST.ModDataKeys.WorldRules
        or key == IKST.ModDataKeys.VehicleClaim
        or key == IKST.ModDataKeys.SafehouseClaim
        or key == IKST.ModDataKeys.Locks
        or key == IKST.ModDataKeys.Waypoints
end

function IKST_ModDataSync.installClient()
    if IKST_ModDataSync.clientInstalled then
        return
    end
    if not Events or not Events.OnReceiveGlobalModData or not Events.OnReceiveGlobalModData.Add then
        return
    end
    Events.OnReceiveGlobalModData.Add(function(key, data)
        if IKST_ModDataSync.isSyncedKey(key) then
            IKST_ModDataSync.apply(key, data)
        end
    end)
    IKST_ModDataSync.clientInstalled = true
end

function IKST_ModDataSync.transmitAll()
    if not IKST.ModDataKeys then
        return
    end
    for _, key in pairs(IKST.ModDataKeys) do
        if IKST.transmitModData then
            IKST.transmitModData(key)
        end
    end
end

function IKST_ModDataSync.installServer()
    if IKST_ModDataSync.serverInstalled then
        return
    end
    if not IKST.runsOnServerJvm or not IKST.runsOnServerJvm() then
        return
    end
    local function push()
        if IKST.isMultiplayerSession and IKST.isMultiplayerSession() then
            IKST_ModDataSync.transmitAll()
        end
    end
    if Events and Events.OnGameStart and Events.OnGameStart.Add then
        Events.OnGameStart.Add(push)
    end
    if Events and Events.OnConnected and Events.OnConnected.Add then
        Events.OnConnected.Add(push)
    end
    IKST_ModDataSync.serverInstalled = true
end

IKST_ModDataSync.installServer()
