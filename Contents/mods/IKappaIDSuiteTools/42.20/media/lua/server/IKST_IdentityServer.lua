-- Server hooks: identity migration, ID card issue on connect.

if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end

require "IKST_Shared"
require "IKST_Identity"
require "IKST_ClaimPolicy"
require "IKST_VehicleClaim"
require "IKST_ServerPlayers"

IKST_IdentityServer = IKST_IdentityServer or {}
IKST_IdentityServer._seen = IKST_IdentityServer._seen or {}

local function tryConnect(player)
    if not IKST_ServerPlayers.playerInWorld(player) then
        return
    end
    local key = IKST_ServerPlayers.playerKey(player)
    if not key or IKST_IdentityServer._seen[key] then
        return
    end
    IKST_IdentityServer._seen[key] = true
    if type(IKST_ServerPlayers.markConnected) == "function" then
        IKST_ServerPlayers.markConnected(player)
    end
    IKST_IdentityServer.onPlayerConnect(player)
end

local function resolvePlayer(index)
    if getSpecificPlayer then
        return getSpecificPlayer(index)
    end
    return nil
end

local function onCreatePlayer(playerIndex)
    tryConnect(resolvePlayer(playerIndex))
end

local function onConnected(player)
    tryConnect(player)
end

local function onCharacterDeath(character)
    if not character or not instanceof or not instanceof(character, "IsoPlayer") then
        return
    end
    if not IKST_Economy or not IKST_Economy.idCardBanking or not IKST_Economy.isEconomyActive
        or not IKST_Economy.isEconomyActive() or not IKST_Economy.idCardBanking() then
        return
    end
    if IKST_EconomyIdentity and IKST_EconomyIdentity.invalidateActiveCard then
        IKST_EconomyIdentity.invalidateActiveCard(character)
    end
end

function IKST_IdentityServer.onGameStart()
    if not IKST.runsOnServerJvm or not IKST.runsOnServerJvm() then
        return
    end
    if IKST_Economy and IKST_Economy.getStore and IKST_EconomyIdentity
        and IKST_EconomyIdentity.migrateEconomyAccounts then
        local store = IKST_Economy.getStore()
        if store then
            IKST_EconomyIdentity.migrateEconomyAccounts(store)
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
        and IKST_Economy.isEconomyActive() and IKST_Economy.idCardBanking()
        and IKST_EconomyIdentity and IKST_EconomyIdentity.strictEnsureIdCardOnConnect then
        IKST_EconomyIdentity.strictEnsureIdCardOnConnect(player)
    end
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
    if Events.OnCharacterDeath then
        Events.OnCharacterDeath.Add(onCharacterDeath)
    end
    if Events.OnTick then
        Events.OnTick.Add(function()
            IKST_IdentityServer._tick = (IKST_IdentityServer._tick or 0) + 1
            if IKST_IdentityServer._tick % 15 ~= 0 then
                return
            end
            IKST_ServerPlayers.pruneDisconnected(IKST_IdentityServer._seen)
            IKST_ServerPlayers.foreachOnlinePlayer(tryConnect)
        end)
    end
end
