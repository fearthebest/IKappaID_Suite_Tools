-- IKST dashboard home - upper half server info, lower half 4x3 function grid (IKappaID UI).
if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKappaID_UI/IKUI_Config"
require "IKappaID_UI/IKUI_Chrome"
require "IKappaID_UI/IKUI_Chrome"
require "IKST_ClaimIcons"
require "IKST_DashboardQuick"

IKST_DashboardUI = IKST_DashboardUI or {}

-- Fixed layout constants (user spec: 20px inset, equal cell division).
IKST_DashboardUI.PAD = 20
IKST_DashboardUI.STAT_COLS = 2
IKST_DashboardUI.STAT_ROWS = 3
IKST_DashboardUI.FUNC_COLS = 3
IKST_DashboardUI.FUNC_ROWS = 3
IKST_DashboardUI.QUICK_COLS = 3
IKST_DashboardUI.QUICK_ROWS = 2
IKST_DashboardUI.LOWER_ROWS = IKST_DashboardUI.FUNC_ROWS + IKST_DashboardUI.QUICK_ROWS
IKST_DashboardUI.HEADER_H = 40

IKST_DashboardUI.STATS = {
    { id = "online", titleKey = "IGUI_IKST_Dashboard_Stat_Online", title = "Online players" },
    { id = "safehouse", titleKey = "IGUI_IKST_Dashboard_Stat_Safehouse", title = "Safehouse claims" },
    { id = "vehicle", titleKey = "IGUI_IKST_Dashboard_Stat_Vehicle", title = "Vehicle claims" },
    { id = "uptime", titleKey = "IGUI_IKST_Dashboard_Stat_Uptime", title = "Server uptime" },
    { id = "admins", titleKey = "IGUI_IKST_Dashboard_Stat_Admins", title = "Active admins" },
    { id = "help", titleKey = "IGUI_IKST_Dashboard_Stat_Help", title = "Pending help requests" },
}

function IKST_DashboardUI.contentTop(panel)
    if IKST_HubNav and type(IKST_HubNav.homeContentY) == "function" then
        return IKST_HubNav.homeContentY(panel)
    end
    if panel and panel.titleBarHeight and type(panel.titleBarHeight) == "function" then
        return panel:titleBarHeight() + 2 + IKUI_Config.statusStripH + 4
    end
    return IKUI_Config.headerH
end

function IKST_DashboardUI.metrics(panel)
    local top = IKST_DashboardUI.contentTop(panel)
    local pad = IKST_DashboardUI.PAD
    local hint = IKUI_Config.hintStripH
    local grip = IKUI_Config.resizeGrip
    local bodyBottom = panel.height - hint - grip
    local areaX = pad
    local areaY = top + pad
    local areaW = math.max(120, panel.width - (pad * 2))
    local areaH = math.max(200, bodyBottom - areaY - pad)
    local midY = areaY + math.floor(areaH / 2)
    return {
        pad = pad,
        top = top,
        areaX = areaX,
        areaY = areaY,
        areaW = areaW,
        areaH = areaH,
        midY = midY,
        infoX = areaX,
        infoY = areaY,
        infoW = areaW,
        infoH = midY - areaY,
        funcX = areaX,
        funcY = midY,
        funcW = areaW,
        funcH = areaY + areaH - midY,
    }
end

function IKST_DashboardUI.sections(panel)
    local m = IKST_DashboardUI.metrics(panel)
    local headerH = IKST_DashboardUI.HEADER_H
    local statsY = m.infoY + headerH
    local statsH = math.max(0, m.midY - statsY)
    local statCellW = math.floor(m.infoW / IKST_DashboardUI.STAT_COLS)
    local statCellH = math.floor(statsH / IKST_DashboardUI.STAT_ROWS)
    local lowerRowH = math.floor(m.funcH / IKST_DashboardUI.LOWER_ROWS)
    local funcGridH = lowerRowH * IKST_DashboardUI.FUNC_ROWS
    local funcCellW = math.floor(m.funcW / IKST_DashboardUI.FUNC_COLS)
    local funcCellH = lowerRowH
    local quickY = m.funcY + funcGridH
    local quickH = lowerRowH * IKST_DashboardUI.QUICK_ROWS
    local quickCellW = funcCellW
    local quickCellH = lowerRowH
    return {
        m = m,
        headerH = headerH,
        headerY = m.infoY,
        statsY = statsY,
        statCellW = statCellW,
        statCellH = statCellH,
        funcGridH = funcGridH,
        funcCellW = funcCellW,
        funcCellH = funcCellH,
        quickY = quickY,
        quickH = quickH,
        quickCellW = quickCellW,
        quickCellH = quickCellH,
    }
end

function IKST_DashboardUI.drawGridLines(panel, x, y, w, h, cols, rows)
    if not panel or cols < 1 or rows < 1 then
        return
    end
    local c = IKUI_Chrome.colors.divider
    local a = 0.85
    local cellW = w / cols
    local cellH = h / rows
    for col = 1, cols - 1 do
        local lx = math.floor(x + (col * cellW))
        panel:drawRect(lx, y, 1, h, a, c.r, c.g, c.b)
    end
    for row = 1, rows - 1 do
        local ly = math.floor(y + (row * cellH))
        panel:drawRect(x, ly, w, 1, a, c.r, c.g, c.b)
    end
    panel:drawRectBorder(x, y, w, h, 0.9, c.r, c.g, c.b)
end

function IKST_DashboardUI.drawRegionBg(panel, x, y, w, h)
    local c = IKUI_Chrome.colors
    panel:drawRect(x, y, w, h, c.bgSurface.a or 0.35, c.bgSurface.r, c.bgSurface.g, c.bgSurface.b)
end

function IKST_DashboardUI.statAt(sec, index)
    local col = (index - 1) % IKST_DashboardUI.STAT_COLS
    local row = math.floor((index - 1) / IKST_DashboardUI.STAT_COLS)
    local x = sec.m.infoX + (col * sec.statCellW)
    local y = sec.statsY + (row * sec.statCellH)
    return x, y, sec.statCellW, sec.statCellH
end

function IKST_DashboardUI.funcCellAt(sec, col, row)
    local x = sec.m.funcX + (col * sec.funcCellW)
    local y = sec.m.funcY + (row * sec.funcCellH)
    return x, y, sec.funcCellW, sec.funcCellH
end

function IKST_DashboardUI.quickCellAt(sec, col, row)
    local x = sec.m.funcX + (col * sec.quickCellW)
    local y = sec.quickY + (row * sec.quickCellH)
    return x, y, sec.quickCellW, sec.quickCellH
end

function IKST_DashboardUI.workspaceClickFn(panel, ws)
    return function()
        if ws._missingPlugin then
            if IKST.notify and panel.player then
                IKST.notify(panel.player, IKST.text("IGUI_IKST_Plugin_Required", "Requires addon mod"), false)
            end
            return
        end
        panel:enterNav(ws.id, IKST_HubNav.defaultTool(ws.id))
    end
end

function IKST_DashboardUI.buildHeader(panel, sec)
    local m = sec.m
    local refreshLabel = IKST.text("IGUI_IKST_Dashboard_Refresh", "Refresh")
    local btnH = math.max(26, sec.headerH - 8)
    local refreshW = IKUI_Config.buttonWidth(refreshLabel, UIFont.Small, 74)
    local btnY = sec.headerY + math.floor((sec.headerH - btnH) / 2)
    local refreshX = m.infoX + m.infoW - refreshW - 4

    local refreshBtn = IKUI_Chrome.newActionButton(refreshX, btnY, refreshW, btnH, refreshLabel, panel, function()
        if IKST_Dashboard and type(IKST_Dashboard.request) == "function" then
            IKST_Dashboard.request(panel.player)
        elseif type(panel.refreshJobUI) == "function" then
            panel:refreshJobUI(true)
        end
    end, "outline")
    panel:addHomeWidget(refreshBtn)
end

function IKST_DashboardUI.buildFunctionGrid(panel, sec)
    local workspaces = IKST_HubNav.visibleWorkspaces(panel.player)
    local inner = 6
    local idx = 0
    for row = 0, IKST_DashboardUI.FUNC_ROWS - 1 do
        for col = 0, IKST_DashboardUI.FUNC_COLS - 1 do
            idx = idx + 1
            local ws = workspaces[idx]
            if ws then
                local cx, cy, cw, ch = IKST_DashboardUI.funcCellAt(sec, col, row)
                local btn = IKUI_Chrome.newActionButton(cx + inner, cy + inner, cw - (inner * 2), ch - (inner * 2),
                    IKST_HubNav.modeLabel(ws), panel, IKST_DashboardUI.workspaceClickFn(panel, ws), "chip")
                if ws._missingPlugin then
                    btn.enable = false
                end
                local tip = IKST_HubNav.modeLabel(ws)
                if ws.descKey or ws.desc then
                    tip = tip .. " <LINE> " .. IKST.text(ws.descKey, ws.desc or "")
                end
                if IKUI_Chrome.setTooltip then
                    IKUI_Chrome.setTooltip(btn, tip)
                end
                if IKST_ClaimIcons and type(IKST_ClaimIcons.applyButtonIcon) == "function" and ws.icon then
                    IKST_ClaimIcons.applyButtonIcon(btn, ws.icon)
                end
                panel:addHomeWidget(btn)
            end
        end
    end
end

function IKST_DashboardUI.buildQuickRow(panel, sec)
    local slots = IKST_DashboardQuick.loadSlots()
    local inner = 6
    for row = 0, IKST_DashboardUI.QUICK_ROWS - 1 do
        for col = 0, IKST_DashboardUI.QUICK_COLS - 1 do
            local slotIndex = (row * IKST_DashboardUI.QUICK_COLS) + col + 1
            local cx, cy, cw, ch = IKST_DashboardUI.quickCellAt(sec, col, row)
            local entryId = slots[slotIndex]
            local label = IKST_DashboardQuick.labelFor(entryId)
            local btn = IKUI_Chrome.newActionButton(cx + inner, cy + inner, cw - (inner * 2), ch - (inner * 2),
                label, panel, function()
                    IKST_DashboardQuick.run(panel, slotIndex)
                end, (entryId and entryId ~= "") and "primary" or "outline")
            if IKUI_Chrome.setTooltip then
                IKUI_Chrome.setTooltip(btn, label)
            end
            btn._ikstQuickSlot = slotIndex
            btn.onMouseDown = function(b, mx, my)
                return IKST_DashboardQuick.onSlotMouseDown(panel, b._ikstQuickSlot, mx, my)
            end
            panel:addHomeWidget(btn)
        end
    end
end

function IKST_DashboardUI.build(panel)
    if not panel then
        return
    end
    if IKST_Dashboard and type(IKST_Dashboard.request) == "function" and not IKST_Dashboard.snapshot then
        IKST_Dashboard.request(panel.player)
    end
    local sec = IKST_DashboardUI.sections(panel)
    IKST_DashboardUI.buildHeader(panel, sec)
    IKST_DashboardUI.buildFunctionGrid(panel, sec)
    IKST_DashboardUI.buildQuickRow(panel, sec)
end

function IKST_DashboardUI.drawStatCell(panel, x, y, w, h, stat)
    local c = IKUI_Chrome.colors
    local pad = 10
    local value = "-"
    local caption = IKST.text("IGUI_IKST_Dashboard_Stat_Placeholder", "Tap Refresh")
    if IKST_Dashboard and type(IKST_Dashboard.statLines) == "function" then
        value, caption = IKST_Dashboard.statLines(stat.id)
    end
    panel:drawText(string.upper(IKST.text(stat.titleKey, stat.title)),
        x + pad, y + pad, c.accent.r, c.accent.g, c.accent.b, 1, UIFont.Small)
    panel:drawText(tostring(value or "-"), x + pad, y + pad + 18,
        c.textPrimary.r, c.textPrimary.g, c.textPrimary.b, 1, UIFont.Large)
    if caption and caption ~= "" then
        panel:drawText(caption, x + pad, y + h - pad - 14,
            c.textMuted.r, c.textMuted.g, c.textMuted.b, 1, UIFont.Small)
    end
end

function IKST_DashboardUI.drawStats(panel, sec)
    for i, stat in ipairs(IKST_DashboardUI.STATS) do
        local x, y, w, h = IKST_DashboardUI.statAt(sec, i)
        IKST_DashboardUI.drawStatCell(panel, x, y, w, h, stat)
    end
end

function IKST_DashboardUI.draw(panel, _bodyY)
    if not panel then
        return
    end
    local sec = IKST_DashboardUI.sections(panel)
    local m = sec.m
    local cc = IKUI_Chrome.colors

    IKST_DashboardUI.drawRegionBg(panel, m.infoX, m.infoY, m.infoW, m.infoH)
    IKST_DashboardUI.drawRegionBg(panel, m.funcX, m.funcY, m.funcW, m.funcH)

    local title = IKST.text("IGUI_IKST_Nav_Dashboard", "Dashboard")
    local font = UIFont.Large
    local tw, th = IKUI_Config.textSize(title, font)
    local groupX = m.infoX + math.floor((m.infoW - tw) / 2)
    local textY = sec.headerY + math.floor((sec.headerH - th) / 2)
    panel:drawText(title, groupX, textY,
        cc.textPrimary.r, cc.textPrimary.g, cc.textPrimary.b, 1, font)

    local statsH = m.midY - sec.statsY
    IKST_DashboardUI.drawGridLines(panel, m.infoX, sec.statsY, m.infoW, statsH,
        IKST_DashboardUI.STAT_COLS, IKST_DashboardUI.STAT_ROWS)
    IKST_DashboardUI.drawStats(panel, sec)

    panel:drawRect(m.infoX, m.midY - 1, m.infoW, 2, cc.accent.a, cc.accent.r, cc.accent.g, cc.accent.b)

    IKST_DashboardUI.drawGridLines(panel, m.funcX, m.funcY, m.funcW, sec.funcGridH,
        IKST_DashboardUI.FUNC_COLS, IKST_DashboardUI.FUNC_ROWS)

    panel:drawRect(m.funcX, sec.quickY - 1, m.funcW, 1, cc.divider.a, cc.divider.r, cc.divider.g, cc.divider.b)

    IKST_DashboardUI.drawGridLines(panel, m.funcX, sec.quickY, m.funcW, sec.quickH,
        IKST_DashboardUI.QUICK_COLS, IKST_DashboardUI.QUICK_ROWS)
end

function IKST_DashboardUI.dashboardMetrics(panel)
    return IKST_DashboardUI.metrics(panel)
end

function IKST_DashboardUI.dashboardSections(panel)
    return IKST_DashboardUI.sections(panel)
end
