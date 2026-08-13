-- Standalone horizontal action log — center third, bottom of screen (not inside JobsPanel).
-- Hard singleton: at most one panel + one drag tab may exist in UIManager.
if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISPanel"
require "ISUI/ISUIElement"
require "ISUI/ISRichTextPanel"
require "IKST_Shared"
require "IKST_Chrome"
require "IKST_UI_Layout"
require "IKST_JobLayout"
require "IKST_ActionLog"
require "IKST_DragHandle"
require "IKST_UIPrefs"

local prevInstance = IKST_ActionLogWindow and IKST_ActionLogWindow.instance or nil

IKST_ActionLogWindow = ISPanel:derive("IKST_ActionLogWindow")
IKST_ActionLogWindow.instance = prevInstance
-- Re-entrancy lock: never create/open while already ensuring.
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
    -- Legacy duplicates (created before Type stamp or after Lua reload).
    if el._ikstDragPlacement == "top" and el.logText then
        return true
    end
    if el.logText and el.pin == true and el.moveWithMouse == false and el._ikstActionLogWindow ~= false then
        if el.Type == "ISPanel" then
            return true
        end
    end
    return false
end

function IKST_ActionLogWindow.onUiList()
    if not UIManager then
        return nil
    end
    -- Java method: use colon form (dot form can fail to return the live list).
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

-- Only purge Action Log drag tabs (top). Never touch JobsPanel right tabs.
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

    -- Prefer the known instance only if it is still live; otherwise reclaim from UI.
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
        -- Scan missed the instance (UIManager list flaky) — still keep it; purge others.
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
    o.pin = true
    o.moveWithMouse = false
    IKST_Chrome.applyPanelColors(o)
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
    -- Printable area: 10px from each border (mirrors dashboard 20px, tighter for this strip).
    local pad = 10
    local headerH = math.max(18, IKST_UI_Layout.s(20))
    return pad, headerH
end

function IKST_ActionLogWindow:layoutLogText()
    if not self.logText then
        return
    end
    local pad, headerH = self:logInsets()
    local textY = pad + headerH
    local w = math.max(40, self.width - (pad * 2))
    local h = math.max(40, self.height - textY - pad)
    self.logText:setX(pad)
    self.logText:setY(textY)
    self.logText:setWidth(w)
    self.logText:setHeight(h)
    self:syncLogScroll()
end

function IKST_ActionLogWindow:syncLogScroll()
    local logText = self.logText
    if not logText then
        return
    end
    if type(logText.paginate) == "function" then
        logText:paginate()
    end
    if type(logText.updateScrollbars) == "function" then
        logText:updateScrollbars()
    end
end

function IKST_ActionLogWindow:onGeometryChanged()
    self:layoutLogText()
    if IKST_DragHandle and type(IKST_DragHandle.layoutTab) == "function" then
        IKST_DragHandle.layoutTab(self)
    end
end

function IKST_ActionLogWindow:createChildren()
    ISPanel.createChildren(self)
    local pad, headerH = self:logInsets()
    local textY = pad + headerH
    local logText = ISRichTextPanel:new(pad, textY, math.max(40, self.width - (pad * 2)),
        math.max(40, self.height - textY - pad))
    logText:initialise()
    if type(logText.instantiate) == "function" then
        logText:instantiate()
    end
    logText.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    logText.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    -- Fixed panel height + clip + scrollbars (same pattern as BriefingUI).
    logText.autosetheight = false
    logText.clip = true
    logText._ikstOmitTitle = true
    logText:setMargins(4, 4, 16, 4)
    self.logText = logText
    self:addChild(logText)
    if type(logText.addScrollBars) == "function" then
        logText:addScrollBars()
    end
    -- Drag tab is created after addToUIManager (see ensure), not during createChildren.
end

function IKST_ActionLogWindow:prerender()
    IKST_Chrome.drawDockedShell(self)
    ISPanel.prerender(self)
    local pad = self:logInsets()
    local title = IKST.text("IGUI_IKST_ActionLog", "Action log")
    local c = IKST_Chrome.colors
    self:drawText(title, pad, pad + 2, c.accent.r, c.accent.g, c.accent.b, 1, UIFont.Small)
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

function IKST_ActionLogWindow:onMouseWheel(del)
    local logText = self.logText
    if logText and type(ISRichTextPanel) == "table" and type(ISRichTextPanel.onMouseWheel) == "function" then
        return ISRichTextPanel.onMouseWheel(logText, del)
    end
    if logText and type(logText.setYScroll) == "function" then
        local cur = 0
        if type(logText.getYScroll) == "function" then
            cur = logText:getYScroll() or 0
        end
        logText:setYScroll(cur - (del * 40))
        return true
    end
    if ISPanel.onMouseWheel then
        return ISPanel.onMouseWheel(self, del)
    end
    return false
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
    if self.logText and self.player then
        IKST_ActionLog.refresh(self.logText, self.player)
        self:layoutLogText()
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
    -- Hard gate: never create a second window while a live instance exists.
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

    local x, y, w, h = 0, 0, 640, 270
    if IKST_JobLayout and type(IKST_JobLayout.actionLogWindowSize) == "function" then
        w, h = IKST_JobLayout.actionLogWindowSize()
        x, y = IKST_JobLayout.actionLogWindowPosition(w, h)
    end
    local panel = IKST_ActionLogWindow:new(x, y, w, h)
    -- Stamp instance before children so any re-entry reuses this panel.
    IKST_ActionLogWindow.instance = panel
    panel:initialise()
    panel:createChildren()
    panel:addToUIManager()
    -- Must use vanilla ISUIElement.setVisible — never define Class.setVisible
    -- (it shadows instance:setVisible and caused open→ensure→setVisible recursion).
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
    -- Sweep any duplicates that stacked while open.
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
