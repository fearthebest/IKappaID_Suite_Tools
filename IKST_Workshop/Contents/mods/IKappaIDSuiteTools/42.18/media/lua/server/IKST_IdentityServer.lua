-- Server hooks: identity migration, ID card issue on connect.

if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end

require "IKST_Shared"
require "IKST_Identity"
require "IKST_ClaimPolicy"
require "IKST_VehicleClaim"

IKST_IdentityServer = IKST_IdentityServer or {}

function IKST_IdentityServer.onGameStart()
    if not IKST.runsOnServerJvm or not IKST.runsOnServerJvm() then
        return
    end
    if IKST_Economy and IKST_Economy.getStore then
        local store = IKST_Economy.getStore()
        if store then
            IKST_Identity.migrateEconomyAccounts(store)
            if IKST_Economy.persistStore then
                IKST_Economy.persistStore()
            end
        end
    end
end

function IKST_IdentityServer.onPlayerConnect(player)
    if not player then
        return
    end
    IKST_Identity.migratePlayerOnConnect(player)
    if IKST_Economy and IKST_Economy.idCardBanking and IKST_Economy.isEconomyActive
        and IKST_Economy.isEconomyActive() and IKST_Economy.idCardBanking() then
        IKST_Identity.strictEnsureIdCardOnConnect(player)
    end
end

local function resolvePlayer(index)
    if getSpecificPlayer then
        return getSpecificPlayer(index)
    end
    return nil
end

local function onCreatePlayer(playerIndex)
    local player = resolvePlayer(playerIndex)
    IKST_IdentityServer.onPlayerConnect(player)
end

local function onConnected(player)
    IKST_IdentityServer.onPlayerConnect(player)
end

local function onPlayerDeath(player)
    if not player then
        return
    end
    if not IKST_Economy or not IKST_Economy.idCardBanking or not IKST_Economy.isEconomyActive
        or not IKST_Economy.isEconomyActive() or not IKST_Economy.idCardBanking() then
        return
    end
    IKST_Identity.invalidateActiveCard(player)
end

if Events then
    if Events.OnGameStart then
        Events.OnGameStart.Add(IKST_IdentityServer.onGameStart)
    end
    if Events.OnCreatePlayer then
        Events.OnCreatePlayer.Add(onCreatePlayer)
    end
    if Events.OnConnected then
        Events.OnConnected.Add(onConnected)
    end
    if Events.OnPlayerDeath then
        Events.OnPlayerDeath.Add(onPlayerDeath)
    end
end
