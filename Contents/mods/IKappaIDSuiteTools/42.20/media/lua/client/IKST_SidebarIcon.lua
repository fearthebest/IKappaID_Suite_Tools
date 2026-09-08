-- Vanilla left-HUD strip button for IKappaID Suite Tools (B42).
-- Positions under the equipped-item column without monkey-patching ISEquippedItem.
if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISButton"
require "IKST_Shared"
require "IKST_Access"

IKST_SidebarIcon = ISButton:derive("IKST_SidebarIcon")
IKST_SidebarIcon.instance = nil
IKST_SidebarIcon.TEX_PATH = "media/ui/ikst/sidebar_ikst.png"
IKST_SidebarIcon.TOOLTIP = "IKappaID Suite Tools"
IKST_SidebarIcon.SYNC_EVERY = 12

local ORANGE_R, ORANGE_G, ORANGE_B = 1.0, 0.42, 0.21
local NAMED_STRIP = {
    "invBtn", "healthBtn", "craftingBtn", "movableBtn", "searchBtn",
    "mapBtn", "safetyBtn", "clientBtn", "debugBtn", "adminBtn",
}

local function scaled(px, fallback)
    if IKUI_Config and type(IKUI_Config.s) == "function" then
        return IKUI_Config.s(px)
    end
    return fallback or px
end

local function num(v, d)
    v = tonumber(v)
    if v == nil then
        return d or 0
    end
    return v
end

local function readXYWH(el)
    if not el then
        return nil
    end
    local x = num(type(el.getX) == "function" and el:getX() or el.x, 0)
    local y = num(type(el.getY) == "function" and el:getY() or el.y, 0)
    local w = num(type(el.getWidth) == "function" and el:getWidth() or el.width, 0)
    local h = num(type(el.getHeight) == "function" and el:getHeight() or el.height, 0)
    return x, y, w, h
end

local function readAbsXY(el)
    if not el then
        return 0, 0
    end
    local x = num(type(el.getAbsoluteX) == "function" and el:getAbsoluteX()
        or (type(el.getX) == "function" and el:getX()) or el.x, 0)
    local y = num(type(el.getAbsoluteY) == "function" and el:getAbsoluteY()
        or (type(el.getY) == "function" and el:getY()) or el.y, 0)
    return x, y
end

function IKST_SidebarIcon.resolvePlayer()
    local player = getPlayer and getPlayer() or nil
    if not player and getSpecificPlayer then
        player = getSpecificPlayer(0)
    end
    if IKST and type(IKST.resolvePlayer) == "function" then
        player = IKST.resolvePlayer(player)
    end
    return player
end

function IKST_SidebarIcon.playerCanOpen(player)
    player = player or IKST_SidebarIcon.resolvePlayer()
    if not player or not IKST_Access or type(IKST_Access.canOpenPanel) ~= "function" then
        return false
    end
    return IKST_Access.canOpenPanel(player) == true
end

function IKST_SidebarIcon:new(x, y, w, h)
    local o = ISButton:new(x, y, w, h, "", nil, nil)
    setmetatable(o, self)
    self.__index = self
    o.onclick = IKST_SidebarIcon.onClicked
    o.target = o
    o.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    o.displayBackground = false
    o.moveWithMouse = false
    o.anchorLeft = true
    o.anchorRight = false
    o.anchorTop = true
    o.anchorBottom = false
    o.tooltip = IKST_SidebarIcon.TOOLTIP
    if type(o.setTooltip) == "function" then
        o:setTooltip(IKST_SidebarIcon.TOOLTIP)
    end
    o._tex = nil
    o._texTried = false
    o._syncTick = 0
    return o
end

function IKST_SidebarIcon:initialise()
    ISButton.initialise(self)
    self.onclick = IKST_SidebarIcon.onClicked
    self.target = self
    if type(self.setDisplayBackground) == "function" then
        self:setDisplayBackground(false)
    end
end

function IKST_SidebarIcon:onClicked()
    local player = IKST_SidebarIcon.resolvePlayer()
    if not IKST_SidebarIcon.playerCanOpen(player) then
        return
    end
    if IKST_Joypad then
        IKST_Joypad._wantFocus = true
    end
    if IKST_Hub and type(IKST_Hub.toggle) == "function" then
        IKST_Hub.toggle(player)
    end
end

function IKST_SidebarIcon:loadTexture()
    if self._texTried then
        return self._tex
    end
    self._texTried = true
    if type(getTexture) == "function" then
        local tex = getTexture(IKST_SidebarIcon.TEX_PATH)
        if tex then
            self._tex = tex
        end
    end
    return self._tex
end

local function drawDisk(panel, cx, cy, radius, a, r, g, b)
    radius = math.floor(radius)
    if radius < 1 or type(panel.drawRect) ~= "function" then
        return
    end
    for dy = -radius, radius do
        local inner = (radius * radius) - (dy * dy)
        if inner >= 0 then
            local span = math.floor(math.sqrt(inner) + 0.5)
            if span > 0 then
                panel:drawRect(cx - span, cy + dy, span * 2, 1, a, r, g, b)
            end
        end
    end
end

function IKST_SidebarIcon:drawFallback()
    local w = self.width or 50
    local h = self.height or 50
    local cx = math.floor(w / 2)
    local cy = math.floor(h / 2)
    local r = math.floor(math.min(w, h) / 2) - 1
    if r < 6 then
        r = 6
    end
    drawDisk(self, cx, cy, r, 1, 0.22, 0.22, 0.24)
    drawDisk(self, cx, cy, r - 1, 1, 0.55, 0.55, 0.58)
    drawDisk(self, cx, cy, r - 3, 1, ORANGE_R, ORANGE_G, ORANGE_B)
    drawDisk(self, cx, cy, r - 5, 1, 0.12, 0.12, 0.13)
    local hover = (type(self.isMouseOver) == "function" and self:isMouseOver())
        or self._ikstJoyFocused == true
    if hover then
        drawDisk(self, cx, cy, r - 3, 0.35, ORANGE_R, ORANGE_G, ORANGE_B)
        drawDisk(self, cx, cy, r - 5, 1, 0.14, 0.13, 0.12)
    end
end

function IKST_SidebarIcon:prerender()
    self._syncTick = (self._syncTick or 0) + 1
    if (self._syncTick % IKST_SidebarIcon.SYNC_EVERY) == 1 then
        self:syncToStrip()
    end
    if type(self.getIsVisible) == "function" and not self:getIsVisible() then
        return
    end
    local tex = self:loadTexture()
    if tex and type(self.drawTextureScaled) == "function" then
        self:drawTextureScaled(tex, 0, 0, self.width, self.height, 1, 1, 1, 1)
    else
        self:drawFallback()
    end
    if self._ikstJoyFocused and type(self.drawRectBorder) == "function" then
        local t = scaled(2, 2)
        for i = 0, t - 1 do
            self:drawRectBorder(i, i, self.width - (i * 2), self.height - (i * 2), 1, ORANGE_R, ORANGE_G, ORANGE_B)
        end
    end
    if ISButton and type(ISButton.updateTooltip) == "function" then
        ISButton.updateTooltip(self)
    end
end

function IKST_SidebarIcon:render()
end

function IKST_SidebarIcon:onJoypadDown(button, _joypadData)
    local aBtn = Joypad and Joypad.AButton
    if aBtn ~= nil and button == aBtn then
        self:onClicked()
        return true
    end
end

function IKST_SidebarIcon:setJoypadFocused(focused, joypadData)
    self.joyfocus = focused and joypadData or nil
    self._ikstJoyFocused = focused == true
    self.joypadFocused = focused == true
end

local function eachChild(host, fn)
    if not host or type(fn) ~= "function" then
        return
    end
    local kids = nil
    if type(host.getChildren) == "function" then
        kids = host:getChildren()
    end
    if kids == nil then
        kids = host.children
    end
    if not kids then
        return
    end
    if type(kids.size) == "function" then
        local n = kids:size()
        if n then
            for i = 0, n - 1 do
                local child = kids:get(i)
                if child then
                    fn(child)
                end
            end
        end
        return
    end
    if type(kids) == "table" then
        for _, child in pairs(kids) do
            if type(child) == "table" then
                fn(child)
            end
        end
    end
end

local function isStripIcon(el, skip)
    if not el or el == skip then
        return false
    end
    if el.Type == "IKST_SidebarIcon" then
        return false
    end
    local x, y, w, h = readXYWH(el)
    if not w or w < 18 or w > 96 or h < 18 or h > 96 then
        return false
    end
    if math.abs(w - h) > 18 then
        return false
    end
    return true, x, y, w, h
end

function IKST_SidebarIcon.collectStripIcons(host, skip)
    local list = {}
    if not host then
        return list
    end
    eachChild(host, function(child)
        local ok, x, y, w, h = isStripIcon(child, skip)
        if ok then
            list[#list + 1] = { el = child, x = x, y = y, w = w, h = h }
        end
    end)
    if #list == 0 then
        for i = 1, #NAMED_STRIP do
            local child = host[NAMED_STRIP[i]]
            local ok, x, y, w, h = isStripIcon(child, skip)
            if ok then
                list[#list + 1] = { el = child, x = x, y = y, w = w, h = h }
            end
        end
    end
    table.sort(list, function(a, b)
        return a.y < b.y
    end)
    return list
end

function IKST_SidebarIcon.measureBottomSlot(host, skip)
    local icons = IKST_SidebarIcon.collectStripIcons(host, skip)
    local sz = scaled(50, 50)
    if sz < 32 then
        sz = 32
    end
    if #icons == 0 then
        local hw = num(type(host.getWidth) == "function" and host:getWidth() or host.width, sz)
        local hh = num(type(host.getHeight) == "function" and host:getHeight() or host.height, sz)
        local icon = math.max(32, math.min(sz, hw > 8 and (hw - 4) or sz))
        return { x = math.max(0, math.floor((hw - icon) / 2)), y = math.max(0, hh), w = icon, h = icon }
    end
    local last = icons[#icons]
    local gap = 5
    if #icons >= 2 then
        local prev = icons[#icons - 1]
        local g = last.y - (prev.y + prev.h)
        if g >= 1 and g <= 20 then
            gap = g
        end
    end
    return {
        x = last.x,
        y = last.y + last.h + gap,
        w = last.w,
        h = last.h,
    }
end

local function eachUI(fn)
    if not UIManager or type(UIManager.getUI) ~= "function" then
        return
    end
    local list = UIManager.getUI()
    if not list then
        return
    end
    if type(list.size) == "function" then
        local n = list:size()
        if n then
            for i = 0, n - 1 do
                local el = list:get(i)
                if el then
                    fn(el)
                end
            end
        end
        return
    end
    if type(list) == "table" then
        for _, el in pairs(list) do
            if type(el) == "table" then
                fn(el)
            end
        end
    end
end

function IKST_SidebarIcon.findHost()
    if ISEquippedItem and ISEquippedItem.instance then
        local inst = ISEquippedItem.instance
        local w = type(inst.getWidth) == "function" and inst:getWidth() or inst.width
        if inst.javaObject or w then
            return inst
        end
    end
    local best, bestScore = nil, -1
    eachUI(function(el)
        if el == IKST_SidebarIcon.instance then
            return
        end
        if el.Type == "ISEquippedItem" then
            best = el
            bestScore = 9999
            return
        end
        local x = num(type(el.getX) == "function" and el:getX() or el.x, 9999)
        local w = num(type(el.getWidth) == "function" and el:getWidth() or el.width, 0)
        local h = num(type(el.getHeight) == "function" and el:getHeight() or el.height, 0)
        if x < 90 and w >= 28 and w <= 130 and h >= 80 then
            local score = (130 - w) + (90 - x) + math.min(h, 400) * 0.05
            if score > bestScore then
                best = el
                bestScore = score
            end
        end
    end)
    return best
end

function IKST_SidebarIcon.scanLeftColumn(skip)
    local icons = {}
    eachUI(function(el)
        if el == skip then
            return
        end
        local x, y = readAbsXY(el)
        local w = num(type(el.getWidth) == "function" and el:getWidth() or el.width, 0)
        local h = num(type(el.getHeight) == "function" and el:getHeight() or el.height, 0)
        if x < 90 and w >= 18 and w <= 96 and h >= 18 and h <= 96 and math.abs(w - h) <= 18 then
            icons[#icons + 1] = { x = x, y = y, w = w, h = h }
        end
    end)
    table.sort(icons, function(a, b)
        if a.x == b.x then
            return a.y < b.y
        end
        return a.x < b.x
    end)
    if #icons == 0 then
        return nil
    end
    local colX = icons[1].x
    local last = icons[1]
    for i = 1, #icons do
        if math.abs(icons[i].x - colX) <= 8 and icons[i].y >= last.y then
            last = icons[i]
        end
    end
    return { x = last.x, y = last.y + last.h + 5, w = last.w, h = last.h }
end

function IKST_SidebarIcon:applyGeom(x, y, w, h)
    if type(self.setX) == "function" then
        self:setX(x)
    else
        self.x = x
    end
    if type(self.setY) == "function" then
        self:setY(y)
    else
        self.y = y
    end
    if type(self.setWidth) == "function" then
        self:setWidth(w)
    else
        self.width = w
    end
    if type(self.setHeight) == "function" then
        self:setHeight(h)
    else
        self.height = h
    end
end

function IKST_SidebarIcon:ensureUIManager()
    if self.parent then
        return
    end
    if type(self.addToUIManager) == "function" then
        self:addToUIManager()
    end
end

function IKST_SidebarIcon:tryParent(host)
    if not host or type(host.addChild) ~= "function" then
        return false
    end
    if self.parent == host then
        return true
    end
    if self.parent and type(self.parent.removeChild) == "function" then
        self.parent:removeChild(self)
    end
    host:addChild(self)
    return self.parent == host
end

function IKST_SidebarIcon:syncToStrip()
    local player = IKST_SidebarIcon.resolvePlayer()
    if not IKST_SidebarIcon.playerCanOpen(player) then
        if type(self.setVisible) == "function" then
            self:setVisible(false)
        end
        return
    end

    local host = IKST_SidebarIcon.findHost()
    self._host = host

    if host then
        local parented = self:tryParent(host)
        if not parented then
            self:ensureUIManager()
        end
        local geom = IKST_SidebarIcon.measureBottomSlot(host, self)
        if geom then
            if parented then
                self:applyGeom(geom.x, geom.y, geom.w, geom.h)
                if type(host.setHeight) == "function" and type(host.getHeight) == "function" then
                    local need = geom.y + geom.h + 4
                    local hh = host:getHeight() or 0
                    if hh < need then
                        host:setHeight(need)
                    end
                end
            else
                local hx, hy = readAbsXY(host)
                self:applyGeom(hx + geom.x, hy + geom.y, geom.w, geom.h)
            end
        end
        local hostVis = true
        if type(host.getIsVisible) == "function" then
            hostVis = host:getIsVisible() ~= false
        end
        if type(self.setVisible) == "function" then
            self:setVisible(hostVis)
        end
        return
    end

    self:ensureUIManager()
    local geom = IKST_SidebarIcon.scanLeftColumn(self)
    if geom then
        self:applyGeom(geom.x, geom.y, geom.w, geom.h)
    else
        local sz = scaled(50, 50)
        local sh = 1080
        if type(getCore) == "function" then
            local core = getCore()
            if core and type(core.getScreenHeight) == "function" then
                sh = core:getScreenHeight() or sh
            end
        end
        self:applyGeom(10, math.min(10 + (5 * (sz + 5)), sh - sz - 20), sz, sz)
    end
    if type(self.setVisible) == "function" then
        self:setVisible(true)
    end
end

function IKST_SidebarIcon.ensure()
    if not IKST_SidebarIcon.playerCanOpen() then
        if IKST_SidebarIcon.instance and type(IKST_SidebarIcon.instance.setVisible) == "function" then
            IKST_SidebarIcon.instance:setVisible(false)
        end
        return IKST_SidebarIcon.instance
    end
    local inst = IKST_SidebarIcon.instance
    if inst and not inst.javaObject then
        IKST_SidebarIcon.instance = nil
        inst = nil
    end
    if inst then
        inst:syncToStrip()
        return inst
    end
    local sz = scaled(50, 50)
    local icon = IKST_SidebarIcon:new(10, 200, sz, sz)
    icon:initialise()
    if type(icon.instantiate) == "function" then
        icon:instantiate()
    end
    IKST_SidebarIcon.instance = icon
    icon:syncToStrip()
    return icon
end

function IKST_SidebarIcon.sync()
    IKST_SidebarIcon.ensure()
end

function IKST_SidebarIcon.destroy()
    local inst = IKST_SidebarIcon.instance
    if not inst then
        return
    end
    if inst.parent and type(inst.parent.removeChild) == "function" then
        inst.parent:removeChild(inst)
    elseif type(inst.removeFromUIManager) == "function" then
        inst:removeFromUIManager()
    end
    IKST_SidebarIcon.instance = nil
end

local function onReady()
    if not ISEquippedItem then
        require "ISUI/ISEquippedItem"
    end
    IKST_SidebarIcon.ensure()
    if IKST_Joypad and type(IKST_Joypad.ensureInstalled) == "function" then
        IKST_Joypad.ensureInstalled()
    end
end

if Events then
    if Events.OnCreatePlayer then
        Events.OnCreatePlayer.Add(onReady)
    end
    if Events.OnGameStart then
        Events.OnGameStart.Add(onReady)
    end
    if Events.OnGameTimeLoaded then
        Events.OnGameTimeLoaded.Add(onReady)
    end
    if Events.OnResolutionChange then
        Events.OnResolutionChange.Add(function()
            IKST_SidebarIcon.ensure()
        end)
    end
end
