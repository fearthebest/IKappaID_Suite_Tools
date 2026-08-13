-- IKappaID visual tokens for IKST client UI (B42).
-- Palette and spacing only; no gameplay.
if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

IKST_UI_Theme = IKST_UI_Theme or {}

-- Dark + orange palette (0–1 RGBA). Glass surface uses ~85% opacity.
IKST_UI_Theme.colors = {
    bgApp = { r = 0.06, g = 0.06, b = 0.07, a = 0.98 },           -- #0F0F12
    bgSurface = { r = 0.10, g = 0.11, b = 0.12, a = 0.85 },        -- #1A1B1E glass
    bgCard = { r = 0.10, g = 0.11, b = 0.12, a = 0.92 },
    bgCardHover = { r = 0.14, g = 0.14, b = 0.16, a = 0.95 },
    bgToolbar = { r = 0.10, g = 0.11, b = 0.12, a = 0.90 },
    bgSidebar = { r = 0.08, g = 0.08, b = 0.09, a = 0.96 },
    bgInput = { r = 0.08, g = 0.08, b = 0.09, a = 1.00 },
    chipOff = { r = 0.14, g = 0.14, b = 0.16, a = 1.00 },
    navPill = { r = 1.00, g = 0.42, b = 0.21, a = 0.22 },
    shadow = { r = 0.00, g = 0.00, b = 0.00, a = 0.45 },
    accent = { r = 1.00, g = 0.42, b = 0.21, a = 1.00 },           -- #FF6B35
    accentDim = { r = 1.00, g = 0.42, b = 0.21, a = 0.45 },
    accentHover = { r = 1.00, g = 0.50, b = 0.30, a = 1.00 },
    textPrimary = { r = 0.96, g = 0.96, b = 0.97, a = 1.00 },      -- #F5F5F7
    textMuted = { r = 0.56, g = 0.56, b = 0.58, a = 1.00 },        -- #8E8E93
    textOnAccent = { r = 0.96, g = 0.96, b = 0.97, a = 1.00 },
    success = { r = 0.19, g = 0.82, b = 0.35, a = 1.00 },          -- #30D158
    warning = { r = 1.00, g = 0.62, b = 0.04, a = 1.00 },          -- #FF9F0A
    danger = { r = 1.00, g = 0.27, b = 0.23, a = 1.00 },           -- #FF453A
    info = { r = 0.04, g = 0.52, b = 1.00, a = 1.00 },             -- #0A84FF
    disabled = { r = 0.24, g = 0.24, b = 0.26, a = 0.55 },
    divider = { r = 0.18, g = 0.18, b = 0.20, a = 0.80 },
}

-- Layout tokens from handoff (px at 1.0 uiScale).
IKST_UI_Theme.space = {
    cornerRadius = 18,
    padding = 24,
    gap = 16,
    sidebarWidth = 280,
    screenMargin = 28,
    buttonMinH = 44,
    buttonPadX = 24,
    cardShadow = 4,
    navItemH = 44,
    statusChipH = 22,
}

IKST_UI_Theme.fonts = {
    h1 = UIFont.Large,
    h2 = UIFont.Medium,
    body = UIFont.Small,
    caption = UIFont.Small,
}

function IKST_UI_Theme.rgba(c, alpha)
    if not c then
        return 1, 1, 1, 1
    end
    return c.r, c.g, c.b, alpha or c.a or 1
end
