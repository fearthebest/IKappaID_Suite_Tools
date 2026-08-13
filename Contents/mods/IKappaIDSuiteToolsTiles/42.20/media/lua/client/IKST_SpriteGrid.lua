if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Chrome"
require "IKST_Shared"

IKST_SpriteGrid = ISPanel:derive("IKST_SpriteGrid")

function IKST_SpriteGrid:new(x, y, w, h, sprites, onPick)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.sprites = sprites or {}
    o.onPick = onPick
    o.cols = 8
    o.cell = 48
    o.gap = 4
    o.perPage = 48
    o.page = 1
    o.backgroundColor = IKST_Chrome.colors.bgCard
    o.borderColor = IKST_Chrome.colors.accentDim
    return o
end

function IKST_SpriteGrid:setSprites(sprites)
    self.sprites = sprites or {}
    self.page = 1
end

function IKST_SpriteGrid:getPageCount()
    if #self.sprites == 0 then
        return 1
    end
    return math.max(1, math.ceil(#self.sprites / self.perPage))
end

function IKST_SpriteGrid:getPageSprites()
    local start = (self.page - 1) * self.perPage + 1
    local out = {}
    for i = start, math.min(start + self.perPage - 1, #self.sprites) do
        out[#out + 1] = self.sprites[i]
    end
    return out
end

function IKST_SpriteGrid:pagePrev()
    self.page = math.max(1, self.page - 1)
end

function IKST_SpriteGrid:pageNext()
    self.page = math.min(self:getPageCount(), self.page + 1)
end

function IKST_SpriteGrid:onMouseDown(x, y)
    local col = math.floor(x / (self.cell + self.gap))
    local row = math.floor(y / (self.cell + self.gap))
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
    return true
end

function IKST_SpriteGrid:render()
    ISPanel.render(self)
    local pageSprites = self:getPageSprites()
    local cc = IKST_Chrome.colors
    for i, entry in ipairs(pageSprites) do
        local spriteName = tostring(entry.sprite or entry)
        local col = (i - 1) % self.cols
        local row = math.floor((i - 1) / self.cols)
        local px = col * (self.cell + self.gap) + 4
        local py = row * (self.cell + self.gap) + 4
        self:drawRect(px, py, self.cell, self.cell, 0.85, 0.12, 0.14, 0.18)
        local tex = IKST_TileIndex and IKST_TileIndex.spriteTexture and IKST_TileIndex.spriteTexture(spriteName)
        if not tex and getTexture then
            tex = getTexture(spriteName)
        end
        if tex and tex.getWidth then
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
    if #self.sprites > self.perPage then
        local footer = string.format("%d/%d  (%d)", self.page, self:getPageCount(), #self.sprites)
        self:drawText(footer, 4, self.height - 14, cc.textMuted.r, cc.textMuted.g, cc.textMuted.b, 1, UIFont.Small)
    end
end
