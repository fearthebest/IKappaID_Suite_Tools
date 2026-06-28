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
IKST_IdentityServer._seen = IKST_IdentityServer._seen or {}

local function playerKey(player)
    if not player then
        return nil
    end
    if player.getUsername then
        local name = player:getUsername()
        if name and name ~= "" then
            return name
        end
    end
    if player.getOnlineID then
        return "id:" .. tostring(player:getOnlineID())
    end
    return nil
end

local function playerInWorld(player)
    if not player then
        return false
    end
    if player.isDead and player:isDead() then
        return false
    end
    if player.getSquare then
        local sq = player:getSquare()
        if sq then
            return true
        end
    end
    if player.getX and player.getY then
        local x = player:getX()
        local y = player:getY()
        if x and y and (x ~= 0 or y ~= 0) then
            return true
        end
    end
    return false
end

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

local function tryConnect(player)
    if not playerInWorld(player) then
        return
    end
    local key = playerKey(player)
    if not key or IKST_IdentityServer._seen[key] then
        return
    end
    IKST_IdentityServer._seen[key] = true
    IKST_IdentityServer.onPlayerConnect(player)
end

local function pruneDisconnected()
    local online = {}
    local list = getOnlinePlayers and getOnlinePlayers()
    if list and list.size then
        for i = 0, list:size() - 1 do
            local p = list:get(i)
            local key = playerKey(p)
            if key then
                online[key] = true
            end
        end
    else
        local sp = getSpecificPlayer and getSpecificPlayer(0)
        local key = playerKey(sp)
        if key then
            online[key] = true
        end
    end
    for key in pairs(IKST_IdentityServer._seen) do
        if not online[key] then
            IKST_IdentityServer._seen[key] = nil
        end
    end
end

local function foreachOnlinePlayer(fn)
    local list = getOnlinePlayers and getOnlinePlayers()
    if list and list.size then
        for i = 0, list:size() - 1 do
            local p = list:get(i)
            if p then
                fn(p)
            end
        end
        return
    end
    local sp = getSpecificPlayer and getSpecificPlayer(0)
    if sp then
        fn(sp)
    end
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
    IKST_Identity.invalidateActiveCard(character)
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
            pruneDisconnected()
            foreachOnlinePlayer(tryConnect)
        end)
    end
end
