-- Dedicated / listen-server JVM only (not remote MP client).
if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end
require "IKST_Shared"
require "IKST_Plugins"
require "IKST_Utility"
require "IKST_Access"
require "IKST_WorldOps"
require "IKST_VehicleUtil"
require "IKST_StaffOps"
require "IKST_Waypoints"
require "IKST_GuardOps"
require "IKST_ClaimPolicy"
require "IKST_RestoreServer"

IKST_Server = IKST_Server or {}

function IKST_Server.playerMayRunCommand(playerObj, command)
    if IKST_Access.canUseTools(playerObj) then
        return true
    end
    if not IKST_ClaimPolicy.playerClaimsEnabled() then
        return false
    end
    return IKST.PLAYER_CLAIM_COMMANDS and IKST.PLAYER_CLAIM_COMMANDS[command] == true
end

local function readCoord(args, key)
    if not args then
        return nil
    end
    local v = tonumber(args[key])
    if v == nil then
        return nil
    end
    return math.floor(v)
end

function IKST_Server.handleCommand(moduleName, command, playerObj, args)
    if moduleName ~= IKST.MODULE then
        return
    end

    args = args or {}

    local pluginHandled, ok, msg, pluginSpec = IKST.Plugins.handleServerCommand(command, playerObj, args)
    if pluginHandled then
        if not pluginSpec or not pluginSpec.afterServer then
            IKST_WorldOps.sendResult(playerObj, ok, msg, args.x, args.y, args.z, command)
        end
        return
    end

    if not IKST_Server.playerMayRunCommand(playerObj, command) then
        IKST_WorldOps.sendResult(playerObj, false, "not allowed", nil, nil, nil, command)
        return
    end

    if command == IKST.CMD.threatCull then
        local x, y, z = readCoord(args, "x"), readCoord(args, "y"), readCoord(args, "z")
        local n = IKST_WorldOps.threatCull(x, y, z, IKST.clampRadius(args.radius), tonumber(args.maxPerTick) or 100)
        IKST.deliverClientCommand(playerObj, IKST.CMD.threatResult, { removed = n, x = x, y = y, z = z })
        return
    end

    if command == IKST.CMD.threatPopulation then
        local x, y, z = readCoord(args, "x"), readCoord(args, "y"), readCoord(args, "z")
        local total, sprinters = IKST_WorldOps.threatPopulation(x, y, z, IKST.clampRadius(args.radius))
        IKST.deliverClientCommand(playerObj, IKST.CMD.threatResult, { total = total, sprinters = sprinters, x = x, y = y, z = z })
        return
    end

    if command == IKST.CMD.quickWater or command == IKST.CMD.quickPower then
        IKST_WorldOps.sendResult(playerObj, false, "use client utility toggle", nil, nil, nil, command)
        return
    end

    if command == IKST.CMD.setWeather or command == IKST.CMD.clearWeather then
        IKST_WorldOps.sendResult(playerObj, false, "use client weather controls", nil, nil, nil, command)
        return
    end

    if command == IKST.CMD.quickSave then
        if saveGame then saveGame() end
        IKST_WorldOps.sendResult(playerObj, true, "save requested", nil, nil, nil, command)
        return
    end

    if command == IKST.CMD.quickBroadcast then
        if args.message and serverMsg then
            serverMsg(args.message)
        end
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
        local ok, msg = IKST_GuardOps.handle(command, playerObj, args)
        IKST_WorldOps.sendResult(playerObj, ok, msg, args.x, args.y, args.z, command)
        return
    end

    if command == IKST.CMD.journalRecord or command == IKST.CMD.journalRestore then
        local ok, msg = IKST_RestoreServer.handle(command, playerObj, args)
        IKST_WorldOps.sendResult(playerObj, ok, msg, nil, nil, nil, command)
        return
    end

    if IKST.STAFF_COMMANDS and IKST.STAFF_COMMANDS[command] then
        if not IKST_StaffOps or not IKST_StaffOps.handle then
            IKST_WorldOps.sendResult(playerObj, false, "staff ops unavailable", nil, nil, nil, command)
            return
        end
        local ok, msg = IKST_StaffOps.handle(command, playerObj, args)
        IKST_WorldOps.sendResult(playerObj, ok, msg, nil, nil, nil, command)
        return
    end

    IKST_WorldOps.sendResult(playerObj, false, "unknown command", nil, nil, nil, command)
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

    print("[IKST] IKappaID Suite Tools v" .. IKST.VERSION .. " loaded (server)")
end
