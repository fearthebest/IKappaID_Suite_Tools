-- Dedicated / listen-server JVM only (not remote MP client).
if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end
require "IKST_Shared"
require "IKST_Plugins"
require "IKST_Utility"
require "IKST_Access"
require "IKST_Args"
require "IKST_ServerGate"
require "IKST_WorldOps"
require "IKST_VehicleUtil"
require "IKST_StaffOps"
require "IKST_Waypoints"
require "IKST_GuardOps"
require "IKST_ClaimPolicy"
require "IKST_RestoreServer"
require "IKST_RateLimit"
require "IKST_AuditLog"
require "IKST_BriefingServer"
require "IKST_ArrivalServer"

IKST_Server = IKST_Server or {}

local function readCoord(args, key)
    return IKST_Args.readCoord(args, key)
end

function IKST_Server.logSuccess(player, command, args, msg)
    if IKST_AuditLog and IKST_AuditLog.record then
        local logIt = false
        if IKST.STAFF_COMMANDS and IKST.STAFF_COMMANDS[command] then
            logIt = true
        elseif command == IKST.CMD.backupSafehouses or command == IKST.CMD.restoreSafehouses
            or command == IKST.CMD.quickSave or command == IKST.CMD.quickBroadcast
            or command == IKST.CMD.quickWater or command == IKST.CMD.quickPower then
            logIt = true
        elseif command == IKST.CMD.economyDeposit or command == IKST.CMD.economyWithdraw
            or command == IKST.CMD.economyWire or command == IKST.CMD.economyVendBuy
            or command == IKST.CMD.economyAtmPlace or command == IKST.CMD.economyVendEnable then
            logIt = true
        elseif command == IKST.CMD.giveItem or command == IKST.CMD.giveTarget then
            logIt = true
        end
        if logIt then
            IKST_AuditLog.record(player, command, args, true, msg)
        end
    end
end

function IKST_Server.handleUtilityToggle(playerObj, command, args)
    local which = command == IKST.CMD.quickWater and "water" or "power"
    local currentlyOn
    if which == "water" then
        currentlyOn = IKST.isWaterOn()
    else
        currentlyOn = IKST.isPowerOn()
    end
    local wantOn = not currentlyOn
    if args and args.on ~= nil then
        wantOn = args.on == true
    end
    if not IKST.setUtilityOnServer(which, wantOn) then
        return false, "utility toggle failed"
    end
    IKST_Utility.broadcastSync()
    local state = wantOn and "ON" or "OFF"
    return true, which .. ": " .. state
end

function IKST_Server.handleCommand(moduleName, command, playerObj, args)
    if moduleName ~= IKST.MODULE then
        return
    end

    args = args or {}

    local okAuth, reason, meta = IKST_ServerGate.authorize(playerObj, command, args)
    if not okAuth then
        local msg = IKST_ServerGate.deny(playerObj, command, args, reason, meta)
        IKST_WorldOps.sendResult(playerObj, false, msg, args.x, args.y, args.z, command, meta)
        return
    end

    local pluginHandled, ok, msg, pluginSpec = IKST.Plugins.handleServerCommand(command, playerObj, args)
    if pluginHandled then
        if ok and IKST_AuditLog and IKST_AuditLog.record then
            if pluginSpec and pluginSpec.adminCommands and pluginSpec.adminCommands[command] then
                IKST_AuditLog.record(playerObj, command, args, true, msg)
            end
        elseif not ok and IKST_AuditLog and IKST_AuditLog.record then
            IKST_AuditLog.record(playerObj, command, args, false, msg)
        end
        if command == IKST.CMD.lockTryUnlock and not ok and IKST_RateLimit then
            local x = readCoord(args, "x") or (playerObj and math.floor(playerObj:getX()))
            local y = readCoord(args, "y") or (playerObj and math.floor(playerObj:getY()))
            local z = tonumber(args and args.z) or (playerObj and playerObj:getZ()) or 0
            IKST_RateLimit.recordLockFail(playerObj, x, y, z)
        elseif command == IKST.CMD.lockTryUnlock and ok and IKST_RateLimit then
            local x = readCoord(args, "x") or (playerObj and math.floor(playerObj:getX()))
            local y = readCoord(args, "y") or (playerObj and math.floor(playerObj:getY()))
            local z = tonumber(args and args.z) or (playerObj and playerObj:getZ()) or 0
            IKST_RateLimit.clearLockFails(playerObj, x, y, z)
        end
        if not pluginSpec or not pluginSpec.afterServer then
            IKST_WorldOps.sendResult(playerObj, ok, msg, args.x, args.y, args.z, command, meta)
        end
        return
    end

    if command == IKST.CMD.auditTail then
        IKST_AuditLog.sendTail(playerObj, args and args.count)
        return
    end

    if command == IKST.CMD.briefingFetch then
        if IKST_BriefingServer and IKST_BriefingServer.handleFetch then
            IKST_BriefingServer.handleFetch(playerObj, args)
        end
        return
    end

    if command == IKST.CMD.threatCull then
        local x, y, z = readCoord(args, "x"), readCoord(args, "y"), readCoord(args, "z")
        local n = IKST_WorldOps.threatCull(x, y, z, IKST_Args.readRadius(args, "radius"), tonumber(args.maxPerTick) or 100)
        IKST.deliverClientCommand(playerObj, IKST.CMD.threatResult, { removed = n, x = x, y = y, z = z })
        IKST_Server.logSuccess(playerObj, command, args, "culled " .. n)
        return
    end

    if command == IKST.CMD.threatPopulation then
        local x, y, z = readCoord(args, "x"), readCoord(args, "y"), readCoord(args, "z")
        local total, sprinters = IKST_WorldOps.threatPopulation(x, y, z, IKST_Args.readRadius(args, "radius"))
        IKST.deliverClientCommand(playerObj, IKST.CMD.threatResult, { total = total, sprinters = sprinters, x = x, y = y, z = z })
        return
    end

    if command == IKST.CMD.quickWater or command == IKST.CMD.quickPower then
        ok, msg = IKST_Server.handleUtilityToggle(playerObj, command, args)
        IKST_Server.logSuccess(playerObj, command, args, msg)
        IKST_WorldOps.sendResult(playerObj, ok, msg, nil, nil, nil, command)
        return
    end

    if command == IKST.CMD.setWeather or command == IKST.CMD.clearWeather then
        if not IKST_StaffOps or not IKST_StaffOps.handle then
            IKST_WorldOps.sendResult(playerObj, false, "staff ops unavailable", nil, nil, nil, command)
            return
        end
        ok, msg = IKST_StaffOps.handle(command, playerObj, args)
        if ok then
            IKST_Server.logSuccess(playerObj, command, args, msg)
        end
        IKST_WorldOps.sendResult(playerObj, ok, msg, nil, nil, nil, command)
        return
    end

    if command == IKST.CMD.quickSave then
        if saveGame then saveGame() end
        IKST_Server.logSuccess(playerObj, command, args, "save requested")
        IKST_WorldOps.sendResult(playerObj, true, "save requested", nil, nil, nil, command)
        return
    end

    if command == IKST.CMD.quickBroadcast then
        if args.message and serverMsg then
            serverMsg(args.message)
        end
        IKST_Server.logSuccess(playerObj, command, args, "broadcast sent")
        IKST_WorldOps.sendResult(playerObj, true, "broadcast sent", nil, nil, nil, command)
        return
    end

    if command == IKST.CMD.staffListPlayers then
        IKST.deliverClientCommand(playerObj, IKST.CMD.staffListResult, {
            players = IKST_StaffOps.listOnlinePlayers(),
        })
        return
    end

    if command == IKST.CMD.listWaypoints then
        IKST.deliverClientCommand(playerObj, IKST.CMD.waypointListResult, {
            waypoints = IKST_Waypoints.list(),
        })
        return
    end

    if IKST.GUARD_COMMANDS and IKST.GUARD_COMMANDS[command] then
        ok, msg = IKST_GuardOps.handle(command, playerObj, args)
        if ok and (command == IKST.CMD.backupSafehouses or command == IKST.CMD.restoreSafehouses) then
            IKST_Server.logSuccess(playerObj, command, args, msg)
        end
        IKST_WorldOps.sendResult(playerObj, ok, msg, args.x, args.y, args.z, command)
        return
    end

    if command == IKST.CMD.journalRecord or command == IKST.CMD.journalRestore then
        ok, msg = IKST_RestoreServer.handle(command, playerObj, args)
        IKST_WorldOps.sendResult(playerObj, ok, msg, nil, nil, nil, command)
        return
    end

    if IKST.STAFF_COMMANDS and IKST.STAFF_COMMANDS[command] then
        if not IKST_StaffOps or not IKST_StaffOps.handle then
            IKST_WorldOps.sendResult(playerObj, false, "staff ops unavailable", nil, nil, nil, command)
            return
        end
        ok, msg = IKST_StaffOps.handle(command, playerObj, args)
        if ok then
            IKST_Server.logSuccess(playerObj, command, args, msg)
        elseif IKST_AuditLog and IKST_AuditLog.record then
            IKST_AuditLog.record(playerObj, command, args, false, msg)
        end
        IKST_WorldOps.sendResult(playerObj, ok, msg, nil, nil, nil, command)
        return
    end

    local msg = IKST_ServerGate.deny(playerObj, command, args, "unknown_command", meta)
    IKST_WorldOps.sendResult(playerObj, false, msg, nil, nil, nil, command)
end

local function onClientCommand(moduleName, command, playerObj, args)
    IKST_Server.handleCommand(moduleName, command, playerObj, args)
end

if type(isServer) == "function" and isServer() then
    Events.OnClientCommand.Add(onClientCommand)

    local function onTickCatch()
        IKST_Server._catchTick = (IKST_Server._catchTick or 0) + 1
        if IKST_Server._catchTick % 30 ~= 0 then
            return
        end
        local list = getOnlinePlayers and getOnlinePlayers()
        if not list or not list.size then
            return
        end
        for i = 0, list:size() - 1 do
            local p = list:get(i)
            if p and IKST_GuardOps and IKST_GuardOps.enforceCaughtPosition then
                IKST_GuardOps.enforceCaughtPosition(p)
            end
        end
    end
    if Events.OnTick then
        Events.OnTick.Add(onTickCatch)
    end
    if Events.EveryOneMinute then
        Events.EveryOneMinute.Add(function()
            if IKST_VehicleClaim and IKST_VehicleClaim.purgeExpired then
                IKST_VehicleClaim.purgeExpired()
            end
            if IKST_GuardOps and IKST_GuardOps.purgeExpiredSafehouses then
                IKST_GuardOps.purgeExpiredSafehouses()
            end
        end)
    end

    print("[IKST] IKappaID Suite Tools v" .. IKST.VERSION .. " loaded (server, Tier C gate)")
end
