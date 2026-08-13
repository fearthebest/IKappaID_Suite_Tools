-- IKappaID layout helpers for IKST client UI (B42).
-- Measure-first layout; no hardcoded content positions outside callers.
if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_UI_Theme"

IKST_UI_Layout = IKST_UI_Layout or {}

function IKST_UI_Layout.uiScale()
    local sh = 1080
    if getCore and type(getCore) == "function" then
        local core = getCore()
        if core and type(core.getScreenHeight) == "function" then
            sh = core:getScreenHeight() or sh
        end
    end
    if sh < 800 then
        return 0.85
    end
    if sh >= 1400 then
        return 1.25
    end
    return 1.0
end

function IKST_UI_Layout.s(px)
    return math.floor((tonumber(px) or 0) * IKST_UI_Layout.uiScale() + 0.5)
end

function IKST_UI_Layout.textSize(text, font)
    font = font or UIFont.Small
    text = text or ""
    local w, h = 0, 14
    if getTextManager and type(getTextManager) == "function" then
        local tm = getTextManager()
        if tm and type(tm.MeasureStringX) == "function" then
            w = tm:MeasureStringX(font, text) or 0
        end
        if tm and type(tm.MeasureStringY) == "function" then
            h = tm:MeasureStringY(font, text) or h
        elseif tm and type(tm.getFontFromEnum) == "function" then
            local fontObj = tm:getFontFromEnum(font)
            if fontObj and type(fontObj.getLineHeight) == "function" then
                h = fontObj:getLineHeight() or h
            end
        end
    end
    return w, h
end

function IKST_UI_Layout.buttonWidth(label, font, minW)
    local pad = IKST_UI_Layout.s(IKST_UI_Theme.space.buttonPadX)
    local tw = IKST_UI_Layout.textSize(label or "", font or UIFont.Small)
    local w = tw + (pad * 2)
    minW = minW or 80
    if w < minW then
        w = minW
    end
    return w
end

function IKST_UI_Layout.screen(margin)
    margin = margin or IKST_UI_Layout.s(IKST_UI_Theme.space.screenMargin)
    local sw, sh = 1280, 720
    if getCore and type(getCore) == "function" then
        local core = getCore()
        if core and type(core.getScreenWidth) == "function" then
            sw = core:getScreenWidth() or sw
        end
        if core and type(core.getScreenHeight) == "function" then
            sh = core:getScreenHeight() or sh
        end
    end
    return {
        x = margin,
        y = margin,
        w = math.max(200, sw - (margin * 2)),
        h = math.max(200, sh - (margin * 2)),
        sw = sw,
        sh = sh,
        margin = margin,
    }
end

function IKST_UI_Layout.center(childW, childH, rect)
    rect = rect or IKST_UI_Layout.screen()
    local rw = rect.w or rect.width or 0
    local rh = rect.h or rect.height or 0
    local rx = rect.x or 0
    local ry = rect.y or 0
    return rx + math.floor((rw - childW) / 2), ry + math.floor((rh - childH) / 2)
end

-- Vertical stack. children = { {h=n} or number, ... }. Returns nextY and list of {x,y,w,h}.
function IKST_UI_Layout.column(parent, x, y, w, children, opts)
    opts = opts or {}
    local gap = opts.gap or IKST_UI_Layout.s(IKST_UI_Theme.space.gap)
    local pad = opts.pad or 0
    local curY = y + pad
    local out = {}
    local innerW = w - (pad * 2)
    for _, child in ipairs(children or {}) do
        local h = child
        if type(child) == "table" then
            h = child.h or child.height or 0
        end
        h = tonumber(h) or 0
        out[#out + 1] = { x = x + pad, y = curY, w = innerW, h = h }
        curY = curY + h + gap
    end
    if opts.consumeLastGap ~= false and #out > 0 then
        curY = curY - gap
    end
    return curY + pad, out
end

-- Horizontal row with proportional widths. children = { {flex=1} or {w=n}, ... }.
function IKST_UI_Layout.row(parent, x, y, h, children, opts)
    opts = opts or {}
    local gap = opts.gap or IKST_UI_Layout.s(IKST_UI_Theme.space.gap)
    local pad = opts.pad or 0
    local totalW = opts.w or (parent and parent.width) or 0
    local innerW = totalW - (pad * 2)
    local fixed = 0
    local flexSum = 0
    local n = #(children or {})
    for _, child in ipairs(children or {}) do
        if type(child) == "table" and child.w then
            fixed = fixed + (tonumber(child.w) or 0)
        else
            local flex = 1
            if type(child) == "table" and child.flex then
                flex = tonumber(child.flex) or 1
            end
            flexSum = flexSum + flex
        end
    end
    local gaps = math.max(0, n - 1) * gap
    local flexBudget = math.max(0, innerW - fixed - gaps)
    local curX = x + pad
    local out = {}
    for _, child in ipairs(children or {}) do
        local cw
        if type(child) == "table" and child.w then
            cw = tonumber(child.w) or 0
        else
            local flex = 1
            if type(child) == "table" and child.flex then
                flex = tonumber(child.flex) or 1
            end
            if flexSum > 0 then
                cw = math.floor(flexBudget * (flex / flexSum))
            else
                cw = 0
            end
        end
        out[#out + 1] = { x = curX, y = y + pad, w = cw, h = h - (pad * 2) }
        curX = curX + cw + gap
    end
    return out
end

function IKST_UI_Layout.sidebarWidth()
    local base = IKST_UI_Theme.space.sidebarWidth
    local scaled = IKST_UI_Layout.s(base)
    -- Keep usable content on smaller panels.
    if scaled > 220 and IKST_UI_Layout.uiScale() < 1.1 then
        scaled = 200
    end
    return scaled
end

function IKST_UI_Layout.padding()
    return IKST_UI_Layout.s(IKST_UI_Theme.space.padding)
end

function IKST_UI_Layout.gap()
    return IKST_UI_Layout.s(IKST_UI_Theme.space.gap)
end

function IKST_UI_Layout.buttonMinH()
    local h = IKST_UI_Layout.s(IKST_UI_Theme.space.buttonMinH)
    if h < 28 then
        h = 28
    end
    return h
end
