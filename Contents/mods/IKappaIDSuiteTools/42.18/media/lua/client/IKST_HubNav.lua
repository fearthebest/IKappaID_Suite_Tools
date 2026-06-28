if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Plugins"
require "IKST_Access"
require "IKST_JobLayout"

IKST_HubNav = IKST_HubNav or {}
IKST_HubNav.SIDEBAR_W = 112

IKST_HubNav.WORKSPACES = {
    {
        id = IKST.VIEW.utilities,
        titleKey = "IGUI_IKST_WS_Utilities",
        title = "Utilities",
        descKey = "IGUI_IKST_WS_Utilities_Desc",
        desc = "Server tools: self, items, players, zombies, world, teleport",
        adminOnly = true,
        tools = {
            { id = "self", titleKey = "IGUI_IKST_Util_Self", title = "Self", order = 10 },
            { id = "items", titleKey = "IGUI_IKST_Util_Items", title = "Items", order = 20 },
            { id = "players", titleKey = "IGUI_IKST_Util_Players", title = "Players", order = 30 },
            { id = "zombies", titleKey = "IGUI_IKST_Util_Zombies", title = "Zombies", order = 40 },
            { id = "servertools", titleKey = "IGUI_IKST_Util_ServerTools", title = "Server tools", order = 50 },
            { id = "teleport", titleKey = "IGUI_IKST_Util_Teleport", title = "Teleport", order = 60 },
        },
    },
    {
        id = IKST.VIEW.claim,
        titleKey = "IGUI_IKST_WS_Claim",
        title = "Claim",
        descKey = "IGUI_IKST_WS_Claim_Desc",
        desc = "Claim a safehouse or vehicle",
        tools = {
            { id = "safehouses", titleKey = "IGUI_IKST_Claim_Safehouse", title = "Claim safehouse", order = 10 },
            { id = "vehicleclaim", titleKey = "IGUI_IKST_Claim_Vehicle", title = "Claim vehicle", order = 20 },
        },
    },
    {
        id = IKST.VIEW.tiles,
        titleKey = "IGUI_IKST_WS_World",
        title = "World",
        descKey = "IGUI_IKST_WS_World_Desc",
        desc = "Remove, paint, inspect, blueprints, protection",
        pluginId = "tiles",
        adminOnly = true,
        tools = nil,
    },
    {
        id = IKST.VIEW.vehicles,
        titleKey = "IGUI_IKST_WS_Vehicles",
        title = "Vehicles",
        descKey = "IGUI_IKST_WS_Vehicles_Desc",
        desc = "Spawn, repair, prune — admin vehicle tools",
        pluginId = "vehicles",
        adminOnly = true,
        tools = nil,
    },
    {
        id = IKST.VIEW.everyone,
        titleKey = "IGUI_IKST_WS_Everyone",
        title = "Everyone",
        descKey = "IGUI_IKST_WS_Everyone_Desc",
        desc = "Useful info and claim lists for everyday play",
        tools = nil,
    },
    {
        id = IKST.VIEW.economy,
        titleKey = "IGUI_IKST_WS_Economy",
        title = "Economy",
        descKey = "IGUI_IKST_WS_Economy_Desc",
        desc = "Balances, vending, and transfers",
        pluginId = "economy",
        tools = nil,
    },
    {
        id = IKST.VIEW.loot,
        titleKey = "IGUI_IKST_WS_Loot",
        title = "Loot",
        descKey = "IGUI_IKST_WS_Loot_Desc",
        desc = "Repopulate containers with vanilla loot",
        pluginId = "loot",
        adminOnly = true,
        tools = nil,
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
    [IKST.VIEW.economy] = { mode = IKST.VIEW.economy, tool = "economy" },
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
    [IKST.VIEW.worldguard] = { mode = IKST.VIEW.utilities, tool = "self" },
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
        if ws.pluginId and (not IKST.Plugins or not IKST.Plugins.isActive(ws.pluginId)) then
            -- skip inactive addon
        elseif IKST_Access.canUseWorkspace(player, ws.id) then
            out[#out + 1] = ws
        end
    end
    return out
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
        return "economy"
    end
    if modeId == IKST.VIEW.loot then
        return "loot"
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
        return IKST.VIEW.everyone, nil
    end
    if mode == IKST.VIEW.economy and not tool then
        tool = "economy"
    end
    if mode == IKST.VIEW.loot and not tool then
        tool = "loot"
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
    state.navMode = modeId
    state.view = modeId
    state.job = modeId
    if modeId == IKST.VIEW.everyone then
        state.navTool = nil
        return
    end
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
        end
    elseif modeId == IKST.VIEW.claim then
        if toolId == "safehouses" then
            state.guardMode = "safehouses"
        elseif toolId == "vehicleclaim" then
            state.guardMode = "vehicles"
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
        elseif toolId == "protect" then
            state.guardMode = "tiles"
        end
    elseif modeId == IKST.VIEW.vehicles then
        if toolId == "spawn" then
            state.vehicleMode = "spawn"
        elseif toolId == "repair" then
            state.vehicleMode = "extras"
        elseif toolId == "prune" then
            state.vehicleMode = "prune"
        end
    elseif modeId == IKST.VIEW.loot then
        state.lootScope = state.lootScope or IKST.CLEANUP_SCOPES.single
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
    if mode == IKST.VIEW.everyone then
        return IKST.VIEW.everyone
    end
    return mode
end

function IKST_HubNav.syncArmedTab(state, armedJob)
    if not state or not armedJob then
        return
    end
    local mode, tool = IKST_HubNav.resolveView(armedJob)
    IKST_HubNav.applyNav(state, mode, tool)
end

function IKST_HubNav.onNavEntered(panel, modeId, toolId)
    if not panel or not panel.player then
        return
    end
    local player = panel.player
    if modeId == IKST.VIEW.claim and toolId == "safehouses" and IKST_JobGuard then
        IKST_JobGuard.requestSafehouses(player)
    elseif modeId == IKST.VIEW.claim and toolId == "vehicleclaim" and IKST_JobGuard then
        IKST_JobGuard.requestClaims(player)
        IKST_JobGuard.requestNearbyVehicles(player)
    elseif modeId == IKST.VIEW.utilities and toolId == "players" then
        local st = IKST.getPlayerState(player)
        if st and (st.staffMode == "players" or st.staffMode == "moderate") and IKST.isMultiplayerSession() and IKST_JobStaff then
            IKST_JobStaff.requestPlayers(player)
        end
    elseif modeId == IKST.VIEW.utilities and toolId == "teleport" and IKST_JobStaff then
        IKST_JobStaff.requestWaypoints(player)
    end
    IKST.Plugins.onNavEntered(panel, modeId, toolId)
end

function IKST_HubNav.homeContentY(panel)
    return panel:titleBarHeight() + 2 + IKST_JobLayout.STATUS_HEIGHT + 8
end

function IKST_HubNav.toolsForWorkspace(workspaceId)
    local ws = IKST_HubNav.workspaceById(workspaceId)
    local tools = {}
    if ws and ws.tools then
        for _, tool in ipairs(ws.tools) do
            tools[#tools + 1] = tool
        end
    end
    for _, tool in ipairs(IKST.Plugins.hubToolsForMode(workspaceId)) do
        tools[#tools + 1] = tool
    end
    table.sort(tools, function(a, b)
        return (tonumber(a.order) or 50) < (tonumber(b.order) or 50)
    end)
    return tools
end

function IKST_HubNav.hasSidebar(view)
    if IKST_HubNav.isHomeView(view) or view == IKST.VIEW.everyone then
        return false
    end
    return #IKST_HubNav.toolsForWorkspace(view) > 0
end

function IKST_HubNav.buildSidebar(panel)
    if not panel or not IKST_HubNav.hasSidebar(panel.view) then
        return
    end
    local tools = IKST_HubNav.toolsForWorkspace(panel.view)
    local state = IKST.getPlayerState(panel.player)
    local activeTool = state and state.navTool or IKST_HubNav.defaultTool(panel.view)
    local y = IKST_JobLayout.toLayerY(panel, panel.jobHeaderY or IKST_JobLayout.chromeContentTop(panel))
    local x = 4
    local w = IKST_HubNav.SIDEBAR_W - 8
    for _, tool in ipairs(tools) do
        local label = IKST_HubNav.toolLabel(tool)
        panel:makeChromeButton(x, y, w, 24, label, function()
            panel:enterNav(panel.view, tool.id)
        end, activeTool == tool.id)
        y = y + 26
    end
end

function IKST_HubNav.drawHomeModes(panel, bodyY)
    panel.homeHits = panel.homeHits or {}
    local cc = IKST_Chrome.colors
    local y = bodyY + 4
    panel:drawText(IKST.text("IGUI_IKST_Workspaces", "Workspaces"), IKST_JobLayout.MARGIN, y, cc.textMuted.r, cc.textMuted.g, cc.textMuted.b, 1, UIFont.Small)
    y = y + 20
    local cardH = 58
    local gap = 10
    local w = IKST_JobLayout.contentWidth(panel)
    for _, ws in ipairs(IKST_HubNav.visibleWorkspaces(panel.player)) do
        local title = IKST_HubNav.modeLabel(ws)
        local desc = IKST.text(ws.descKey, ws.desc or "")
        IKST_Chrome.drawJobCard(panel, IKST_JobLayout.MARGIN, y, w, cardH, title, desc)
        table.insert(panel.homeHits, { x = IKST_JobLayout.MARGIN, y = y, w = w, h = cardH, mode = ws.id })
        y = y + cardH + gap
    end
end
