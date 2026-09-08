-- Client JVM only (integrated SP server JVM is not isClient per B42).
if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Debug"
require "IKST_Plugins"
require "IKST_ModDataSync"
require "IKST_VehicleClaimMirror"
require "IKST_SafehouseClaimMirror"
require "IKST_Threat"
require "IKST_Utility"
require "IKST_Access"
require "IKST_ClientNet"
require "IKST_Dashboard"
require "IKST_DashboardQuick"
require "IKST_DashboardUI"
require "IKST_ActionLog"
require "IKST_DragHandle"
require "IKST_EdgeDock"
require "IKST_ActionLogWindow"
require "IKST_JobsPanel"
require "IKST_SoftPageHost"
require "IKST_Hub"
require "IKST_JobThreat"
require "IKST_JobStaff"
require "IKST_ClaimRequestDraw"
require "IKST_JobGuard"
require "IKST_SoftTool_Claim"
require "IKST_SoftTool_Everyone"
require "IKST_SoftTool_Utilities"
require "IKST_SoftTool_Home"
require "IKST_JobUtilities"
require "IKST_ClientStaff"
require "IKST_JobClaim"
require "IKST_JobEveryone"
require "IKST_Enforcement"
require "IKST_QuickActions"
require "IKST_QuickDrawer"
require "IKST_HudChip"
require "IKST_SidebarIcon"
require "IKST_Joypad"
require "IKST_ClaimPermissionsUI"
require "IKST_VehicleClaimUI"
require "IKST_VehicleContext"
require "IKST_SafehouseClaimClient"
require "IKST_SafehouseInviteClient"
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
    if IKST_Hub and type(IKST_Hub.toggle) == "function" then
        IKST_Hub.toggle(player)
    end
end

local function onServerCommand(module, command, args)
    if module ~= IKST.MODULE then
        return
    end
    if IKST_Debug and IKST_Debug.logNet then
        local dbgPlayer = getPlayer()
        IKST_Debug.logNet("client<-server", command, dbgPlayer, args, "")
    end

    if command == IKST.CMD.vehicleClaimBootstrap then
        if IKST_VehicleClaimMirror and IKST_VehicleClaimMirror.applyBootstrap then
            IKST_VehicleClaimMirror.applyBootstrap(args)
        end
        return
    end

    if command == IKST.CMD.vehicleClaimPatch then
        if IKST_VehicleClaimMirror and IKST_VehicleClaimMirror.applyPatch then
            IKST_VehicleClaimMirror.applyPatch(args)
        end
        return
    end

    if command == IKST.CMD.vehicleClaimPingResult then
        if IKST_VehicleClaimMirror and IKST_VehicleClaimMirror.onPingResult then
            IKST_VehicleClaimMirror.onPingResult(args)
        end
        return
    end

    if command == IKST.CMD.safehouseClaimBootstrap then
        if IKST_SafehouseClaimMirror and IKST_SafehouseClaimMirror.applyBootstrap then
            IKST_SafehouseClaimMirror.applyBootstrap(args)
        end
        return
    end

    if command == IKST.CMD.safehouseClaimPatch then
        if IKST_SafehouseClaimMirror and IKST_SafehouseClaimMirror.applyPatch then
            IKST_SafehouseClaimMirror.applyPatch(args)
        end
        return
    end

    if command == IKST.CMD.safehouseClaimPingResult then
        if IKST_SafehouseClaimMirror and IKST_SafehouseClaimMirror.onPingResult then
            IKST_SafehouseClaimMirror.onPingResult(args)
        end
        return
    end

    if command == IKST.CMD.applySelfCheat then
        if IKST_ClientStaff and IKST_ClientStaff.applySelfCheatLocal then
            IKST_ClientStaff.applySelfCheatLocal(nil, args and args.cheat, args and args.on)
        end
        return
    end

    local player = getPlayer()
    if not player then
        return
    end

    if command == IKST.CMD.result then
        if IKST_Debug and IKST_Debug.logResult then
            IKST_Debug.logResult(args and args.mode or command, player, args and args.success, args and args.message, args)
        end
        if args and args.message then
            local mode = args.mode
            local skipLog = mode == IKST.CMD.safehouseList or mode == IKST.CMD.vehicleClaimList
            if not skipLog then
                local line = tostring(mode or "action")
                if args.code then
                    line = line .. " [" .. tostring(args.code) .. "]"
                end
                local x = tonumber(args.x)
                local y = tonumber(args.y)
                if x ~= nil and y ~= nil then
                    local z = tonumber(args.z) or 0
                    line = line .. " @ " .. tostring(x) .. "," .. tostring(y) .. "," .. tostring(z)
                end
                line = line .. " - " .. tostring(args.message)
                if args.success then
                    IKST.pushLog(player, line, "success")
                else
                    IKST.pushLog(player, "DENIED: " .. line, "deny")
                    if IKST.notify then
                        IKST.notify(player, tostring(args.message), false)
                    end
                end
            elseif args.success ~= true and IKST.notify then
                IKST.notify(player, tostring(args.message), false)
            end
        end
        if IKST_EconomyUI and IKST_EconomyUI.onServerResult then
            IKST_EconomyUI.onServerResult(args or {})
        end
        local panel = IKST_Hub and type(IKST_Hub.activeJobPanel) == "function" and IKST_Hub.activeJobPanel()
        if panel and type(panel.onServerResult) == "function" then
            panel:onServerResult(args or {})
        elseif IKST_Hub and type(IKST_Hub.activeJobPanel) == "function" then
            local panel = IKST_Hub.activeJobPanel()
            if panel and type(panel.onServerResult) == "function" then
                panel:onServerResult(args or {})
            end
        elseif args and IKST_JobLoot and IKST_JobLoot.onServerResult then
            local mode = args.mode
            if mode == IKST.CMD.lootRepopulateZone or mode == IKST.CMD.lootRepopulateContainer then
                IKST_JobLoot.onServerResult({ player = player }, args or {})
            end
        end
        return
    end

    if command == IKST.CMD.batchProgress then
        local label = args and args.label or "batch"
        local index = tonumber(args and args.index) or 0
        local total = tonumber(args and args.total) or 0
        local line = tostring(label) .. " " .. tostring(index) .. "/" .. tostring(total)
        if args and args.msg then
            line = line .. " - " .. tostring(args.msg)
        end
        IKST.pushLog(player, line, "progress")
        local panel = IKST_Hub and type(IKST_Hub.activeJobPanel) == "function" and IKST_Hub.activeJobPanel()
        if panel and type(panel.onBatchProgress) == "function" then
            panel:onBatchProgress(args or {})
        elseif IKST_Hub and type(IKST_Hub.refreshActive) == "function" then
            IKST_Hub.refreshActive(true)
        end
        return
    end

    if command == IKST.CMD.lootContainerRefresh then
        if IKST.Plugins and IKST.Plugins.onServerCommand
            and IKST.Plugins.onServerCommand(command, args, player) then
            return
        end
        if IKST_LootClientRefresh and IKST_LootClientRefresh.applyRefresh then
            IKST_LootClientRefresh.applyRefresh(args)
        end
        return
    end

    if command == IKST.CMD.vehicleListResult then
        if IKST_VehicleClaimClient and IKST_VehicleClaimClient.onNearbyResult then
            IKST_VehicleClaimClient.onNearbyResult(args and args.vehicles)
        end
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
        local panel = IKST_Hub and type(IKST_Hub.activeJobPanel) == "function" and IKST_Hub.activeJobPanel()
        if panel and type(panel.onInspectResult) == "function" then
            panel:onInspectResult(args)
        elseif IKST_Hub and type(IKST_Hub.refreshActive) == "function" then
            IKST_Hub.refreshActive(true)
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

    if command == IKST.CMD.helpListResult then
        if IKST_JobStaff and IKST_JobStaff.onHelpListResult then
            IKST_JobStaff.onHelpListResult(args)
        end
        return
    end

    if command == IKST.CMD.claimRequestListResult then
        if IKST_JobStaff and IKST_JobStaff.onClaimRequestListResult then
            IKST_JobStaff.onClaimRequestListResult(args)
        end
        return
    end

    if command == IKST.CMD.staffHistoryResult then
        if IKST_JobStaff and IKST_JobStaff.onHistoryResult then
            IKST_JobStaff.onHistoryResult(args)
        end
        return
    end

    if command == IKST.CMD.applyTeleport then
        if IKST_ClientStaff and IKST_ClientStaff.applyTeleportLocal then
            IKST_ClientStaff.applyTeleportLocal(player, args and args.x, args and args.y, args and args.z)
        end
        return
    end

    if command == IKST.CMD.applyStaffModes then
        if IKST_ClientStaff and IKST_ClientStaff.applyPlayerModes then
            IKST_ClientStaff.applyPlayerModes(player, args)
        end
        return
    end

    if command == IKST.CMD.rewindSync then
        if not IKST_Rewind then
            require "IKST_Rewind"
        end
        if IKST_Rewind and IKST_Rewind.setClientCount then
            IKST_Rewind.setClientCount(player, args and args.count)
        end
        if IKST_Hub and type(IKST_Hub.refreshActive) == "function" then
            IKST_Hub.refreshActive()
        elseif IKST_Hub and type(IKST_Hub.refreshActive) == "function" then
        IKST_Hub.refreshActive()
        end
        return
    end

    if command == IKST.CMD.applyVehicleSync then
        if IKST_ClientStaff and IKST_ClientStaff.applyVehicleSync then
            IKST_ClientStaff.applyVehicleSync(args)
        end
        return
    end

    if command == IKST.CMD.safehouseListResult then
        if IKST_SafehouseClaimClient and IKST_SafehouseClaimClient.onSafehouseListResult then
            IKST_SafehouseClaimClient.onSafehouseListResult(args)
        end
        if IKST_JobGuard and IKST_JobGuard.onSafehouseListResult then
            IKST_JobGuard.onSafehouseListResult(args)
        end
        return
    end

    if command == IKST.CMD.safehouseInviteNotify then
        if IKST_SafehouseInviteClient and type(IKST_SafehouseInviteClient.onInviteNotify) == "function" then
            IKST_SafehouseInviteClient.onInviteNotify(args)
        end
        return
    end

    if command == IKST.CMD.safehouseInviteListResult then
        if IKST_SafehouseInviteClient and type(IKST_SafehouseInviteClient.setPending) == "function" then
            IKST_SafehouseInviteClient.setPending(args and args.invites)
        end
        return
    end

    if command == IKST.CMD.safehouseClientRefresh then
        if IKST_GuardHooks and IKST_GuardHooks.forceSafehouseRefresh then
            IKST_GuardHooks.forceSafehouseRefresh(args)
        end
        return
    end

    if command == IKST.CMD.safehouseClaimResult then
        if args and args.message then
            IKST.notify(player, tostring(args.message), args.ok == true)
        end
        if IKST_GuardHooks and IKST_GuardHooks.forceSafehouseRefresh then
            IKST_GuardHooks.forceSafehouseRefresh()
        end
        if IKST_SafehouseClaimClient and IKST_SafehouseClaimClient.forceRefresh then
            IKST_SafehouseClaimClient.forceRefresh()
        end
        if IKST_Hub and type(IKST_Hub.refreshActive) == "function" then
            IKST_Hub.refreshActive()
        elseif IKST_Hub and type(IKST_Hub.refreshActive) == "function" then
        IKST_Hub.refreshActive()
        end
        return
    end

    if command == IKST.CMD.safehouseClaimMirror then
        if IKST_SafehouseClaimClient and IKST_SafehouseClaimClient.forceRefresh then
            IKST_SafehouseClaimClient.forceRefresh(args)
        end
        return
    end

    if command == IKST.CMD.vehicleClaimListResult then
        if IKST_VehicleClaimClient and IKST_VehicleClaimClient.onClaimListResult then
            IKST_VehicleClaimClient.onClaimListResult(args)
        end
        if IKST_JobGuard and IKST_JobGuard.onClaimListResult then
            IKST_JobGuard.onClaimListResult(args)
        end
        return
    end

    if command == IKST.CMD.vehicleClaimMirror then
        if IKST_VehicleClaimClient and IKST_VehicleClaimClient.forceRefresh then
            IKST_VehicleClaimClient.forceRefresh(args)
        end
        return
    end

    if command == IKST.CMD.vehicleClaimResult then
        if args and args.message then
            IKST.notify(player, tostring(args.message), args.ok == true)
        end
        if IKST_VehicleClaimClient and IKST_VehicleClaimClient.forceRefresh then
            IKST_VehicleClaimClient.forceRefresh()
        end
        if IKST_Hub and type(IKST_Hub.refreshActive) == "function" then
            IKST_Hub.refreshActive()
        elseif IKST_Hub and type(IKST_Hub.refreshActive) == "function" then
        IKST_Hub.refreshActive()
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
        if IKST_Hub and type(IKST_Hub.refreshActive) == "function" then
            IKST_Hub.refreshActive()
        elseif IKST_Hub and type(IKST_Hub.refreshActive) == "function" then
        IKST_Hub.refreshActive()
        end
        return
    end

    if command == IKST.CMD.weatherMirror then
        -- Server-authored display only. Never treat this as client climate authority.
        if not IKST_ClimatePresets then
            require "IKST_ClimatePresets"
        end
        if IKST_ClimatePresets then
            if args and args.clear == true and IKST_ClimatePresets.clearWeatherLocal then
                IKST_ClimatePresets.clearWeatherLocal()
            elseif args and args.preset and IKST_ClimatePresets.applyPresetLocal then
                IKST_ClimatePresets.applyPresetLocal(args.preset)
            end
        end
        return
    end

    if command == IKST.CMD.timeMirror then
        -- Server already chose the hour; clients only snap local clock + lighting.
        if not IKST_ClimatePresets then
            require "IKST_ClimatePresets"
        end
        if IKST_ClimatePresets and IKST_ClimatePresets.applyTimeOfDayLocal then
            IKST_ClimatePresets.applyTimeOfDayLocal(args and args.hour)
        end
        return
    end

    if command == IKST.CMD.dashboardSnapshotResult then
        if IKST_Dashboard and IKST_Dashboard.applyResult then
            IKST_Dashboard.applyResult(args)
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

    if command == IKST.CMD.debugStatusResult then
        if IKST_Debug and IKST_Debug.onClientStatusResult then
            IKST_Debug.onClientStatusResult(player, args)
        end
        return
    end

    if command == IKST.CMD.debugTailResult then
        if IKST_Debug and IKST_Debug.onClientTailResult then
            IKST_Debug.onClientTailResult(player, args)
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
    -- Soft hub pages register lazily on first open; no legacy JobsPanel.ensure.
    if IKST_Hub and type(IKST_Hub.ensurePages) == "function" then
        IKST_Hub.ensurePages()
    end
    if not IKST_Debug then
        require "IKST_Debug"
    end
    if IKST_Debug and IKST_Debug.enabled and IKST_Debug.enabled() then
        IKST_Debug.log("boot", "v" .. IKST.VERSION .. " client JVM ready - grep console for [IKST-DEBUG]")
    end
    print("[IKST] IKappaID Suite Tools v" .. IKST.VERSION .. " loaded (client, soft hub)")
    local player = getPlayer and getPlayer() or nil
    if not player and getSpecificPlayer then
        player = getSpecificPlayer(0)
    end
    if player and IKST_VehicleClaimClient and IKST_VehicleClaimClient.bootstrap then
        IKST_VehicleClaimClient.bootstrap(player)
    end
    if player and IKST_SafehouseClaimClient and IKST_SafehouseClaimClient.bootstrap then
        IKST_SafehouseClaimClient.bootstrap(player)
    end
end

if Events then
    if Events.OnGameStart then
        Events.OnGameStart.Add(onGameStart)
    end
    if Events.OnKeyPressed then
        Events.OnKeyPressed.Add(onKeyPressed)
    end
    if Events.OnGameStart then
        Events.OnGameStart.Add(function()
            if IKST_SidebarIcon and IKST_SidebarIcon.sync then
                IKST_SidebarIcon.sync()
            end
        end)
    end
    if Events.OnServerCommand then
        Events.OnServerCommand.Add(onServerCommand)
    end
end
IKST.registerClientCommandHandler(onServerCommand)
