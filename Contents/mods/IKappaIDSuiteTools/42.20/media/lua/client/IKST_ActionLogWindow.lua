-- Standalone action log: fixed list of the latest 20 lines. No scrolling.
if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISPanel"
require "ISUI/ISUIElement"
require "IKST_Shared"
require "IKappaID_UI/IKUI_Chrome"
require "IKST_UI_Layout"
require "IKST_JobLayout"
require "IKST_ActionLog"
require "IKST_DragHandle"
require "IKST_UIPrefs"

local prevInstance = IKST_ActionLogWindow and IKST_ActionLogWindow.instance or nil

IKST_ActionLogWindow = ISPanel:derive("IKST_ActionLogWindow")
IKST_ActionLogWindow.instance = prevInstance
IKST_ActionLogWindow._ensuring = false

function IKST_ActionLogWindow.isActionLogPanel(el)
    if not el or el._ikstDestroyed == true then
        return false
    end
    if el._ikstActionLogWindow == true then
        return true
    end
    if el.Type == "IKST_ActionLogWindow" then
        return true
    end
    return false
end

function IKST_ActionLogWindow.onUiList()
    if not UIManager then
        return nil
    end
    if type(UIManager.getUI) == "function" then
        local ui = UIManager:getUI()
        if ui then
            return ui
        end
    end
    return nil
end

function IKST_ActionLogWindow.isLive(panel)
    if not panel or panel._ikstDestroyed == true then
        return false
    end
    if not IKST_ActionLogWindow.isActionLogPanel(panel) then
        return false
    end
    if type(panel.removeFromUIManager) ~= "function" then
        return false
    end
    return true
end

function IKST_ActionLogWindow.collectPanels()
    local list = {}
    local ui = IKST_ActionLogWindow.onUiList()
    if not ui or type(ui.size) ~= "function" then
        return list
    end
    for i = 0, ui:size() - 1 do
        local el = ui:get(i)
        if IKST_ActionLogWindow.isActionLogPanel(el) then
            list[#list + 1] = el
        end
    end
    return list
end

function IKST_ActionLogWindow.destroyPanel(panel)
    if not panel or panel._ikstDestroyed == true then
        return
    end
    panel._ikstDestroyed = true
    if IKST_DragHandle and type(IKST_DragHandle.destroyTab) == "function" then
        IKST_DragHandle.destroyTab(panel)
    end
    if type(panel.setVisible) == "function" then
        ISUIElement.setVisible(panel, false)
    end
    if type(panel.removeFromUIManager) == "function" then
        panel:removeFromUIManager()
    end
    if IKST_ActionLogWindow.instance == panel then
        IKST_ActionLogWindow.instance = nil
    end
end

function IKST_ActionLogWindow.purgeDragTabs()
    local ui = IKST_ActionLogWindow.onUiList()
    if not ui or type(ui.size) ~= "function" then
        return
    end
    local keeper = IKST_ActionLogWindow.instance
    local keeperTab = keeper and keeper._ikstDragTab or nil
    for i = ui:size() - 1, 0, -1 do
        local el = ui:get(i)
        if el and el.Type == "IKST_DragHandleTab" and el._ikstPlacement == "top" then
            local owner = el.ownerPanel
            local keep = keeper and el == keeperTab and owner == keeper
            if not keep then
                if owner and owner._ikstDragTab == el then
                    owner._ikstDragTab = nil
                end
                if type(el.removeFromUIManager) == "function" then
                    el:removeFromUIManager()
                end
            end
        end
    end
end

function IKST_ActionLogWindow.enforceSingleton()
    local panels = IKST_ActionLogWindow.collectPanels()
    local keeper = IKST_ActionLogWindow.instance

    if keeper and not IKST_ActionLogWindow.isLive(keeper) then
        keeper = nil
        IKST_ActionLogWindow.instance = nil
    end

    if keeper then
        local found = false
        for _, panel in ipairs(panels) do
            if panel == keeper then
                found = true
                break
            end
        end
        if not found then
            panels[#panels + 1] = keeper
        end
    elseif #panels > 0 then
        keeper = panels[1]
        IKST_ActionLogWindow.instance = keeper
        keeper._ikstActionLogWindow = true
        keeper.Type = "IKST_ActionLogWindow"
        keeper._ikstDestroyed = false
    end

    for _, panel in ipairs(panels) do
        if panel ~= keeper then
            IKST_ActionLogWindow.destroyPanel(panel)
        end
    end

    IKST_ActionLogWindow.purgeDragTabs()
    return keeper
end

function IKST_ActionLogWindow:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.Type = "IKST_ActionLogWindow"
    o._ikstActionLogWindow = true
    o._ikstDestroyed = false
    o.player = nil
    o.lines = {}
    o.pin = true
    o.moveWithMouse = false
    IKUI_Chrome.applyPanelColors(o)
    IKST_DragHandle.attach(o, "top", {
        clampFn = function(p)
            if IKST_JobLayout and type(IKST_JobLayout.clampPanelEdges) == "function" then
                IKST_JobLayout.clampPanelEdges(p)
            end
        end,
        saveFn = function(p)
            if IKST_UIPrefs and type(IKST_UIPrefs.saveActionLogGeometry) == "function" then
                IKST_UIPrefs.saveActionLogGeometry(p)
            end
        end,
    })
    return o
end

function IKST_ActionLogWindow:initialise()
    ISPanel.initialise(self)
end

function IKST_ActionLogWindow:logInsets()
    local pad = 10
    local headerH = math.max(18, IKST_UI_Layout.s(20))
    return pad, headerH
end

function IKST_ActionLogWindow:lineHeight()
    if getTextManager and type(getTextManager) == "function" then
        local tm = getTextManager()
        if tm and type(tm.getFontHeight) == "function" then
            return tm:getFontHeight(UIFont.Small)
        end
    end
    return 14
end

function IKST_ActionLogWindow:onGeometryChanged()
    if IKST_DragHandle and type(IKST_DragHandle.layoutTab) == "function" then
        IKST_DragHandle.layoutTab(self)
    end
end

function IKST_ActionLogWindow:createChildren()
    ISPanel.createChildren(self)
end

function IKST_ActionLogWindow:prerender()
    IKUI_Chrome.drawDockedShell(self)
    ISPanel.prerender(self)

    local pad, headerH = self:logInsets()
    local c = IKUI_Chrome.colors
    local title = IKST.text("IGUI_IKST_ActionLog", "Action log")
    self:drawText(title, pad, pad + 2, c.accent.r, c.accent.g, c.accent.b, 1, UIFont.Small)

    local y = pad + headerH
    local lineH = self:lineHeight()
    local lines = self.lines
    if not lines or #lines == 0 then
        local empty = IKST.text("IGUI_IKST_NoLog", "No actions yet.")
        self:drawText(empty, pad, y, c.textMuted.r, c.textMuted.g, c.textMuted.b, 1, UIFont.Small)
    else
        local maxN = IKST_ActionLog.MAX_LINES or 20
        local n = #lines
        if n > maxN then
            n = maxN
        end
        for i = 1, n do
            local row = lines[i]
            if row then
                self:drawText(tostring(row.text or ""), pad, y, row.r or 1, row.g or 1, row.b or 1, 1, UIFont.Small)
                y = y + lineH
            end
        end
    end

    if IKST_DragHandle and type(IKST_DragHandle.syncTab) == "function" then
        IKST_DragHandle.syncTab(self)
    end
end

function IKST_ActionLogWindow:render()
    ISPanel.render(self)
end

function IKST_ActionLogWindow.reclaimInstance()
    return IKST_ActionLogWindow.enforceSingleton()
end

function IKST_ActionLogWindow.purgeOrphans()
    IKST_ActionLogWindow.enforceSingleton()
end

function IKST_ActionLogWindow:onMouseDown(x, y)
    return ISPanel.onMouseDown(self, x, y)
end

function IKST_ActionLogWindow:onMouseMove(dx, dy)
    local mx, my
    if type(self.getMouseX) == "function" and type(self.getMouseY) == "function" then
        mx = self:getMouseX()
        my = self:getMouseY()
    end
    if IKST_DragHandle and IKST_DragHandle.onMouseMove(self, dx, dy, mx, my) then
        return true
    end
    if ISPanel.onMouseMove then
        return ISPanel.onMouseMove(self, dx, dy)
    end
    return false
end

function IKST_ActionLogWindow:onMouseMoveOutside(dx, dy)
    if IKST_DragHandle and IKST_DragHandle.onMouseMove(self, dx, dy) then
        return true
    end
    if ISPanel.onMouseMoveOutside then
        return ISPanel.onMouseMoveOutside(self, dx, dy)
    end
    return false
end

function IKST_ActionLogWindow:onMouseUp(x, y)
    if IKST_DragHandle and IKST_DragHandle.onMouseUp(self) then
        return true
    end
    return ISPanel.onMouseUp(self, x, y)
end

function IKST_ActionLogWindow:refresh()
    if self.player then
        self.lines = IKST_ActionLog.linesForPlayer(self.player)
    else
        self.lines = {}
    end
end

local function applyKeepAlive(panel)
    if not panel then
        return
    end
    if IKST_DragHandle and type(IKST_DragHandle.ensureTab) == "function" then
        IKST_DragHandle.ensureTab(panel)
    end
    if IKST_JobLayout and type(IKST_JobLayout.applyActionLogSize) == "function" then
        IKST_JobLayout.applyActionLogSize(panel)
    end
end

function IKST_ActionLogWindow.ensure()
    local existing = IKST_ActionLogWindow.instance
    if existing and IKST_ActionLogWindow.isLive(existing) then
        if not IKST_ActionLogWindow._ensuring then
            IKST_ActionLogWindow._ensuring = true
            IKST_ActionLogWindow.enforceSingleton()
            applyKeepAlive(existing)
            IKST_ActionLogWindow._ensuring = false
        end
        return existing
    end

    if IKST_ActionLogWindow._ensuring then
        return IKST_ActionLogWindow.instance
    end
    IKST_ActionLogWindow._ensuring = true

    local keeper = IKST_ActionLogWindow.enforceSingleton()
    if keeper then
        applyKeepAlive(keeper)
        IKST_ActionLogWindow._ensuring = false
        return keeper
    end

    local x, y, w, h = 0, 0, 640, 320
    if IKST_JobLayout and type(IKST_JobLayout.actionLogWindowSize) == "function" then
        w, h = IKST_JobLayout.actionLogWindowSize()
        x, y = IKST_JobLayout.actionLogWindowPosition(w, h)
    end
    local panel = IKST_ActionLogWindow:new(x, y, w, h)
    IKST_ActionLogWindow.instance = panel
    panel:initialise()
    panel:createChildren()
    panel:addToUIManager()
    ISUIElement.setVisible(panel, false)
    applyKeepAlive(panel)
    IKST_ActionLogWindow.enforceSingleton()
    IKST_ActionLogWindow._ensuring = false
    return panel
end

function IKST_ActionLogWindow.open(player)
    player = IKST.resolvePlayer(player)
    if not player then
        return
    end
    local panel = IKST_ActionLogWindow.ensure()
    if not panel then
        return
    end
    panel.player = player
    if IKST_JobLayout and type(IKST_JobLayout.restoreActionLogPosition) == "function" then
        IKST_JobLayout.restoreActionLogPosition(panel)
    end
    panel:refresh()
    if type(panel.bringToTop) == "function" then
        panel:bringToTop()
    end
    if IKST_DragHandle and type(IKST_DragHandle.showPanel) == "function" then
        IKST_DragHandle.showPanel(panel)
    else
        ISUIElement.setVisible(panel, true)
    end
end

function IKST_ActionLogWindow.close()
    local panel = IKST_ActionLogWindow.instance
    if panel then
        if IKST_UIPrefs and type(IKST_UIPrefs.saveActionLogGeometry) == "function" then
            IKST_UIPrefs.saveActionLogGeometry(panel)
        end
        if IKST_DragHandle and type(IKST_DragHandle.hidePanel) == "function" then
            IKST_DragHandle.hidePanel(panel)
        else
            ISUIElement.setVisible(panel, false)
        end
    end
    IKST_ActionLogWindow.enforceSingleton()
end

function IKST_ActionLogWindow.refreshForPlayer(player)
    local panel = IKST_ActionLogWindow.instance
    if not panel or not panel.getIsVisible or not panel:getIsVisible() then
        return
    end
    player = IKST.resolvePlayer(player)
    if not player then
        return
    end
    if panel.player ~= player then
        panel.player = player
    end
    panel:refresh()
end

if Events and Events.OnGameStart then
    Events.OnGameStart.Add(function()
        IKST_ActionLogWindow.enforceSingleton()
    end)
end

IKST_ActionLogWindow.enforceSingleton()
