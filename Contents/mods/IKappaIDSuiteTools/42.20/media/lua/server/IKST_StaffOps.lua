if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end
require "IKST_Shared"
require "IKST_Identity"
require "IKST_StaffCheats"
require "IKST_Clearance"
require "IKST_Waypoints"
require "IKST_WorldOps"
require "IKST_StaffOps_Admin"
require "IKST_StaffOps_Weather"
require "IKST_Args"

IKST_StaffOps = IKST_StaffOps or {}


-- Local constants (do not alias IKST_ClimatePresets at load - require order can leave it nil).
IKST_StaffOps.CLIMATE = {
    desat = 0,
    night = 2,
    rain = 3,
    fog = 5,
    wind = 6,
    cloud = 8,
}

IKST_StaffOps.WEATHER = {
    Clear = { rain = 0, cloud = 0, fog = 0, wind = 0 },
    Rain = { rain = 0.6, cloud = 0.8, fog = 0.1, wind = 0.4 },
    Storm = { rain = 1.0, cloud = 1.0, fog = 0.2, wind = 0.85 },
    Fog = { rain = 0, cloud = 0.4, fog = 0.85, wind = 0.1 },
}

function IKST_StaffOps.ensureClimatePresets()
    if IKST_ClimatePresets then
        return IKST_ClimatePresets
    end
    require "IKST_ClimatePresets"
    return IKST_ClimatePresets
end

function IKST_StaffOps.climateMgr()
    local cp = IKST_StaffOps.ensureClimatePresets()
    if cp and cp.climateMgr then
        return cp.climateMgr()
    end
    return nil
end

function IKST_StaffOps.transmitClimate()
    local cp = IKST_StaffOps.ensureClimatePresets()
    if cp and cp.transmitClimate then
        cp.transmitClimate()
    end
end

function IKST_StaffOps.setClimateFloat(idx, value)
    local cp = IKST_StaffOps.ensureClimatePresets()
    if cp and cp.setClimateFloat then
        return cp.setClimateFloat(idx, value)
    end
    return false
end

function IKST_StaffOps.releaseClimate()
    local cp = IKST_StaffOps.ensureClimatePresets()
    if cp and cp.releaseClimate then
        return cp.releaseClimate()
    end
    return false
end

function IKST_StaffOps.setTime(hour)
    if not IKST_ClimatePresets then
        require "IKST_ClimatePresets"
    end
    hour = IKST_ClimatePresets and IKST_ClimatePresets.normalizeHour(hour) or tonumber(hour)
    if hour == nil then
        return false, "no hour"
    end
    local ok, msg
    if IKST_ClimatePresets and IKST_ClimatePresets.applyTimeOfDayLocal then
        ok, msg = IKST_ClimatePresets.applyTimeOfDayLocal(hour)
    else
        return false, "no game time"
    end
    if not ok then
        return false, msg
    end
    -- Server decided the hour. Push display mirror so remote clients match without trusting clients.
    if IKST.isMultiplayerSession and IKST.isMultiplayerSession() and IKST_StaffOps.forEachOnline then
        IKST_StaffOps.forEachOnline(function(p)
            IKST.deliverClientCommand(p, IKST.CMD.timeMirror, { hour = hour })
        end)
    end
    return true, msg
end

function IKST_StaffOps.handle(command, player, args)
    args = args or {}

    if command == IKST.CMD.healSelf then
        return IKST_StaffOps.heal(player)
    end
    if command == IKST.CMD.feedSelf then
        return IKST_StaffOps.feed(player)
    end
    if command == IKST.CMD.cureSelf then
        return IKST_StaffOps.cure(player)
    end
    if command == IKST.CMD.godSelf then
        return IKST_StaffOps.toggleGod(player)
    end
    if command == IKST.CMD.invisSelf then
        return IKST_StaffOps.toggleInvisible(player)
    end
    if command == IKST.CMD.ghostSelf then
        return IKST_StaffOps.toggleGhost(player)
    end
    if command == IKST.CMD.noclipSelf then
        return IKST_StaffOps.toggleNoClip(player)
    end
    if command == IKST.CMD.tpCoords then
        local x, y, z = tonumber(args.x), tonumber(args.y), tonumber(args.z) or 0
        if not x or not y then
            return false, "enter X and Y"
        end
        IKST_StaffOps.teleportPlayer(player, x, y, z)
        return true, string.format("TP %d,%d,%d", math.floor(x), math.floor(y), math.floor(z))
    end
    if command == IKST.CMD.toggleSelfCheat then
        if not IKST_StaffOps.engineCheatsAllowed or not IKST_StaffOps.engineCheatsAllowed() then
            return false, "needs -debug in SP"
        end
        if not IKST_StaffCheats or not IKST_StaffCheats.toggle then
            return false, "cheats unavailable"
        end
        local cheatId = IKST_Args.readCheatId(args)
        if not cheatId or not IKST_StaffCheats.isValidId(cheatId) then
            return false, "invalid cheat"
        end
        return IKST_StaffCheats.toggle(player, cheatId)
    end
    if command == IKST.CMD.repairSelfGear then
        return IKST_StaffOps.repairGear(player)
    end
    if command == IKST.CMD.resetSelfMood then
        return IKST_StaffOps.resetMood(player)
    end
    if command == IKST.CMD.clearZombiesSelf then
        local radius = IKST_Args.readRadius(args, "radius", 20)
        return IKST_StaffOps.clearZombies(player, radius)
    end
    if command == IKST.CMD.clearanceIssueSelf then
        local zoneId = IKST_Args.readZoneId(args, "zoneId")
        if not zoneId then
            return false, "invalid zone id"
        end
        return IKST_StaffOps.issueClearance(player, zoneId)
    end
    if command == IKST.CMD.clearanceRevokeSelf then
        return IKST_StaffOps.revokeClearance(player)
    end
    if command == IKST.CMD.clearanceIssueTarget then
        local target = IKST_StaffOps.findPlayerByOnlineID(args.target)
        if not target then
            return false, "target offline"
        end
        local zoneId = IKST_Args.readZoneId(args, "zoneId")
        if not zoneId then
            return false, "invalid zone id"
        end
        local ok, msg = IKST_StaffOps.issueClearance(target, zoneId)
        if ok then
            return true, (msg or "issued") .. " -> " .. IKST_StaffOps.playerLabel(target)
        end
        return false, (msg or "issue failed") .. " (" .. IKST_StaffOps.playerLabel(target) .. ")"
    end
    if command == IKST.CMD.clearanceRevokeTarget then
        local target = IKST_StaffOps.findPlayerByOnlineID(args.target)
        if not target then
            return false, "target offline"
        end
        local ok, msg = IKST_StaffOps.revokeClearance(target)
        if ok then
            return true, (msg or "revoked") .. " -> " .. IKST_StaffOps.playerLabel(target)
        end
        return false, (msg or "revoke failed") .. " (" .. IKST_StaffOps.playerLabel(target) .. ")"
    end
    if command == IKST.CMD.giveItem then
        local ok, msg = IKST_StaffOps.giveItem(player, args.type, args.count)
        if ok and IKST_StaffHistory and type(IKST_StaffHistory.record) == "function" then
            IKST_StaffHistory.record(player, "give", tostring(msg or args.type), true)
        end
        return ok, msg
    end
    if command == IKST.CMD.duplicateItem then
        local ok, msg = IKST_StaffOps.duplicateHeldItem(player)
        if ok and IKST_StaffHistory and type(IKST_StaffHistory.record) == "function" then
            IKST_StaffHistory.record(player, "duplicate", tostring(msg or ""), true)
        end
        return ok, msg
    end
    if command == IKST.CMD.giveKit then
        return IKST_StaffOps.giveKit(player, args.kit)
    end
    if command == IKST.CMD.setTime then
        return IKST_StaffOps.setTime(args.hour)
    end
    if command == IKST.CMD.setWeather then
        return IKST_StaffOps.setWeather(args.preset)
    end
    if command == IKST.CMD.clearWeather then
        return IKST_StaffOps.clearWeather()
    end
    if command == IKST.CMD.clearZombies then
        return IKST_StaffOps.clearZombies(player, args.radius)
    end
    if command == IKST.CMD.economyGive then
        if not IKST_EconomyBridge or not IKST_EconomyBridge.giveMoney then
            return false, "enable Economy addon + PhoneShop"
        end
        local amount = IKST_Args.readAmount(args, "amount", 1, IKST.STAFF_ECONOMY_GIVE_MAX)
        if amount == nil then
            return false, "invalid amount (max " .. tostring(IKST.STAFF_ECONOMY_GIVE_MAX) .. ")"
        end
        return IKST_EconomyBridge.giveMoney(player, amount)
    end
    if command == IKST.CMD.economyBalance then
        if IKST_EconomyOps and IKST_EconomyOps.sendSnapshot then
            IKST_EconomyOps.sendSnapshot(player)
            return true, "Balance updated"
        end
        if not IKST_EconomyBridge or not IKST_EconomyBridge.getBalance then
            return false, "enable Economy addon + PhoneShop"
        end
        local bal = IKST_EconomyBridge.getBalance(player)
        if IKST_Economy and IKST_Economy.formatAmount then
            return true, "Balance: " .. IKST_Economy.formatAmount(bal)
        end
        return true, "Balance: " .. tostring(bal)
    end

    if command == IKST.CMD.economyReissueId then
        if not IKST_Access or not IKST_Access.canUseTools or not IKST_Access.canUseTools(player) then
            return false, "admin only"
        end
        return IKST_StaffOps.reissueBankId(player)
    end
    if command == IKST.CMD.economyReissueIdTarget then
        if not IKST_Access or not IKST_Access.canUseTools or not IKST_Access.canUseTools(player) then
            return false, "admin only"
        end
        local target = IKST_StaffOps.findPlayerByOnlineID(args.target)
        if not target then
            return false, "target offline"
        end
        local ok, msg = IKST_StaffOps.reissueBankId(target)
        local label = IKST_StaffOps.playerLabel(target)
        if ok then
            return true, (msg or "ID reissued") .. " -> " .. label
        end
        return false, (msg or "reissue failed") .. " (" .. label .. ")"
    end

    if command == IKST.CMD.healTarget then
        local target = IKST_StaffOps.findPlayerByOnlineID(args.target)
        if not target then
            return false, "target offline"
        end
        local ok, msg = IKST_StaffOps.heal(target)
        return ok, msg .. " (" .. IKST_StaffOps.playerLabel(target) .. ")"
    end
    if command == IKST.CMD.bringTarget then
        local target = IKST_StaffOps.findPlayerByOnlineID(args.target)
        if not target then
            return false, "target offline"
        end
        IKST_StaffOps.teleportPlayer(target, player:getX(), player:getY(), player:getZ())
        return true, "Brought " .. IKST_StaffOps.playerLabel(target)
    end
    if command == IKST.CMD.tpToTarget then
        local target = IKST_StaffOps.findPlayerByOnlineID(args.target)
        if not target then
            return false, "target offline"
        end
        IKST_StaffOps.teleportPlayer(player, target:getX(), target:getY(), target:getZ())
        return true, "TP to " .. IKST_StaffOps.playerLabel(target)
    end
    if command == IKST.CMD.giveTarget then
        local target = IKST_StaffOps.findPlayerByOnlineID(args.target)
        if not target then
            return false, "target offline"
        end
        local ok, msg = IKST_StaffOps.giveItem(target, args.type, args.count)
        if ok and IKST_StaffHistory and type(IKST_StaffHistory.record) == "function" then
            IKST_StaffHistory.record(player, "give", tostring(msg or args.type)
                .. " -> " .. IKST_StaffOps.playerLabel(target), true)
        end
        return ok, msg .. " -> " .. IKST_StaffOps.playerLabel(target)
    end
    if command == IKST.CMD.economyGiveTarget then
        if not IKST_EconomyBridge or not IKST_EconomyBridge.giveMoney then
            return false, "enable Economy addon + PhoneShop"
        end
        local target = IKST_StaffOps.findPlayerByOnlineID(args.target)
        if not target then
            return false, "target offline"
        end
        local amount = IKST_Args.readAmount(args, "amount", 1, IKST.STAFF_ECONOMY_GIVE_MAX)
        if amount == nil then
            return false, "invalid amount (max " .. tostring(IKST.STAFF_ECONOMY_GIVE_MAX) .. ")"
        end
        local ok, msg = IKST_EconomyBridge.giveMoney(target, amount)
        return ok, msg .. " -> " .. IKST_StaffOps.playerLabel(target)
    end

    if command == IKST.CMD.healAll then
        return IKST_StaffOps.healAll()
    end
    if command == IKST.CMD.feedAll then
        return IKST_StaffOps.feedAll()
    end
    if command == IKST.CMD.cureAll then
        return IKST_StaffOps.cureAll()
    end
    if command == IKST.CMD.tpAllToMe then
        return IKST_StaffOps.tpAllToMe(player)
    end
    if command == IKST.CMD.saveWaypoint then
        return IKST_Waypoints.save(player, args and args.name)
    end
    if command == IKST.CMD.delWaypoint then
        return IKST_Waypoints.delete(args and args.name)
    end
    if command == IKST.CMD.tpWaypoint then
        local wp = IKST_Waypoints.find(args and args.name)
        if not wp then
            return false, "no such waypoint"
        end
        if not IKST_StaffOps.teleportPlayer(player, wp.x, wp.y, wp.z) then
            return false, "bad waypoint coords"
        end
        return true, "TP '" .. wp.name .. "'"
    end
    if command == IKST.CMD.feedTarget then
        local target = IKST_StaffOps.findPlayerByOnlineID(args.target)
        if not target then
            return false, "target offline"
        end
        local ok, msg = IKST_StaffOps.feed(target)
        return ok, msg .. " (" .. IKST_StaffOps.playerLabel(target) .. ")"
    end
    if command == IKST.CMD.cureTarget then
        local target = IKST_StaffOps.findPlayerByOnlineID(args.target)
        if not target then
            return false, "target offline"
        end
        local ok, msg = IKST_StaffOps.cure(target)
        return ok, msg .. " (" .. IKST_StaffOps.playerLabel(target) .. ")"
    end
    if command == IKST.CMD.godTarget then
        local target = IKST_StaffOps.findPlayerByOnlineID(args.target)
        if not target then
            return false, "target offline"
        end
        local ok, msg = IKST_StaffOps.toggleGod(target)
        if ok then
            IKST_StaffOps.syncStaffModesToClient(target)
        end
        return ok, msg .. " (" .. IKST_StaffOps.playerLabel(target) .. ")"
    end

    return false, "unknown staff command"
end

local function onStaffPlayerReady(player)
    -- Dedicated/listen server JVM, or integrated SP (not a remote MP client).
    if IKST.isRemoteClient and IKST.isRemoteClient() then
        return
    end
    if not player then
        return
    end
    IKST_StaffOps.applyStaffModes(player)
    IKST_StaffOps.syncStaffModesToClient(player)
    if not IKST_StaffCheats then
        require "IKST_StaffCheats"
    end
    if IKST_StaffCheats and IKST_StaffCheats.reapplyStored then
        IKST_StaffCheats.reapplyStored(player)
    end
    if IKST_StaffCheats and IKST_StaffCheats.syncAllToClient then
        IKST_StaffCheats.syncAllToClient(player)
    end
    if not IKST_Rewind then
        require "IKST_Rewind"
    end
    if IKST_Rewind and IKST_Rewind.syncCountToClient then
        IKST_Rewind.syncCountToClient(player)
    end
end

if Events then
    if Events.OnCreatePlayer and Events.OnCreatePlayer.Add then
        Events.OnCreatePlayer.Add(function(playerIndex)
            local player = getSpecificPlayer and getSpecificPlayer(playerIndex)
            onStaffPlayerReady(player)
        end)
    end
    if Events.OnConnected and Events.OnConnected.Add then
        Events.OnConnected.Add(function(player)
            onStaffPlayerReady(player)
        end)
    end
end
