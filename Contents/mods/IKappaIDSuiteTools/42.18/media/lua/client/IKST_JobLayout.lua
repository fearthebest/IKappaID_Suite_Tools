if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"

IKST_JobLayout = IKST_JobLayout or {}

IKST_JobLayout.STATUS_HEIGHT = 24
IKST_JobLayout.TAB_BAR_HEIGHT = 0
IKST_JobLayout.SIDEBAR_W = 112
IKST_JobLayout.Q1_W = 112
IKST_JobLayout.Q2_H = 80
IKST_JobLayout.Q4_H = 96
IKST_JobLayout.MARGIN = 12
IKST_JobLayout.LOG_HEIGHT = 96
IKST_JobLayout.HINT_HEIGHT = 22
IKST_JobLayout.HEADER_ROW = 28
IKST_JobLayout.MIN_WIDTH = 440
IKST_JobLayout.MIN_HEIGHT = 400
-- Keep bottom-right clear for ISCollapsableWindow resize grip
IKST_JobLayout.RESIZE_GRIP = 18

function IKST_JobLayout.contentWidth(panel)
    return math.max(120, (panel.width or 520) - (IKST_JobLayout.MARGIN * 2))
end

function IKST_JobLayout.contentRight(panel)
    return IKST_JobLayout.MARGIN + IKST_JobLayout.contentWidth(panel)
end

function IKST_JobLayout.q1Rect(panel)
    local top = IKST_JobLayout.layerTop(panel)
    local h = panel.height - top - IKST_JobLayout.HINT_HEIGHT - IKST_JobLayout.RESIZE_GRIP
    return 0, 0, IKST_JobLayout.Q1_W, h
end

function IKST_JobLayout.q2Rect(panel)
    local x = IKST_JobLayout.Q1_W
    local w = panel.width - x - IKST_JobLayout.RESIZE_GRIP
    return x, 0, w, IKST_JobLayout.Q2_H
end

function IKST_JobLayout.q3Rect(panel)
    local x = IKST_JobLayout.Q1_W
    local y = IKST_JobLayout.Q2_H
    local w = panel.width - x - IKST_JobLayout.RESIZE_GRIP
    local h = panel.height - IKST_JobLayout.layerTop(panel) - y - IKST_JobLayout.Q4_H - IKST_JobLayout.HINT_HEIGHT - IKST_JobLayout.RESIZE_GRIP
    return x, y, w, h
end

function IKST_JobLayout.q4Rect(panel)
    local x = IKST_JobLayout.Q1_W
    local w = panel.width - x - IKST_JobLayout.RESIZE_GRIP
    local h = IKST_JobLayout.Q4_H
    local y = panel.height - IKST_JobLayout.layerTop(panel) - h - IKST_JobLayout.HINT_HEIGHT - IKST_JobLayout.RESIZE_GRIP
    return x, y, w, h
end

function IKST_JobLayout.clampWidth(panel, x, w)
    local maxW = IKST_JobLayout.contentRight(panel) - x
    if w > maxW then
        return math.max(40, maxW)
    end
    return w
end

function IKST_JobLayout.logRect(panel)
    if panel.q4Panel then
        return 0, 0, panel.q4Panel:getWidth(), panel.q4Panel:getHeight()
    end
    local h = panel.logHeight or IKST_JobLayout.LOG_HEIGHT
    local hint = panel.hintHeight or IKST_JobLayout.HINT_HEIGHT
    local y = panel.height - hint - h - 6
    return IKST_JobLayout.MARGIN, y, IKST_JobLayout.contentWidth(panel), h
end

function IKST_JobLayout.chromeContentTop(panel)
    return panel:titleBarHeight() + 2 + IKST_JobLayout.STATUS_HEIGHT + 4
end

function IKST_JobLayout.layerTop(panel)
    return IKST_JobLayout.chromeContentTop(panel)
end

function IKST_JobLayout.toLayerY(panel, absY)
    return absY - IKST_JobLayout.layerTop(panel)
end

function IKST_JobLayout.relayoutJobLayer(panel)
    if not panel or not panel.jobLayer then
        return
    end
    local top = IKST_JobLayout.layerTop(panel)
    local grip = IKST_JobLayout.RESIZE_GRIP
    panel.jobLayer:setX(0)
    panel.jobLayer:setY(top)
    panel.jobLayer:setWidth(math.max(0, panel.width - grip))
    panel.jobLayer:setHeight(math.max(0, panel.height - top - grip))

    if panel.q1Panel then
        local x, y, w, h = IKST_JobLayout.q1Rect(panel)
        panel.q1Panel:setX(x)
        panel.q1Panel:setY(y)
        panel.q1Panel:setWidth(w)
        panel.q1Panel:setHeight(h)
    end
    if panel.q2Panel then
        local x, y, w, h = IKST_JobLayout.q2Rect(panel)
        panel.q2Panel:setX(x)
        panel.q2Panel:setY(y)
        panel.q2Panel:setWidth(w)
        panel.q2Panel:setHeight(h)
    end
    if panel.q3Panel then
        local x, y, w, h = IKST_JobLayout.q3Rect(panel)
        panel.q3Panel:setX(x)
        panel.q3Panel:setY(y)
        panel.q3Panel:setWidth(w)
        panel.q3Panel:setHeight(h)
    end
    if panel.q4Panel then
        local x, y, w, h = IKST_JobLayout.q4Rect(panel)
        panel.q4Panel:setX(x)
        panel.q4Panel:setY(y)
        panel.q4Panel:setWidth(w)
        panel.q4Panel:setHeight(h)
    end
end

function IKST_JobLayout.isResizeGrip(panel, x, y)
    if not panel or not panel.resizable then
        return false
    end
    local grip = IKST_JobLayout.RESIZE_GRIP
    return x >= panel.width - grip and y >= panel.height - grip
end

function IKST_JobLayout.sidebarWidth(panel)
    if not panel or IKST_HubNav.isHomeView(panel.view) or panel.view == IKST.VIEW.everyone then
        return 0
    end
    if IKST_HubNav.hasSidebar and not IKST_HubNav.hasSidebar(panel.view) then
        return 0
    end
    return IKST_JobLayout.SIDEBAR_W
end

function IKST_JobLayout.begin(panel, opts)
    opts = opts or {}
    local savedYScroll = 0
    if opts.preserveScroll and panel.jobScroll and panel.jobScroll.getYScroll then
        savedYScroll = panel.jobScroll:getYScroll() or 0
    end

    IKST_JobLayout.relayoutJobLayer(panel)
    local q3X, q3Y, q3W, q3H = IKST_JobLayout.q3Rect(panel)

    panel.contentX = IKST_JobLayout.MARGIN
    panel.contentW = q3W - (IKST_JobLayout.MARGIN * 2)
    panel.logHeight = IKST_JobLayout.Q4_H
    panel.hintHeight = IKST_JobLayout.HINT_HEIGHT
    panel.scrollHeight = q3H
    if panel.scrollHeight < 80 then
        panel.scrollHeight = 80
    end
    panel.bodyY = 0

    if panel.jobScroll then
        panel.jobScroll:setX(0)
        panel.jobScroll:setY(0)
        panel.jobScroll:setWidth(q3W)
        panel.jobScroll:setHeight(q3H)
        panel.jobScroll:setScrollChildren(true)
        if opts.preserveScroll then
            panel.jobScroll:setYScroll(savedYScroll)
        else
            panel.jobScroll:setYScroll(0)
        end
    end
end

function IKST_JobLayout.flowRow(panel, y, specs, gap, rowH)
    gap = gap or 6
    rowH = rowH or 24
    local x = IKST_JobLayout.MARGIN
    local maxX = IKST_JobLayout.MARGIN + (panel.contentW or 264)
    local row = 0
    for _, spec in ipairs(specs) do
        local w = spec.w or 100
        if x + w > maxX and x > IKST_JobLayout.MARGIN then
            y = y + rowH + gap
            x = IKST_JobLayout.MARGIN
            row = row + 1
        end
        w = IKST_JobLayout.clampWidth(panel, x, w)
        local btn = panel:makeJobButton(x, y, w, rowH, spec.label, spec.fn, spec.primary == true)
        if spec.icon and IKST_ClaimIcons then
            IKST_ClaimIcons.applyButtonIcon(btn, spec.icon)
        end
        x = x + w + gap
    end
    return y + rowH + gap, row + 1
end

function IKST_JobLayout.finish(panel, contentBottomY)
    contentBottomY = contentBottomY or panel.bodyY or 0
    panel._lastScrollContentH = contentBottomY + 12
    if panel.jobScroll then
        panel.jobScroll:setScrollHeight(math.max(panel._lastScrollContentH, panel.scrollHeight))
    end
end

function IKST_JobLayout.relayoutChrome(panel, opts)
    if not panel or IKST_HubNav.isHomeView(panel.view) then
        return
    end
    IKST_JobLayout.begin(panel, opts)
    if panel.jobScroll then
        panel.jobScroll:setScrollHeight(math.max(panel._lastScrollContentH or 0, panel.scrollHeight))
    end
    if panel.logPanel then
        local x, y, w, h = IKST_JobLayout.logRect(panel)
        if panel.q4Panel and panel.logPanel.parent == panel.q4Panel then
            panel.logPanel:setX(x)
            panel.logPanel:setY(y)
        else
            panel.logPanel:setX(x)
            panel.logPanel:setY(IKST_JobLayout.toLayerY(panel, y))
        end
        panel.logPanel:setWidth(w)
        panel.logPanel:setHeight(h)
    end
end

function IKST_JobLayout.syncHomeNav(panel)
    if not panel or not panel.homeNavBtn then
        return
    end
    local chromeY = panel:titleBarHeight() + 2
    local show = panel.view and IKST_HubNav and not IKST_HubNav.isHomeView(panel.view)
    panel.homeNavBtn:setX(6)
    panel.homeNavBtn:setY(chromeY + 2)
    panel.homeNavBtn:setVisible(show == true)
    if show and panel.homeNavBtn.bringToTop then
        panel.homeNavBtn:bringToTop()
    end
end

function IKST_JobLayout.hubColumns(panel, minCardW, gap)
    minCardW = minCardW or 140
    gap = gap or 8
    local innerW = IKST_JobLayout.contentWidth(panel)
    local cols = math.floor((innerW + gap) / (minCardW + gap))
    if cols < 1 then
        cols = 1
    end
    if cols > 3 then
        cols = 3
    end
    local cardW = math.floor((innerW - (cols - 1) * gap) / cols)
    return cols, cardW, gap
end
