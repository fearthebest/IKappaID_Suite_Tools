-- Soft-shell page host — SoftBody frontend + SoftTool feature paint.
-- Shell sidebar = workspaces. This host = tool rail + one stencil body (IKappaID_UI).
-- SoftTool_* own soft paint; Job* = dispatch/request helpers only.
-- No JobsPanel Q1–Q4 puzzle; no ActionLog satellite.
if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISPanel"
require "ISUI/ISLabel"
require "IKST_Shared"
require "IKST_Access"
require "IKappaID_UI/IKUI_Chrome"
require "IKappaID_UI/IKUI_Controls"
require "IKappaID_UI/IKUI_SoftBody"
require "IKST_HubNav"
require "IKST_ScrollArea"
require "IKST_SoftTool_Claim"
require "IKST_SoftTool_Everyone"
require "IKST_SoftTool_Utilities"

IKST_SoftPageHost = ISPanel:derive("IKST_SoftPageHost")

local TOOL_RAIL = 160
local CONTENT_PAD = (IKUI_SoftBody and IKUI_SoftBody.CONTENT_PAD) or 16
local GRIP_CHIN = 0 -- shell already reserves chin around this page

local ENTRY_DRAFT_KEYS = {
    "guardShOwnerEntry",
    "guardShWEntry",
    "guardShHEntry",
    "guardShMemberEntry",
    "guardVehicleOwnerEntry",
    "guardVehicleLabelEntry",
    "guardSpriteEntry",
    "guardOwnerEntry",
    "guardLockEntry",
    "claimReqWEntry",
    "claimReqHEntry",
}

function IKST_SoftPageHost:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    o.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    o.clipping = true
    o.window = nil
    o.player = nil
    o.view = nil
    o._softShellMode = true
    o.bodyY = 0
    o.jobWidgets = {}
    o.chromeWidgets = {}
    o.logPanel = nil
    o._lastScrollContentH = 0
    o._pendingRefresh = false
    o._flushRefresh = false
    return o
end

function IKST_SoftPageHost.create(window, x, y, w, h, viewId)
    local panel = IKST_SoftPageHost:new(x, y, w, h)
    panel.window = window
    panel.player = window and window.player or nil
    panel.view = viewId
    panel._softShellMode = true
    return panel
end

function IKST_SoftPageHost:initialise()
    ISPanel.initialise(self)
end

function IKST_SoftPageHost:createChildren()
    -- Aegis-style: tool rail | stencil scroll. No Q2/Q4/jobLayer puzzle.
    local sc = IKUI_Chrome.colors.bgSidebar
    self.toolRail = ISPanel:new(0, 0, TOOL_RAIL, self.height)
    self.toolRail.backgroundColor = { r = sc.r, g = sc.g, b = sc.b, a = sc.a }
    self.toolRail.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    self.toolRail.clipping = true
    self.toolRail:initialise()
    self:addChild(self.toolRail)

    -- HubNav / JobLayout soft aliases
    self.q1Panel = self.toolRail
    self.q2Panel = nil
    self.q4Panel = nil
    self.jobLayer = self

    self.jobScroll = IKST_ScrollArea:new(TOOL_RAIL, 0, math.max(80, self.width - TOOL_RAIL), self.height)
    self.jobScroll.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    self.jobScroll.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    self.jobScroll.clipping = true
    self.jobScroll:initialise()
    if type(self.jobScroll.setScrollChildren) == "function" then
        self.jobScroll:setScrollChildren(true)
    end
    self:addChild(self.jobScroll)
    self.q3Panel = self.jobScroll
end

-- Geometry owned here — not IKST_JobLayout.resolveColumns / relayoutJobLayer.
function IKST_SoftPageHost:placeChrome(opts)
    opts = opts or {}
    local savedYScroll = 0
    if opts.preserveScroll and self.jobScroll and type(self.jobScroll.getYScroll) == "function" then
        savedYScroll = self.jobScroll:getYScroll() or 0
    end

    local hasTools = IKST_HubNav and type(IKST_HubNav.hasSidebar) == "function"
        and IKST_HubNav.hasSidebar(self.view, self.player)
    local rail = hasTools and TOOL_RAIL or 0
    local h = math.max(80, self.height - GRIP_CHIN)
    local w = math.max(80, self.width)

    if self.toolRail then
        self.toolRail:setX(0)
        self.toolRail:setY(0)
        self.toolRail:setWidth(rail)
        self.toolRail:setHeight(h)
        self.toolRail:setVisible(rail > 0)
    end
    self.q1Panel = self.toolRail

    local cx = rail
    local cw = math.max(80, w - rail)
    if self.jobScroll then
        self.jobScroll:setX(cx)
        self.jobScroll:setY(0)
        self.jobScroll:setWidth(cw)
        self.jobScroll:setHeight(h)
        if type(self.jobScroll.setScrollChildren) == "function" then
            self.jobScroll:setScrollChildren(true)
        end
        if opts.preserveScroll and type(self.jobScroll.setYScroll) == "function" then
            self.jobScroll:setYScroll(savedYScroll)
        elseif type(self.jobScroll.setYScroll) == "function" then
            self.jobScroll:setYScroll(0)
        end
    end
    self.q3Panel = self.jobScroll

    self.contentX = CONTENT_PAD
    self.contentW = math.max(80, cw - (CONTENT_PAD * 2))
    self.scrollHeight = h
    -- Exact viewport page bounds for SoftBody.contentRect / pageBands.
    local pad = (IKUI_SoftBody and IKUI_SoftBody.CONTENT_PAD) or CONTENT_PAD
    self._softContentRect = {
        x = self.contentX,
        y = pad,
        w = self.contentW,
        h = math.max(80, h - (pad * 2)),
    }
    self._q2HasContent = false
end

function IKST_SoftPageHost:titleBarHeight()
    return 0
end

function IKST_SoftPageHost:onShow()
    if self.window and self.window.player then
        self.player = self.window.player
    end
    -- Bind this page's workspace before paint (shell sidebar may not have applied nav yet).
    if self.view and self.player and IKST_HubNav and type(IKST_HubNav.applyNav) == "function" then
        local state = IKST.getPlayerState(self.player)
        if state then
            local tool = state.navTool
            local okTool = false
            if state.navMode == self.view and tool then
                local tools = IKST_HubNav.toolsForWorkspace(self.view, self.player)
                for i = 1, #tools do
                    if tools[i].id == tool then
                        okTool = true
                        break
                    end
                end
            end
            if not okTool then
                tool = IKST_HubNav.defaultTool(self.view)
            end
            IKST_HubNav.applyNav(state, self.view, tool)
        end
    end
    self:refreshJobUI()
end

function IKST_SoftPageHost:saveState()
    self:captureEntryDraft()
    return {
        drafts = self._entryDraft,
        helpShowRules = self.helpShowRules == true,
        economyVendX = self.economyVendX,
        economyVendY = self.economyVendY,
        economyVendZ = self.economyVendZ,
    }
end

function IKST_SoftPageHost:restoreState(saved)
    if type(saved) ~= "table" then
        return
    end
    if type(saved.drafts) == "table" then
        self._entryDraft = saved.drafts
    end
    self.helpShowRules = saved.helpShowRules == true
    self.economyVendX = saved.economyVendX
    self.economyVendY = saved.economyVendY
    self.economyVendZ = saved.economyVendZ
end

function IKST_SoftPageHost:captureEntryDraft()
    local draft = self._entryDraft or {}
    for _, key in ipairs(ENTRY_DRAFT_KEYS) do
        local entry = self[key]
        if entry and type(entry.getText) == "function" then
            draft[key] = entry:getText()
        end
    end
    self._entryDraft = draft
end

function IKST_SoftPageHost:draftEntryText(key, fallback)
    local draft = self._entryDraft
    if draft and draft[key] ~= nil then
        return draft[key]
    end
    return fallback or ""
end

function IKST_SoftPageHost:clearJobLayer()
    local function detachLeaf(widget)
        if not widget then
            return
        end
        if IKUI_Chrome and type(IKUI_Chrome.hideTooltip) == "function" then
            IKUI_Chrome.hideTooltip(widget)
        end
        if type(widget.setVisible) == "function" then
            widget:setVisible(false)
        end
        local parent = widget.parent
        if parent and type(parent.removeChild) == "function" then
            parent:removeChild(widget)
        elseif type(self.removeChild) == "function" then
            self:removeChild(widget)
        end
        -- Match JobsPanel: only RemoveElement for true UIManager roots (no parent).
        -- removeChild already detaches children; removeFromUIManager on a child orphans it.
        if not widget.parent and type(widget.removeFromUIManager) == "function" then
            widget:removeFromUIManager()
        end
        widget.tooltip = nil
        widget._ikuiTooltip = nil
        if type(widget.setTooltip) == "function" then
            widget:setTooltip(nil)
        end
    end

    local function detachTree(widget)
        if not widget then
            return
        end
        local kids = nil
        if type(widget.getChildren) == "function" then
            kids = widget:getChildren()
        elseif type(widget.children) == "table" then
            kids = widget.children
        end
        if kids then
            if type(kids.size) == "function" then
                for i = kids:size() - 1, 0, -1 do
                    detachTree(kids:get(i))
                end
            elseif type(kids) == "table" then
                for _, child in pairs(kids) do
                    detachTree(child)
                end
            end
        end
        detachLeaf(widget)
    end

    if IKUI_Chrome and type(IKUI_Chrome.hideAllOwnedTooltips) == "function" then
        IKUI_Chrome.hideAllOwnedTooltips()
    end

    local list = self.jobWidgets or {}
    for i = #list, 1, -1 do
        detachTree(list[i])
        list[i] = nil
    end
    self.jobWidgets = {}

    local chrome = self.chromeWidgets or {}
    for i = #chrome, 1, -1 do
        detachTree(chrome[i])
        chrome[i] = nil
    end
    self.chromeWidgets = {}

    self._ikstSelectLists = {}
    self.economyAmount = nil
    self.logPanel = nil
    self.staffPlayerList = nil
    self.staffPlayerFilterBox = nil
    self.staffItemList = nil
    self.staffItemType = nil
end

function IKST_SoftPageHost:trackWidget(widget)
    if not widget then
        return
    end
    widget._ikstHubSatellite = true
    self.jobWidgets = self.jobWidgets or {}
    for i = 1, #self.jobWidgets do
        if self.jobWidgets[i] == widget then
            return
        end
    end
    self.jobWidgets[#self.jobWidgets + 1] = widget
end

function IKST_SoftPageHost:addQ1Widget(widget)
    if not widget or not self.toolRail then
        return widget
    end
    widget._ikstHubSatellite = true
    table.insert(self.chromeWidgets, widget)
    self.toolRail:addChild(widget)
    if widget then
        widget.doRepaintStencil = true
    end
    return widget
end

function IKST_SoftPageHost:addQ2Widget(widget)
    return widget
end

function IKST_SoftPageHost:addQ4Widget(widget)
    return widget
end

function IKST_SoftPageHost:addJobWidget(widget)
    if not widget or not self.jobScroll then
        return widget
    end
    widget._ikstHubSatellite = true
    local baseY = widget.y
    if type(baseY) ~= "number" and type(widget.getY) == "function" then
        baseY = widget:getY()
    end
    if type(baseY) == "number" then
        widget._ikstBaseY = baseY
    end
    table.insert(self.jobWidgets, widget)
    if type(self.jobScroll.addScrollChild) == "function" then
        self.jobScroll:addScrollChild(widget)
    else
        self.jobScroll:addChild(widget)
        if widget then
            widget.doRepaintStencil = true
        end
    end
    return widget
end

function IKST_SoftPageHost:makeJobHeader(x, y, text)
    local w = math.max(40, self.contentW or (self.width - 24))
    local label = ISLabel:new(x, y, 18, text or "", 1, 1, 1, 1, UIFont.Medium, true)
    label:initialise()
    if IKUI_Chrome and type(IKUI_Chrome.styleHeaderLabel) == "function" then
        IKUI_Chrome.styleHeaderLabel(label)
    end
    self:addJobWidget(label)
    return y + 22
end

function IKST_SoftPageHost:makeJobButton(x, y, w, h, label, onClick, primary)
    w = math.min(w, math.max(36, (self.contentW or w) - (x - (self.contentX or 0))))
    local kind = primary and "primary" or "outline"
    local btn = IKUI_Chrome.newActionButton(x, y, w, h, label, self, onClick, kind)
    return self:addJobWidget(btn)
end

function IKST_SoftPageHost:makeJobLabel(x, y, text, font)
    local w = math.max(40, self.contentW or (self.width - 24))
    local labelFont = font or UIFont.Small
    local labelText = text or ""
    local lineH = 16
    local lineCount = 1
    local wrapped = labelText
    if getTextManager then
        local tm = getTextManager()
        if tm.WrapText then
            wrapped = tm:WrapText(labelFont, labelText, w)
        end
        if tm.getFontFromEnum then
            local fontObj = tm:getFontFromEnum(labelFont)
            if fontObj and fontObj.getLineHeight then
                lineH = fontObj:getLineHeight()
            end
        end
    end
    for _ in string.gmatch(wrapped, "\n") do
        lineCount = lineCount + 1
    end
    local h = math.max(16, (lineCount * lineH) + 2)
    local label = ISPanel:new(x, y, w, h)
    label.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    label.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    label:initialise()
    label.ikstHeight = h
    label.render = function(p)
        ISPanel.render(p)
        local cc = IKUI_Chrome.colors
        local ly = 0
        for line in string.gmatch(wrapped .. "\n", "(.-)\n") do
            p:drawText(line, 0, ly, cc.textMuted.r, cc.textMuted.g, cc.textMuted.b, 1, labelFont)
            ly = ly + lineH
        end
    end
    return self:addJobWidget(label)
end

function IKST_SoftPageHost:enterNav(modeId, toolId)
    modeId = modeId or self.view
    if modeId ~= self.view and IKST_Hub and type(IKST_Hub.switchWorkspace) == "function" then
        IKST_Hub.switchWorkspace(modeId, toolId)
        return
    end
    local state = IKST.getPlayerState(self.player)
    if state and IKST_HubNav and type(IKST_HubNav.applyNav) == "function" then
        IKST_HubNav.applyNav(state, modeId or self.view, toolId)
        modeId = state.navMode or modeId
        toolId = state.navTool or toolId
    end
    if modeId then
        self.view = modeId
    end
    self:refreshJobUI()
    if IKST_HubNav and type(IKST_HubNav.onNavEntered) == "function" then
        IKST_HubNav.onNavEntered(self, modeId, toolId)
    end
end

function IKST_SoftPageHost:updateNav()
    if IKST_HubNav and type(IKST_HubNav.buildSidebar) == "function" then
        IKST_HubNav.buildSidebar(self)
    end
end

function IKST_SoftPageHost:updateActions(preserveScroll)
    self:placeChrome({ preserveScroll = preserveScroll == true })
    local contentY = 8
    local state = IKST.getPlayerState(self.player)
    local toolId = state and state.navTool

    if self.view == IKST.VIEW.utilities then
        contentY = (IKST_SoftTool_Utilities and IKST_SoftTool_Utilities.build and IKST_SoftTool_Utilities.build(self)) or contentY
    elseif self.view == IKST.VIEW.claim then
        contentY = (IKST_SoftTool_Claim and IKST_SoftTool_Claim.build and IKST_SoftTool_Claim.build(self)) or contentY
    elseif self.view == IKST.VIEW.tiles then
        if IKST.Plugins and type(IKST.Plugins.buildJobTool) == "function" then
            contentY = IKST.Plugins.buildJobTool(self, toolId or "overview") or contentY
        elseif IKST_SoftTool_Tiles and type(IKST_SoftTool_Tiles.build) == "function" then
            contentY = IKST_SoftTool_Tiles.build(self) or contentY
        end
    elseif self.view == IKST.VIEW.vehicles then
        if IKST.Plugins and type(IKST.Plugins.buildJobTool) == "function" then
            contentY = IKST.Plugins.buildJobTool(self, toolId or "overview") or contentY
        elseif IKST_SoftTool_Vehicle and type(IKST_SoftTool_Vehicle.build) == "function" then
            contentY = IKST_SoftTool_Vehicle.build(self) or contentY
        end
    elseif self.view == IKST.VIEW.economy and IKST.Plugins and type(IKST.Plugins.buildJobTool) == "function" then
        contentY = IKST.Plugins.buildJobTool(self, toolId or "money") or contentY
    elseif self.view == IKST.VIEW.loot and IKST.Plugins and type(IKST.Plugins.buildJobTool) == "function" then
        contentY = IKST.Plugins.buildJobTool(self, toolId or "loot") or contentY
    elseif self.view == IKST.VIEW.admin and IKST.Plugins and type(IKST.Plugins.buildJobTool) == "function" then
        contentY = IKST.Plugins.buildJobTool(self, toolId or "ghost") or contentY
    elseif self.view == IKST.VIEW.everyone then
        contentY = (IKST_SoftTool_Everyone and IKST_SoftTool_Everyone.build and IKST_SoftTool_Everyone.build(self)) or contentY
    end
    self.bodyY = contentY
    if IKUI_SoftBody and type(IKUI_SoftBody.finish) == "function" then
        IKUI_SoftBody.finish(self, contentY)
    end
end

function IKST_SoftPageHost:refreshJobUI(preserveScroll)
    -- Defer rebuild out of mouse/network dispatch (Aegis rebuildWanted pattern).
    if not self._flushRefresh then
        self._pendingRefresh = true
        if preserveScroll ~= nil then
            self._pendingPreserveScroll = preserveScroll
        end
        return
    end
    local state = IKST.getPlayerState(self.player)
    local tool = state and state.navTool
    if preserveScroll == nil then
        preserveScroll = (self._lastBuiltView == self.view and self._lastBuiltTool == tool)
    end
    self:captureEntryDraft()
    self:clearJobLayer()
    self:placeChrome({ preserveScroll = preserveScroll == true })
    self:updateNav()
    self:updateActions(preserveScroll)
    if IKST_Preview and type(IKST_Preview.syncForPanel) == "function" then
        IKST_Preview.syncForPanel(self)
    end
    self._lastBuiltView = self.view
    self._lastBuiltTool = tool
end

function IKST_SoftPageHost:onInspectResult(args)
    local state = IKST.getPlayerState(self.player)
    if state and args then
        state.lastInspect = args
    end
    self:refreshJobUI(true)
end

function IKST_SoftPageHost:onBatchProgress(args)
    if not args then
        return
    end
    local state = IKST.getPlayerState(self.player)
    if state then
        state.batchProgress = args
    end
    self:refreshJobUI(true)
end

function IKST_SoftPageHost:onServerResult(args)
    if self.player and args and args.message and IKST.shouldNotifyResult(args.mode) then
        IKST.notify(self.player, IKST.formatServerResult(args.message, args), args.success == true)
    end
    if args and (args.mode == IKST.CMD.quickWater or args.mode == IKST.CMD.quickPower) then
        self:refreshJobUI(true)
    end
    if args and args.success and IKST_JobStaff and (args.mode == IKST.CMD.saveWaypoint or args.mode == IKST.CMD.delWaypoint) then
        IKST_JobStaff.requestWaypoints(self.player)
    end
    if args and IKST_JobVehicle and type(IKST_JobVehicle.onServerResult) == "function" then
        IKST_JobVehicle.onServerResult(self, args)
    end
    if args and IKST_JobLoot and type(IKST_JobLoot.onServerResult) == "function" then
        IKST_JobLoot.onServerResult(self, args)
    end
    self:refreshJobUI(true)
end

function IKST_SoftPageHost:stopArmedMode()
    if IKST_Hub and type(IKST_Hub.disarmWorldTools) == "function" then
        IKST_Hub.disarmWorldTools(self.player)
    end
    self:refreshJobUI(true)
end

function IKST_SoftPageHost:prerender()
    if self._pendingRefresh then
        self._pendingRefresh = false
        local preserve = self._pendingPreserveScroll
        self._pendingPreserveScroll = nil
        self._flushRefresh = true
        self:refreshJobUI(preserve)
        self._flushRefresh = false
    end
    if type(ISPanel.prerender) == "function" then
        ISPanel.prerender(self)
    end
end

function IKST_SoftPageHost:onMouseWheel(del)
    local lists = self._ikstSelectLists or {}
    for i = 1, #lists do
        local list = lists[i]
        if list and type(list.isMouseOver) == "function" and list:isMouseOver()
            and type(list.onMouseWheel) == "function" then
            return list:onMouseWheel(del)
        end
    end
    local rail = self.toolRail
    local maxNav = self._hubNavMaxScroll or 0
    if maxNav > 0 and rail and type(rail.isMouseOver) == "function" and rail:isMouseOver() then
        local cur = self._hubNavScroll or 0
        cur = math.max(0, math.min(maxNav, cur - (del * 30)))
        if cur ~= (self._hubNavScroll or 0) then
            self._hubNavScroll = cur
            self:refreshJobUI(true)
        end
        return true
    end
    local scroll = self.jobScroll
    if scroll and type(scroll.isMouseOver) == "function" and scroll:isMouseOver()
        and type(scroll.setYScroll) == "function" then
        scroll:setYScroll((scroll:getYScroll() or 0) - (del * 48))
        return true
    end
    if type(ISPanel.onMouseWheel) == "function" then
        return ISPanel.onMouseWheel(self, del)
    end
    return false
end
