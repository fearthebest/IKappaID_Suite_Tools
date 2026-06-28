-- Client JVM only (integrated SP server JVM is not isClient per B42).
if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Plugins"
require "IKST_ModDataSync"
require "IKST_Utility"
require "IKST_Access"
require "IKST_ClientNet"
require "IKST_JobsPanel"
require "IKST_JobThreat"
require "IKST_JobStaff"
require "IKST_JobGuard"
require "IKST_JobGadgets"
require "IKST_JobUtilities"
require "IKST_ClientStaff"
require "IKST_JobClaim"
require "IKST_JobEveryone"
require "IKST_Enforcement"
require "IKST_VehicleClaimWatch"
require "IKST_QuickActions"
require "IKST_QuickDrawer"
require "IKST_HudChip"
require "IKST_VehicleClaimUI"
require "IKST_VehicleContext"
require "IKST_SafehouseClaimUI"
require "IKST_SafehouseContext"
require "IKST_ClaimIcons"
require "IKST_RestoreJournal"
require "IKST_ContextMenu"
require "IKST_Briefing"
require "IKST_BriefingUI"
require "IKST_Arrival"
require "IKST_ArrivalClient"

local function onKeyPressed(key)
    if not Keyboard or key ~= Keyboard.KEY_W then
        return
    end
    if not isCtrlKeyDown() or not isShiftKeyDown() then
        return
    end
    local player = getPlayer()
    if not player and getSpecificPlayer then
        player = getSpecificPlayer(0)
    end
    if not player then
        return
    end
    IKST_JobsPanel.toggle(player)
end

local function onServerCommand(module, command, args)
    if module ~= IKST.MODULE then
        return
    end
    local player = getPlayer()
    if not player then
        return
    end

    if command == IKST.CMD.result then
        if args and args.success and args.message then
            local line = tostring(args.mode or "action") .. " @ " .. tostring(args.x) .. "," .. tostring(args.y) .. "," .. tostring(args.z) .. " — " .. tostring(args.message)
            IKST.pushLog(player, line)
        end
        if IKST_EconomyUI and IKST_EconomyUI.onServerResult then
            IKST_EconomyUI.onServerResult(args or {})
        end
        if IKST_JobsPanel.instance then
            IKST_JobsPanel.instance:onServerResult(args or {})
        end
        return
    end

    if IKST.Plugins.onServerCommand(command, args, player) then
        return
    end

    if command == IKST.CMD.threatResult then
        if IKST_JobThreat and IKST_JobThreat.onResult then
            IKST_JobThreat.onResult(args)
        end
        return
    end

    if command == IKST.CMD.inspectResult then
        if args and args.x then
            IKST.pushLog(player, "inspect @ " .. args.x .. "," .. args.y .. "," .. args.z)
        end
        if IKST_JobsPanel.instance and IKST_JobsPanel.instance.onInspectResult then
            IKST_JobsPanel.instance:onInspectResult(args)
        end
        return
    end

    if command == IKST.CMD.staffListResult then
        if IKST_JobStaff and IKST_JobStaff.onListResult then
            IKST_JobStaff.onListResult(args and args.players)
        end
        return
    end

    if command == IKST.CMD.waypointListResult then
        if IKST_JobStaff and IKST_JobStaff.onWaypointListResult then
            IKST_JobStaff.onWaypointListResult(args and args.waypoints)
        end
        return
    end

    if command == IKST.CMD.safehouseListResult then
        if IKST_JobGuard and IKST_JobGuard.onSafehouseListResult then
            IKST_JobGuard.onSafehouseListResult(args)
        end
        return
    end

    if command == IKST.CMD.vehicleClaimListResult then
        if IKST_JobGuard and IKST_JobGuard.onClaimListResult then
            IKST_JobGuard.onClaimListResult(args)
        end
        return
    end

    if command == IKST.CMD.dumpPlayersResult then
        if IKST_JobGuard and IKST_JobGuard.onDumpResult then
            IKST_JobGuard.onDumpResult(args)
        end
        return
    end

    if command == IKST.CMD.catchSync then
        if IKST.Plugins.onServerCommand(command, args, player) then
            return
        end
        if IKST_GuardHooks and IKST_GuardHooks.applyCatchSync then
            IKST_GuardHooks.applyCatchSync(player, args)
        end
        return
    end

    if command == IKST.CMD.safehouseBordersSync then
        if IKST_GuardHooks and IKST_GuardHooks.setBordersEnabled then
            IKST_GuardHooks.setBordersEnabled(args and args.on == true)
        end
        return
    end

    if command == IKST.CMD.lockUnlockSync then
        if IKST_Locks and args then
            IKST_Locks.markUnlocked(player, args.x, args.y, args.z)
        end
        return
    end

    if command == IKST.CMD.utilitySync then
        if args then
            if args.waterOn ~= nil then
                IKST.applyUtilitySandboxVar("water", args.waterOn and IKST_Utility.FAR_FUTURE or -1)
            end
            if args.powerOn ~= nil then
                IKST.applyUtilitySandboxVar("power", args.powerOn and IKST_Utility.FAR_FUTURE or -1)
            end
        end
        if IKST_JobsPanel and IKST_JobsPanel.instance then
            IKST_JobsPanel.instance:refreshJobUI()
        end
        return
    end

    if command == IKST.CMD.auditTailResult then
        if args and args.entries and IKST.pushLog then
            for i = #args.entries, 1, -1 do
                local row = args.entries[i]
                if row then
                    local line = tostring(row.cmd or "?") .. " " .. (row.ok and "ok" or "deny")
                        .. " " .. tostring(row.user or "?") .. " " .. tostring(row.reason or "")
                    IKST.pushLog(player, line)
                end
            end
        end
        return
    end

    if command == IKST.CMD.briefingResult then
        if IKST_BriefingUI and IKST_BriefingUI.onResult then
            IKST_BriefingUI.onResult(args or {})
        end
        return
    end

    if command == IKST.CMD.arrivalSync then
        if IKST_ArrivalClient and IKST_ArrivalClient.onSync then
            IKST_ArrivalClient.onSync(args or {})
        end
        return
    end
end

local function onGameStart()
    IKST_ModDataSync.installClient()
    IKST_JobsPanel.ensure()
    print("[IKST] IKappaID Suite Tools v" .. IKST.VERSION .. " loaded (client)")
end

if Events then
    if Events.OnGameStart then
        Events.OnGameStart.Add(onGameStart)
    end
    if Events.OnKeyPressed then
        Events.OnKeyPressed.Add(onKeyPressed)
    end
    if Events.OnServerCommand then
        Events.OnServerCommand.Add(onServerCommand)
    end
end
IKST.registerClientCommandHandler(onServerCommand)
