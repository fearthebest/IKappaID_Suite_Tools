-- Edge drag tabs - floating UIManager buttons that move their owner window.
if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISButton"
require "ISUI/ISUIElement"
require "IKST_UI_Layout"
require "IKappaID_UI/IKUI_Chrome"

IKST_DragHandle = IKST_DragHandle or {}
if IKST_DragHandle._tickHooked ~= true then
    IKST_DragHandle._tickHooked = false
end

function IKST_DragHandle.tabSize(placement)
    if placement == "right" then
        return math.max(28, IKST_UI_Layout.s(32)), math.max(88, IKST_UI_Layout.s(108))
    end
    if placement == "top" then
        return math.max(88, IKST_UI_Layout.s(108)), math.max(28, IKST_UI_Layout.s(32))
    end
    return 0, 0
end

function IKST_DragHandle.screenOutset(panel)
    local placement = panel and panel._ikstDragPlacement or nil
    local tw, th = IKST_DragHandle.tabSize(placement)
    if placement == "right" then
        return 0, 0, tw, 0
    end
    if placement == "top" then
        return th, 0, 0, 0
    end
    return 0, 0, 0, 0
end

function IKST_DragHandle.mouseXY()
    if type(getMouseX) == "function" and type(getMouseY) == "function" then
        return getMouseX(), getMouseY()
    end
    if type(getMouseXScaled) == "function" and type(getMouseYScaled) == "function" then
        return getMouseXScaled(), getMouseYScaled()
    end
    return nil, nil
end

function IKST_DragHandle.ownerPanels()
    local list = {}
    if IKUI_Shell and IKUI_Shell.instance then
        list[#list + 1] = IKUI_Shell.instance
    end
    if IKST_ActionLogWindow and IKST_ActionLogWindow.instance then
        list[#list + 1] = IKST_ActionLogWindow.instance
    end
    return list
end

function IKST_DragHandle.anyDragging()
    for _, panel in ipairs(IKST_DragHandle.ownerPanels()) do
        if panel._ikstDragging then
            return true
        end
    end
    return false
end

function IKST_DragHandle.ensureTick()
    if IKST_DragHandle._tickHooked then
        return
    end
    IKST_DragHandle._tickHooked = true
    Events.OnTick.Add(IKST_DragHandle.onTick)
end

function IKST_DragHandle.onTick()
    for _, panel in ipairs(IKST_DragHandle.ownerPanels()) do
        if panel._ikstDragNeedsLeave == true then
            local tab = panel._ikstDragTab
            if not tab or not IKST_DragHandle.mouseOverTab(tab) then
                panel._ikstDragNeedsLeave = false
            end
        end
        if panel._ikstDragging then
            IKST_DragHandle.updateDragPosition(panel)
        end
    end
end

function IKST_DragHandle.nowMs()
    if type(getTimestampMs) == "function" then
        return getTimestampMs()
    end
    if type(getTimeInMillis) == "function" then
        return getTimeInMillis()
    end
    return 0
end

function IKST_DragHandle.setTabVisible(tab, visible)
    if not tab then
        return
    end
    if type(ISUIElement) == "table" and type(ISUIElement.setVisible) == "function" then
        ISUIElement.setVisible(tab, visible == true)
    elseif type(tab.setVisible) == "function" then
        tab:setVisible(visible == true)
    end
end

function IKST_DragHandle.mouseOverTab(tab)
    if not tab or type(tab.getX) ~= "function" then
        return false
    end
    local mx, my = IKST_DragHandle.mouseXY()
    if mx == nil or my == nil then
        return false
    end
    local x = tab:getX()
    local y = tab:getY()
    return mx >= x and mx <= (x + tab:getWidth()) and my >= y and my <= (y + tab:getHeight())
end

function IKST_DragHandle.cancelDrag(panel)
    if not panel then
        return
    end
    panel._ikstDragging = false
    panel._ikstDragHover = false
    panel._ikstDragOffX = nil
    panel._ikstDragOffY = nil
    local tab = panel._ikstDragTab
    if tab and type(tab.setCapture) == "function" then
        tab:setCapture(false)
    end
end

function IKST_DragHandle.canBeginDrag(panel)
    if not panel then
        return false
    end
    if type(panel.getIsVisible) == "function" and not panel:getIsVisible() then
        return false
    end
    local grace = panel._ikstDragGraceUntil
    if grace and IKST_DragHandle.nowMs() < grace then
        return false
    end
    if panel._ikstDragNeedsLeave == true then
        return false
    end
    return true
end

function IKST_DragHandle.armAfterShow(panel)
    if not panel then
        return
    end
    IKST_DragHandle.cancelDrag(panel)
    panel._ikstDragGraceUntil = IKST_DragHandle.nowMs() + 350
    panel._ikstDragNeedsLeave = IKST_DragHandle.mouseOverTab(panel._ikstDragTab) == true
end

function IKST_DragHandle.attach(panel, placement, opts)
    if not panel then
        return
    end
    panel._ikstDragPlacement = placement
    panel._ikstDragClampFn = opts and opts.clampFn or nil
    panel._ikstDragSaveFn = opts and opts.saveFn or nil
    panel._ikstDragging = false
    panel._ikstDragHover = false
    panel._ikstDragNeedsLeave = false
    panel._ikstDragGraceUntil = nil
    IKST_DragHandle.ensureTick()
end

function IKST_DragHandle.destroyTab(panel)
    local tab = panel and panel._ikstDragTab or nil
    if not tab then
        return
    end
    IKST_DragHandle.cancelDrag(panel)
    if tab.parent and type(tab.parent.removeChild) == "function" then
        tab.parent:removeChild(tab)
    end
    if type(tab.removeFromUIManager) == "function" then
        tab:removeFromUIManager()
    end
    panel._ikstDragTab = nil
end

function IKST_DragHandle.drawTabBody(tab, placement, hover)
    if not tab or type(tab.drawRect) ~= "function" then
        return
    end
    local c = IKUI_Chrome.colors
    local w = tab.width or 0
    local h = tab.height or 0
    local radius = math.min(IKUI_Chrome.ROUND_RADIUS, math.floor(math.min(w, h) / 2))
    local fill = hover and c.bgCardHover or c.bgCard
    IKUI_Chrome.drawRoundedCard(tab, 0, 0, w, h, {
        fill = fill,
        borderColor = c.accent,
        selected = hover == true,
        shadow = false,
        radius = radius,
    })
    local barW = math.max(12, math.floor(w * 0.42))
    local barH = math.max(3, IKST_UI_Layout.s(3))
    local gap = math.max(5, IKST_UI_Layout.s(6))
    if placement == "right" then
        local cx = math.floor(w / 2)
        local span = (barH * 3) + (gap * 2)
        local sy = math.floor((h - span) / 2)
        for i = 0, 2 do
            tab:drawRect(cx - math.floor(barW / 2), sy + i * (barH + gap), barW, barH, 1, c.accent.r, c.accent.g, c.accent.b)
        end
    else
        local cy = math.floor(h / 2)
        local span = (barH * 3) + (gap * 2)
        local sx = math.floor((w - span) / 2)
        for i = 0, 2 do
            tab:drawRect(sx + i * (barH + gap), cy - math.floor(barH / 2), barH, barH, 1, c.accent.r, c.accent.g, c.accent.b)
        end
    end
end

-- Position + show/hide only. Never creates tabs (avoids recursion).
function IKST_DragHandle.syncTab(panel)
    local tab = panel and panel._ikstDragTab or nil
    local placement = panel and panel._ikstDragPlacement or nil
    if not tab or not placement then
        return
    end
    local shown = type(panel.getIsVisible) == "function" and panel:getIsVisible()
    if not shown then
        IKST_DragHandle.cancelDrag(panel)
        IKST_DragHandle.setTabVisible(tab, false)
        return
    end
    local px, py = panel:getX(), panel:getY()
    local pw, ph = panel:getWidth(), panel:getHeight()
    local tw, th = IKST_DragHandle.tabSize(placement)
    local seam = 2
    if placement == "right" then
        tab:setX(px + pw - seam)
        tab:setY(py + math.floor((ph - th) / 2))
    else
        tab:setX(px + math.floor((pw - tw) / 2))
        tab:setY(py - th + seam)
    end
    tab:setWidth(tw)
    tab:setHeight(th)
    IKST_DragHandle.setTabVisible(tab, true)
end

function IKST_DragHandle.hidePanel(panel)
    if not panel then
        return
    end
    IKST_DragHandle.cancelDrag(panel)
    if type(ISUIElement) == "table" and type(ISUIElement.setVisible) == "function" then
        ISUIElement.setVisible(panel, false)
    elseif type(panel.setVisible) == "function" then
        panel:setVisible(false)
    end
    IKST_DragHandle.syncTab(panel)
end

function IKST_DragHandle.showPanel(panel)
    if not panel then
        return
    end
    IKST_DragHandle.cancelDrag(panel)
    if type(ISUIElement) == "table" and type(ISUIElement.setVisible) == "function" then
        ISUIElement.setVisible(panel, true)
    elseif type(panel.setVisible) == "function" then
        panel:setVisible(true)
    end
    IKST_DragHandle.ensureTab(panel)
    IKST_DragHandle.syncTab(panel)
    IKST_DragHandle.armAfterShow(panel)
    if panel.bringToTop then
        panel:bringToTop()
    end
    local tab = panel._ikstDragTab
    if tab and tab.bringToTop then
        tab:bringToTop()
    end
end

function IKST_DragHandle.layoutTab(panel)
    IKST_DragHandle.syncTab(panel)
end

function IKST_DragHandle.raiseTab(panel)
    if not panel then
        return
    end
    if panel.bringToTop then
        panel:bringToTop()
    end
    local tab = panel._ikstDragTab
    if tab and type(tab.bringToTop) == "function" then
        tab:bringToTop()
    end
end

function IKST_DragHandle.updateDragPosition(panel)
    if not panel or not panel._ikstDragging then
        return
    end
    local mx, my = IKST_DragHandle.mouseXY()
    if mx and my and panel._ikstDragOffX and panel._ikstDragOffY
        and type(panel.setX) == "function" and type(panel.setY) == "function" then
        panel:setX(mx - panel._ikstDragOffX)
        panel:setY(my - panel._ikstDragOffY)
    end
    IKST_DragHandle.clamp(panel)
    IKST_DragHandle.syncTab(panel)
end

function IKST_DragHandle.beginDrag(panel)
    if not panel or not IKST_DragHandle.canBeginDrag(panel) then
        return false
    end
    panel._ikstDragging = true
    panel._ikstDragHover = true
    local mx, my = IKST_DragHandle.mouseXY()
    if mx and my then
        panel._ikstDragOffX = mx - panel:getX()
        panel._ikstDragOffY = my - panel:getY()
    end
    IKST_DragHandle.raiseTab(panel)
    IKST_DragHandle.syncTab(panel)
    return true
end

function IKST_DragHandle.wireTab(tab, panel, placement)
    tab.ownerPanel = panel
    tab._ikstPlacement = placement
    if type(tab.setConsumeClick) == "function" then
        tab:setConsumeClick(true, true)
    end
    tab.prerender = function(self)
        ISButton.prerender(self)
        local p = self.ownerPanel
        local hover = p and (p._ikstDragHover == true or p._ikstDragging == true)
        IKST_DragHandle.drawTabBody(self, self._ikstPlacement, hover)
    end
    tab.render = function(self)
        ISButton.render(self)
    end
    tab.onMouseDown = function(self, _mx, _my)
        local p = self.ownerPanel
        if not p or not IKST_DragHandle.beginDrag(p) then
            return false
        end
        if type(self.setCapture) == "function" then
            self:setCapture(true)
        end
        return true
    end
    tab.onMouseUp = function(self, _mx, _my)
        if type(self.setCapture) == "function" then
            self:setCapture(false)
        end
        return IKST_DragHandle.onMouseUp(self.ownerPanel)
    end
    tab.onMouseUpOutside = function(self, _mx, _my)
        if type(self.setCapture) == "function" then
            self:setCapture(false)
        end
        return IKST_DragHandle.onMouseUp(self.ownerPanel)
    end
    tab.onMouseMove = function(self, dx, dy)
        local p = self.ownerPanel
        if not p then
            return false
        end
        p._ikstDragHover = true
        if p._ikstDragging then
            IKST_DragHandle.updateDragPosition(p)
            return true
        end
        return false
    end
    tab.onMouseMoveOutside = function(self, dx, dy)
        local p = self.ownerPanel
        if p and p._ikstDragging then
            IKST_DragHandle.updateDragPosition(p)
            return true
        end
        if p then
            p._ikstDragHover = false
            if p._ikstDragNeedsLeave then
                p._ikstDragNeedsLeave = false
            end
        end
        return false
    end
end

function IKST_DragHandle.createTab(panel)
    if not panel or not panel._ikstDragPlacement or panel._ikstDragTab then
        return
    end
    local placement = panel._ikstDragPlacement
    local tw, th = IKST_DragHandle.tabSize(placement)
    local tab = ISButton:new(0, 0, tw, th, "", nil, nil)
    tab:initialise()
    tab:instantiate()
    tab.Type = "IKST_DragHandleTab"
    tab.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    tab.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    if tab.setDisplayBackground then
        tab:setDisplayBackground(false)
    end
    IKST_DragHandle.wireTab(tab, panel, placement)
    panel._ikstDragTab = tab
    tab:addToUIManager()
    IKST_DragHandle.setTabVisible(tab, false)
end

function IKST_DragHandle.ensureTab(panel)
    if not panel or not panel._ikstDragPlacement then
        return
    end
    if panel._ikstDragTab then
        return
    end
    IKST_DragHandle.createTab(panel)
end

function IKST_DragHandle.clamp(panel)
    if not panel then
        return
    end
    if panel._ikstDragClampFn then
        panel._ikstDragClampFn(panel)
        return
    end
    if IKUI_Chrome and type(IKUI_Chrome.clampPanelPosition) == "function" then
        IKUI_Chrome.clampPanelPosition(panel)
    end
end

function IKST_DragHandle.save(panel)
    if panel and panel._ikstDragSaveFn then
        panel._ikstDragSaveFn(panel)
    end
end

function IKST_DragHandle.onMouseMove(panel, dx, dy)
    if not panel or not panel._ikstDragging then
        return false
    end
    IKST_DragHandle.updateDragPosition(panel)
    return true
end

function IKST_DragHandle.onMouseUp(panel)
    if not panel or not panel._ikstDragging then
        return false
    end
    panel._ikstDragging = false
    panel._ikstDragHover = false
    panel._ikstDragOffX = nil
    panel._ikstDragOffY = nil
    IKST_DragHandle.clamp(panel)
    IKST_DragHandle.syncTab(panel)
    IKST_DragHandle.save(panel)
    IKST_DragHandle.raiseTab(panel)
    return true
end
