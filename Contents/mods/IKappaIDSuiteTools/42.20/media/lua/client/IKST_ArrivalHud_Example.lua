--[[
    IKST Arrival HUD — UI example (NOT wired).

    Why the live bar showed "Arrival stabilization ? 17s":
      The old string used a middle-dot "·" (U+00B7). Project Zomboid's Small font
      often cannot draw that glyph, so it becomes "?". Prefer ASCII separators: " - " or " | ".

    How to try this example later:
      1. Compare with IKST_ArrivalClient.lua
      2. Copy render/layout bits into IKST_ArrivalClient, or rename/swap after review
      3. Do NOT require this file from IKST_Z_Bootstrap until you want it live

    Design goals (match IKST_Chrome + Phone Shop):
      - Dark panel, orange accent rail
      - Progress fill for remaining grace
      - Timer on the right, title on the left
      - ASCII-only labels (no fancy punctuation)
]]

if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISPanel"
require "IKST_Shared"
require "IKST_Arrival"
require "IKST_Chrome"

IKST_ArrivalHud_Example = ISPanel:derive("IKST_ArrivalHud_Example")
IKST_ArrivalHud_Example.instance = nil

local PAD = 10
local ACCENT_W = 3
local BAR_H = 4

function IKST_ArrivalHud_Example:new(player)
    local sw = getCore():getScreenWidth()
    local w, h = 320, 44
    local o = ISPanel:new((sw - w) / 2, 40, w, h)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.remainingMs = 0
    o.totalMs = IKST_Arrival.durationMs()
    o.background = false
    o.moveWithMouse = false
    return o
end

function IKST_ArrivalHud_Example:prerender()
    -- Keep transparent; we draw everything in render().
end

function IKST_ArrivalHud_Example:render()
    local remainingMs = self.remainingMs or 0
    if remainingMs <= 0 then
        return
    end

    local c = IKST_Chrome.colors
    local totalMs = self.totalMs or 0
    if totalMs <= 0 and IKST_Arrival and IKST_Arrival.durationMs then
        totalMs = IKST_Arrival.durationMs()
        self.totalMs = totalMs
    end
    if totalMs <= 0 then
        totalMs = remainingMs
    end

    local frac = remainingMs / totalMs
    if frac < 0 then frac = 0 end
    if frac > 1 then frac = 1 end

    local seconds = math.ceil(remainingMs / 1000)
    local title = IKST.text("IGUI_IKST_Arrival_HUD", "Arrival stabilization")
    local timer = tostring(seconds) .. "s"

    -- Card
    self:drawRect(0, 0, self.width, self.height, 0.92, c.bgApp.r, c.bgApp.g, c.bgApp.b)
    self:drawRectBorder(0, 0, self.width, self.height, 0.9, c.divider.r, c.divider.g, c.divider.b)

    -- Orange rail (IKST signature)
    self:drawRect(0, 0, ACCENT_W, self.height, 1, c.accent.r, c.accent.g, c.accent.b)

    -- Title
    self:drawText(title, PAD + ACCENT_W, 8, c.textPrimary.r, c.textPrimary.g, c.textPrimary.b, 1, UIFont.Small)

    -- Timer (right-aligned)
    local tw = getTextManager():MeasureStringX(UIFont.Small, timer)
    self:drawText(timer, self.width - PAD - tw, 8, c.accent.r, c.accent.g, c.accent.b, 1, UIFont.Small)

    -- Progress track
    local barX = PAD + ACCENT_W
    local barY = self.height - PAD - BAR_H
    local barW = self.width - barX - PAD
    self:drawRect(barX, barY, barW, BAR_H, 1, c.bgCard.r, c.bgCard.g, c.bgCard.b)
    local fillW = math.floor(barW * frac)
    if fillW > 0 then
        self:drawRect(barX, barY, fillW, BAR_H, 1, c.accent.r, c.accent.g, c.accent.b)
    end
end

--[[
    EXAMPLE wiring (do not enable until reviewed):

    function IKST_ArrivalHud_Example.ensure()
        ... same as IKST_ArrivalClient.ensure ...
    end

    On arrivalSync: set remainingMs + totalMs from args (server should send durationMs).
    Prefer ASCII in notify too: title .. " - " .. seconds .. "s"
]]
