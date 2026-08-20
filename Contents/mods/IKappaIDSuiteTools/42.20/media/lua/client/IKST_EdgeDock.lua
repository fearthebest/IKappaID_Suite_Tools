if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISPanel"
require "ISUI/ISUIElement"
require "IKST_Shared"
require "IKappaID_UI/IKUI_Chrome"
require "IKappaID_UI/IKUI_Config"
require "IKST_UI_Layout"
require "IKST_UIPrefs"
require "IKST_JobLayout"

local prevInstance = IKST_EdgeDock and IKST_EdgeDock.instance or nil

IKST_EdgeDock = ISPanel:derive("IKST_EdgeDock")
IKST_EdgeDock.instance = prevInstance

local VALID_EDGES = {
    left = true,
    right = true,
    top = true,
    bottom = true,
}

local function screenSize()
    local sw, sh = 1920, 1080
    if getCore and type(getCore) == "function" then
        local core = getCore()
        if core then
            if type(core.getScreenWidth) == "function" then
                sw = core:getScreenWidth() or sw
            end
            if type(core.getScreenHeight) == "function" then
                sh = core:getScreenHeight() or sh
            end
        end
    end
    return sw, sh
end

local function mouseXY()
    if type(getMouseX) == "function" and type(getMouseY) == "function" then
        return getMouseX(), getMouseY()
    end
    return nil, nil
end

function IKST_EdgeDock.metrics()
    local s = IKST_UI_Layout.s
    local thick = s(36)
    local pad = s(8)
    local pip = s(8)
    local gap = s(6)
    local label = "IKST"
    local expand = IKST.text("IGUI_IKST_Expand", "Expand")
    local lw, lh = IKUI_Config.textSize(label, UIFont.Small)
    local ew, eh = IKUI_Config.textSize(expand, UIFont.Small)
    lw = math.floor((lw or 0) + 0.5)
    lh = math.floor((lh or 0) + 0.5)
    ew = math.floor((ew or 0) + 0.5)
    eh = math.floor((eh or 0) + 0.5)
    local hLen = pad + pip + gap + lw + gap + ew + pad
    local vLen = pad + pip + gap + lh + gap + eh + pad
    if hLen < s(120) then
        hLen = s(120)
    end
    if vLen < s(96) then
        vLen = s(96)
    end
    return {
        thick = thick,
        pad = pad,
        pip = pip,
        gap = gap,
        label = label,
        expand = expand,
        lw = lw,
        lh = lh,
        ew = ew,
        eh = eh,
        hLen = hLen,
        vLen = vLen,
    }
end

function IKST_EdgeDock:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.Type = "IKST_EdgeDock"
    o.moveWithMouse = false
    o.edge = "left"
    o.offset = 0
    o._dragging = false
    o._dragMoved = false
    IKUI_Chrome.applyPanelColors(o)
    return o
end

function IKST_EdgeDock:initialise()
    ISPanel.initialise(self)
    if type(self.setConsumeClick) == "function" then
        self:setConsumeClick(true, true)
    end
end

function IKST_EdgeDock:isVertical()
    return self.edge == "left" or self.edge == "right"
end

function IKST_EdgeDock:applyEdge(edge, offset)
    if not VALID_EDGES[edge] then
        edge = "left"
    end
    local m = IKST_EdgeDock.metrics()
    local sw, sh = screenSize()
    local left = 0
    if IKST_JobLayout and IKST_JobLayout.LEFT_HUD_CLEARANCE then
        left = IKST_JobLayout.LEFT_HUD_CLEARANCE
    end
    self.edge = edge
    if self:isVertical() then
        local w = math.max(m.thick, m.lw + (m.pad * 2), m.ew + (m.pad * 2))
        local h = m.vLen
        self:setWidth(w)
        self:setHeight(h)
        if offset == nil then
            offset = self:getY()
        end
        offset = math.floor(math.max(0, math.min(tonumber(offset) or 0, sh - h)))
        self.offset = offset
        self:setY(offset)
        if edge == "left" then
            self:setX(left)
        else
            self:setX(sw - w)
        end
    else
        local w = m.hLen
        local h = m.thick
        self:setWidth(w)
        self:setHeight(h)
        if offset == nil then
            offset = self:getX()
        end
        offset = math.floor(math.max(0, math.min(tonumber(offset) or 0, sw - w)))
        self.offset = offset
        self:setX(offset)
        if edge == "top" then
            self:setY(0)
        else
            self:setY(sh - h)
        end
    end
end

function IKST_EdgeDock:snapToNearestEdge()
    local sw, sh = screenSize()
    local x = self:getX() or 0
    local y = self:getY() or 0
    local w = self:getWidth() or 0
    local h = self:getHeight() or 0
    local cx = x + (w / 2)
    local cy = y + (h / 2)
    local edge = "left"
    local best = cx
    if (sw - cx) < best then
        edge = "right"
        best = sw - cx
    end
    if cy < best then
        edge = "top"
        best = cy
    end
    if (sh - cy) < best then
        edge = "bottom"
    end
    local offset
    if edge == "left" or edge == "right" then
        offset = y
    else
        offset = x
    end
    self:applyEdge(edge, offset)
end

function IKST_EdgeDock:savePref()
    if IKST_UIPrefs and type(IKST_UIPrefs.saveDock) == "function" then
        IKST_UIPrefs.saveDock(self.edge, self.offset)
    end
end

function IKST_EdgeDock:restorePref()
    local edge, offset = "left", nil
    if IKST_UIPrefs and type(IKST_UIPrefs.loadDock) == "function" then
        local saved = IKST_UIPrefs.loadDock()
        if saved then
            edge = saved.edge or edge
            offset = saved.offset
        end
    end
    if offset == nil then
        offset = IKST_UI_Layout.s(80)
    end
    self:applyEdge(edge, offset)
end

function IKST_EdgeDock:prerender()
    IKUI_Chrome.drawDockedShell(self)
    ISPanel.prerender(self)
end

function IKST_EdgeDock:render()
    local m = IKST_EdgeDock.metrics()
    local c = IKUI_Chrome.colors
    local hover = type(self.isMouseOver) == "function" and self:isMouseOver()
    local expandCol = hover and c.accent or c.textMuted
    local pip = m.pip
    if self:isVertical() then
        local x = math.floor((self.width - pip) / 2)
        local y = m.pad
        self:drawRect(x, y, pip, pip, 1, c.accent.r, c.accent.g, c.accent.b)
        y = y + pip + m.gap
        local lx = math.floor((self.width - m.lw) / 2)
        self:drawText(m.label, lx, y, c.textMuted.r, c.textMuted.g, c.textMuted.b, 1, UIFont.Small)
        y = y + m.lh + m.gap
        local ex = math.floor((self.width - m.ew) / 2)
        self:drawText(m.expand, ex, y, expandCol.r, expandCol.g, expandCol.b, 1, UIFont.Small)
    else
        local x = m.pad
        local py = math.floor((self.height - pip) / 2)
        self:drawRect(x, py, pip, pip, 1, c.accent.r, c.accent.g, c.accent.b)
        x = x + pip + m.gap
        local ty = math.floor((self.height - m.lh) / 2)
        self:drawText(m.label, x, ty, c.textMuted.r, c.textMuted.g, c.textMuted.b, 1, UIFont.Small)
        x = x + m.lw + m.gap
        local ey = math.floor((self.height - m.eh) / 2)
        self:drawText(m.expand, x, ey, expandCol.r, expandCol.g, expandCol.b, 1, UIFont.Small)
    end
    if self._ikstJoyFocused then
        self:drawRectBorder(0, 0, self.width, self.height, 1, c.accent.r, c.accent.g, c.accent.b)
    end
end

function IKST_EdgeDock:onMouseDown(x, y)
    self._dragging = true
    self._dragMoved = false
    self._downMX, self._downMY = mouseXY()
    self._offX = x
    self._offY = y
    if type(self.setCapture) == "function" then
        self:setCapture(true)
    end
    if self.bringToTop then
        self:bringToTop()
    end
    return true
end

function IKST_EdgeDock:onMouseMove(_dx, _dy)
    if not self._dragging then
        return false
    end
    local mx, my = mouseXY()
    if mx and my and self._downMX and self._downMY then
        if math.abs(mx - self._downMX) > 3 or math.abs(my - self._downMY) > 3 then
            self._dragMoved = true
        end
    end
    if self._dragMoved and mx and my and self._offX and self._offY then
        self:setX(math.floor(mx - self._offX))
        self:setY(math.floor(my - self._offY))
    end
    return true
end

function IKST_EdgeDock:onMouseMoveOutside(dx, dy)
    if self._dragging then
        return self:onMouseMove(dx, dy)
    end
    return false
end

function IKST_EdgeDock:onMouseUp(_x, _y)
    if not self._dragging then
        return false
    end
    self._dragging = false
    if type(self.setCapture) == "function" then
        self:setCapture(false)
    end
    if self._dragMoved then
        self:snapToNearestEdge()
        self:savePref()
    else
        IKST_EdgeDock.expandHub()
    end
    return true
end

function IKST_EdgeDock:onMouseUpOutside(x, y)
    return self:onMouseUp(x, y)
end

function IKST_EdgeDock.ensure()
    if IKST_EdgeDock.instance then
        return IKST_EdgeDock.instance
    end
    local m = IKST_EdgeDock.metrics()
    local dock = IKST_EdgeDock:new(0, 0, m.thick, m.vLen)
    dock:initialise()
    if type(dock.instantiate) == "function" then
        dock:instantiate()
    end
    dock:addToUIManager()
    if type(ISUIElement) == "table" and type(ISUIElement.setVisible) == "function" then
        ISUIElement.setVisible(dock, false)
    else
        dock:setVisible(false)
    end
    IKST_EdgeDock.instance = dock
    dock:restorePref()
    return dock
end

function IKST_EdgeDock.show()
    local dock = IKST_EdgeDock.ensure()
    if not dock then
        return
    end
    dock:restorePref()
    if type(ISUIElement) == "table" and type(ISUIElement.setVisible) == "function" then
        ISUIElement.setVisible(dock, true)
    else
        dock:setVisible(true)
    end
    if dock.bringToTop then
        dock:bringToTop()
    end
    if type(setJoypadFocus) == "function" and JoypadState and JoypadState.players then
        for i = 0, 3 do
            local data = JoypadState.players[i]
            if data then
                if IKST_Joypad and type(IKST_Joypad.take) == "function" then
                    IKST_Joypad.take(dock, data)
                else
                    setJoypadFocus(i, dock)
                end
                break
            end
        end
    end
end

function IKST_EdgeDock.hide()
    local dock = IKST_EdgeDock.instance
    if not dock then
        return
    end
    dock._dragging = false
    if type(dock.setCapture) == "function" then
        dock:setCapture(false)
    end
    if type(ISUIElement) == "table" and type(ISUIElement.setVisible) == "function" then
        ISUIElement.setVisible(dock, false)
    elseif type(dock.setVisible) == "function" then
        dock:setVisible(false)
    end
end

function IKST_EdgeDock.isShown()
    local dock = IKST_EdgeDock.instance
    if not dock or type(dock.getIsVisible) ~= "function" then
        return false
    end
    return dock:getIsVisible() == true
end

function IKST_EdgeDock.minimizeHub()
    local panel = IKST_JobsPanel and IKST_JobsPanel.instance
    if panel then
        if IKST_UIPrefs and type(IKST_UIPrefs.savePanelGeometry) == "function" then
            IKST_UIPrefs.savePanelGeometry(panel)
        end
        if IKST_DragHandle and type(IKST_DragHandle.hidePanel) == "function" then
            IKST_DragHandle.hidePanel(panel)
        elseif type(panel.setVisible) == "function" then
            panel:setVisible(false)
        end
    end
    if IKST_ActionLogWindow and type(IKST_ActionLogWindow.close) == "function" then
        IKST_ActionLogWindow.close()
    end
    IKST_EdgeDock.show()
end

function IKST_EdgeDock.expandHub()
    IKST_EdgeDock.hide()
    local player = getPlayer and getPlayer() or nil
    if not player and getSpecificPlayer then
        player = getSpecificPlayer(0)
    end
    if IKST_Joypad then
        IKST_Joypad._wantFocus = true
    end
    if IKST_JobsPanel and type(IKST_JobsPanel.open) == "function" then
        IKST_JobsPanel.open(player)
    end
end

IKST_EdgeDock.minimize = IKST_EdgeDock.minimizeHub
IKST_EdgeDock.expand = IKST_EdgeDock.expandHub

local EDGE_CYCLE = { "left", "top", "right", "bottom" }

function IKST_EdgeDock:cycleEdge(dir)
    local cur = 1
    for i = 1, #EDGE_CYCLE do
        if EDGE_CYCLE[i] == self.edge then
            cur = i
            break
        end
    end
    cur = cur + (dir or 1)
    if cur < 1 then
        cur = #EDGE_CYCLE
    end
    if cur > #EDGE_CYCLE then
        cur = 1
    end
    self:applyEdge(EDGE_CYCLE[cur], self.offset)
    self:savePref()
end

function IKST_EdgeDock:onJoypadDown(button, _joypadData)
    local aBtn = Joypad and Joypad.AButton
    local bBtn = Joypad and Joypad.BButton
    if aBtn ~= nil and button == aBtn then
        IKST_EdgeDock.expandHub()
        return true
    end
    if bBtn ~= nil and button == bBtn then
        return true
    end
    return false
end

function IKST_EdgeDock:onJoypadDirUp()
    self:cycleEdge(-1)
    return true
end

function IKST_EdgeDock:onJoypadDirDown()
    self:cycleEdge(1)
    return true
end

function IKST_EdgeDock:onJoypadDirLeft()
    self:cycleEdge(-1)
    return true
end

function IKST_EdgeDock:onJoypadDirRight()
    self:cycleEdge(1)
    return true
end
