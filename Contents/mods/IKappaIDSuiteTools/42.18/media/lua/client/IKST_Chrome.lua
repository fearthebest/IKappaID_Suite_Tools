if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Access"

IKST_Chrome = IKST_Chrome or {}

-- Shared palette with IKappaID Phone Shop (dark UI, orange accents). Values 0–1 RGBA.
IKST_Chrome.colors = {
    bgApp = { r = 0.10, g = 0.10, b = 0.10, a = 0.98 },
    bgCard = { r = 0.17, g = 0.17, b = 0.17, a = 1.00 },
    bgCardHover = { r = 0.22, g = 0.22, b = 0.22, a = 1.00 },
    bgToolbar = { r = 0.23, g = 0.23, b = 0.23, a = 0.95 },
    chipOff = { r = 0.24, g = 0.24, b = 0.24, a = 1.00 },
    accent = { r = 1.00, g = 0.40, b = 0.00, a = 1.00 },
    accentDim = { r = 0.75, g = 0.30, b = 0.00, a = 0.55 },
    textPrimary = { r = 0.95, g = 0.95, b = 0.95, a = 1.00 },
    textMuted = { r = 0.54, g = 0.54, b = 0.54, a = 1.00 },
    textOnAccent = { r = 0.95, g = 0.95, b = 0.95, a = 1.00 },
    danger = { r = 0.90, g = 0.30, b = 0.25, a = 1.00 },
    success = { r = 0.45, g = 0.85, b = 0.50, a = 1.00 },
    disabled = { r = 0.24, g = 0.24, b = 0.24, a = 0.60 },
    divider = { r = 0.23, g = 0.23, b = 0.23, a = 1.00 },
}

function IKST_Chrome.rgba(c, alpha)
    if not c then
        return 1, 1, 1, 1
    end
    return c.r, c.g, c.b, alpha or c.a or 1
end

function IKST_Chrome.applyPanelColors(panel)
    local c = IKST_Chrome.colors
    panel.backgroundColor = { r = c.bgApp.r, g = c.bgApp.g, b = c.bgApp.b, a = c.bgApp.a }
    panel.borderColor = { r = c.divider.r, g = c.divider.g, b = c.divider.b, a = 0.9 }
end

function IKST_Chrome.stylePrimaryButton(btn)
    local c = IKST_Chrome.colors
    btn.backgroundColor = { r = c.accent.r, g = c.accent.g, b = c.accent.b, a = 1 }
    btn.borderColor = { r = c.accent.r, g = c.accent.g, b = c.accent.b, a = 1 }
    btn.textColor = { r = c.textOnAccent.r, g = c.textOnAccent.g, b = c.textOnAccent.b, a = 1 }
end

function IKST_Chrome.styleSecondaryButton(btn)
    local c = IKST_Chrome.colors
    btn.backgroundColor = { r = c.bgCard.r, g = c.bgCard.g, b = c.bgCard.b, a = 1 }
    btn.borderColor = { r = c.divider.r, g = c.divider.g, b = c.divider.b, a = 1 }
    btn.textColor = { r = c.textPrimary.r, g = c.textPrimary.g, b = c.textPrimary.b, a = 1 }
end

function IKST_Chrome.styleChipButton(btn, active)
    if active then
        IKST_Chrome.stylePrimaryButton(btn)
    else
        local c = IKST_Chrome.colors
        btn.backgroundColor = { r = c.chipOff.r, g = c.chipOff.g, b = c.chipOff.b, a = 1 }
        btn.borderColor = { r = c.divider.r, g = c.divider.g, b = c.divider.b, a = 1 }
        btn.textColor = { r = c.textPrimary.r, g = c.textPrimary.g, b = c.textPrimary.b, a = 1 }
    end
end

function IKST_Chrome.styleModeButton(btn, active)
    IKST_Chrome.styleChipButton(btn, active)
end

function IKST_Chrome.drawAccentBar(panel, y, h)
    local c = IKST_Chrome.colors
    panel:drawRect(0, y or 0, panel.width, h or 3, c.accent.a, c.accent.r, c.accent.g, c.accent.b)
end

function IKST_Chrome.drawStatusStrip(panel, player, y)
    local c = IKST_Chrome.colors
    local stripH = 24
    panel:drawRect(0, y, panel.width, stripH, 0.9, c.bgToolbar.r, c.bgToolbar.g, c.bgToolbar.b)
    local textX = 12
    if panel.view and IKST_HubNav and not IKST_HubNav.isHomeView(panel.view) then
        textX = 66
    end
    local x = player and player:getX() or 0
    local py = player and player:getY() or 0
    local z = player and player:getZ() or 0
    local cellX = math.floor(x / 300)
    local cellY = math.floor(py / 300)
    local line = string.format("%d, %d, %d  ·  Cell %d,%d", math.floor(x), math.floor(py), z, cellX, cellY)
    panel:drawText(line, textX, y + 5, c.textPrimary.r, c.textPrimary.g, c.textPrimary.b, c.textPrimary.a, UIFont.Small)
    local roleKey = "IGUI_IKST_Player"
    local roleFallback = "Player"
    if player and IKST_Access and IKST_Access.isAdmin(player) then
        roleKey = "IGUI_IKST_Admin"
        roleFallback = "Admin"
    end
    local role = IKST.text(roleKey, roleFallback)
    local tw = getTextManager():MeasureStringX(UIFont.Small, role)
    local roleColor = roleFallback == "Admin" and c.accent or c.textMuted
    panel:drawText(role, panel.width - tw - 12, y + 5, roleColor.r, roleColor.g, roleColor.b, 1, UIFont.Small)
    return stripH
end

function IKST_Chrome.drawHintStrip(panel, text, y)
    local c = IKST_Chrome.colors
    local stripH = 22
    panel:drawRect(0, y, panel.width, stripH, 0.85, c.bgToolbar.r, c.bgToolbar.g, c.bgToolbar.b)
    panel:drawText(text, 12, y + 4, c.textMuted.r, c.textMuted.g, c.textMuted.b, c.textMuted.a, UIFont.Small)
    return stripH
end

function IKST_Chrome.drawTextButton(panel, x, y, w, h, label, primary)
    local c = IKST_Chrome.colors
    if primary then
        panel:drawRect(x, y, w, h, 1, c.accent.r, c.accent.g, c.accent.b)
        panel:drawText(label, x + 8, y + 4, c.textOnAccent.r, c.textOnAccent.g, c.textOnAccent.b, 1, UIFont.Small)
    else
        panel:drawRect(x, y, w, h, c.bgCard.a, c.bgCard.r, c.bgCard.g, c.bgCard.b)
        panel:drawRectBorder(x, y, w, h, 1, c.divider.r, c.divider.g, c.divider.b)
        panel:drawText(label, x + 8, y + 4, c.textPrimary.r, c.textPrimary.g, c.textPrimary.b, 1, UIFont.Small)
    end
end

function IKST_Chrome.drawCompactToolTile(panel, x, y, w, h, title, active)
    local c = IKST_Chrome.colors
    if active then
        panel:drawRect(x, y, w, h, 1, c.accent.r, c.accent.g, c.accent.b)
        panel:drawText(title, x + 8, y + math.floor((h - 14) / 2), c.textOnAccent.r, c.textOnAccent.g, c.textOnAccent.b, 1, UIFont.Small)
    else
        panel:drawRect(x, y, w, h, c.bgCard.a, c.bgCard.r, c.bgCard.g, c.bgCard.b)
        panel:drawRectBorder(x, y, w, h, 1, c.divider.r, c.divider.g, c.divider.b)
        panel:drawRect(x, y, 3, h, 1, c.accent.r, c.accent.g, c.accent.b)
        panel:drawText(title, x + 10, y + math.floor((h - 14) / 2), c.textPrimary.r, c.textPrimary.g, c.textPrimary.b, 1, UIFont.Small)
    end
end

function IKST_Chrome.drawJobCard(panel, x, y, w, h, title, desc, icon)
    local c = IKST_Chrome.colors
    panel:drawRect(x, y, w, h, c.bgCard.a, c.bgCard.r, c.bgCard.g, c.bgCard.b)
    panel:drawRectBorder(x, y, w, h, 1, c.divider.r, c.divider.g, c.divider.b)
    panel:drawRect(x, y, 4, h, 1, c.accent.r, c.accent.g, c.accent.b)
    local textX = x + 12
    if icon then
        local tex = icon
        if type(icon) == "string" then
            tex = getTexture(icon)
        end
        if tex then
            panel:drawTextureScaled(tex, x + 12, y + 8, 20, 20, 1, 1, 1, 1)
            textX = x + 40
        end
    end
    panel:drawText(title, textX, y + 8, c.textPrimary.r, c.textPrimary.g, c.textPrimary.b, 1, UIFont.Small)
    panel:drawText(desc, textX, y + 28, c.textMuted.r, c.textMuted.g, c.textMuted.b, 1, UIFont.Small)
end

function IKST_Chrome.drawCategoryHeader(panel, x, y, title, subtitle)
    local c = IKST_Chrome.colors
    panel:drawText(title, x, y, c.accent.r, c.accent.g, c.accent.b, 1, UIFont.Medium)
    if subtitle and subtitle ~= "" then
        panel:drawText(subtitle, x, y + 17, c.textMuted.r, c.textMuted.g, c.textMuted.b, 1, UIFont.Small)
    end
end

function IKST_Chrome.clampPanelPosition(panel)
    local sw = getCore():getScreenWidth()
    local sh = getCore():getScreenHeight()
    panel:setX(math.max(8, math.min(panel:getX(), sw - panel.width - 8)))
    panel:setY(math.max(8, math.min(panel:getY(), sh - panel.height - 8)))
end
