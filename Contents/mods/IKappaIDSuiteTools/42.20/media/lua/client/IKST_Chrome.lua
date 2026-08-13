-- IKST chrome / dark+orange draw + control styling (client UI only).
if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Access"
require "IKST_UI_Theme"
require "IKST_UI_Layout"
require "ISUI/ISPanel"

IKST_Chrome = IKST_Chrome or {}

-- Back-compat: callers read IKST_Chrome.colors
IKST_Chrome.colors = IKST_UI_Theme.colors

function IKST_Chrome.rgba(c, alpha)
    return IKST_UI_Theme.rgba(c, alpha)
end

function IKST_Chrome.mutedTextRgb()
    return IKST_UI_Theme.rgba(IKST_UI_Theme.colors.textMuted)
end

function IKST_Chrome.applyPanelColors(panel)
    if not panel then
        return
    end
    local c = IKST_Chrome.colors
    -- Shell is drawn manually (rounded dock); keep ISUI frame transparent.
    panel.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    panel.borderColor = { r = 0, g = 0, b = 0, a = 0 }
end

function IKST_Chrome.drawDockedShell(panel)
    if not panel or type(panel.drawRect) ~= "function" then
        return
    end
    local c = IKST_Chrome.colors
    local bw = math.max(2, IKST_UI_Layout.s(2))
    IKST_Chrome.drawRoundedCard(panel, 0, 0, panel.width, panel.height, {
        radius = IKST_Chrome.ROUND_RADIUS,
        fill = c.bgApp,
        borderColor = c.accent,
        borderWidth = bw,
        selected = true,
        shadow = false,
    })
end

function IKST_Chrome.applySurfaceColors(panel)
    if not panel then
        return
    end
    local c = IKST_Chrome.colors
    panel.backgroundColor = { r = c.bgCard.r, g = c.bgCard.g, b = c.bgCard.b, a = c.bgCard.a }
    panel.borderColor = { r = c.divider.r, g = c.divider.g, b = c.divider.b, a = 0.35 }
end

-- Vanilla ISButton still paints its title (often near-black in B42) even after
-- Lua sets textColor. Capture the label, hide the vanilla title, and draw it
-- ourselves so every tool button stays readable on dark IKappaID surfaces.
function IKST_Chrome.buttonTitle(btn)
    if not btn then
        return ""
    end
    if type(btn._ikstTitle) == "string" and btn._ikstTitle ~= "" then
        return btn._ikstTitle
    end
    return btn.title or ""
end

function IKST_Chrome.prerenderCustomButton(b)
    ISPanel.prerender(b)
end

function IKST_Chrome.suppressVanillaButtonPaint(btn)
    if not btn then
        return
    end
    if type(btn.setDisplayBackground) == "function" then
        btn:setDisplayBackground(false)
    end
    btn.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    btn.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    if btn.backgroundColorMouseOver then
        btn.backgroundColorMouseOver = { r = 0, g = 0, b = 0, a = 0 }
    end
    if type(btn.title) == "string" and btn.title ~= "" then
        btn._ikstTitle = btn.title
        btn.title = ""
    elseif type(btn._ikstTitle) ~= "string" then
        btn._ikstTitle = ""
    end
    btn.prerender = IKST_Chrome.prerenderCustomButton
end

function IKST_Chrome.stylePrimaryButton(btn)
    IKST_Chrome.styleRoundedButton(btn, "primary")
end

function IKST_Chrome.styleSecondaryButton(btn)
    IKST_Chrome.styleRoundedButton(btn, "outline")
end

function IKST_Chrome.styleGhostButton(btn)
    IKST_Chrome.styleRoundedButton(btn, "ghost")
end

function IKST_Chrome.styleDangerButton(btn)
    IKST_Chrome.styleRoundedButton(btn, "danger")
end

function IKST_Chrome.styleChipButton(btn, active)
    IKST_Chrome.styleRoundedButton(btn, active and "primary" or "chip")
end

function IKST_Chrome.styleModeButton(btn, active)
    IKST_Chrome.styleNavPill(btn, active)
end

function IKST_Chrome.drawShadowText(panel, text, x, y, col, font, alpha)
    if not panel or type(panel.drawText) ~= "function" then
        return
    end
    if not text or text == "" then
        return
    end
    font = font or UIFont.Small
    alpha = alpha or 1
    col = col or IKST_Chrome.colors.textPrimary
    panel:drawText(text, x + 1, y + 1, 0, 0, 0, alpha * 0.8, font)
    panel:drawText(text, x, y, col.r, col.g, col.b, alpha, font)
end

function IKST_Chrome.onActionButtonMouseDown(b, _x, _y)
    if not b or b.enable == false then
        return false
    end
    if type(b._ikstOnClick) == "function" then
        b._ikstOnClick(b._ikstClickTarget, b)
    end
    return true
end

-- Tool control painted by us (ISPanel). B42 ISButton still draws its own
-- near-black title on dark fills, which is what made Self / Players unreadable.
function IKST_Chrome.newActionButton(x, y, w, h, label, target, onClick, kind)
    local btn = ISPanel:new(x, y, w, h)
    btn:initialise()
    btn.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    btn.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    btn.enable = true
    btn.font = UIFont.Small
    btn._ikstTitle = label or ""
    btn._ikstClickTarget = target
    btn._ikstOnClick = onClick
    btn.setEnable = function(self, enabled)
        self.enable = enabled ~= false
    end
    btn.setImage = function(self, tex)
        self.image = tex
    end
    btn.setDisplayBackground = function(_self, _show)
    end
    IKST_Chrome.styleRoundedButton(btn, kind or "chip")
    btn.onMouseDown = IKST_Chrome.onActionButtonMouseDown
    return btn
end

-- Vanilla ISButton draws its icon at x=0 and its title centered across the
-- FULL button width, so any button with both an icon (btn.image, set via
-- IKST_ClaimIcons.applyButtonIcon/setImage) and a label overlaps them. Every
-- custom render below calls this instead of drawing the label itself, so the
-- label always starts after the icon (icon-only buttons keep centered text).
function IKST_Chrome.drawIconLabel(b, textCol, font)
    font = font or b.font or UIFont.Small
    local title = IKST_Chrome.buttonTitle(b)
    local pad = IKST_UI_Layout.s(8)
    local icon = b.image
    if icon and type(b.drawTextureScaled) == "function" then
        local iconSz = math.max(12, math.min(b.height - IKST_UI_Layout.s(8), IKST_UI_Layout.s(20)))
        local iconY = math.floor((b.height - iconSz) / 2)
        b:drawTextureScaled(icon, pad, iconY, iconSz, iconSz, 1, 1, 1, 1)
        if title ~= "" then
            local textX = pad + iconSz + IKST_UI_Layout.s(8)
            local _, th = IKST_UI_Layout.textSize(title, font)
            IKST_Chrome.drawShadowText(b, title, textX, math.floor((b.height - th) / 2), textCol, font, 1)
        end
    elseif title ~= "" then
        local tw, th = IKST_UI_Layout.textSize(title, font)
        IKST_Chrome.drawShadowText(b, title, math.floor((b.width - tw) / 2), math.floor((b.height - th) / 2), textCol, font, 1)
    end
end

-- Rounded-free nav pill (sidebar rows: workspace list, tool tabs). Bypasses
-- ISButton's own render entirely so drawIconLabel can lay out icon+text.
function IKST_Chrome.styleNavPill(btn, active)
    if not btn then
        return
    end
    IKST_Chrome.suppressVanillaButtonPaint(btn)
    btn._ikstNavActive = active == true
    local c = IKST_Chrome.colors
    btn.textColor = { r = c.textPrimary.r, g = c.textPrimary.g, b = c.textPrimary.b, a = 1 }
    btn.render = IKST_Chrome.renderNavPill
end

function IKST_Chrome.renderNavPill(b)
    local c = IKST_Chrome.colors
    if b._ikstNavActive then
        b:drawRect(0, 0, b.width, b.height, c.navPill.a, c.navPill.r, c.navPill.g, c.navPill.b)
        b:drawRectBorder(0, 0, b.width, b.height, 0.55, c.accent.r, c.accent.g, c.accent.b)
    elseif b.enable ~= false and type(b.isMouseOver) == "function" and b:isMouseOver() then
        b:drawRect(0, 0, b.width, b.height, 0.08, 1, 1, 1)
    end
    local textCol = b._ikstNavActive and c.accent or c.textMuted
    IKST_Chrome.drawIconLabel(b, textCol)
end

function IKST_Chrome.styleListBox(list)
    if not list then
        return
    end
    local c = IKST_Chrome.colors
    list.backgroundColor = { r = c.bgInput.r, g = c.bgInput.g, b = c.bgInput.b, a = 0.95 }
    list.borderColor = { r = c.divider.r, g = c.divider.g, b = c.divider.b, a = 0.8 }
end

function IKST_Chrome.styleInput(entry, focused)
    if not entry then
        return
    end
    local c = IKST_Chrome.colors
    entry.backgroundColor = { r = c.bgInput.r, g = c.bgInput.g, b = c.bgInput.b, a = 1 }
    if focused then
        entry.borderColor = { r = c.accent.r, g = c.accent.g, b = c.accent.b, a = 1 }
    else
        entry.borderColor = { r = c.divider.r, g = c.divider.g, b = c.divider.b, a = 0.8 }
    end
end

function IKST_Chrome.drawAccentBar(panel, y, h)
    if not panel or type(panel.drawRect) ~= "function" then
        return
    end
    local c = IKST_Chrome.colors
    panel:drawRect(0, y or 0, panel.width, h or 2, c.accent.a, c.accent.r, c.accent.g, c.accent.b)
end

-- Soft card: shadow layer + surface (PZ has no native round-rect; approximate glass).
function IKST_Chrome.drawCard(panel, x, y, w, h, opts)
    if not panel or type(panel.drawRect) ~= "function" then
        return
    end
    opts = opts or {}
    local c = IKST_Chrome.colors
    local shadow = opts.shadow
    if shadow == nil then
        shadow = true
    end
    if shadow then
        local off = opts.shadowOff or IKST_UI_Layout.s(IKST_UI_Theme.space.cardShadow)
        panel:drawRect(x + off, y + off, w, h, c.shadow.a * 0.55, c.shadow.r, c.shadow.g, c.shadow.b)
    end
    local fill = opts.fill or c.bgCard
    panel:drawRect(x, y, w, h, fill.a or 0.92, fill.r, fill.g, fill.b)
    if opts.accentLeft then
        panel:drawRect(x, y, 3, h, 1, c.accent.r, c.accent.g, c.accent.b)
    end
    if opts.selected then
        panel:drawRectBorder(x, y, w, h, 1, c.accent.r, c.accent.g, c.accent.b)
    elseif opts.border ~= false then
        panel:drawRectBorder(x, y, w, h, 0.35, c.divider.r, c.divider.g, c.divider.b)
    end
end

-- Rounded-rect corner art (plain white silhouette, tints to any IKappaID
-- surface color via drawTextureScaled's r,g,b). Falls back to a square
-- corner if the texture ever fails to load (vanilla fallback, no gimmick
-- pcall needed).
IKST_Chrome.ROUND_RADIUS = IKST_UI_Layout.s(IKST_UI_Theme.space.cornerRadius)
local ROUND_CORNER_TEX = {
    tl = "media/ui/ikst/corner_tl.png",
    tr = "media/ui/ikst/corner_tr.png",
    bl = "media/ui/ikst/corner_bl.png",
    br = "media/ui/ikst/corner_br.png",
}

-- Draws a solid rounded-rect fill: a plus-shaped block of plain rects plus 4
-- corner arcs, so it works over any backdrop (no need to know what's behind).
function IKST_Chrome.drawRoundedFill(panel, x, y, w, h, r, g, b, a, radius)
    if not panel or type(panel.drawRect) ~= "function" then
        return
    end
    w = math.max(0, w)
    h = math.max(0, h)
    radius = math.max(0, math.min(radius or IKST_Chrome.ROUND_RADIUS, math.floor(math.min(w, h) / 2)))
    if radius < 2 then
        panel:drawRect(x, y, w, h, a, r, g, b)
        return
    end
    panel:drawRect(x + radius, y, math.max(0, w - (radius * 2)), h, a, r, g, b)
    panel:drawRect(x, y + radius, radius, math.max(0, h - (radius * 2)), a, r, g, b)
    panel:drawRect(x + w - radius, y + radius, radius, math.max(0, h - (radius * 2)), a, r, g, b)
    local tl = getTexture(ROUND_CORNER_TEX.tl)
    if tl and type(panel.drawTextureScaled) == "function" then
        panel:drawTextureScaled(tl, x, y, radius, radius, a, r, g, b)
        panel:drawTextureScaled(getTexture(ROUND_CORNER_TEX.tr), x + w - radius, y, radius, radius, a, r, g, b)
        panel:drawTextureScaled(getTexture(ROUND_CORNER_TEX.bl), x, y + h - radius, radius, radius, a, r, g, b)
        panel:drawTextureScaled(getTexture(ROUND_CORNER_TEX.br), x + w - radius, y + h - radius, radius, radius, a, r, g, b)
    else
        panel:drawRect(x, y, radius, radius, a, r, g, b)
        panel:drawRect(x + w - radius, y, radius, radius, a, r, g, b)
        panel:drawRect(x, y + h - radius, radius, radius, a, r, g, b)
        panel:drawRect(x + w - radius, y + h - radius, radius, radius, a, r, g, b)
    end
end

-- Rounded version of drawCard: same shadow/fill/border semantics, curved corners.
function IKST_Chrome.drawRoundedCard(panel, x, y, w, h, opts)
    if not panel or type(panel.drawRect) ~= "function" then
        return
    end
    opts = opts or {}
    local c = IKST_Chrome.colors
    local radius = opts.radius or IKST_Chrome.ROUND_RADIUS
    local shadow = opts.shadow
    if shadow == nil then
        shadow = true
    end
    if shadow then
        local off = opts.shadowOff or IKST_UI_Layout.s(IKST_UI_Theme.space.cardShadow)
        IKST_Chrome.drawRoundedFill(panel, x + off, y + off, w, h,
            c.shadow.r, c.shadow.g, c.shadow.b, (c.shadow.a or 1) * 0.55, radius)
    end
    local fill = opts.fill or c.bgCard
    if opts.border == false then
        IKST_Chrome.drawRoundedFill(panel, x, y, w, h, fill.r, fill.g, fill.b, fill.a or 0.92, radius)
        return
    end
    local outline = opts.selected and c.accent or (opts.borderColor or c.divider)
    local outlineA = opts.selected and 1 or (opts.borderColor and (opts.borderColor.a or 1) or 0.5)
    local bw = opts.borderWidth or 1
    IKST_Chrome.drawRoundedFill(panel, x, y, w, h, outline.r, outline.g, outline.b, outlineA, radius)
    IKST_Chrome.drawRoundedFill(panel, x + bw, y + bw, w - (bw * 2), h - (bw * 2),
        fill.r, fill.g, fill.b, fill.a or 0.92, math.max(1, radius - bw))
end

-- Rounded pill button: bypasses ISButton's own square render entirely so the
-- corners can curve. kind: "primary" (solid accent), "chip" (solid dark grey,
-- for secondary favorites), "outline" (accent ring), "danger" (red text on chip).
function IKST_Chrome.styleRoundedButton(btn, kind)
    if not btn then
        return
    end
    IKST_Chrome.suppressVanillaButtonPaint(btn)
    btn._ikstRoundKind = kind or "chip"
    local c = IKST_Chrome.colors
    local textCol = c.textPrimary
    if kind == "primary" then
        textCol = c.textOnAccent
    elseif kind == "outline" or kind == "ghost" then
        textCol = c.accent
    elseif kind == "danger" then
        textCol = c.danger
    end
    btn.textColor = { r = textCol.r, g = textCol.g, b = textCol.b, a = 1 }
    btn.render = IKST_Chrome.renderRoundedButton
end

function IKST_Chrome.renderRoundedButton(b)
    local c = IKST_Chrome.colors
    local kind = b._ikstRoundKind or "chip"
    local radius = math.min(IKST_Chrome.ROUND_RADIUS, math.floor(b.height / 2))
    local alpha = (b.enable == false) and 0.5 or 1
    local textCol = c.textPrimary
    if kind == "primary" then
        IKST_Chrome.drawRoundedFill(b, 0, 0, b.width, b.height, c.accent.r, c.accent.g, c.accent.b, alpha, radius)
        textCol = c.textOnAccent
    elseif kind == "outline" then
        IKST_Chrome.drawRoundedFill(b, 0, 0, b.width, b.height, c.accent.r, c.accent.g, c.accent.b, alpha, radius)
        IKST_Chrome.drawRoundedFill(b, 1, 1, b.width - 2, b.height - 2,
            c.bgApp.r, c.bgApp.g, c.bgApp.b, 1, math.max(1, radius - 1))
        textCol = c.accent
    elseif kind == "ghost" then
        textCol = c.accent
    elseif kind == "danger" then
        IKST_Chrome.drawRoundedFill(b, 0, 0, b.width, b.height, c.chipOff.r, c.chipOff.g, c.chipOff.b, alpha, radius)
        textCol = c.danger
    else
        IKST_Chrome.drawRoundedFill(b, 0, 0, b.width, b.height, c.chipOff.r, c.chipOff.g, c.chipOff.b, alpha, radius)
        textCol = c.textPrimary
    end
    if b.enable ~= false and type(b.isMouseOver) == "function" and b:isMouseOver() then
        IKST_Chrome.drawRoundedFill(b, 0, 0, b.width, b.height, 1, 1, 1, 0.10, radius)
    end
    IKST_Chrome.drawIconLabel(b, textCol)
end

-- Boolean toggle pill: solid orange when on, dark grey chip when off. Same
-- renderRoundedButton plumbing as styleRoundedButton, just a different kind
-- picked per-frame from real state instead of fixed at style time.
function IKST_Chrome.styleTogglePill(btn, on)
    if not btn then
        return
    end
    IKST_Chrome.styleRoundedButton(btn, on and "primary" or "chip")
end

-- Shared with drawSectionCard so callers can size a card's real ISPanel
-- height (header + content) before content exists to measure against.
function IKST_Chrome.sectionHeaderH()
    local pad = IKST_UI_Layout.s(14)
    local _, th = IKST_UI_Layout.textSize("Ag", UIFont.Small)
    return pad + th + IKST_UI_Layout.s(10)
end

-- Rounded section-card wrapper: card background + small icon + orange caps
-- label header (e.g. "SELF & MOVEMENT"). Returns the y to start drawing
-- content below the header.
function IKST_Chrome.drawSectionCard(panel, x, y, w, h, icon, title)
    if not panel or type(panel.drawRect) ~= "function" then
        return y + IKST_Chrome.sectionHeaderH()
    end
    local c = IKST_Chrome.colors
    IKST_Chrome.drawRoundedCard(panel, x, y, w, h, { shadow = false })
    local pad = IKST_UI_Layout.s(14)
    local textX = x + pad
    if icon then
        local tex = type(icon) == "string" and getTexture(icon) or icon
        if tex then
            local iconSz = IKST_UI_Layout.s(18)
            panel:drawTextureScaled(tex, textX, y + pad - 2, iconSz, iconSz, 1, 1, 1, 1)
            textX = textX + iconSz + IKST_UI_Layout.s(8)
        end
    end
    local header = string.upper(title or "")
    local tw, th = IKST_UI_Layout.textSize(header, UIFont.Small)
    panel:drawText(header, textX, y + pad, c.textPrimary.r, c.textPrimary.g, c.textPrimary.b, 1, UIFont.Small)
    panel:drawRect(textX, y + pad + th + 2, math.max(16, math.min(tw, 48)), 2, 1, c.accent.r, c.accent.g, c.accent.b)
    return y + IKST_Chrome.sectionHeaderH()
end

-- Real ISPanel with a rounded-card background + icon/title header, ready for
-- real ISUI children (buttons, labels) at local coordinates starting at the
-- returned contentY. Paint the card in prerender so children are not covered
-- by the 92% fill (B42 draws parent render over already-painted children).
function IKST_Chrome.newSectionCardPanel(x, y, w, h, icon, title)
    local card = ISPanel:new(x, y, w, h)
    card:initialise()
    card.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    card.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    card._ikstSectionIcon = icon
    card._ikstSectionTitle = title
    card.prerender = function(self)
        IKST_Chrome.drawSectionCard(self, 0, 0, self.width, self.height, self._ikstSectionIcon, self._ikstSectionTitle)
        ISPanel.prerender(self)
    end
    local contentY = IKST_Chrome.sectionHeaderH()
    return card, contentY
end

function IKST_Chrome.drawBadge(panel, x, y, label, kind)
    if not panel or type(panel.drawRect) ~= "function" then
        return 0
    end
    local c = IKST_Chrome.colors
    local fill = c.chipOff
    local text = c.textPrimary
    if kind == "success" then
        fill = c.success
        text = c.textOnAccent
    elseif kind == "warning" then
        fill = c.warning
        text = { r = 0.08, g = 0.08, b = 0.08, a = 1 }
    elseif kind == "error" or kind == "danger" then
        fill = c.danger
        text = c.textOnAccent
    elseif kind == "info" then
        fill = c.info
        text = c.textOnAccent
    elseif kind == "accent" then
        fill = c.accent
        text = c.textOnAccent
    end
    local padX = 8
    local tw, th = IKST_UI_Layout.textSize(label or "", UIFont.Small)
    local bh = math.max(IKST_UI_Layout.s(IKST_UI_Theme.space.statusChipH), th + 4)
    local bw = tw + (padX * 2)
    panel:drawRect(x, y, bw, bh, 0.92, fill.r, fill.g, fill.b)
    panel:drawText(label or "", x + padX, y + math.floor((bh - th) / 2), text.r, text.g, text.b, 1, UIFont.Small)
    return bw, bh
end

function IKST_Chrome.drawToggle(panel, x, y, on)
    if not panel or type(panel.drawRect) ~= "function" then
        return
    end
    local c = IKST_Chrome.colors
    local tw, th = IKST_UI_Layout.s(40), IKST_UI_Layout.s(22)
    if on then
        panel:drawRect(x, y, tw, th, 1, c.accent.r, c.accent.g, c.accent.b)
    else
        panel:drawRect(x, y, tw, th, 1, c.chipOff.r, c.chipOff.g, c.chipOff.b)
    end
    local knob = th - 4
    local kx = on and (x + tw - knob - 2) or (x + 2)
    panel:drawRect(kx, y + 2, knob, knob, 1, c.textPrimary.r, c.textPrimary.g, c.textPrimary.b)
    return tw, th
end

function IKST_Chrome.styleHeaderLabel(label)
    if not label then
        return
    end
    local c = IKST_Chrome.colors
    if label.setColor then
        label:setColor(c.textPrimary.r, c.textPrimary.g, c.textPrimary.b, 1)
    end
    label.r = c.textPrimary.r
    label.g = c.textPrimary.g
    label.b = c.textPrimary.b
    label.a = 1
end

-- Armed-mode status strip (no chrome STOP — tools already expose disarm in their actions).
function IKST_Chrome.drawArmedBanner(panel, y, modeText, _stopLabel)
    if not panel or type(panel.drawRect) ~= "function" then
        return 0
    end
    local c = IKST_Chrome.colors
    local h = (IKST_JobLayout and IKST_JobLayout.armedBannerHeight and IKST_JobLayout.armedBannerHeight(panel))
        or IKST_UI_Layout.s(28)
    if h <= 0 then
        return 0
    end
    panel:drawRect(0, y, panel.width, h, 0.95, c.bgCard.r, c.bgCard.g, c.bgCard.b)
    panel:drawRectBorder(0, y, panel.width, h, 1, c.accent.r, c.accent.g, c.accent.b)
    local grip = (IKST_JobLayout and IKST_JobLayout.RESIZE_GRIP) or 18
    local text = modeText or ""
    local maxTextW = math.max(40, panel.width - IKST_UI_Layout.s(24) - grip)
    if getTextManager():MeasureStringX(UIFont.Small, text) > maxTextW then
        while #text > 4 and getTextManager():MeasureStringX(UIFont.Small, text .. "…") > maxTextW do
            text = string.sub(text, 1, #text - 1)
        end
        text = text .. "…"
    end
    local _, th = IKST_UI_Layout.textSize(text, UIFont.Small)
    panel:drawText(text, IKST_UI_Layout.s(12), y + math.floor((h - th) / 2),
        c.textPrimary.r, c.textPrimary.g, c.textPrimary.b, 1, UIFont.Small)
    panel._armedStopHit = nil
    return h
end

-- Legacy no-op: hide any leftover chrome STOP button.
function IKST_Chrome.syncArmedStopButton(panel)
    if not panel then
        return
    end
    panel._armedStopHit = nil
    if panel.armedStopBtn then
        panel.armedStopBtn:setVisible(false)
    end
end

function IKST_Chrome.drawStatusStrip(panel, player, y)
    if not panel or type(panel.drawRect) ~= "function" then
        return 0
    end
    local c = IKST_Chrome.colors
    local stripH = IKST_JobLayout and IKST_JobLayout.STATUS_HEIGHT or IKST_UI_Layout.s(28)
    panel:drawRect(0, y, panel.width, stripH, 0.92, c.bgToolbar.r, c.bgToolbar.g, c.bgToolbar.b)
    local textX = IKST_UI_Layout.s(12)
    local homeBtn = panel.homeNavBtn
    if homeBtn and homeBtn:getIsVisible() then
        local btnRight = (homeBtn:getX() or 0) + (homeBtn:getWidth() or 0)
        textX = btnRight + IKST_UI_Layout.s(10)
    end
    local x = 0
    local py = 0
    local z = 0
    if player and type(player.getX) == "function" then
        x = player:getX() or 0
    end
    if player and type(player.getY) == "function" then
        py = player:getY() or 0
    end
    if player and type(player.getZ) == "function" then
        z = player:getZ() or 0
    end
    local cellX = math.floor(x / 300)
    local cellY = math.floor(py / 300)
    local line = string.format("%d, %d, %d  ·  Cell %d,%d", math.floor(x), math.floor(py), z, cellX, cellY)
    local _, lineH = IKST_UI_Layout.textSize(line, UIFont.Small)
    local textY = y + math.floor((stripH - lineH) / 2)
    panel:drawText(line, textX, textY, c.textMuted.r, c.textMuted.g, c.textMuted.b, 1, UIFont.Small)
    local roleKey = "IGUI_IKST_Player"
    local roleFallback = "Player"
    if player and IKST_Access and IKST_Access.isAdmin and IKST_Access.isAdmin(player) then
        roleKey = "IGUI_IKST_Admin"
        roleFallback = "Admin"
    end
    local role = IKST.text(roleKey, roleFallback)
    local tw, roleH = IKST_UI_Layout.textSize(role, UIFont.Small)
    local roleColor = roleFallback == "Admin" and c.accent or c.textMuted
    panel:drawText(role, panel.width - tw - IKST_UI_Layout.s(12), y + math.floor((stripH - roleH) / 2), roleColor.r, roleColor.g, roleColor.b, 1, UIFont.Small)
    return stripH
end

function IKST_Chrome.drawHintStrip(panel, text, y)
    if not panel or type(panel.drawRect) ~= "function" then
        return 0
    end
    local c = IKST_Chrome.colors
    local stripH = IKST_JobLayout and IKST_JobLayout.HINT_HEIGHT or IKST_UI_Layout.s(26)
    local grip = (IKST_JobLayout and IKST_JobLayout.RESIZE_GRIP) or 18
    panel:drawRect(0, y, panel.width, stripH, 0.88, c.bgToolbar.r, c.bgToolbar.g, c.bgToolbar.b)
    local tip = text or ""
    local maxW = math.max(40, panel.width - IKST_UI_Layout.s(24) - grip)
    if getTextManager and type(getTextManager) == "function" then
        local tm = getTextManager()
        if tm and type(tm.MeasureStringX) == "function" and tm:MeasureStringX(UIFont.Small, tip) > maxW then
            while #tip > 4 and tm:MeasureStringX(UIFont.Small, tip .. "…") > maxW do
                tip = string.sub(tip, 1, #tip - 1)
            end
            tip = tip .. "…"
        end
    end
    local _, th = IKST_UI_Layout.textSize(tip, UIFont.Small)
    local textY = y + math.max(2, math.floor((stripH - th) / 2))
    panel:drawText(tip, IKST_UI_Layout.s(12), textY, c.textMuted.r, c.textMuted.g, c.textMuted.b, c.textMuted.a, UIFont.Small)
    return stripH
end

function IKST_Chrome.drawTextButton(panel, x, y, w, h, label, primary)
    if not panel or type(panel.drawRect) ~= "function" then
        return
    end
    local c = IKST_Chrome.colors
    if primary then
        panel:drawRect(x, y, w, h, 1, c.accent.r, c.accent.g, c.accent.b)
        panel:drawText(label, x + 8, y + math.floor((h - 14) / 2), c.textOnAccent.r, c.textOnAccent.g, c.textOnAccent.b, 1, UIFont.Small)
    else
        panel:drawRect(x, y, w, h, 0.35, c.bgCard.r, c.bgCard.g, c.bgCard.b)
        panel:drawRectBorder(x, y, w, h, 1, c.accent.r, c.accent.g, c.accent.b)
        panel:drawText(label, x + 8, y + math.floor((h - 14) / 2), c.accent.r, c.accent.g, c.accent.b, 1, UIFont.Small)
    end
end

function IKST_Chrome.drawCompactToolTile(panel, x, y, w, h, title, active)
    if not panel or type(panel.drawRect) ~= "function" then
        return
    end
    local c = IKST_Chrome.colors
    if active then
        panel:drawRect(x, y, w, h, c.navPill.a, c.navPill.r, c.navPill.g, c.navPill.b)
        panel:drawRectBorder(x, y, w, h, 0.55, c.accent.r, c.accent.g, c.accent.b)
        panel:drawText(title, x + 10, y + math.floor((h - 14) / 2), c.accent.r, c.accent.g, c.accent.b, 1, UIFont.Small)
    else
        IKST_Chrome.drawCard(panel, x, y, w, h, { shadow = false, border = true })
        panel:drawText(title, x + 10, y + math.floor((h - 14) / 2), c.textPrimary.r, c.textPrimary.g, c.textPrimary.b, 1, UIFont.Small)
    end
end

function IKST_Chrome.fitText(text, font, maxW)
    text = tostring(text or "")
    font = font or UIFont.Small
    maxW = tonumber(maxW) or 0
    if maxW < 8 or not getTextManager then
        return text
    end
    local tm = getTextManager()
    if not tm or type(tm.MeasureStringX) ~= "function" then
        return text
    end
    if tm:MeasureStringX(font, text) <= maxW then
        return text
    end
    while #text > 1 and tm:MeasureStringX(font, text .. "…") > maxW do
        text = string.sub(text, 1, #text - 1)
    end
    return text .. "…"
end

function IKST_Chrome.wrapText(text, font, maxW, maxLines)
    text = tostring(text or "")
    font = font or UIFont.Small
    maxW = tonumber(maxW) or 0
    maxLines = tonumber(maxLines) or 3
    local lines = {}
    if maxW < 8 or text == "" then
        lines[1] = text
        return lines
    end
    local tm = getTextManager and getTextManager() or nil
    if not tm or type(tm.MeasureStringX) ~= "function" then
        lines[1] = text
        return lines
    end
    local words = {}
    for word in string.gmatch(text, "%S+") do
        words[#words + 1] = word
    end
    if #words == 0 then
        lines[1] = text
        return lines
    end
    local cur = ""
    local overflow = false
    for i = 1, #words do
        local try = (cur == "") and words[i] or (cur .. " " .. words[i])
        if tm:MeasureStringX(font, try) > maxW and cur ~= "" then
            lines[#lines + 1] = cur
            cur = words[i]
            if #lines >= maxLines then
                overflow = (i < #words) or (tm:MeasureStringX(font, cur) > maxW)
                break
            end
        else
            cur = try
        end
    end
    if #lines < maxLines and cur ~= "" then
        lines[#lines + 1] = cur
    elseif #lines >= maxLines and overflow then
        lines[maxLines] = IKST_Chrome.fitText(cur ~= "" and cur or (lines[maxLines] or ""), font, maxW)
    end
    if #lines > 0 then
        lines[#lines] = IKST_Chrome.fitText(lines[#lines], font, maxW)
    end
    return lines
end

function IKST_Chrome.drawJobCard(panel, x, y, w, h, title, desc, icon)
    if not panel or type(panel.drawRect) ~= "function" then
        return
    end
    local c = IKST_Chrome.colors
    IKST_Chrome.drawCard(panel, x, y, w, h, { accentLeft = true })
    local pad = math.max(10, math.floor(math.min(w, h) * 0.08))
    if pad > IKST_UI_Layout.s(16) then
        pad = IKST_UI_Layout.s(16)
    end
    local textX = x + pad
    local textRight = x + w - pad
    local maxTextW = math.max(24, textRight - textX)
    local titleY = y + pad
    if icon then
        local tex = icon
        if type(icon) == "string" then
            tex = getTexture(icon)
        end
        if tex then
            local iconSz = math.min(IKST_UI_Layout.s(22), h - (pad * 2))
            panel:drawTextureScaled(tex, x + pad, y + pad, iconSz, iconSz, 1, 1, 1, 1)
            textX = x + pad + iconSz + math.max(6, math.floor(pad * 0.6))
            maxTextW = math.max(24, textRight - textX)
        end
    end
    local titleFont = UIFont.Medium
    local descFont = UIFont.Small
    local titleLine = IKST_Chrome.fitText(title or "", titleFont, maxTextW)
    panel:drawText(titleLine, textX, titleY, c.textPrimary.r, c.textPrimary.g, c.textPrimary.b, 1, titleFont)
    local _, titleH = IKST_UI_Layout.textSize(titleLine, titleFont)
    local descY = titleY + titleH + math.max(4, math.floor(pad * 0.35))
    local descBudget = (y + h - pad) - descY
    local lineH = select(2, IKST_UI_Layout.textSize("Ag", descFont)) or 14
    local maxLines = math.max(1, math.floor(descBudget / math.max(12, lineH)))
    local wrapped = IKST_Chrome.wrapText(desc or "", descFont, maxTextW, maxLines)
    for i = 1, #wrapped do
        local ly = descY + ((i - 1) * lineH)
        if ly + lineH <= y + h - pad + 1 then
            panel:drawText(wrapped[i], textX, ly, c.textMuted.r, c.textMuted.g, c.textMuted.b, 1, descFont)
        end
    end
end

function IKST_Chrome.drawStatCard(panel, x, y, w, h, title, value, subtitle)
    if not panel or type(panel.drawRect) ~= "function" then
        return
    end
    local c = IKST_Chrome.colors
    local pad = IKST_UI_Layout.s(16)
    IKST_Chrome.drawRoundedCard(panel, x, y, w, h, { shadow = false })
    panel:drawText(string.upper(title or ""), x + pad, y + pad, c.accent.r, c.accent.g, c.accent.b, 1, UIFont.Small)
    panel:drawText(tostring(value or ""), x + pad, y + pad + 20, c.textPrimary.r, c.textPrimary.g, c.textPrimary.b, 1, UIFont.Large)
    if subtitle and subtitle ~= "" then
        panel:drawText(subtitle, x + pad, y + h - pad - 14, c.textMuted.r, c.textMuted.g, c.textMuted.b, 1, UIFont.Small)
    end
end

function IKST_Chrome.drawCategoryHeader(panel, x, y, title, subtitle)
    if not panel or type(panel.drawText) ~= "function" then
        return
    end
    local c = IKST_Chrome.colors
    panel:drawText(title or "", x, y, c.textPrimary.r, c.textPrimary.g, c.textPrimary.b, 1, UIFont.Medium)
    if subtitle and subtitle ~= "" then
        panel:drawText(subtitle, x, y + 18, c.textMuted.r, c.textMuted.g, c.textMuted.b, 1, UIFont.Small)
    end
end

function IKST_Chrome.drawSidebarBg(panel, x, y, w, h)
    if not panel or type(panel.drawRect) ~= "function" then
        return
    end
    local c = IKST_Chrome.colors
    panel:drawRect(x, y, w, h, c.bgSidebar.a, c.bgSidebar.r, c.bgSidebar.g, c.bgSidebar.b)
    panel:drawRect(x + w - 1, y, 1, h, 0.5, c.divider.r, c.divider.g, c.divider.b)
end

function IKST_Chrome.clampPanelPosition(panel)
    if not panel or type(panel.setX) ~= "function" then
        return
    end
    local margin = IKST_UI_Layout.s(8)
    local sw = getCore():getScreenWidth()
    local sh = getCore():getScreenHeight()
    panel:setX(math.max(margin, math.min(panel:getX(), sw - panel.width - margin)))
    panel:setY(math.max(margin, math.min(panel:getY(), sh - panel.height - margin)))
end
