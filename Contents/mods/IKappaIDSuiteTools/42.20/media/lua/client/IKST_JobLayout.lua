if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_UI_Theme"
require "IKST_UI_Layout"
require "IKappaID_UI/IKUI_Chrome"
require "ISUI/ISButton"
require "ISUI/ISTextEntryBox"
require "ISUI/ISScrollingListBox"

IKST_JobLayout = IKST_JobLayout or {}

-- Fixed single-size shell: no drag-resize, no compact/spacious toggle.
-- Puzzle-piece proportions (sidebar/content/log) still apply within that one size.
IKST_JobLayout.CONTENT_MIN_W = 280
IKST_JobLayout.SIDEBAR_MIN_W = 140
IKST_JobLayout.SIDEBAR_MAX_W = 220
IKST_JobLayout.LOG_MIN_W = 160
IKST_JobLayout.LOG_MAX_W = 300
IKST_JobLayout.SIDEBAR_RATIO = 0.22
IKST_JobLayout.LOG_RATIO = 0.28
IKST_JobLayout.SCREEN_EDGE = 12
-- Leave the vanilla left HUD strip (inventory / health / etc.) uncovered.
IKST_JobLayout.LEFT_HUD_CLEARANCE = 48
IKST_JobLayout.RESIZE_GRIP = 0

-- Left-dock shell: one vertical third of the monitor (Windows snap-style).
-- Center + right thirds stay free for world clicks. Action log is not in this window.
IKST_JobLayout.DOCK_SCREEN_COLUMNS = 3

function IKST_JobLayout.dockColumnWidth(sw)
    sw = tonumber(sw) or 1920
    local left = IKST_JobLayout.LEFT_HUD_CLEARANCE or 0
    return math.max(280, math.floor(sw / IKST_JobLayout.DOCK_SCREEN_COLUMNS) - left)
end

function IKST_JobLayout.defaultSize()
    local core = getCore()
    local sw = core and type(core.getScreenWidth) == "function" and core:getScreenWidth() or 1920
    local sh = core and type(core.getScreenHeight) == "function" and core:getScreenHeight() or 1080
    local edge = IKST_JobLayout.SCREEN_EDGE
    local defW = IKST_JobLayout.dockColumnWidth(sw)
    local defH = sh - (edge * 2)
    return defW, defH
end

function IKST_JobLayout.defaultPosition(_w, _h)
    return IKST_JobLayout.LEFT_HUD_CLEARANCE or 0, IKST_JobLayout.SCREEN_EDGE
end

-- Right edge of the left dock column (hub ends here; action log starts after the drag tab).
function IKST_JobLayout.dockColumnRight(sw)
    sw = tonumber(sw) or 1920
    local left = IKST_JobLayout.LEFT_HUD_CLEARANCE or 0
    return left + IKST_JobLayout.dockColumnWidth(sw)
end

function IKST_JobLayout.useBottomLog(_panel)
    return false
end

function IKST_JobLayout.isHomeBottomLog(_panel)
    return false
end

-- Action log lives outside the main hub window (future separate panel / HUD).
function IKST_JobLayout.wantActionLog(_panel)
    return false
end

function IKST_JobLayout.logPlacement(_panel)
    return "none"
end

function IKST_JobLayout.bottomLogReserve(_panel)
    return 0
end

function IKST_JobLayout.restorePanelPosition(panel)
    if not panel or type(panel.setX) ~= "function" then
        return
    end
    local x, y
    if IKST_UIPrefs and type(IKST_UIPrefs.loadPanelGeometry) == "function" then
        local geo = IKST_UIPrefs.loadPanelGeometry()
        if geo.x then
            x = geo.x
        end
        if geo.y then
            y = geo.y
        end
    end
    if x == nil or y == nil then
        local w = panel.width or (type(panel.getWidth) == "function" and panel:getWidth()) or IKST_JobLayout.MIN_WIDTH
        local h = panel.height or (type(panel.getHeight) == "function" and panel:getHeight()) or IKST_JobLayout.MIN_HEIGHT
        x, y = IKST_JobLayout.defaultPosition(w, h)
    end
    panel:setX(x)
    panel:setY(y)
    IKST_JobLayout.clampDockPosition(panel)
end

function IKST_JobLayout.clampPanelEdges(panel)
    if not panel or type(panel.setX) ~= "function" then
        return
    end
    local edge = IKST_JobLayout.SCREEN_EDGE
    local core = getCore()
    if not core then
        return
    end
    local sw = core:getScreenWidth()
    local sh = core:getScreenHeight()
    local dockW = IKST_JobLayout.dockColumnWidth(sw)
    local w = panel.width or (type(panel.getWidth) == "function" and panel:getWidth()) or dockW
    local isHub = IKST_JobsPanel and IKST_JobsPanel.instance and panel == IKST_JobsPanel.instance
    if isHub and w ~= dockW and type(panel.setWidth) == "function" then
        panel:setWidth(dockW)
        w = dockW
    end
    local h = panel.height or (type(panel.getHeight) == "function" and panel:getHeight()) or 0
    local x = panel:getX()
    local y = panel:getY()
    local topOut, leftOut, rightOut, bottomOut = 0, 0, 0, 0
    if IKST_DragHandle and type(IKST_DragHandle.screenOutset) == "function" then
        topOut, leftOut, rightOut, bottomOut = IKST_DragHandle.screenOutset(panel)
    end
    local minX = edge + leftOut
    if isHub then
        minX = math.max(minX, IKST_JobLayout.LEFT_HUD_CLEARANCE or 0)
    end
    panel:setX(math.max(minX, math.min(x, sw - edge - w - rightOut)))
    panel:setY(math.max(edge + topOut, math.min(y, sh - edge - h - bottomOut)))
end

-- Legacy name used by JobsPanel mouse-up handler.
function IKST_JobLayout.clampDockPosition(panel)
    IKST_JobLayout.clampPanelEdges(panel)
end

-- Horizontal action log: center third, bottom - width = 1/3 screen, height fits 20 fixed lines.
function IKST_JobLayout.actionLogWindowSize()
    local core = getCore()
    local sw = core and type(core.getScreenWidth) == "function" and core:getScreenWidth() or 1920
    local pad = math.max(8, IKST_UI_Layout.s(10))
    local btn = IKST_UI_Layout.s(22)
    local headerH = math.max(math.max(18, IKST_UI_Layout.s(20)), btn + IKST_UI_Layout.s(6))
    local lineH = 14
    if getTextManager and type(getTextManager) == "function" then
        local tm = getTextManager()
        if tm and type(tm.getFontHeight) == "function" then
            lineH = tm:getFontHeight(UIFont.Small)
        end
    end
    local maxLines = 20
    if IKST_ActionLog and type(IKST_ActionLog.MAX_LINES) == "number" then
        maxLines = IKST_ActionLog.MAX_LINES
    end
    local h = pad + headerH + (maxLines * lineH) + pad
    return IKST_JobLayout.dockColumnWidth(sw), h
end

function IKST_JobLayout.actionLogWindowPosition(w, h)
    local core = getCore()
    local sw = core and type(core.getScreenWidth) == "function" and core:getScreenWidth() or 1920
    local sh = core and type(core.getScreenHeight) == "function" and core:getScreenHeight() or 1080
    local edge = IKST_JobLayout.SCREEN_EDGE
    -- Sit just right of the hub dock + its right drag tab.
    local hubTabW = 0
    if IKST_DragHandle and type(IKST_DragHandle.tabSize) == "function" then
        hubTabW = select(1, IKST_DragHandle.tabSize("right")) or 0
    end
    local x = IKST_JobLayout.dockColumnRight(sw) + hubTabW
    local y = sh - h - edge
    if y < edge then
        y = edge
    end
    return x, y
end

function IKST_JobLayout.applyActionLogSize(panel)
    if not panel or type(panel.setWidth) ~= "function" then
        return
    end
    local w, h = IKST_JobLayout.actionLogWindowSize()
    panel:setWidth(w)
    if type(panel.setHeight) == "function" then
        panel:setHeight(h)
    end
    if type(panel.onGeometryChanged) == "function" then
        panel:onGeometryChanged()
    end
end

function IKST_JobLayout.restoreActionLogPosition(panel)
    if not panel or type(panel.setX) ~= "function" then
        return
    end
    local w, h = IKST_JobLayout.actionLogWindowSize()
    local x, y
    if IKST_UIPrefs and type(IKST_UIPrefs.loadActionLogGeometry) == "function" then
        local geo = IKST_UIPrefs.loadActionLogGeometry()
        if geo.x and geo.y then
            x = geo.x
            y = geo.y
        end
    end
    if not x or not y then
        x, y = IKST_JobLayout.actionLogWindowPosition(w, h)
    end
    panel:setX(x)
    panel:setY(y)
    IKST_JobLayout.clampPanelEdges(panel)
    if type(panel.onGeometryChanged) == "function" then
        panel:onGeometryChanged()
    end
end

function IKST_JobLayout.applyActionLogGeometry(panel)
    IKST_JobLayout.applyActionLogSize(panel)
    IKST_JobLayout.restoreActionLogPosition(panel)
end

local function syncChromeMetrics(_panel)
    local scale = IKST_UI_Layout.uiScale()
    local sidebar = IKST_UI_Layout.sidebarWidth()
    IKST_JobLayout.STATUS_HEIGHT = math.max(26, IKST_UI_Layout.s(28))
    IKST_JobLayout.TAB_BAR_HEIGHT = 0
    IKST_JobLayout.SIDEBAR_W = sidebar
    IKST_JobLayout.Q1_W = sidebar
    IKST_JobLayout.Q2_H = math.max(72, IKST_UI_Layout.s(88))
    IKST_JobLayout.Q4_H = math.max(88, IKST_UI_Layout.s(96))
    IKST_JobLayout.MARGIN = math.max(12, IKST_UI_Layout.s(14))
    IKST_JobLayout.GAP = IKST_UI_Layout.gap()
    IKST_JobLayout.PAD = IKST_UI_Layout.padding()
    IKST_JobLayout.LOG_HEIGHT = IKST_JobLayout.Q4_H
    IKST_JobLayout.HINT_HEIGHT = math.max(26, IKST_UI_Layout.s(28))
    IKST_JobLayout.HEADER_ROW = math.max(28, IKST_UI_Layout.s(32))
    IKST_JobLayout.LOG_W = math.max(200, math.floor(240 * scale))
    local fixedW, fixedH = IKST_JobLayout.defaultSize()
    IKST_JobLayout.MIN_WIDTH = fixedW
    IKST_JobLayout.MIN_HEIGHT = fixedH
end

syncChromeMetrics()
IKST_JobLayout.syncChromeMetrics = syncChromeMetrics

-- Window no longer resizes: always snap back to the one fixed size.
function IKST_JobLayout.clampSize(panel, _w, _h)
    IKST_JobLayout.syncChromeMetrics(panel)
    return IKST_JobLayout.defaultSize()
end

-- Compact mode retired: puzzle pieces never rearrange.
function IKST_JobLayout.syncCompactMode(panel)
    if panel then
        panel._layoutCompact = false
    end
    return false
end

function IKST_JobLayout.compactMode(_panel)
    return false
end

-- Fixed three-pane puzzle: sidebar | content | log (same slots, proportional widths).
function IKST_JobLayout.resolveColumns(panel)
    IKST_JobLayout.syncChromeMetrics(panel)
    local grip = IKST_JobLayout.RESIZE_GRIP
    local avail = math.max(0, (panel and panel.width or IKST_JobLayout.MIN_WIDTH) - grip)

    local wantSidebar = false
    if panel and IKST_HubNav and type(IKST_HubNav.isHomeView) == "function"
        and not IKST_HubNav.isHomeView(panel.view) and panel.view ~= IKST.VIEW.everyone then
        if not (type(IKST_HubNav.hasSidebar) == "function" and not IKST_HubNav.hasSidebar(panel.view)) then
            wantSidebar = true
        end
    end

    local wantLog = false
    local bottomLog = false

    if panel and IKST_HubNav and type(IKST_HubNav.isHomeView) == "function" and IKST_HubNav.isHomeView(panel.view) then
        return 0, 0, 0
    end

    if not wantSidebar then
        return 0, 0, 0
    end

    local sidebar = 0
    if wantSidebar then
        sidebar = math.floor(avail * IKST_JobLayout.SIDEBAR_RATIO)
        sidebar = math.min(sidebar, math.max(IKST_JobLayout.SIDEBAR_MIN_W, math.floor(avail * 0.30)))
        if sidebar < IKST_JobLayout.SIDEBAR_MIN_W then
            sidebar = IKST_JobLayout.SIDEBAR_MIN_W
        end
        if sidebar > IKST_JobLayout.SIDEBAR_MAX_W then
            sidebar = IKST_JobLayout.SIDEBAR_MAX_W
        end
    end

    local logW = 0
    if wantLog and not bottomLog then
        logW = math.floor(avail * IKST_JobLayout.LOG_RATIO)
        if logW < IKST_JobLayout.LOG_MIN_W then
            logW = IKST_JobLayout.LOG_MIN_W
        end
        if logW > IKST_JobLayout.LOG_MAX_W then
            logW = IKST_JobLayout.LOG_MAX_W
        end
    end

    local content = avail - sidebar - logW
    if content < IKST_JobLayout.CONTENT_MIN_W then
        local need = IKST_JobLayout.CONTENT_MIN_W - content
        local takeLog = math.min(need, math.max(0, logW - IKST_JobLayout.LOG_MIN_W))
        logW = logW - takeLog
        need = need - takeLog
        if need > 0 then
            local takeSide = math.min(need, math.max(0, sidebar - IKST_JobLayout.SIDEBAR_MIN_W))
            sidebar = sidebar - takeSide
        end
    end
    if sidebar + logW > avail then
        logW = math.max(IKST_JobLayout.LOG_MIN_W, avail - sidebar)
    end
    return sidebar, logW, 0
end

function IKST_JobLayout.contentWidth(panel)
    if panel and panel.contentW and panel.contentW > 0 and panel.jobLayer and panel.jobLayer:getIsVisible() then
        return panel.contentW
    end
    return math.max(120, (panel.width or 520) - (IKST_JobLayout.MARGIN * 2))
end

function IKST_JobLayout.contentRight(panel)
    local x = (panel and panel.contentX) or IKST_JobLayout.MARGIN
    return x + IKST_JobLayout.contentWidth(panel)
end

function IKST_JobLayout.clampWidth(panel, x, w)
    local maxW = IKST_JobLayout.contentRight(panel) - x
    if w > maxW then
        return math.max(36, maxW)
    end
    return w
end

-- Scale existing job widgets in place while the frame resizes (pieces stay put).
function IKST_JobLayout.stampPuzzlePiece(widget)
    if not widget then
        return
    end
    widget._puzzleBaseX = widget.x or (type(widget.getX) == "function" and widget:getX()) or 0
    widget._puzzleBaseY = widget.y or (type(widget.getY) == "function" and widget:getY()) or 0
    widget._puzzleBaseW = widget.width or (type(widget.getWidth) == "function" and widget:getWidth()) or 0
    widget._puzzleBaseH = widget.height or (type(widget.getHeight) == "function" and widget:getHeight()) or 0
end

function IKST_JobLayout.stretchPuzzlePieces(panel)
    if not panel then
        return
    end
    local baseW = tonumber(panel._puzzleBaseContentW) or 0
    local curW = tonumber(panel.contentW) or 0
    if baseW <= 0 or curW <= 0 then
        return
    end
    local ratio = curW / baseW
    if ratio > 0.995 and ratio < 1.005 then
        return
    end
    local widgets = panel.jobWidgets
    if not widgets then
        return
    end
    for i = 1, #widgets do
        local child = widgets[i]
        if child and child._puzzleBaseX ~= nil then
            if type(child.setX) == "function" then
                child:setX(math.floor(child._puzzleBaseX * ratio))
            end
            if child._puzzleBaseW and child._puzzleBaseW >= 36 and type(child.setWidth) == "function" then
                child:setWidth(math.max(36, math.floor(child._puzzleBaseW * ratio)))
            end
        end
    end
end

function IKST_JobLayout.recordPuzzleBaseline(panel)
    if not panel then
        return
    end
    panel._puzzleBaseContentW = tonumber(panel.contentW) or 0
    local widgets = panel.jobWidgets
    if not widgets then
        return
    end
    for i = 1, #widgets do
        IKST_JobLayout.stampPuzzlePiece(widgets[i])
    end
end
function IKST_JobLayout.q1Rect(panel)
    local sidebarW = IKST_JobLayout.resolveColumns(panel)
    local top = IKST_JobLayout.layerTop(panel)
    local h = panel.height - top - IKST_JobLayout.HINT_HEIGHT - IKST_JobLayout.RESIZE_GRIP
    h = h - IKST_JobLayout.bottomLogReserve(panel)
    if h < 0 then
        h = 0
    end
    return 0, 0, sidebarW, h
end

function IKST_JobLayout.q2Height(panel)
    if panel and panel._q2HasContent == true then
        return IKST_JobLayout.Q2_H
    end
    return 0
end

function IKST_JobLayout.armedBannerHeight(panel)
    if not panel or not panel.player then
        return 0
    end
    local state = IKST.getPlayerState(panel.player)
    if state and state.armed and state.armedJob then
        return math.max(26, IKST_UI_Layout.s(28))
    end
    return 0
end

function IKST_JobLayout.q2Rect(panel)
    local sidebarW = IKST_JobLayout.resolveColumns(panel)
    local x = sidebarW
    local w = panel.width - x - IKST_JobLayout.RESIZE_GRIP
    if w < 0 then
        w = 0
    end
    return x, 0, w, IKST_JobLayout.q2Height(panel)
end

-- Action log: always the right puzzle piece (never a bottom drawer). The log
-- card draws its own rounded border (IKST_ActionLog), so it needs a real
-- margin from the window's right edge or the border looks like it's clipped
-- past the frame instead of floating inside it.
function IKST_JobLayout.q4Rect(panel)
    local placement = IKST_JobLayout.logPlacement(panel)
    if placement == "bottom" then
        local margin = IKST_JobLayout.MARGIN or 12
        local h = IKST_JobLayout.Q4_H
        local layerTop = IKST_JobLayout.layerTop(panel)
        local layerH = panel.height - layerTop - IKST_JobLayout.HINT_HEIGHT - IKST_JobLayout.RESIZE_GRIP
        local y = layerH - h
        if y < 0 then
            y = 0
            h = layerH
        end
        local grip = IKST_JobLayout.RESIZE_GRIP
        local w = panel.width - (margin * 2) - grip
        if w < 0 then
            w = 0
        end
        return margin, y, w, h
    end
    local _, logW = IKST_JobLayout.resolveColumns(panel)
    local reserved = logW or 0
    local margin = IKST_JobLayout.MARGIN or 0
    local w = reserved > 0 and math.max(0, reserved - margin) or 0
    local x = panel.width - IKST_JobLayout.RESIZE_GRIP - margin - w
    local y = IKST_JobLayout.q2Height(panel)
    local h = panel.height - IKST_JobLayout.layerTop(panel) - y - IKST_JobLayout.HINT_HEIGHT - IKST_JobLayout.RESIZE_GRIP
    if h < 0 then
        h = 0
    end
    return x, y, w, h
end

function IKST_JobLayout.q3Rect(panel)
    local sidebarW, logW = IKST_JobLayout.resolveColumns(panel)
    local x = sidebarW
    local y = IKST_JobLayout.q2Height(panel)
    local w = panel.width - IKST_JobLayout.RESIZE_GRIP - (logW or 0) - x
    if w < 0 then
        w = 0
    end
    local h = panel.height - IKST_JobLayout.layerTop(panel) - y - IKST_JobLayout.HINT_HEIGHT - IKST_JobLayout.RESIZE_GRIP
    h = h - IKST_JobLayout.bottomLogReserve(panel)
    if h < 0 then
        h = 0
    end
    return x, y, w, h
end

function IKST_JobLayout.logRect(panel)
    if panel and panel.q4Panel and panel.q4Panel:getIsVisible() then
        return 0, 0, panel.q4Panel:getWidth(), panel.q4Panel:getHeight()
    end
    local _, logW = IKST_JobLayout.resolveColumns(panel)
    return 0, 0, logW, 200
end

function IKST_JobLayout.chromeContentTop(panel)
    local banner = IKST_JobLayout.armedBannerHeight(panel)
    return panel:titleBarHeight() + 2 + IKST_JobLayout.STATUS_HEIGHT + 4 + banner
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
    IKST_JobLayout.syncChromeMetrics(panel)
    local top = IKST_JobLayout.layerTop(panel)
    local grip = IKST_JobLayout.RESIZE_GRIP
    panel.jobLayer:setX(0)
    panel.jobLayer:setY(top)
    panel.jobLayer:setWidth(math.max(0, panel.width - grip))
    panel.jobLayer:setHeight(math.max(0, panel.height - top - grip))
    -- Clip regions so controls do not paint over the game while shrunk.
    if panel.jobLayer.clipping ~= nil then
        panel.jobLayer.clipping = true
    end
    if panel.q3Panel and panel.q3Panel.clipping ~= nil then
        panel.q3Panel.clipping = true
    end
    if panel.jobScroll and panel.jobScroll.clipping ~= nil then
        panel.jobScroll.clipping = true
    end

    if panel.q1Panel then
        local x, y, w, h = IKST_JobLayout.q1Rect(panel)
        panel.q1Panel:setX(x)
        panel.q1Panel:setY(y)
        panel.q1Panel:setWidth(w)
        panel.q1Panel:setHeight(h)
        panel.q1Panel:setVisible(w > 0)
    end
    if panel.q2Panel then
        local x, y, w, h = IKST_JobLayout.q2Rect(panel)
        panel.q2Panel:setX(x)
        panel.q2Panel:setY(y)
        panel.q2Panel:setWidth(w)
        panel.q2Panel:setHeight(h)
        panel.q2Panel:setVisible(h > 0)
    end
    if panel.q3Panel then
        local x, y, w, h = IKST_JobLayout.q3Rect(panel)
        panel.q3Panel:setX(x)
        panel.q3Panel:setY(y)
        panel.q3Panel:setWidth(w)
        panel.q3Panel:setHeight(h)
        panel.q3Panel:setVisible(w > 0 and h > 0)
    end
    if panel.q4Panel then
        local x, y, w, h = IKST_JobLayout.q4Rect(panel)
        panel.q4Panel:setX(x)
        panel.q4Panel:setY(y)
        panel.q4Panel:setWidth(math.max(0, w))
        panel.q4Panel:setHeight(math.max(0, h))
        local showLog = IKST_JobLayout.logPlacement(panel) ~= "none"
        panel.q4Panel:setVisible(showLog and w > 0 and h > 0)
    end
    -- Keep scroll host sized to Q3; stretch puzzle pieces instead of rebuilding.
    if panel.jobScroll and panel.q3Panel then
        local _, _, q3W, q3H = IKST_JobLayout.q3Rect(panel)
        panel.jobScroll:setX(0)
        panel.jobScroll:setY(0)
        panel.jobScroll:setWidth(math.max(0, q3W))
        panel.jobScroll:setHeight(math.max(0, q3H))
        panel.scrollHeight = math.max(80, q3H)
        panel.contentX = IKST_JobLayout.MARGIN
        panel.contentW = math.max(80, q3W - (panel.contentX * 2))
        if panel.jobScroll.setScrollHeight and panel._lastScrollContentH then
            panel.jobScroll:setScrollHeight(math.max(panel._lastScrollContentH, panel.scrollHeight))
        end
        IKST_JobLayout.stretchPuzzlePieces(panel)
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
    local sidebarW = IKST_JobLayout.resolveColumns(panel)
    return sidebarW
end

function IKST_JobLayout.begin(panel, opts)
    opts = opts or {}
    local savedYScroll = 0
    if opts.preserveScroll and panel.jobScroll and panel.jobScroll.getYScroll then
        savedYScroll = panel.jobScroll:getYScroll() or 0
    end

    panel._ikstToolFit = false
    IKST_JobLayout.relayoutJobLayer(panel)
    local q3X, q3Y, q3W, q3H = IKST_JobLayout.q3Rect(panel)

    panel.contentX = IKST_JobLayout.MARGIN
    panel.contentW = math.max(80, q3W - (panel.contentX * 2))
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
        panel.jobScroll:setWidth(math.max(0, q3W))
        panel.jobScroll:setHeight(math.max(0, q3H))
        panel.jobScroll:setScrollChildren(true)
        if opts.preserveScroll then
            panel.jobScroll:setYScroll(savedYScroll)
        else
            panel.jobScroll:setYScroll(0)
        end
    end
end

-- One row of puzzle pieces: scale widths to fit; never wrap to a new row.
function IKST_JobLayout.flowRow(panel, y, specs, gap, rowH)
    gap = gap or 6
    rowH = rowH or 24
    local x0 = panel.contentX or IKST_JobLayout.MARGIN
    local budget = math.max(36, panel.contentW or 264)
    local n = #(specs or {})
    if n < 1 then
        return y, 0
    end
    local sumW = 0
    for i = 1, n do
        sumW = sumW + (specs[i].w or 100)
    end
    local gaps = math.max(0, n - 1) * gap
    local scale = 1
    if sumW + gaps > budget and sumW > 0 then
        scale = (budget - gaps) / sumW
    end
    local x = x0
    for i = 1, n do
        local spec = specs[i]
        local w = math.max(36, math.floor((spec.w or 100) * scale))
        w = IKST_JobLayout.clampWidth(panel, x, w)
        local btn = panel:makeJobButton(x, y, w, rowH, spec.label, spec.fn, spec.primary == true)
        if spec.icon and IKST_ClaimIcons and type(IKST_ClaimIcons.applyButtonIcon) == "function" then
            IKST_ClaimIcons.applyButtonIcon(btn, spec.icon)
        end
        x = x + w + gap
    end
    return y + rowH + gap, 1
end

-- Hand-placed tool pills (dashboard density). Locked from UI preview:
-- fixed standard size (Utilities Self), pack fewer columns - never shrink.
IKST_JobLayout.TOOL_PAD = 20
IKST_JobLayout.BTN_GAP = 6
IKST_JobLayout.PACK_COLS = 3
IKST_JobLayout.STANDARD_BTN_H = 36
IKST_JobLayout.SECTION_INNER = 8
-- Search/name fields: wide enough for ~28 visible chars (Small font); never the old 64px stub.
IKST_JobLayout.FIELD_MIN_W = 200
IKST_JobLayout.FIELD_W = 200
IKST_JobLayout.FIELD_H = 32
IKST_JobLayout.CONTENT_PAD_Y = 8
IKST_JobLayout.LIST_PILL_GAP = 8
IKST_JobLayout.QTY_FIELD_W = 48

function IKST_JobLayout.toolContentRect(panel)
    local _, _, q3W, q3H = IKST_JobLayout.q3Rect(panel)
    local pad = IKST_JobLayout.TOOL_PAD
    local w = math.max(80, (q3W or 0) - (pad * 2))
    local h = math.max(80, (q3H or 0) - (pad * 2))
    return { x = pad, y = pad, w = w, h = h }
end

function IKST_JobLayout.standardPillSize(panel)
    local rect = IKST_JobLayout.toolContentRect(panel)
    local inner = IKST_JobLayout.SECTION_INNER
    local usable = math.max(40, rect.w - (inner * 2))
    local gap = IKST_JobLayout.BTN_GAP
    local cols = IKST_JobLayout.PACK_COLS
    local cellW = math.floor((usable - gap * (cols - 1)) / cols)
    local w = math.max(72, cellW - 8)
    return w, IKST_JobLayout.STANDARD_BTN_H
end

function IKST_JobLayout.sectionHeaderH()
    if IKUI_Chrome and type(IKUI_Chrome.sectionHeaderH) == "function" then
        return IKUI_Chrome.sectionHeaderH()
    end
    return 32
end

function IKST_JobLayout.splitBands(areaY, areaH, count, gap)
    gap = gap or 8
    count = math.max(1, count or 1)
    local bandH = math.floor((areaH - gap * (count - 1)) / count)
    local bands = {}
    for i = 1, count do
        bands[i] = {
            y = areaY + (i - 1) * (bandH + gap),
            h = bandH,
        }
    end
    return bands, bandH
end

-- Filter entry height + gap below it (matches makeFilterEntry).
function IKST_JobLayout.filterBlockH()
    return math.max(22, IKST_UI_Layout.s(22)) + 6
end

-- Compact band tall enough for a section header + one pill row.
function IKST_JobLayout.compactSectionBandH()
    local header = IKST_JobLayout.sectionHeaderH()
    local inner = IKST_JobLayout.SECTION_INNER or 8
    local btnH = IKST_JobLayout.STANDARD_BTN_H or 36
    return header + (inner * 2) + btnH + 8
end

-- Compact band for two pill rows (Self / Items overview cards).
function IKST_JobLayout.compactPillBandH(rows)
    rows = math.max(1, rows or 2)
    local header = IKST_JobLayout.sectionHeaderH()
    local inner = IKST_JobLayout.SECTION_INNER or 8
    local btnH = IKST_JobLayout.STANDARD_BTN_H or 36
    local gap = IKST_JobLayout.BTN_GAP or 6
    return header + (inner * 2) + (rows * btnH) + ((rows - 1) * gap) + 8
end

-- Two fixed compact bands + one flex band that keeps the leftover height.
function IKST_JobLayout.splitCompactFlex(areaY, areaH, compactH, gap)
    gap = gap or 8
    compactH = math.max(48, compactH or IKST_JobLayout.compactPillBandH(2))
    local need = compactH * 2 + gap * 2
    if areaH < need + 80 then
        return IKST_JobLayout.splitBands(areaY, areaH, 3, gap)
    end
    local flexH = areaH - need
    return {
        { y = areaY, h = compactH },
        { y = areaY + compactH + gap, h = compactH },
        { y = areaY + (compactH + gap) * 2, h = flexH },
    }, flexH
end

function IKST_JobLayout.colsThatFit(areaW, btnW)
    btnW = btnW or 100
    local gap = IKST_JobLayout.BTN_GAP
    return math.max(1, math.floor((areaW + gap) / (btnW + gap)))
end

function IKST_JobLayout.pillCell(areaX, areaY, areaW, areaH, index, count, btnW, btnH)
    btnW = btnW or 100
    btnH = btnH or IKST_JobLayout.STANDARD_BTN_H
    local gap = IKST_JobLayout.BTN_GAP
    local cols = math.min(IKST_JobLayout.colsThatFit(areaW, btnW), math.max(1, count))
    local rows = math.max(1, math.ceil(count / cols))
    local col = index % cols
    local row = math.floor(index / cols)
    local gridW = cols * btnW + (cols - 1) * gap
    local gridH = rows * btnH + (rows - 1) * gap
    local ox = areaX + math.max(0, math.floor((areaW - gridW) / 2))
    local oy = areaY + math.floor((areaH - gridH) / 2)
    if gridH + 4 >= areaH then
        oy = areaY
    end
    if oy + gridH > areaY + areaH then
        oy = math.max(areaY, areaY + areaH - gridH)
    end
    return {
        x = ox + col * (btnW + gap),
        y = oy + row * (btnH + gap),
        w = btnW,
        h = btnH,
    }
end

function IKST_JobLayout.packFrame(areaX, areaW, btnW)
    btnW = btnW or 100
    local cols = IKST_JobLayout.PACK_COLS
    local gap = IKST_JobLayout.BTN_GAP
    local gridW = cols * btnW + (cols - 1) * gap
    local ox = areaX + math.max(0, math.floor((areaW - gridW) / 2))
    return ox, gridW
end

function IKST_JobLayout.attachToolWidget(panel, parent, widget)
    if parent and parent ~= panel and type(parent.addChild) == "function" then
        parent:addChild(widget)
        return widget
    end
    return panel:addJobWidget(widget)
end

function IKST_JobLayout.placePill(panel, parent, cell, label, onClick, primary)
    local kind = "outline"
    if primary == true then
        kind = "primary"
    elseif primary == "chip" then
        kind = "chip"
    end
    local btn = IKUI_Chrome.newActionButton(cell.x, cell.y, cell.w, cell.h, label, panel, onClick, kind)
    return IKST_JobLayout.attachToolWidget(panel, parent, btn)
end

-- items: { label=, onClick=, primary=true|false|"chip" }
function IKST_JobLayout.placePillGroup(panel, parent, areaX, areaY, areaW, areaH, items)
    local btnW, btnH = IKST_JobLayout.standardPillSize(panel)
    local n = #(items or {})
    for i = 1, n do
        local item = items[i]
        local cell = IKST_JobLayout.pillCell(areaX, areaY, areaW, areaH, i - 1, n, btnW, btnH)
        IKST_JobLayout.placePill(panel, parent, cell, item.label, item.onClick, item.primary)
    end
end

function IKST_JobLayout.placeSectionCard(panel, x, y, w, h, icon, title)
    -- Drop custom section glyphs (soft when scaled); title text only.
    local card, contentY = IKUI_Chrome.newSectionCardPanel(x, y, w, h, nil, title)
    -- Clip children so pills/lists never paint into the next band or hint strip.
    if card.clipping ~= nil then
        card.clipping = true
    end
    panel:addJobWidget(card)
    return card, contentY
end

function IKST_JobLayout.pillGridMetrics(areaW, count, btnW, btnH)
    btnW = btnW or 100
    btnH = btnH or IKST_JobLayout.STANDARD_BTN_H
    count = math.max(0, count or 0)
    local gap = IKST_JobLayout.BTN_GAP
    if count < 1 then
        return 1, 0, 0, 0
    end
    local cols = math.min(IKST_JobLayout.colsThatFit(areaW, btnW), count)
    local rows = math.max(1, math.ceil(count / cols))
    local gridW = cols * btnW + (cols - 1) * gap
    local gridH = rows * btnH + (rows - 1) * gap
    return cols, rows, gridW, gridH
end

-- Split a content area into list (optional filter) + bottom pill row(s).
-- withFilter=true reserves makeFilterEntry height so pills stay below the real list.
-- listH is never larger than the remaining budget (no math.max inventing space).
function IKST_JobLayout.listPillSplit(areaH, pillRows, withFilter)
    pillRows = math.max(1, pillRows or 1)
    local gap = IKST_JobLayout.LIST_PILL_GAP or IKST_JobLayout.BTN_GAP
    local btnH = IKST_JobLayout.STANDARD_BTN_H
    local pillH = pillRows * btnH + (pillRows - 1) * IKST_JobLayout.BTN_GAP
    local filterH = 0
    if withFilter then
        filterH = IKST_JobLayout.filterBlockH()
    end
    local listH = math.max(0, areaH - pillH - gap - filterH)
    return listH, pillH, gap, filterH
end

-- Fields top-left (wide enough to proofread), action pill bottom-right.
-- Side margins still match the 3-pill pack frame.
function IKST_JobLayout.placeFieldActionCorner(panel, parent, areaX, areaY, areaW, areaH, fieldSpecs, actionLabel, onAction)
    local btnW, btnH = IKST_JobLayout.standardPillSize(panel)
    local ox, gridW = IKST_JobLayout.packFrame(areaX, areaW, btnW)
    local fieldH = IKST_JobLayout.FIELD_H
    local fieldGap = IKST_JobLayout.BTN_GAP
    local gutter = math.max(10, fieldGap + 4)
    local specs = fieldSpecs or {}
    local n = #specs
    local minW = IKST_JobLayout.FIELD_MIN_W or 200
    if getTextManager and type(getTextManager) == "function" then
        local tm = getTextManager()
        if tm and type(tm.MeasureStringX) == "function" then
            local sample = "MMMMMMMMMMMMMMMMMMMMMMMMMMMM"
            local measured = tm:MeasureStringX(UIFont.Small, sample)
            if measured and measured > minW then
                minW = measured
            end
        end
    end

    -- Stack action under fields when the band is too short for a clear corner layout.
    local needStack = areaH < (fieldH + btnH + gutter + 4)
    local btnX = ox + gridW - btnW
    local btnY = areaY + math.max(0, areaH - btnH)
    if needStack then
        btnY = areaY + fieldH + gutter
        if btnY + btnH > areaY + areaH then
            btnY = math.max(areaY, areaY + areaH - btnH)
        end
    end
    -- Hard clamp: never place the action pill outside the content area.
    if btnY < areaY then
        btnY = areaY
    end
    if btnY + btnH > areaY + areaH then
        btnY = math.max(areaY, areaY + areaH - btnH)
    end

    -- Width left of the action column (same-row). When stacked, fields may use full pack width.
    local sideRoom = math.max(72, gridW - btnW - gutter)
    local fieldRowW = needStack and gridW or sideRoom
    local entries = {}
    local x = ox
    if n <= 0 then
        IKST_JobLayout.placePill(panel, parent, { x = btnX, y = btnY, w = btnW, h = btnH }, actionLabel, onAction, true)
        return entries
    end

    if n == 1 then
        local fieldW = math.min(fieldRowW, math.max(minW, fieldRowW))
        fieldW = math.max(72, math.min(fieldW, fieldRowW))
        local spec = specs[1]
        local entry = ISTextEntryBox:new(tostring(spec.text or ""), ox, areaY, fieldW, fieldH)
        entry:initialise()
        entry:instantiate()
        if IKUI_Chrome and type(IKUI_Chrome.styleInput) == "function" then
            IKUI_Chrome.styleInput(entry, false)
        end
        IKST_JobLayout.attachToolWidget(panel, parent, entry)
        entries[1] = entry
        if spec.fieldName then
            panel[spec.fieldName] = entry
        end
    elseif n == 2 then
        -- ID + qty: never let qty collide with Give - clamp into fieldRowW.
        local qtyW = IKST_JobLayout.QTY_FIELD_W or 48
        local primaryW = fieldRowW - qtyW - fieldGap
        if primaryW < 96 then
            qtyW = math.max(36, math.min(qtyW, fieldRowW - 96 - fieldGap))
            primaryW = math.max(72, fieldRowW - qtyW - fieldGap)
        end
        if primaryW + qtyW + fieldGap > fieldRowW then
            primaryW = math.max(72, fieldRowW - qtyW - fieldGap)
        end
        for i = 1, 2 do
            local spec = specs[i]
            local fw = (i == 1) and primaryW or qtyW
            local entry = ISTextEntryBox:new(tostring(spec.text or ""), x, areaY, fw, fieldH)
            entry:initialise()
            entry:instantiate()
            if IKUI_Chrome and type(IKUI_Chrome.styleInput) == "function" then
                IKUI_Chrome.styleInput(entry, false)
            end
            IKST_JobLayout.attachToolWidget(panel, parent, entry)
            entries[i] = entry
            if spec.fieldName then
                panel[spec.fieldName] = entry
            end
            x = x + fw + fieldGap
        end
    else
        local share = math.floor((fieldRowW - fieldGap * (n - 1)) / n)
        local fw = math.max(48, share)
        if fw * n + fieldGap * (n - 1) > fieldRowW then
            fw = math.max(40, math.floor((fieldRowW - fieldGap * (n - 1)) / n))
        end
        for i = 1, n do
            local spec = specs[i]
            local entry = ISTextEntryBox:new(tostring(spec.text or ""), ox + (i - 1) * (fw + fieldGap), areaY, fw, fieldH)
            entry:initialise()
            entry:instantiate()
            if IKUI_Chrome and type(IKUI_Chrome.styleInput) == "function" then
                IKUI_Chrome.styleInput(entry, false)
            end
            IKST_JobLayout.attachToolWidget(panel, parent, entry)
            entries[i] = entry
            if spec.fieldName then
                panel[spec.fieldName] = entry
            end
        end
    end

    IKST_JobLayout.placePill(panel, parent, { x = btnX, y = btnY, w = btnW, h = btnH }, actionLabel, onAction, true)
    return entries
end

function IKST_JobLayout.finishFit(panel)
    local _, _, _, q3H = IKST_JobLayout.q3Rect(panel)
    local h = math.max(80, q3H or panel.scrollHeight or 80)
    panel._lastScrollContentH = h
    panel.bodyY = h
    if panel.jobScroll then
        if panel.jobScroll.setContentHeight then
            panel.jobScroll:setContentHeight(h)
        end
        if panel.jobScroll.setScrollHeight then
            panel.jobScroll:setScrollHeight(h)
        end
        if type(panel.jobScroll.setYScroll) == "function" then
            panel.jobScroll:setYScroll(0)
        end
    end
    IKST_JobLayout.recordPuzzleBaseline(panel)
    if IKUI_Chrome and IKUI_Chrome.syncArmedStopButton then
        IKUI_Chrome.syncArmedStopButton(panel)
    end
end

function IKST_JobLayout.listItemHeight()
    return math.max(22, IKST_UI_Layout.s(24))
end

function IKST_JobLayout.selectListHeight(visibleRows)
    visibleRows = tonumber(visibleRows) or 8
    if visibleRows < 1 then
        visibleRows = 1
    end
    return (IKST_JobLayout.listItemHeight() * visibleRows) + 2
end

-- How many list rows fit in a pixel budget.
function IKST_JobLayout.rowsForListHeight(listH)
    local rowH = IKST_JobLayout.listItemHeight()
    return math.max(1, math.floor(math.max(0, (listH or 0) - 2) / rowH))
end

function IKST_JobLayout.filterRows(rows, query)
    query = string.lower(string.gsub(tostring(query or ""), "^%s*(.-)%s*$", "%1"))
    if query == "" then
        return rows or {}
    end
    local out = {}
    for i = 1, #(rows or {}) do
        local row = rows[i]
        local hay = string.lower(tostring(row.label or "") .. " " .. tostring(row.sub or ""))
        if string.find(hay, query, 1, true) then
            out[#out + 1] = row
        end
    end
    return out
end

function IKST_JobLayout.drawSelectListItem(self, y, item, alt)
    local c = IKUI_Chrome and IKUI_Chrome.colors or nil
    local h = self.itemheight or 22
    if self.selected == item.index and c then
        self:drawRect(0, y, self:getWidth(), h, 0.35, c.accentDim.r, c.accentDim.g, c.accentDim.b)
    elseif alt and c then
        self:drawRect(0, y, self:getWidth(), h, 0.10, c.bgCard.r, c.bgCard.g, c.bgCard.b)
    end
    local row = item.item
    local text = (row and row.label) or item.text or ""
    if c then
        self:drawText(text, 6, y + 3, c.textPrimary.r, c.textPrimary.g, c.textPrimary.b, 1, self.font)
    else
        self:drawText(text, 6, y + 3, 1, 1, 1, 1, self.font)
    end
    return y + h
end

function IKST_JobLayout.refillSelectList(list, rows, selectedId)
    if not list or type(list.clear) ~= "function" then
        return
    end
    list:clear()
    local selectedIndex = 1
    for i, row in ipairs(rows or {}) do
        list:addItem(row.label or "?", row)
        if selectedId ~= nil and row.id == selectedId then
            selectedIndex = i
        end
    end
    if #(rows or {}) > 0 then
        list.selected = selectedIndex
    end
end

function IKST_JobLayout.attachSelectChild(panel, parent, widget)
    if parent and type(parent.addChild) == "function" then
        parent:addChild(widget)
    elseif panel and type(panel.addJobWidget) == "function" then
        panel:addJobWidget(widget)
    end
end

function IKST_JobLayout.makeFilterEntry(panel, parent, x, y, w, fieldName, onChange)
    local text = ""
    if fieldName and panel[fieldName] ~= nil then
        text = tostring(panel[fieldName])
    end
    local h = math.max(22, IKST_UI_Layout.s(22))
    local entry = ISTextEntryBox:new(text, x, y, w, h)
    entry:initialise()
    entry:instantiate()
    if IKUI_Chrome and type(IKUI_Chrome.styleInput) == "function" then
        IKUI_Chrome.styleInput(entry, false)
    end
    IKST_JobLayout.attachSelectChild(panel, parent, entry)
    entry.onTextChange = function()
        local value = ""
        if type(entry.getText) == "function" then
            value = entry:getText() or ""
        end
        if fieldName then
            panel[fieldName] = value
        end
        if onChange then
            onChange(value)
        end
    end
    return entry, y + h + 6
end

function IKST_JobLayout.makeSelectList(panel, parent, x, y, w, h, rows, opts)
    opts = opts or {}
    local list = ISScrollingListBox:new(x, y, w, h)
    list:initialise()
    list:instantiate()
    list.itemheight = opts.itemHeight or IKST_JobLayout.listItemHeight()
    list.font = UIFont.Small
    list.drawBorder = true
    if IKUI_Chrome and type(IKUI_Chrome.styleListBox) == "function" then
        IKUI_Chrome.styleListBox(list)
    end
    list.doDrawItem = opts.doDrawItem or IKST_JobLayout.drawSelectListItem
    IKST_JobLayout.attachSelectChild(panel, parent, list)
    panel._ikstSelectLists = panel._ikstSelectLists or {}
    panel._ikstSelectLists[#panel._ikstSelectLists + 1] = list
    IKST_JobLayout.refillSelectList(list, rows, opts.selectedId)
    if type(list.setOnMouseDownFunction) == "function" then
        list:setOnMouseDownFunction(panel, function(_target, row)
            if row and opts.onSelect then
                opts.onSelect(row)
            end
        end)
    end
    return list, y + h
end

function IKST_JobLayout.finish(panel, contentBottomY)
    if panel and panel._ikstToolFit == true then
        panel._ikstToolFit = false
        IKST_JobLayout.finishFit(panel)
        return
    end
    contentBottomY = contentBottomY or panel.bodyY or 0
    panel._lastScrollContentH = contentBottomY + 12
    if panel.jobScroll then
        if panel.jobScroll.setContentHeight then
            panel.jobScroll:setContentHeight(panel._lastScrollContentH)
        end
        if panel.jobScroll.setScrollHeight then
            panel.jobScroll:setScrollHeight(math.max(panel._lastScrollContentH, panel.scrollHeight or 0))
        end
    end
    IKST_JobLayout.recordPuzzleBaseline(panel)
    if IKUI_Chrome and IKUI_Chrome.syncArmedStopButton then
        IKUI_Chrome.syncArmedStopButton(panel)
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
    if panel.logPanel and IKST_ActionLog and type(IKST_ActionLog.relayout) == "function" then
        local x, y, w, h = IKST_JobLayout.logRect(panel)
        IKST_ActionLog.relayout(panel.logPanel, x, y, w, h, panel)
    end
end

function IKST_JobLayout.syncHomeNav(panel)
    if not panel or not panel.homeNavBtn then
        return
    end
    local stripY = panel:titleBarHeight() + 2
    local stripH = IKST_JobLayout.STATUS_HEIGHT
    local btnH = math.min(stripH - 4, math.max(20, IKST_UI_Layout.s(22)))
    local show = panel.view and IKST_HubNav and not IKST_HubNav.isHomeView(panel.view)
    panel.homeNavBtn:setX(6)
    panel.homeNavBtn:setWidth(72)
    panel.homeNavBtn:setHeight(btnH)
    panel.homeNavBtn:setY(stripY + math.floor((stripH - btnH) / 2))
    panel.homeNavBtn:setVisible(show == true)
    if show and panel.homeNavBtn.bringToTop then
        panel.homeNavBtn:bringToTop()
    end
end

-- Hint strip sits above the resize grip so text is not clipped by the window edge.
function IKST_JobLayout.hintStripY(panel)
    if not panel then
        return 0
    end
    return panel.height - IKST_JobLayout.RESIZE_GRIP - IKST_JobLayout.HINT_HEIGHT
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
