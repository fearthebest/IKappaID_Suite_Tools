-- Per-player command rate limits (server JVM only).

if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end

require "IKST_Shared"
require "IKST_Access"
require "IKST_Plugins"

IKST_RateLimit = IKST_RateLimit or {}
IKST_RateLimit._state = IKST_RateLimit._state or {}
IKST_RateLimit._lockFails = IKST_RateLimit._lockFails or {}

local GROUPS = {
    economy_write = { intervalMs = 400, burst = 1 },
    economy_read = { intervalMs = 1000, burst = 1 },
    staff_give = { intervalMs = 1000, burst = 1 },
    staff_tp = { intervalMs = 1000, burst = 1 },
    staff_power = { intervalMs = 1000, burst = 1 },
    staff_world = { intervalMs = 1000, burst = 1 },
    tiles_edit = { intervalMs = 100, burst = 15 },
    tiles_batch = { intervalMs = 1500, burst = 2 },
    loot_edit = { intervalMs = 100, burst = 15 },
    threat_cull = { intervalMs = 5000, burst = 1 },
    claim_write = { intervalMs = 1000, burst = 1 },
    lock_auth = { intervalMs = 12000, burst = 5 },
    list_query = { intervalMs = 1000, burst = 1 },
    utility = { intervalMs = 1000, burst = 1 },
    field_recovery = { intervalMs = 60000, burst = 1 },
}

function IKST_RateLimit.enabled()
    if not IKST_Access.sandboxBool then
        return true
    end
    return IKST_Access.sandboxBool("RateLimitEnabled", true)
end

function IKST_RateLimit.isTilesBatchCommand(command)
    if command == IKST.CMD.cleanupRadius or command == IKST.CMD.cleanupCube
        or command == IKST.CMD.cleanupRoom or command == IKST.CMD.cleanupBuilding
        or command == IKST.CMD.cleanupVegetation then
        return true
    end
    if IKST.AUTO_COMMANDS and IKST.AUTO_COMMANDS[command] then
        return true
    end
    return false
end

function IKST_RateLimit.isTilesAdminCommand(command)
    if not IKST.Plugins or not IKST.Plugins.findCommandSpec then
        return false
    end
    local pluginId, _, tier = IKST.Plugins.findCommandSpec(command)
    if pluginId ~= "tiles" or tier ~= "admin" then
        return false
    end
    return true
end

function IKST_RateLimit.isLootAdminCommand(command)
    if not IKST.Plugins or not IKST.Plugins.findCommandSpec then
        return false
    end
    local pluginId, _, tier = IKST.Plugins.findCommandSpec(command)
    if pluginId ~= "loot" or tier ~= "admin" then
        return false
    end
    return true
end

function IKST_RateLimit.isAddonAdminEditCommand(command)
    if IKST_RateLimit.isTilesBatchCommand(command) then
        return false
    end
    if not IKST.Plugins or not IKST.Plugins.findCommandSpec then
        return false
    end
    local pluginId, _, tier = IKST.Plugins.findCommandSpec(command)
    if tier ~= "admin" or not pluginId then
        return false
    end
    if pluginId == "economy" or pluginId == "tiles" or pluginId == "loot" then
        return false
    end
    return true
end

function IKST_RateLimit.groupForCommand(command)
    if IKST_RateLimit.isTilesBatchCommand(command) then
        return "tiles_batch"
    end
    if IKST_RateLimit.isLootAdminCommand(command) then
        return "loot_edit"
    end
    if IKST_RateLimit.isTilesAdminCommand(command) then
        return "tiles_edit"
    end
    if IKST_RateLimit.isAddonAdminEditCommand(command) then
        return "tiles_edit"
    end
    if command == IKST.CMD.threatCull then
        return "threat_cull"
    end
    if command == IKST.CMD.quickWater or command == IKST.CMD.quickPower then
        return "utility"
    end
    if command == IKST.CMD.giveItem or command == IKST.CMD.giveKit or command == IKST.CMD.giveTarget then
        return "staff_give"
    end
    if command == IKST.CMD.tpCoords or command == IKST.CMD.bringTarget or command == IKST.CMD.tpToTarget
        or command == IKST.CMD.tpWaypoint or command == IKST.CMD.tpAllToMe or command == IKST.CMD.safehouseTp then
        return "staff_tp"
    end
    if command == IKST.CMD.healSelf or command == IKST.CMD.feedSelf or command == IKST.CMD.cureSelf
        or command == IKST.CMD.godSelf or command == IKST.CMD.invisSelf or command == IKST.CMD.ghostSelf
        or command == IKST.CMD.clearZombies or command == IKST.CMD.healTarget or command == IKST.CMD.feedTarget
        or command == IKST.CMD.cureTarget or command == IKST.CMD.godTarget or command == IKST.CMD.healAll
        or command == IKST.CMD.feedAll or command == IKST.CMD.cureAll
        or command == IKST.CMD.catchTarget or command == IKST.CMD.catchPlayer
        or command == IKST.CMD.releaseTarget or command == IKST.CMD.releasePlayer then
        return "staff_power"
    end
    if command == IKST.CMD.quickSave or command == IKST.CMD.quickBroadcast
        or command == IKST.CMD.backupSafehouses or command == IKST.CMD.restoreSafehouses
        or command == IKST.CMD.setWeather or command == IKST.CMD.clearWeather or command == IKST.CMD.setTime then
        return "staff_world"
    end
    if command == IKST.CMD.lockTryUnlock or command == IKST.CMD.lockInstallKeypad then
        return "lock_auth"
    end
    if command == IKST.CMD.safehouseList or command == IKST.CMD.vehicleClaimList
        or command == IKST.CMD.vehicleClaimNearby
        or command == IKST.CMD.staffListPlayers or command == IKST.CMD.listWaypoints
        or command == IKST.CMD.dumpPlayers or command == IKST.CMD.threatPopulation
        or command == IKST.CMD.economySnapshot or command == IKST.CMD.economyVendList
        or command == IKST.CMD.protectList or command == IKST.CMD.vehicleList
        or command == IKST.CMD.briefingFetch then
        return "list_query"
    end
    if command == IKST.CMD.vehicleFieldRecovery then
        return "field_recovery"
    end
    if command == IKST.CMD.journalRecord or command == IKST.CMD.journalRestore
        or command == IKST.CMD.safehouseClaim or command == IKST.CMD.safehouseRelease
        or command == IKST.CMD.vehicleClaim or command == IKST.CMD.vehicleReleaseClaim
        or command == IKST.CMD.vehicleClaimSetLabel or command == IKST.CMD.vehicleClaimSetPerms
        or command == IKST.CMD.safehouseAddMember or command == IKST.CMD.safehouseRemoveMember
        or command == IKST.CMD.safehouseClaimSetPerms then
        return "claim_write"
    end
    if command == IKST.CMD.economyDeposit or command == IKST.CMD.economyWithdraw
        or command == IKST.CMD.economyWire or command == IKST.CMD.economyExchange
        or command == IKST.CMD.economyExchangeAll or command == IKST.CMD.economyIdCardReissue
        or command == IKST.CMD.economyVendBuy or command == IKST.CMD.economyVendSetPrice
        or command == IKST.CMD.economyVendClaim or command == IKST.CMD.economyShopPlace
        or command == IKST.CMD.economyVendDisable then
        return "economy_write"
    end
  return "staff_world"
end

function IKST_RateLimit.playerKey(player)
    if not player then
        return "?"
    end
    if not IKST_Identity then
        require "IKST_Identity"
    end
    if IKST_Identity and IKST_Identity.accountKey then
        local account = IKST_Identity.accountKey(player)
        if account and account ~= "" and account ~= "local:anonymous" then
            return account
        end
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
    return "?"
end

function IKST_RateLimit.nowMs()
    if getTimeInMillis then
        return getTimeInMillis()
    end
    return 0
end

function IKST_RateLimit.check(player, command)
    if not IKST_RateLimit.enabled() then
        return true, 0, nil
    end
    local group = IKST_RateLimit.groupForCommand(command)
    local cfg = GROUPS[group] or GROUPS.staff_world
    local key = IKST_RateLimit.playerKey(player)
    IKST_RateLimit._state[key] = IKST_RateLimit._state[key] or {}
    local row = IKST_RateLimit._state[key][group] or { lastMs = 0, count = 0, windowStart = 0 }
    local now = IKST_RateLimit.nowMs()

    if row.lockoutUntil and now < row.lockoutUntil then
        return false, row.lockoutUntil - now, "rate_limit"
    end

    if now - row.windowStart >= cfg.intervalMs then
        row.windowStart = now
        row.count = 0
    end
    row.count = row.count + 1
    if row.count > cfg.burst then
        local retry = cfg.intervalMs - (now - row.windowStart)
        if retry < 1 then
            retry = cfg.intervalMs
        end
        IKST_RateLimit._state[key][group] = row
        return false, retry, "rate_limit"
    end

    row.lastMs = now
    IKST_RateLimit._state[key][group] = row
    return true, 0, nil
end

function IKST_RateLimit.lockKey(x, y, z)
    return tostring(math.floor(tonumber(x) or 0)) .. ","
        .. tostring(math.floor(tonumber(y) or 0)) .. ","
        .. tostring(math.floor(tonumber(z) or 0))
end

function IKST_RateLimit.recordLockFail(player, x, y, z)
    local maxFails = 20
    if IKST_Access.sandboxInt then
        maxFails = IKST_Access.sandboxInt("LockMaxAttempts", 20, 5, 100)
    end
    local lockoutMs = 60000
    local lk = IKST_RateLimit.lockKey(x, y, z)
    local pk = IKST_RateLimit.playerKey(player)
    IKST_RateLimit._lockFails[pk] = IKST_RateLimit._lockFails[pk] or {}
    local row = IKST_RateLimit._lockFails[pk][lk] or { fails = 0 }
    row.fails = row.fails + 1
    if row.fails >= maxFails then
        row.lockoutUntil = IKST_RateLimit.nowMs() + lockoutMs
        row.fails = 0
    end
    IKST_RateLimit._lockFails[pk][lk] = row
    local group = "lock_auth"
    IKST_RateLimit._state[pk] = IKST_RateLimit._state[pk] or {}
    local g = IKST_RateLimit._state[pk][group] or {}
    g.lockoutUntil = row.lockoutUntil
    IKST_RateLimit._state[pk][group] = g
end

function IKST_RateLimit.clearLockFails(player, x, y, z)
    local pk = IKST_RateLimit.playerKey(player)
    local lk = IKST_RateLimit.lockKey(x, y, z)
    if IKST_RateLimit._lockFails[pk] then
        IKST_RateLimit._lockFails[pk][lk] = nil
    end
end
