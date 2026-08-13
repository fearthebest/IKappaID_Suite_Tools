-- Stenciled scroll panel for job content and economy lists.
-- Uses vanilla setYScroll when available; stencil clips children.

if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISPanel"
require "IKST_Chrome"

IKST_ScrollArea = ISPanel:derive("IKST_ScrollArea")

function IKST_ScrollArea:new(x, y, w, h)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    o.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    o.scrollChildren = {}
    o.contentH = 0
    return o
end

function IKST_ScrollArea:initialise()
    ISPanel.initialise(self)
    if type(self.setScrollChildren) == "function" then
        self:setScrollChildren(true)
    end
end

function IKST_ScrollArea:addScrollChild(widget)
    if not widget then
        return
    end
    self:addChild(widget)
    self.scrollChildren[#self.scrollChildren + 1] = widget
end

function IKST_ScrollArea:setContentHeight(h)
    self.contentH = math.max(0, tonumber(h) or 0)
    if type(self.setScrollHeight) == "function" then
        self:setScrollHeight(math.max(self.contentH, self.height or 0))
    end
end

function IKST_ScrollArea:prerender()
    ISPanel.prerender(self)
    if type(self.setStencilRect) == "function" then
        self:setStencilRect(0, 0, self.width, self.height)
    end
end

function IKST_ScrollArea:render()
    ISPanel.render(self)
    if type(self.clearStencilRect) == "function" then
        self:clearStencilRect()
    end
    if type(self.repaintStencilRect) == "function" then
        self:repaintStencilRect(0, 0, self.width, self.height)
    end
end

function IKST_ScrollArea:onMouseWheel(del)
    if type(self.setYScroll) == "function" and type(self.getYScroll) == "function" then
        local cur = self:getYScroll() or 0
        self:setYScroll(cur - (del * 40))
        return true
    end
    return false
end

function IKST_ScrollArea.wrap(parent, x, y, w, h)
    local area = IKST_ScrollArea:new(x, y, w, h)
    area:initialise()
    area:instantiate()
    if parent and type(parent.addJobWidget) == "function" then
        parent:addJobWidget(area)
    elseif parent and type(parent.addChild) == "function" then
        parent:addChild(area)
    end
    return area
end
