if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKappaID_UI_Framework/IKUI_Chrome"
require "IKST_Shared"

IKST_SpriteGrid = ISPanel:derive("IKST_SpriteGrid")

local CELL = 48
local GAP = 4
local PAD = 4
local FOOTER_H = 16

function IKST_SpriteGrid:new(x, y, w, h, sprites, onPick)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.sprites = sprites or {}
    o.onPick = onPick
    o.cell = CELL
    o.gap = GAP
    o.page = 1
    o.backgroundColor = IKUI_Chrome.colors.bgCard
    o.borderColor = IKUI_Chrome.colors.accentDim
    -- Soft Pack cards disable clipping; this panel must clip or tiles paint over List/Load/Search.
    o.clipping = true
    o:layoutMetrics()
    return o
end

function IKST_SpriteGrid:layoutMetrics()
    local w = math.max(40, self.width or 40)
    local h = math.max(36, self.height or 36)
    local cell = CELL
    local gap = GAP
    local cols = math.max(1, math.floor((w - PAD) / (cell + gap)))
    local bodyH = math.max(cell, h - FOOTER_H - PAD)
    local rows = math.max(1, math.floor(bodyH / (cell + gap)))
    -- If the band is short, shrink cells so at least one row stays inside the box.
    if rows < 1 or (rows * (cell + gap)) > bodyH then
        cell = math.max(28, math.floor((bodyH - PAD) / 1) - gap)
        rows = 1
        cols = math.max(1, math.floor((w - PAD) / (cell + gap)))
    end
    self.cols = cols
    self.rows = rows
    self.cell = cell
    self.gap = gap
    self.perPage = cols * rows
end

function IKST_SpriteGrid:setSprites(sprites)
    self.sprites = sprites or {}
    self.page = 1
    self:layoutMetrics()
end

function IKST_SpriteGrid:onResize()
    self:layoutMetrics()
end

function IKST_SpriteGrid:getPageCount()
    if #self.sprites == 0 then
        return 1
    end
    local per = math.max(1, self.perPage or 1)
    return math.max(1, math.ceil(#self.sprites / per))
end

function IKST_SpriteGrid:getPageSprites()
    self:layoutMetrics()
    local per = math.max(1, self.perPage or 1)
    local start = (self.page - 1) * per + 1
    local out = {}
    for i = start, math.min(start + per - 1, #self.sprites) do
        out[#out + 1] = self.sprites[i]
    end
    return out
end

function IKST_SpriteGrid:pagePrev()
    self.page = math.max(1, self.page - 1)
    if type(self.onPageChange) == "function" then
        self.onPageChange(self.page)
    end
end

function IKST_SpriteGrid:pageNext()
    self.page = math.min(self:getPageCount(), self.page + 1)
    if type(self.onPageChange) == "function" then
        self.onPageChange(self.page)
    end
end

function IKST_SpriteGrid:onMouseDown(x, y)
    self:layoutMetrics()
    local step = self.cell + self.gap
    local col = math.floor((x - PAD) / step)
    local row = math.floor((y - PAD) / step)
    if col < 0 or row < 0 or col >= self.cols or row >= self.rows then
        return true
    end
    local idx = row * self.cols + col + 1
    local pageSprites = self:getPageSprites()
    local entry = pageSprites[idx]
    if entry and self.onPick then
        self.onPick(entry.sprite or entry)
    end
    return true
end

function IKST_SpriteGrid:onMouseWheel(del)
    if del > 0 then
        self:pagePrev()
    else
        self:pageNext()
    end
    -- Persist without full rebuild so the soft host does not steal focus mid-scroll.
    return true
end

function IKST_SpriteGrid:render()
    self:layoutMetrics()
    ISPanel.render(self)
    local pageSprites = self:getPageSprites()
    local cc = IKUI_Chrome.colors
    local step = self.cell + self.gap
    local maxY = self.height - FOOTER_H
    for i, entry in ipairs(pageSprites) do
        local spriteName = tostring(entry.sprite or entry)
        local col = (i - 1) % self.cols
        local row = math.floor((i - 1) / self.cols)
        if row >= self.rows then
            break
        end
        local px = col * step + PAD
        local py = row * step + PAD
        if py + self.cell > maxY then
            break
        end
        self:drawRect(px, py, self.cell, self.cell, 0.85, 0.12, 0.14, 0.18)
        local tex = IKST_TileIndex and IKST_TileIndex.spriteTexture and IKST_TileIndex.spriteTexture(spriteName)
        if not tex and getTexture then
            tex = getTexture(spriteName)
        end
        if tex and type(tex.getWidth) == "function" then
            local tw = tex:getWidth()
            local th = tex:getHeight()
            if tw > 0 and th > 0 then
                local scale = math.min((self.cell - 4) / tw, (self.cell - 4) / th)
                local dw = math.floor(tw * scale)
                local dh = math.floor(th * scale)
                self:drawTextureScaled(tex, px + math.floor((self.cell - dw) / 2), py + math.floor((self.cell - dh) / 2), dw, dh, 1, 1, 1, 1)
            end
        else
            local label = string.sub(spriteName, -8)
            self:drawText(label, px + 4, py + 16, cc.textMuted.r, cc.textMuted.g, cc.textMuted.b, 1, UIFont.Small)
        end
    end
    if #self.sprites > (self.perPage or 0) then
        local footer = string.format("%d/%d  (%d)", self.page, self:getPageCount(), #self.sprites)
        self:drawText(footer, PAD, self.height - 14, cc.textMuted.r, cc.textMuted.g, cc.textMuted.b, 1, UIFont.Small)
    end
end
