if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Plugins"
require "IKST_Access"
require "IKST_JobLayout"
require "IKST_ClaimIcons"
require "IKappaID_UI/IKUI_Chrome"
require "IKST_UI_Layout"
require "IKST_Dashboard"
require "IKST_DashboardQuick"
require "IKST_DashboardUI"

IKST_HubNav = IKST_HubNav or {}
IKST_HubNav.SIDEBAR_W = IKST_UI_Layout.sidebarWidth()

IKST_HubNav.WORKSPACES = {
    -- Order: player-facing → claims/zones → staff utilities → world tools → vehicles → extras → moderation.
    {
        id = IKST.VIEW.everyone,
        titleKey = "IGUI_IKST_WS_Everyone",
        title = "Everyone",
        icon = "media/ui/ikst/ws_everyone.png",
        descKey = "IGUI_IKST_WS_Everyone_Desc",
        desc = "Server info, claims list, events, and help",
        tools = {
            { id = "overview", titleKey = "IGUI_IKST_Everyone_Overview", title = "Overview", order = 10 },
            { id = "claims", titleKey = "IGUI_IKST_EveryoneTile_SectionClaims", title = "Claims", order = 20 },
            { id = "events", titleKey = "IGUI_IKST_EveryoneTile_SectionEvents", title = "Events", order = 30 },
            { id = "help", titleKey = "IGUI_IKST_EveryoneTile_SectionQuick", title = "Help", order = 40 },
        },
    },
    {
        id = IKST.VIEW.claim,
        titleKey = "IGUI_IKST_WS_Claim",
        title = "Claim",
        icon = "media/ui/ikst/ws_claim.png",
        descKey = "IGUI_IKST_WS_Claim_Desc",
        desc = "Claim a safehouse or vehicle",
        tools = {
            { id = "overview", titleKey = "IGUI_IKST_Claim_Overview", title = "Overview", order = 5 },
            { id = "requests", titleKey = "IGUI_IKST_ClaimRequestQueue", title = "Claim requests", order = 8, adminOnly = true },
            { id = "safehouses", titleKey = "IGUI_IKST_Claim_Safehouse", title = "Claim safehouse", order = 10 },
            { id = "vehicleclaim", titleKey = "IGUI_IKST_Claim_Vehicle", title = "Claim vehicle", order = 20 },
            { id = "catch", titleKey = "IGUI_IKST_Guard_Catch", title = "Freeze player", order = 40, adminOnly = true },
        },
    },
    {
        id = IKST.VIEW.utilities,
        titleKey = "IGUI_IKST_WS_Utilities",
        title = "Utilities",
        icon = "media/ui/ikst/ws_utilities.png",
        descKey = "IGUI_IKST_WS_Utilities_Desc",
        desc = "Self powers, items, players, zombies, world, teleport",
        adminOnly = true,
        tools = {
            { id = "self", titleKey = "IGUI_IKST_Util_Self", title = "Self", order = 10 },
            { id = "items", titleKey = "IGUI_IKST_Util_Items", title = "Items", order = 20 },
            { id = "players", titleKey = "IGUI_IKST_Util_Players", title = "Players", order = 30 },
            { id = "zombies", titleKey = "IGUI_IKST_Util_Zombies", title = "Zombies", order = 40 },
            { id = "servertools", titleKey = "IGUI_IKST_Util_ServerTools", title = "World", order = 50 },
            { id = "teleport", titleKey = "IGUI_IKST_Util_Teleport", title = "Teleport", order = 60 },
            { id = "batch", titleKey = "IGUI_IKST_Staff_batch", title = "Batch", order = 70, adminOnly = true },
        },
    },
    {
        id = IKST.VIEW.tiles,
        titleKey = "IGUI_IKST_WS_World",
        title = "Tiles",
        icon = "media/ui/ikst/ws_world.png",
        descKey = "IGUI_IKST_WS_World_Desc",
        desc = "Remove, paint, inspect, blueprints, protection",
        pluginId = "tiles",
        adminOnly = true,
        tools = {
            { id = "overview", titleKey = "IGUI_IKST_Tiles_Overview", title = "Overview", order = 5 },
            { id = "remove", titleKey = "IGUI_IKST_Job_Cleanup", title = "Remove", order = 10 },
            { id = "paint", titleKey = "IGUI_IKST_Job_Painter", title = "Paint tiles", order = 20 },
            { id = "inspect", titleKey = "IGUI_IKST_Job_Inspector", title = "Inspect tile", order = 30 },
            { id = "blueprints", titleKey = "IGUI_IKST_Gadget_blueprints", title = "Copy build", order = 40 },
            { id = "area", titleKey = "IGUI_IKST_Job_Automation", title = "Area jobs", order = 45 },
            { id = "protect", titleKey = "IGUI_IKST_Tool_Protect", title = "Protection", order = 50 },
        },
    },
    {
        id = IKST.VIEW.vehicles,
        titleKey = "IGUI_IKST_WS_Vehicles",
        title = "Vehicles",
        icon = "media/ui/ikst/ws_vehicles.png",
        descKey = "IGUI_IKST_WS_Vehicles_Desc",
        desc = "Spawn, repair, prune - admin vehicle tools",
        pluginId = "vehicles",
        adminOnly = true,
        tools = {
            { id = "overview", titleKey = "IGUI_IKST_Vehicles_Overview", title = "Overview", order = 5 },
            { id = "spawn", titleKey = "IGUI_IKST_VehicleTool_Spawn", title = "Spawn", order = 10 },
            { id = "repair", titleKey = "IGUI_IKST_VehicleTool_Repair", title = "Repair", order = 20 },
            { id = "prune", titleKey = "IGUI_IKST_VehicleTool_Prune", title = "Prune", order = 30 },
        },
    },
    {
        id = IKST.VIEW.economy,
        titleKey = "IGUI_IKST_WS_Economy",
        title = "Economy",
        icon = "media/ui/ikst/ws_economy.png",
        descKey = "IGUI_IKST_WS_Economy_Desc",
        desc = "Balances, vending, and transfers",
        pluginId = "economy",
        tools = {
            { id = "money", titleKey = "IGUI_IKST_Economy_Tab_Money", title = "Money", order = 10 },
            { id = "shop", titleKey = "IGUI_IKST_Economy_Tab_Shop", title = "Shops", order = 20 },
            { id = "valuables", titleKey = "IGUI_IKST_Economy_Tab_Values", title = "Valuables", order = 30 },
            { id = "admin", titleKey = "IGUI_IKST_Economy_Tab_Admin", title = "Admin", order = 40, adminOnly = true },
        },
    },
    {
        id = IKST.VIEW.loot,
        titleKey = "IGUI_IKST_WS_Loot",
        title = "Loot",
        icon = "media/ui/ikst/ws_loot.png",
        descKey = "IGUI_IKST_WS_Loot_Desc",
        desc = "Repopulate containers with vanilla loot",
        pluginId = "loot",
        adminOnly = true,
        tools = {
            { id = "loot", titleKey = "IGUI_IKST_WS_Loot", title = "Loot", order = 10 },
        },
    },
    {
        id = IKST.VIEW.admin,
        titleKey = "IGUI_IKST_WS_Admin",
        title = "Admin",
        icon = "media/ui/ikst/ws_admin.png",
        descKey = "IGUI_IKST_WS_Admin_Desc",
        desc = "Ghost, kick, and ban",
        pluginId = "admin",
        adminOnly = true,
        tools = {
            { id = "ghost", titleKey = "IGUI_IKST_AdminGhostSelf", title = "Ghost", order = 10 },
            { id = "kick", titleKey = "IGUI_IKST_UtilTile_KickPlayer", title = "Kick", order = 20 },
            { id = "ban", titleKey = "IGUI_IKST_UtilTile_BanPlayer", title = "Ban", order = 30 },
        },
    },
}

IKST_HubNav.LEGACY_VIEW = {
    [IKST.VIEW.cleanup] = { mode = IKST.VIEW.tiles, tool = "remove" },
    [IKST.VIEW.painter] = { mode = IKST.VIEW.tiles, tool = "paint" },
    [IKST.VIEW.inspector] = { mode = IKST.VIEW.tiles, tool = "inspect" },
    [IKST.VIEW.automation] = { mode = IKST.VIEW.tiles, tool = "area" },
    [IKST.VIEW.staff] = { mode = IKST.VIEW.utilities, tool = "players" },
    [IKST.VIEW.guard] = { mode = IKST.VIEW.claim, tool = "safehouses" },
    [IKST.VIEW.protect] = { mode = IKST.VIEW.tiles, tool = "protect" },
    [IKST.VIEW.vehicle] = { mode = IKST.VIEW.vehicles, tool = "spawn" },
    [IKST.VIEW.economy] = { mode = IKST.VIEW.economy, tool = "money" },
    [IKST.VIEW.threat] = { mode = IKST.VIEW.utilities, tool = "zombies" },
    [IKST.VIEW.loot] = { mode = IKST.VIEW.loot, tool = "loot" },
    [IKST.VIEW.worldedit] = { mode = IKST.VIEW.tiles, tool = "remove" },
    [IKST.VIEW.players] = { mode = IKST.VIEW.utilities, tool = "players" },
    [IKST.VIEW.safehouses] = { mode = IKST.VIEW.claim, tool = "safehouses" },
    [IKST.VIEW.rules] = { mode = IKST.VIEW.tiles, tool = "protect" },
    [IKST.VIEW.gadgets] = { mode = IKST.VIEW.utilities, tool = "servertools" },
    [IKST.VIEW.hub] = { mode = IKST.VIEW.favorites, tool = nil },
    [IKST.VIEW.build] = { mode = IKST.VIEW.tiles, tool = "remove" },
    [IKST.VIEW.server] = { mode = IKST.VIEW.utilities, tool = "players" },
    [IKST.VIEW.quick] = { mode = IKST.VIEW.utilities, tool = "self" },
}

function IKST_HubNav.isHomeView(view)
    return view == IKST.VIEW.favorites or view == IKST.VIEW.hub
end

function IKST_HubNav.isFavoritesView(view)
    return IKST_HubNav.isHomeView(view)
end

function IKST_HubNav.workspaceById(workspaceId)
    for _, ws in ipairs(IKST_HubNav.WORKSPACES) do
        if ws.id == workspaceId then
            return ws
        end
    end
    return nil
end

function IKST_HubNav.modeById(modeId)
    return IKST_HubNav.workspaceById(modeId)
end

function IKST_HubNav.visibleWorkspaces(player)
    local out = {}
    player = IKST.resolvePlayer(player)
    for _, ws in ipairs(IKST_HubNav.WORKSPACES) do
        local missingPlugin = ws.pluginId and (not IKST.Plugins or not IKST.Plugins.isActive(ws.pluginId))
        if missingPlugin then
            -- B10: still list so dashboard can show Requires badge
            local copy = {}
            for k, v in pairs(ws) do
                copy[k] = v
            end
            copy._missingPlugin = true
            out[#out + 1] = copy
        elseif ws.adminOnly and IKST_Access and not IKST_Access.canUseStaffTools(player) then
            -- hide staff-only workspaces for non-staff
        elseif ws.pluginId and IKST.Plugins and IKST.Plugins.canUseAdmin
            and not IKST.Plugins.canUseAdmin(ws.pluginId, player)
            and ws.adminOnly then
            -- plugin admin gate
        elseif IKST_Access.canUseWorkspace(player, ws.id) then
            out[#out + 1] = ws
        end
    end
    return out
end

function IKST_HubNav.allDashboardWorkspaces(player)
    return IKST_HubNav.visibleWorkspaces(player)
end

function IKST_HubNav.toolLabel(tool)
    if not tool then
        return "?"
    end
    return IKST.text(tool.titleKey, tool.title or tool.id or "?")
end

function IKST_HubNav.modeLabel(mode)
    if type(mode) == "string" then
        mode = IKST_HubNav.workspaceById(mode)
    end
    if not mode then
        return "?"
    end
    return IKST.text(mode.titleKey, mode.title or mode.id or "?")
end

function IKST_HubNav.labelForNav(modeId, toolId)
    if IKST_HubNav.isHomeView(modeId) then
        return IKST.text("IGUI_IKST_Home", "Home")
    end
    local ws = IKST_HubNav.workspaceById(modeId)
    if ws and ws.tools and toolId then
        for _, tool in ipairs(ws.tools) do
            if tool.id == toolId then
                return IKST_HubNav.toolLabel(tool)
            end
        end
    end
    for _, tool in ipairs(IKST.Plugins.hubToolsForMode(modeId)) do
        if tool.id == toolId then
            return IKST_HubNav.toolLabel(tool)
        end
    end
    if toolId then
        return IKST_HubNav.toolLabel({ id = toolId, title = toolId })
    end
    return IKST_HubNav.modeLabel(ws)
end

function IKST_HubNav.labelForView(view)
    local state = IKST.getPlayerState and IKST.resolvePlayer and IKST.getPlayerState(IKST.resolvePlayer())
    if state and state.navMode then
        return IKST_HubNav.labelForNav(state.navMode, state.navTool)
    end
    local mode, tool = IKST_HubNav.resolveView(view)
    return IKST_HubNav.labelForNav(mode, tool)
end

function IKST_HubNav.resolveView(view)
    if IKST_HubNav.isHomeView(view) then
        return IKST.VIEW.favorites, nil
    end
    if IKST_HubNav.workspaceById(view) then
        return view, nil
    end
    local legacy = IKST_HubNav.LEGACY_VIEW[view]
    if legacy then
        return legacy.mode, legacy.tool
    end
    return IKST.VIEW.favorites, nil
end

function IKST_HubNav.defaultTool(modeId)
    local ws = IKST_HubNav.workspaceById(modeId)
    if ws and ws.tools and ws.tools[1] then
        return ws.tools[1].id
    end
    local pluginTools = IKST.Plugins.hubToolsForMode(modeId)
    if pluginTools[1] then
        return pluginTools[1].id
    end
    if modeId == IKST.VIEW.economy then
        return "money"
    end
    if modeId == IKST.VIEW.loot then
        return "loot"
    end
    if modeId == IKST.VIEW.admin then
        return "ghost"
    end
    if modeId == IKST.VIEW.everyone then
        return "overview"
    end
    if modeId == IKST.VIEW.tiles then
        return "overview"
    end
    if modeId == IKST.VIEW.vehicles then
        return "overview"
    end
    return nil
end

function IKST_HubNav.getNav(state)
    if not state then
        return IKST.VIEW.favorites, nil
    end
    local mode = state.navMode or state.view or IKST.VIEW.favorites
    local tool = state.navTool
    if IKST_HubNav.isHomeView(mode) then
        return IKST.VIEW.favorites, nil
    end
    if mode == IKST.VIEW.everyone then
        if not tool then
            tool = "overview"
        end
        return IKST.VIEW.everyone, tool
    end
    if mode == IKST.VIEW.economy and not tool then
        tool = "money"
    end
    if mode == IKST.VIEW.loot and not tool then
        tool = "loot"
    end
    if mode == IKST.VIEW.admin and not tool then
        tool = "ghost"
    end
    if not tool then
        tool = IKST_HubNav.defaultTool(mode)
    end
    return mode, tool
end

function IKST_HubNav.applyNav(state, modeId, toolId)
    if not state then
        return
    end
    if IKST_HubNav.isHomeView(modeId) then
        state.navMode = IKST.VIEW.favorites
        state.navTool = nil
        state.view = IKST.VIEW.favorites
        state.job = nil
        return
    end
    -- Keep protect under Tiles (no Claim redirect).
    state.navMode = modeId
    state.view = modeId
    state.job = modeId
    if not toolId then
        toolId = IKST_HubNav.defaultTool(modeId)
    end
    state.navTool = toolId
    IKST_HubNav.applyToolState(state, modeId, toolId)
end

function IKST_HubNav.applyToolState(state, modeId, toolId)
    if not state or not toolId then
        return
    end
    if modeId == IKST.VIEW.utilities then
        if toolId == "self" then
            state.staffMode = "self"
        elseif toolId == "items" then
            state.staffMode = "items"
        elseif toolId == "players" then
            state.staffMode = "players"
        elseif toolId == "zombies" then
            state.gadgetMode = "threat"
        elseif toolId == "servertools" then
            state.staffMode = "world"
        elseif toolId == "teleport" then
            state.staffMode = "waypoints"
        elseif toolId == "batch" then
            state.staffMode = "batch"
        end
    elseif modeId == IKST.VIEW.claim then
        if toolId == "overview" then
            state.guardMode = "overview"
        elseif toolId == "requests" then
            state.guardMode = "requests"
        elseif toolId == "safehouses" then
            state.guardMode = "safehouses"
        elseif toolId == "vehicleclaim" then
            state.guardMode = "vehicles"
        elseif toolId == "catch" then
            state.guardMode = "tools"
        end
    elseif modeId == IKST.VIEW.tiles then
        if toolId == "remove" then
            state.worldEditMode = "remove"
        elseif toolId == "paint" then
            state.worldEditMode = "paint"
        elseif toolId == "inspect" then
            state.worldEditMode = "inspect"
        elseif toolId == "blueprints" then
            state.guardMode = "blueprints"
        elseif toolId == "area" then
            state.autoRadius = state.autoRadius or IKST.RADIUS_PRESETS.M
        elseif toolId == "protect" then
            state.guardMode = "tiles"
        end
    elseif modeId == IKST.VIEW.vehicles then
        if toolId == "spawn" then
            state.vehicleMode = "spawn"
        elseif toolId == "repair" then
            state.vehicleMode = "list"
        elseif toolId == "prune" then
            state.vehicleMode = "prune"
        end
    elseif modeId == IKST.VIEW.loot then
        state.lootScope = state.lootScope or IKST.CLEANUP_SCOPES.single
    elseif modeId == IKST.VIEW.economy then
        if toolId == "money" or toolId == "shop" or toolId == "valuables" or toolId == "admin" then
            state.economyMode = toolId
        elseif toolId == "economy" then
            state.economyMode = state.economyMode or "money"
        end
    elseif modeId == IKST.VIEW.everyone then
        state.everyoneTool = toolId
    elseif modeId == IKST.VIEW.admin then
        state.adminTool = toolId
    end
end

function IKST_HubNav.armedToNav(state)
    if not state or not state.armed or not state.armedJob then
        return nil, nil
    end
    return IKST_HubNav.resolveView(state.armedJob)
end

function IKST_HubNav.resolveOpenView(player)
    return IKST.VIEW.favorites, nil
end

function IKST_HubNav.effectiveView(panel, state)
    if not panel then
        return nil
    end
    state = state or (panel.player and IKST.getPlayerState(panel.player))
    local mode, tool = IKST_HubNav.getNav(state)
    if mode == IKST.VIEW.tiles and tool then
        if tool == "paint" then
            return IKST.VIEW.painter
        end
        if tool == "inspect" then
            return IKST.VIEW.inspector
        end
        if tool == "remove" then
            return IKST.VIEW.cleanup
        end
        if tool == "area" then
            return IKST.VIEW.automation
        end
        if tool == "protect" or tool == "blueprints" then
            return IKST.VIEW.guard
        end
    end
    if mode == IKST.VIEW.utilities and tool == "zombies" then
        return IKST.VIEW.threat
    end
    if mode == IKST.VIEW.utilities and (tool == "players" or tool == "self" or tool == "items" or tool == "teleport" or tool == "servertools") then
        return IKST.VIEW.staff
    end
    if mode == IKST.VIEW.claim then
        return IKST.VIEW.guard
    end
    if mode == IKST.VIEW.vehicles then
        return IKST.VIEW.vehicle
    end
    if mode == IKST.VIEW.economy then
        return IKST.VIEW.economy
    end
    if mode == IKST.VIEW.loot then
        return IKST.VIEW.loot
    end
    if mode == IKST.VIEW.admin then
        return IKST.VIEW.admin
    end
    if mode == IKST.VIEW.everyone then
        return IKST.VIEW.everyone
    end
    return mode
end

function IKST_HubNav.syncArmedTab(state, armedJob)
    if not state or not armedJob then
        return
    end
    -- Do not yank the sidebar away while a click-tool is armed (old guard->claim redirect broke picks).
    local mode, tool = IKST_HubNav.resolveView(armedJob)
    if state.navMode == mode then
        return
    end
    if mode == IKST.VIEW.tiles or mode == IKST.VIEW.loot or mode == IKST.VIEW.cleanup
        or mode == IKST.VIEW.inspector or mode == IKST.VIEW.painter then
        IKST_HubNav.applyNav(state, mode, tool)
    end
end

function IKST_HubNav.onNavEntered(panel, modeId, toolId)
    if not panel or not panel.player then
        return
    end
    local player = panel.player
    if modeId == IKST.VIEW.claim and toolId == "overview" and IKST_JobGuard then
        IKST_JobGuard.requestSafehouses(player)
        IKST_JobGuard.requestClaims(player)
        if IKST_JobStaff and type(IKST_JobStaff.requestClaimRequests) == "function"
            and IKST_Access and type(IKST_Access.canUseStaffTools) == "function"
            and IKST_Access.canUseStaffTools(player) then
            IKST_JobStaff.requestClaimRequests(player)
        end
    elseif modeId == IKST.VIEW.claim and toolId == "requests" and IKST_JobStaff then
        IKST_JobStaff.requestClaimRequests(player)
    elseif modeId == IKST.VIEW.claim and toolId == "safehouses" and IKST_JobGuard then
        IKST_JobGuard.requestSafehouses(player)
    elseif modeId == IKST.VIEW.claim and toolId == "vehicleclaim" and IKST_JobGuard then
        IKST_JobGuard.requestClaims(player)
        IKST_JobGuard.requestNearbyVehicles(player)
    elseif modeId == IKST.VIEW.claim and toolId == "catch" and IKST_JobStaff then
        IKST_JobStaff.requestPlayers(player)
    elseif modeId == IKST.VIEW.utilities and toolId == "players" then
        if IKST_JobStaff then
            IKST_JobStaff.requestPlayers(player)
            if type(IKST_JobStaff.requestHelpList) == "function" then
                IKST_JobStaff.requestHelpList(player)
            else
                IKST.dispatchCommand(player, IKST.CMD.helpList, {})
            end
        end
    elseif modeId == IKST.VIEW.utilities and toolId == "teleport" and IKST_JobStaff then
        IKST_JobStaff.requestWaypoints(player)
    end
    IKST.Plugins.onNavEntered(panel, modeId, toolId)
end

function IKST_HubNav.homeContentY(panel)
    return panel:titleBarHeight() + 2 + IKST_JobLayout.STATUS_HEIGHT + 8
end

-- Dashboard: delegates to IKST_DashboardUI (IKappaID_UI framework).
IKST_HubNav.DASHBOARD_STATS = IKST_DashboardUI and IKST_DashboardUI.STATS or {}

function IKST_HubNav.dashboardMetrics(panel)
    if IKST_DashboardUI then
        return IKST_DashboardUI.metrics(panel)
    end
    return { top = 0, margin = 12, gap = 8, sidebarW = 200, sidebarH = 400, contentX = 220, contentW = 400 }
end

function IKST_HubNav.dashboardSections(panel)
    if IKST_DashboardUI then
        return IKST_DashboardUI.sections(panel)
    end
    return { m = IKST_HubNav.dashboardMetrics(panel), headerY = 0, headerH = 32, statsY = 40, cardW = 120, cardH = 80, cardGap = 8, btnH = 28, favHeaderY = 200, favY = 230, cols = 2 }
end

function IKST_HubNav.buildDashboardSidebar(_panel)
end

function IKST_HubNav.buildDashboardFavorites(_panel, _sec)
end

function IKST_HubNav.favoriteAvailable(_panel, _fav)
    return false
end

function IKST_HubNav.favoriteClickFn(_panel, _fav)
    return function() end
end

function IKST_HubNav.buildDashboardHeaderButtons(panel, sec)
    if IKST_DashboardUI then
        IKST_DashboardUI.buildHeader(panel, sec)
    end
end

function IKST_HubNav.buildDashboard(panel)
    if IKST_DashboardUI then
        IKST_DashboardUI.build(panel)
    end
end

function IKST_HubNav.drawDashboardStats(panel, sec)
    if IKST_DashboardUI then
        IKST_DashboardUI.drawStats(panel, sec)
    end
end

function IKST_HubNav.drawDashboard(panel, bodyY)
    if IKST_DashboardUI then
        IKST_DashboardUI.draw(panel, bodyY)
    end
end

function IKST_HubNav.toolsForWorkspace(workspaceId, player)
    local ws = IKST_HubNav.workspaceById(workspaceId)
    local tools = {}
    if ws and ws.tools then
        for _, tool in ipairs(ws.tools) do
            if tool.adminOnly and player and IKST_Access and not IKST_Access.canUseStaffTools(player) then
                -- skip staff-only tools for non-staff
            elseif tool.pluginId and IKST.Plugins and not IKST.Plugins.isActive(tool.pluginId) then
                -- skip tools that need a missing plugin
            elseif tool.pluginId and IKST.Plugins and IKST.Plugins.canUseAdmin
                and not IKST.Plugins.canUseAdmin(tool.pluginId, player)
                and tool.adminOnly then
                -- skip
            else
                tools[#tools + 1] = tool
            end
        end
    end
    for _, tool in ipairs(IKST.Plugins.hubToolsForMode(workspaceId)) do
        local id = tool and tool.id
        local dup = false
        if id then
            for i = 1, #tools do
                if tools[i].id == id then
                    dup = true
                    break
                end
            end
        end
        if not dup then
            tools[#tools + 1] = tool
        end
    end
    table.sort(tools, function(a, b)
        return (tonumber(a.order) or 50) < (tonumber(b.order) or 50)
    end)
    return tools
end

function IKST_HubNav.hasSidebar(view, player)
    if IKST_HubNav.isHomeView(view) then
        return false
    end
    return #IKST_HubNav.toolsForWorkspace(view, player) > 0
end

function IKST_HubNav.buildSidebar(panel)
    if not panel or not IKST_HubNav.hasSidebar(panel.view, panel.player) or not panel.q1Panel then
        return
    end
    IKST_HubNav.SIDEBAR_W = IKST_UI_Layout.sidebarWidth()
    local tools = IKST_HubNav.toolsForWorkspace(panel.view, panel.player)
    local state = IKST.getPlayerState(panel.player)
    local activeTool = state and state.navTool or IKST_HubNav.defaultTool(panel.view)
    local pad = IKST_UI_Layout.s(12)
    local y = pad
    local x = pad
    local sidebarW = IKST_JobLayout.resolveColumns(panel)
    if sidebarW < 1 and panel.q1Panel then
        sidebarW = panel.q1Panel:getWidth() or IKST_JobLayout.SIDEBAR_MIN_W
    end
    local w = math.max(28, sidebarW - (pad * 2))
    local itemH = math.max(32, IKST_UI_Layout.s(40))
    local gap = IKST_UI_Layout.s(8)

    -- On tight height, pack rows then scroll — never paint through the floor.
    local q1H = panel.q1Panel.height or 0
    local visibleCount = #tools
    local space = math.max(0, q1H - pad * 2)
    local need = visibleCount * (itemH + gap)
    local navScroll = panel._hubNavScroll or 0
    if visibleCount > 0 and need > space and space > 0 then
        local perEntry = math.max(24, math.floor(space / visibleCount))
        gap = math.max(2, math.min(gap, perEntry - 22))
        itemH = math.max(22, perEntry - gap)
        need = visibleCount * (itemH + gap)
    end
    local maxScroll = math.max(0, need - space)
    if navScroll > maxScroll then
        navScroll = maxScroll
    end
    if navScroll < 0 then
        navScroll = 0
    end
    panel._hubNavScroll = navScroll
    panel._hubNavMaxScroll = maxScroll
    y = pad - navScroll

    if panel.q1Panel.clipping ~= nil then
        panel.q1Panel.clipping = true
    end

    -- Home lives on the chrome Home button; do not duplicate Dashboard in the sidebar.
    for _, tool in ipairs(tools) do
        local label = IKST_HubNav.toolLabel(tool)
        local btn = ISButton:new(x, y, w, itemH, label, panel, function()
            panel:enterNav(panel.view, tool.id)
        end)
        btn:initialise()
        btn._ikstHubSatellite = true
        IKUI_Chrome.styleNavPill(btn, activeTool == tool.id)
        local tip = label
        if tool.descKey or tool.desc then
            tip = label .. " <LINE> " .. IKST.text(tool.descKey, tool.desc or "")
        end
        if IKUI_Chrome.setTooltip then
            IKUI_Chrome.setTooltip(btn, tip)
        else
            btn.tooltip = tip
        end
        if IKST_ClaimIcons and type(IKST_ClaimIcons.applyButtonIcon) == "function" then
            local iconPath = tool.icon
            if not iconPath and type(IKST_ClaimIcons.pathForTool) == "function" then
                iconPath = IKST_ClaimIcons.pathForTool(panel.view, tool.id)
            end
            if iconPath then
                IKST_ClaimIcons.applyButtonIcon(btn, iconPath)
            end
        end
        if IKST_DashboardQuick and type(IKST_DashboardQuick.decorateToolButton) == "function" then
            local entryId = IKST_DashboardQuick.entryIdForNav(panel.view, tool.id)
            IKST_DashboardQuick.decorateToolButton(panel, btn, entryId)
        end
        panel:addQ1Widget(btn)
        y = y + itemH + gap
    end
end

