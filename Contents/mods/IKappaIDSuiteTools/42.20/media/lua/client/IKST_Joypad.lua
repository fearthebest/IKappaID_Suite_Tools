--[[
    IKappaID Suite Tools - controller map (B42 Joypad.* constants)

    Keyboard
      Ctrl+Shift+W          always              toggle hub

    World / HUD (no hub focus)
      Y                     open/toggle hub (Start if Y is already used)
      A                     sidebar icon        open hub
      A                     edge dock           expand hub
      D-pad                 edge dock           cycle dock edge
      B                     edge dock           no-op

    Hub focused
      A                     activate focused control
      B                     back; Home closes and restores focus
      X                     minimize to edge dock
      D-pad Up/Down         move focus (nav then tools)
      D-pad Left/Right      sidebar <-> content
      LB / RB               previous / next workspace

    Authority note: one thin JoypadControllerData.onPressButtonNoFocus wrap
    for world Y/Start only - no OnTick poll, no ISEquippedItem patches.
]]
if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Access"
require "IKappaID_UI/IKUI_Shell"
require "IKST_Hub"

IKST_Joypad = IKST_Joypad or {}
IKST_Joypad._wantFocus = false
IKST_Joypad._worldHooked = false
IKST_Joypad._hubHooks = false

local ORANGE_R, ORANGE_G, ORANGE_B = 1.0, 0.42, 0.21

local function scaled(px, fallback)
    if IKUI_Config and type(IKUI_Config.s) == "function" then
        return IKUI_Config.s(px)
    end
    return fallback or px
end

local function playerNumOf(player)
    if player and type(player.getPlayerNum) == "function" then
        local n = player:getPlayerNum()
        if n ~= nil then
            return n
        end
    end
    return 0
end

local function joypadDataOf(player)
    local n = playerNumOf(player)
    if type(getJoypadData) == "function" then
        local data = getJoypadData(n)
        if data then
            return data
        end
    end
    if JoypadState and JoypadState.players then
        return JoypadState.players[n + 1]
    end
    return nil
end

function IKST_Joypad.resolvePlayer(player)
    if not player then
        player = getPlayer and getPlayer() or nil
    end
    if not player and getSpecificPlayer then
        player = getSpecificPlayer(0)
    end
    if IKST and type(IKST.resolvePlayer) == "function" then
        player = IKST.resolvePlayer(player)
    end
    return player
end

function IKST_Joypad.canOpen(player)
    player = IKST_Joypad.resolvePlayer(player)
    if not player or not IKST_Access or type(IKST_Access.canOpenPanel) ~= "function" then
        return false
    end
    return IKST_Access.canOpenPanel(player) == true
end

function IKST_Joypad.restorePlayerFocus(player)
    player = IKST_Joypad.resolvePlayer(player)
    local n = playerNumOf(player)
    IKST_Joypad._wantFocus = false
    if type(setJoypadFocus) == "function" then
        setJoypadFocus(n, nil)
    end
    if type(setPlayerJoypadFocus) == "function" then
        setPlayerJoypadFocus(n, nil)
    end
    local jd = joypadDataOf(player)
    if jd then
        jd.focus = nil
        if jd.prevFocus ~= nil then
            jd.prevFocus = nil
        end
        if type(updateJoypadFocus) == "function" then
            updateJoypadFocus(jd)
        end
    end
end

function IKST_Joypad.takeFocus(ui, player)
    if not ui then
        return
    end
    player = player or ui.player or IKST_Joypad.resolvePlayer()
    local n = playerNumOf(player)
    local jd = joypadDataOf(player)
    if type(setJoypadFocus) == "function" then
        setJoypadFocus(n, ui)
    elseif jd then
        jd.focus = ui
        if type(updateJoypadFocus) == "function" then
            updateJoypadFocus(jd)
        end
    end
    if type(ui.setJoypadFocused) == "function" then
        ui:setJoypadFocused(true, jd)
    else
        ui.joyfocus = jd
        ui._ikstJoypadOn = true
    end
end

function IKST_Joypad.focusHub(player)
    player = IKST_Joypad.resolvePlayer(player)
    local panel = IKUI_Shell and IKUI_Shell.instance
    if not panel then
        return false
    end
    if type(panel.getIsVisible) == "function" and panel:getIsVisible() == false then
        return false
    end
    IKST_Joypad.takeFocus(panel, player)
    return true
end

local function widgetVisible(w)
    if not w then
        return false
    end
    if type(w.getIsVisible) == "function" then
        return w:getIsVisible() ~= false
    end
    if w.visible == false then
        return false
    end
    return true
end

local function widgetEnabled(w)
    if not w then
        return false
    end
    if w.enable == false then
        return false
    end
    if type(w.isEnabled) == "function" and not w:isEnabled() then
        return false
    end
    if type(w.isEnable) == "function" and not w:isEnable() then
        return false
    end
    return true
end

local function isFocusable(w)
    if not w or not widgetVisible(w) or not widgetEnabled(w) then
        return false
    end
    if w._ikuiOnClick or w.onclick or w.onClick or w.forceClick then
        return true
    end
    if w.Type == "ISButton" or w.Type == "ISTickBox" then
        return true
    end
    return false
end

local function isDescendantOf(w, ancestor)
    local p = w
    local guard = 0
    while p and guard < 24 do
        if p == ancestor then
            return true
        end
        p = p.parent
        guard = guard + 1
    end
    return false
end

function IKST_Joypad.rebuildFocusList(panel)
    if not panel then
        return
    end
    local sidebar = {}
    local content = {}
    local seen = {}

    local function add(list, w)
        if not w or seen[w] or not isFocusable(w) then
            return
        end
        seen[w] = true
        list[#list + 1] = w
    end

    if panel.homeNavBtn then
        add(sidebar, panel.homeNavBtn)
    end

    local chrome = panel.chromeWidgets or {}
    for i = 1, #chrome do
        local w = chrome[i]
        if w and panel.q1Panel and isDescendantOf(w, panel.q1Panel) then
            add(sidebar, w)
        end
    end

    if panel.q1Panel and type(panel.q1Panel.children) == "table" then
        for _, w in pairs(panel.q1Panel.children) do
            add(sidebar, w)
        end
    end

    for i = 1, #chrome do
        local w = chrome[i]
        if w and not seen[w] then
            if not (panel.q4Panel and isDescendantOf(w, panel.q4Panel)) then
                add(content, w)
            end
        end
    end

    local jobs = panel.jobWidgets or {}
    for i = 1, #jobs do
        add(content, jobs[i])
    end

    panel._ikstSidebar = sidebar
    panel._ikstContent = content

    local keep = panel._ikstFocusWidget
    panel._ikstFocusIndex = 1
    if keep then
        local list = (panel._ikstFocusRegion == "sidebar") and sidebar or content
        for i = 1, #list do
            if list[i] == keep then
                panel._ikstFocusIndex = i
                break
            end
        end
    end
    if panel._ikstFocusRegion == "sidebar" and #sidebar == 0 then
        panel._ikstFocusRegion = "content"
        panel._ikstFocusIndex = 1
    elseif panel._ikstFocusRegion ~= "sidebar" and #content == 0 and #sidebar > 0 then
        panel._ikstFocusRegion = "sidebar"
        panel._ikstFocusIndex = 1
    elseif not panel._ikstFocusRegion then
        panel._ikstFocusRegion = (#sidebar > 0) and "sidebar" or "content"
    end
end

function IKST_Joypad.currentList(panel)
    if not panel then
        return {}
    end
    if panel._ikstFocusRegion == "sidebar" then
        return panel._ikstSidebar or {}
    end
    return panel._ikstContent or {}
end

function IKST_Joypad.clearFocusFlags(panel)
    if not panel then
        return
    end
    local function clear(list)
        if not list then
            return
        end
        for i = 1, #list do
            local w = list[i]
            if w then
                w._ikstJoyFocused = false
            end
        end
    end
    clear(panel._ikstSidebar)
    clear(panel._ikstContent)
    panel._ikstFocusWidget = nil
end

function IKST_Joypad.drawRingOn(el)
    if not el then
        return
    end
    local ww = 0
    local hh = 0
    if type(el.getWidth) == "function" then
        ww = tonumber(el:getWidth()) or 0
    else
        ww = tonumber(el.width) or 0
    end
    if type(el.getHeight) == "function" then
        hh = tonumber(el:getHeight()) or 0
    else
        hh = tonumber(el.height) or 0
    end
    if ww < 2 or hh < 2 then
        return
    end
    -- Rounded highlight only - never drawRectBorder (that made square corners
    -- on top of pill buttons like Refresh / Home / Disarm).
    local radius = math.max(2, math.floor(math.min(ww, hh) / 2))
    if IKUI_Chrome and type(IKUI_Chrome.drawRoundedFill) == "function" then
        IKUI_Chrome.drawRoundedFill(el, 0, 0, ww, hh, ORANGE_R, ORANGE_G, ORANGE_B, 0.28, radius)
        return
    end
    if type(el.drawRect) == "function" then
        el:drawRect(0, 0, ww, hh, 0.28, ORANGE_R, ORANGE_G, ORANGE_B)
    end
end

function IKST_Joypad.hookWidgetRender(w)
    if not w or w._ikstJoyRenderHooked then
        return
    end
    w._ikstJoyRenderHooked = true
    local old = w.render
    w.render = function(self)
        if old then
            old(self)
        end
        if self._ikstJoyFocused then
            IKST_Joypad.drawRingOn(self)
        end
    end
end

function IKST_Joypad.applyFocus(panel)
    if not panel then
        return
    end
    if not panel._ikstSidebar or not panel._ikstContent then
        IKST_Joypad.rebuildFocusList(panel)
    end
    IKST_Joypad.clearFocusFlags(panel)
    local list = IKST_Joypad.currentList(panel)
    local idx = panel._ikstFocusIndex or 1
    if idx < 1 then
        idx = 1
    end
    if idx > #list then
        idx = #list
    end
    panel._ikstFocusIndex = idx
    local w = list[idx]
    if w then
        w._ikstJoyFocused = true
        panel._ikstFocusWidget = w
        IKST_Joypad.hookWidgetRender(w)
    end
end

function IKST_Joypad.paintFocusRing(panel)
    if not panel or not panel._ikstJoypadOn then
        return
    end
    local w = panel._ikstFocusWidget
    if not w or not w._ikstJoyFocused or w._ikstJoyRenderHooked then
        return
    end
    IKST_Joypad.drawRingOn(w)
end

function IKST_Joypad.activateWidget(widget, panel)
    if not widget or not widgetEnabled(widget) then
        return
    end
    if type(widget._ikuiOnClick) == "function" then
        widget._ikuiOnClick(widget._ikuiClickTarget or panel, widget)
        return
    end
    if type(widget.forceClick) == "function" then
        widget:forceClick()
        return
    end
    local fn = widget.onclick or widget.onClick
    if type(fn) == "function" then
        fn(widget.target or panel, widget)
        return
    end
    if type(widget.activate) == "function" then
        widget:activate()
    end
end

function IKST_Joypad.moveFocus(panel, delta)
    if not panel then
        return
    end
    IKST_Joypad.rebuildFocusList(panel)
    local list = IKST_Joypad.currentList(panel)
    if #list == 0 then
        if panel._ikstFocusRegion == "sidebar" and panel._ikstContent and #panel._ikstContent > 0 then
            panel._ikstFocusRegion = "content"
            panel._ikstFocusIndex = 1
        elseif panel._ikstFocusRegion ~= "sidebar" and panel._ikstSidebar and #panel._ikstSidebar > 0 then
            panel._ikstFocusRegion = "sidebar"
            panel._ikstFocusIndex = 1
        else
            return
        end
        IKST_Joypad.applyFocus(panel)
        return
    end
    local idx = (panel._ikstFocusIndex or 1) + delta
    if idx < 1 then
        if panel._ikstFocusRegion == "content" and panel._ikstSidebar and #panel._ikstSidebar > 0 and delta < 0 then
            panel._ikstFocusRegion = "sidebar"
            panel._ikstFocusIndex = #panel._ikstSidebar
            IKST_Joypad.applyFocus(panel)
            return
        end
        idx = #list
    elseif idx > #list then
        if panel._ikstFocusRegion == "sidebar" and panel._ikstContent and #panel._ikstContent > 0 and delta > 0 then
            panel._ikstFocusRegion = "content"
            panel._ikstFocusIndex = 1
            IKST_Joypad.applyFocus(panel)
            return
        end
        idx = 1
    end
    panel._ikstFocusIndex = idx
    IKST_Joypad.applyFocus(panel)
end

-- JobsPanel stubs call step(); keep as Up/Down alias.
function IKST_Joypad.step(panel, delta)
    IKST_Joypad.moveFocus(panel, delta or 1)
end

function IKST_Joypad.switchRegion(panel, wantSidebar)
    if not panel then
        return
    end
    IKST_Joypad.rebuildFocusList(panel)
    if wantSidebar then
        if panel._ikstSidebar and #panel._ikstSidebar > 0 then
            panel._ikstFocusRegion = "sidebar"
            if not panel._ikstFocusIndex or panel._ikstFocusIndex < 1 or panel._ikstFocusIndex > #panel._ikstSidebar then
                panel._ikstFocusIndex = 1
            end
        end
    else
        if panel._ikstContent and #panel._ikstContent > 0 then
            panel._ikstFocusRegion = "content"
            if not panel._ikstFocusIndex or panel._ikstFocusIndex < 1 or panel._ikstFocusIndex > #panel._ikstContent then
                panel._ikstFocusIndex = 1
            end
        end
    end
    IKST_Joypad.applyFocus(panel)
end

function IKST_Joypad.onHubDir(panel, dx, dy)
    if not panel then
        return true
    end
    if dx ~= 0 then
        IKST_Joypad.switchRegion(panel, dx < 0)
        return true
    end
    if dy ~= 0 then
        IKST_Joypad.moveFocus(panel, dy)
        return true
    end
    return true
end

function IKST_Joypad.cycleWorkspace(panel, dir)
    if not panel or not IKST_HubNav or type(IKST_HubNav.visibleWorkspaces) ~= "function" then
        return
    end
    local list = IKST_HubNav.visibleWorkspaces(panel.player) or {}
    local usable = {}
    for i = 1, #list do
        local ws = list[i]
        if ws and ws.id and not ws._missingPlugin then
            usable[#usable + 1] = ws
        end
    end
    if #usable == 0 then
        return
    end
    local idx = 0
    for i = 1, #usable do
        if usable[i].id == panel.view then
            idx = i
            break
        end
    end
    local nextIdx
    if idx == 0 then
        nextIdx = (dir >= 0) and 1 or #usable
    else
        nextIdx = idx + dir
        if nextIdx < 1 then
            nextIdx = #usable
        elseif nextIdx > #usable then
            nextIdx = 1
        end
    end
    local ws = usable[nextIdx]
    if ws and type(panel.enterNav) == "function" then
        local tool = nil
        if type(IKST_HubNav.defaultTool) == "function" then
            tool = IKST_HubNav.defaultTool(ws.id)
        end
        panel:enterNav(ws.id, tool)
    end
end

function IKST_Joypad.back(panel)
    if not panel then
        return
    end
    local home = IKST_HubNav and type(IKST_HubNav.isHomeView) == "function" and IKST_HubNav.isHomeView(panel.view)
    if home then
        if type(panel.close) == "function" then
            panel:close()
        end
        IKST_Joypad.restorePlayerFocus(panel.player)
        return
    end
    if type(panel.goHome) == "function" then
        panel:goHome()
    end
end

function IKST_Joypad.dockObject()
    if not IKST_EdgeDock then
        return nil
    end
    return IKST_EdgeDock.instance
end

function IKST_Joypad.focusDock()
    local dock = IKST_Joypad.dockObject()
    if not dock then
        return false
    end
    if type(dock.getIsVisible) == "function" and dock:getIsVisible() == false then
        return false
    end
    IKST_Joypad.takeFocus(dock, dock.player or IKST_Joypad.resolvePlayer())
    return true
end

function IKST_Joypad.minimizeHub(panel)
    if not panel then
        return
    end
    local player = panel.player
    if IKST_EdgeDock and type(IKST_EdgeDock.minimizeHub) == "function" then
        IKST_EdgeDock.minimizeHub()
        if IKST_Joypad.focusDock() then
            return
        end
    elseif type(panel.close) == "function" then
        panel:close()
    end
    IKST_Joypad.restorePlayerFocus(player)
end

function IKST_Joypad.onHubDown(panel, button, _joypadData)
    if not panel or not Joypad then
        return
    end
    if button == Joypad.AButton then
        IKST_Joypad.rebuildFocusList(panel)
        IKST_Joypad.applyFocus(panel)
        IKST_Joypad.activateWidget(panel._ikstFocusWidget, panel)
        return true
    end
    if button == Joypad.BButton then
        IKST_Joypad.back(panel)
        return true
    end
    if button == Joypad.XButton then
        IKST_Joypad.minimizeHub(panel)
        return true
    end
    if button == Joypad.LBumper then
        IKST_Joypad.cycleWorkspace(panel, -1)
        return true
    end
    if button == Joypad.RBumper then
        IKST_Joypad.cycleWorkspace(panel, 1)
        return true
    end
end

function IKST_Joypad.yIsUsed(player)
    player = IKST_Joypad.resolvePlayer(player)
    if player and type(player.getVehicle) == "function" then
        local veh = player:getVehicle()
        if veh then
            return true
        end
    end
    if ISButtonPrompt then
        local prompt = ISButtonPrompt.instance
        if not prompt and type(ISButtonPrompt.player) == "table" then
            prompt = ISButtonPrompt.player[playerNumOf(player) + 1]
        end
        if type(prompt) == "table" then
            if prompt.yPrompt or prompt.isYButton or prompt.yButton or prompt.buttonY then
                return true
            end
        end
    end
    return false
end

function IKST_Joypad.worldToggleButton(player)
    if not Joypad then
        return nil
    end
    if IKST_Joypad.yIsUsed(player) and Joypad.Start ~= nil then
        return Joypad.Start
    end
    return Joypad.YButton
end

function IKST_Joypad.toggleHubFromWorld(player)
    player = IKST_Joypad.resolvePlayer(player)
    if not IKST_Joypad.canOpen(player) then
        return false
    end
    if not IKST_Hub or type(IKST_Hub.toggle) ~= "function" then
        return false
    end
    local panel = IKUI_Shell and IKUI_Shell.instance
    local wasVis = panel and type(panel.getIsVisible) == "function" and panel:getIsVisible()
        and not (panel.minimized == true)
    IKST_Joypad._wantFocus = not wasVis
    IKST_Hub.toggle(player)
    panel = IKUI_Shell and IKUI_Shell.instance
    local vis = panel and type(panel.getIsVisible) == "function" and panel:getIsVisible()
        and not (panel.minimized == true)
    if vis and IKST_Joypad._wantFocus then
        IKST_Joypad.focusHub(player)
    else
        IKST_Joypad.restorePlayerFocus(player)
    end
    return true
end

function IKST_Joypad.installHub()
    if IKST_Joypad._hubHooks then
        return
    end
    IKST_Joypad._hubHooks = true

    if IKST_Hub and type(IKST_Hub.open) == "function" then
        local oldOpen = IKST_Hub.open
        function IKST_Hub.open(player)
            local win = oldOpen(player)
            if IKST_Joypad._wantFocus then
                IKST_Joypad.focusHub(player)
            end
            return win
        end
    end

    if IKST_Hub and type(IKST_Hub.toggle) == "function" then
        local oldToggle = IKST_Hub.toggle
        function IKST_Hub.toggle(player)
            local win = oldToggle(player)
            local panel = IKUI_Shell and IKUI_Shell.instance
            local vis = panel and type(panel.getIsVisible) == "function" and panel:getIsVisible()
                and not (panel.minimized == true)
            if vis and IKST_Joypad._wantFocus then
                IKST_Joypad.focusHub(player)
            elseif not vis then
                IKST_Joypad.restorePlayerFocus(player)
            end
            return win
        end
    end

    if IKST_SoftPageHost then
        local oldRefresh = IKST_SoftPageHost.refreshJobUI
        function IKST_SoftPageHost:refreshJobUI(preserveScroll)
            if oldRefresh then
                oldRefresh(self, preserveScroll)
            end
            if self._flushRefresh then
                IKST_Joypad.rebuildFocusList(self)
                if self._ikstJoypadOn then
                    IKST_Joypad.applyFocus(self)
                end
            end
        end
    end
end

-- Sole accepted vanilla hook: world open when no UI has joypad focus.
-- No OnTick poll; no ISEquippedItem patch.
function IKST_Joypad.hookWorldJoypad()
    if IKST_Joypad._worldHooked then
        return
    end
    if not JoypadControllerData or type(JoypadControllerData.onPressButtonNoFocus) ~= "function" then
        return
    end
    IKST_Joypad._worldHooked = true
    local old = JoypadControllerData.onPressButtonNoFocus
    function JoypadControllerData:onPressButtonNoFocus(button)
        local player = nil
        if self.player ~= nil and type(getSpecificPlayer) == "function" then
            player = getSpecificPlayer(self.player)
        end
        local want = IKST_Joypad.worldToggleButton(player)
        if want ~= nil and button == want then
            if IKST_Joypad.toggleHubFromWorld(player) then
                return
            end
        end
        if old then
            return old(self, button)
        end
    end
end

function IKST_Joypad.ensureInstalled()
    IKST_Joypad.installHub()
    IKST_Joypad.hookWorldJoypad()
end

IKST_Joypad.ensureInstalled()

if Events then
    if Events.OnGameStart then
        Events.OnGameStart.Add(function()
            IKST_Joypad.ensureInstalled()
        end)
    end
    if Events.OnCreatePlayer then
        Events.OnCreatePlayer.Add(function()
            IKST_Joypad.ensureInstalled()
        end)
    end
    if Events.OnJoypadActivate then
        Events.OnJoypadActivate.Add(function()
            IKST_Joypad.ensureInstalled()
        end)
    end
end
