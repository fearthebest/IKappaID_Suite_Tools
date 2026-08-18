if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end
require "ISUI/ISCollapsableWindow"
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISUIElement"
require "IKST_Shared"
require "IKST_Access"
require "IKappaID_UI/IKUI_Chrome"
require "IKappaID_UI/IKUI_Config"
require "IKST_UI_Layout"
require "IKST_UIPrefs"
require "IKST_DragHandle"
require "IKST_JobLayout"
require "IKST_HubNav"
require "IKST_ScrollArea"
IKST_JobsPanel = ISCollapsableWindow:derive("IKST_JobsPanel")
IKST_JobsPanel.instance = nil
do
    local defW, defH = IKST_JobLayout.defaultSize()
    IKST_JobsPanel.WIDTH = defW
    IKST_JobsPanel.HEIGHT = defH
end
IKST_JobsPanel.MIN_WIDTH = IKST_JobLayout.MIN_WIDTH
IKST_JobsPanel.MIN_HEIGHT = IKST_JobLayout.MIN_HEIGHT
local HUB_CATEGORIES = nil
function IKST_JobsPanel:new(x, y, width, height)
    width = width or IKST_JobsPanel.WIDTH
    height = height or IKST_JobsPanel.HEIGHT
    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.player = nil
    o.view = IKST.VIEW.favorites
    o.pin = true
    o.resizable = false
    o.minimumWidth = IKST_JobsPanel.MIN_WIDTH
    o.minimumHeight = IKST_JobsPanel.MIN_HEIGHT
    o.bodyY = 0
    o.hubHits = {}
    o.jobWidgets = {}
    o.chromeWidgets = {}
    o.logPanel = nil
    o._lastScrollContentH = 0
    o._layoutCompact = nil
    IKUI_Chrome.applyPanelColors(o)
    o:setTitle(IKST.text("IGUI_IKST_Title", "IKappaID Suite Tools"))
    IKST_DragHandle.attach(o, "right", {
        clampFn = function(p)
            if IKST_JobLayout and type(IKST_JobLayout.clampPanelEdges) == "function" then
                IKST_JobLayout.clampPanelEdges(p)
            end
        end,
        saveFn = function(p)
            if IKST_UIPrefs and type(IKST_UIPrefs.savePanelGeometry) == "function" then
                IKST_UIPrefs.savePanelGeometry(p)
            end
        end,
    })
    return o
end

function IKST_JobsPanel:initialise()
    ISCollapsableWindow.initialise(self)
    if self.setResizable then
        self:setResizable(false)
    end
    self.clipping = false
end

function IKST_JobsPanel:createChildren()
    ISCollapsableWindow.createChildren(self)
    self.jobLayer = ISPanel:new(0, 0, self.width, self.height)
    self.jobLayer.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    self.jobLayer.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    self.jobLayer.clipping = true
    self.jobLayer:initialise()
    self:addChild(self.jobLayer)
    self.jobLayer:setVisible(false)
    -- Q1: NAV
    self.q1Panel = ISPanel:new(0, 0, 100, 100)
    local sc = IKUI_Chrome.colors.bgSidebar
    self.q1Panel.backgroundColor = { r = sc.r, g = sc.g, b = sc.b, a = sc.a }
    self.q1Panel.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    self.q1Panel:initialise()
    self.jobLayer:addChild(self.q1Panel)
    -- Q2: TARGET
    self.q2Panel = ISPanel:new(0, 0, 100, 100)
    local card = IKUI_Chrome.colors.bgCard
    self.q2Panel.backgroundColor = { r = card.r, g = card.g, b = card.b, a = 0.55 }
    self.q2Panel.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    self.q2Panel:initialise()
    self.jobLayer:addChild(self.q2Panel)
    -- Q3: ACTIONS
    self.q3Panel = ISPanel:new(0, 0, 100, 100)
    self.q3Panel.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    self.q3Panel.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    self.q3Panel.clipping = true
    self.q3Panel:initialise()
    self.jobLayer:addChild(self.q3Panel)
    self.jobScroll = IKST_ScrollArea:new(0, 0, 100, 100)
    self.jobScroll.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    self.jobScroll.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    self.jobScroll.clipping = true
    self.jobScroll:initialise()
    self.jobScroll:instantiate()
    if self.jobScroll.setScrollChildren then
        self.jobScroll:setScrollChildren(true)
    end
    self.q3Panel:addChild(self.jobScroll)
    -- Q4: LOG (the log panel itself paints a rounded card that fully covers
    -- this rect, so keep the quadrant transparent to avoid a square halo
    -- showing through its rounded corners).
    self.q4Panel = ISPanel:new(0, 0, 100, 100)
    self.q4Panel.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    self.q4Panel.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    self.q4Panel:initialise()
    self.jobLayer:addChild(self.q4Panel)
    local homeH = math.max(22, IKST_UI_Layout.s(24))
    self.homeNavBtn = IKUI_Chrome.newActionButton(6, 0, 72, homeH,
        IKST.text("IGUI_IKST_BackHome", "Home"), self, IKST_JobsPanel.onHomeNavClick, "outline")
    self:addChild(self.homeNavBtn)
    self.homeNavBtn:setVisible(false)
    if IKST_DragHandle and type(IKST_DragHandle.ensureTab) == "function" then
        IKST_DragHandle.ensureTab(self)
    end
end

function IKST_JobsPanel.onHomeNavClick(_btn)
    if IKST_JobsPanel.instance then
        IKST_JobsPanel.instance:goHome()
    end
end
local ENTRY_DRAFT_KEYS = {
    "guardShOwnerEntry",
    "guardShWEntry",
    "guardShHEntry",
    "guardShMemberEntry",
    "guardVehicleOwnerEntry",
    "guardVehicleLabelEntry",
}
function IKST_JobsPanel:captureEntryDraft()
    local draft = self._entryDraft or {}
    for _, key in ipairs(ENTRY_DRAFT_KEYS) do
        local entry = self[key]
        if entry and type(entry.getText) == "function" then
            draft[key] = entry:getText()
        end
    end
    self._entryDraft = draft
end

function IKST_JobsPanel:draftEntryText(key, fallback)
    local draft = self._entryDraft
    if draft and draft[key] ~= nil then
        return draft[key]
    end
    return fallback or ""
end

function IKST_JobsPanel:clearJobLayer()
    local list = self.jobWidgets or {}
    for i = #list, 1, -1 do
        local widget = list[i]
        if widget and widget.parent and widget.parent.removeChild then
            widget.parent:removeChild(widget)
        end
        list[i] = nil
    end
    self.jobWidgets = {}
    local chrome = self.chromeWidgets or {}
    for i = #chrome, 1, -1 do
        local widget = chrome[i]
        if widget and widget.parent and widget.parent.removeChild then
            widget.parent:removeChild(widget)
        end
        chrome[i] = nil
    end
    self.chromeWidgets = {}
    self._ikstSelectLists = {}
    self.economyAmount = nil
    self.logPanel = nil
end

function IKST_JobsPanel:addQ1Widget(widget)
    if not widget or not self.q1Panel then return widget end
    table.insert(self.chromeWidgets, widget)
    self.q1Panel:addChild(widget)
    return widget
end

function IKST_JobsPanel:addQ2Widget(widget)
    if not widget or not self.q2Panel then return widget end
    table.insert(self.chromeWidgets, widget)
    self.q2Panel:addChild(widget)
    return widget
end

function IKST_JobsPanel:addQ4Widget(widget)
    if not widget or not self.q4Panel then return widget end
    table.insert(self.chromeWidgets, widget)
    self.q4Panel:addChild(widget)
    return widget
end

function IKST_JobsPanel:addChromeWidget(widget)
    if not widget or not self.jobLayer then
        return widget
    end
    table.insert(self.chromeWidgets, widget)
    self.jobLayer:addChild(widget)
    return widget
end

-- Dashboard widgets (sidebar nav, header buttons, favorites) attach directly
-- to the panel rather than jobLayer, since Q1/Q2/Q3 are unused on the Home
-- view. Reuses the same chromeWidgets bookkeeping so clearJobLayer() tears
-- them down on every refresh.
function IKST_JobsPanel:addHomeWidget(widget)
    if not widget then
        return widget
    end
    table.insert(self.chromeWidgets, widget)
    self:addChild(widget)
    return widget
end

function IKST_JobsPanel:addJobWidget(widget)
    if not widget or not self.jobScroll then
        return widget
    end
    if widget.setY and widget.getY then
        widget._ikstBaseY = widget:getY()
    end
    table.insert(self.jobWidgets, widget)
    if self.jobScroll.addScrollChild then
        self.jobScroll:addScrollChild(widget)
    else
        self.jobScroll:addChild(widget)
    end
    if IKST_JobLayout and IKST_JobLayout.stampPuzzlePiece then
        IKST_JobLayout.stampPuzzlePiece(widget)
    end
    return widget
end


function IKST_JobsPanel:makeJobHeader(x, y, text)
    local w = IKST_JobLayout.clampWidth(self, x, self.contentW or (self.width - 24))
    local label = ISLabel:new(x, y, 18, text or "", 1, 1, 1, 1, UIFont.Medium, true)
    label:initialise()
    if IKUI_Chrome and IKUI_Chrome.styleHeaderLabel then
        IKUI_Chrome.styleHeaderLabel(label)
    end
    self:addJobWidget(label)
    return y + 22
end

function IKST_JobsPanel:makeJobButton(x, y, w, h, label, onClick, primary)
    w = IKST_JobLayout.clampWidth(self, x, w)
    local kind = primary and "primary" or "outline"
    local btn = IKUI_Chrome.newActionButton(x, y, w, h, label, self, onClick, kind)
    return self:addJobWidget(btn)
end

function IKST_JobsPanel:makeChromeButton(x, y, w, h, label, onClick, primary)
    local kind = primary and "primary" or "outline"
    local btn = IKUI_Chrome.newActionButton(x, y, w, h, label, self, onClick, kind)
    return self:addChromeWidget(btn)
end

function IKST_JobsPanel:makeJobLabel(x, y, text, font)
    local w = IKST_JobLayout.clampWidth(self, x, self.contentW or (self.width - 24))
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
        if type(tm.MeasureStringX) == "function" and tm:MeasureStringX(labelFont, labelText) > w then
            local est = math.ceil(tm:MeasureStringX(labelFont, labelText) / math.max(w, 1))
            if est > lineCount then
                lineCount = est
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

-- Window is fixed-size (no drag-resize); this is a safety net that snaps any
-- externally-forced width/height change (e.g. DPI/resolution change) back to
-- the one fixed shell size and rebuilds the UI.
function IKST_JobsPanel:onResize()
    IKST_JobLayout.syncHyperOsMetrics(self)
    self.minimumWidth = IKST_JobLayout.MIN_WIDTH
    self.minimumHeight = IKST_JobLayout.MIN_HEIGHT
    IKST_JobsPanel.MIN_WIDTH = IKST_JobLayout.MIN_WIDTH
    IKST_JobsPanel.MIN_HEIGHT = IKST_JobLayout.MIN_HEIGHT
    local w, h = IKST_JobLayout.clampSize(self, self.width, self.height)
    if w ~= self.width then
        self:setWidth(w)
    end
    if h ~= self.height then
        self:setHeight(h)
    end
    ISCollapsableWindow.onResize(self)
    IKST_JobLayout.relayoutJobLayer(self)
    IKST_JobLayout.syncHomeNav(self)
    if IKUI_Chrome and IKUI_Chrome.syncArmedStopButton then
        IKUI_Chrome.syncArmedStopButton(self)
    end
    self:refreshJobUI(true)
    if IKST_DragHandle and type(IKST_DragHandle.layoutTab) == "function" then
        IKST_DragHandle.layoutTab(self)
    end
end


function IKST_JobsPanel:disarmAllWorldTools()
    if IKST_WorldPick and IKST_WorldPick.disarm then
        IKST_WorldPick.disarm(self.player)
    end
    if IKST_PaintCursorManager and IKST_PaintCursorManager.disarm then
        IKST_PaintCursorManager.disarm(self.player)
    end
    local state = IKST.getPlayerState(self.player)
    if state then
        state.armed = false
        state.armedJob = nil
        if IKST_WorldPick and IKST_WorldPick.clearCommandPickState then
            IKST_WorldPick.clearCommandPickState(state)
        end
    end
    if IKST_PreviewOverlay and IKST_PreviewOverlay.clear then
        IKST_PreviewOverlay.clear()
    end
    if IKST_HudChip and IKST_HudChip.sync then
        IKST_HudChip.sync(self.player)
    end
end

function IKST_JobsPanel:stopArmedMode()
    self:disarmAllWorldTools()
    self:refreshJobUI()
end

function IKST_JobsPanel:armedModeLabel()
    local state = IKST.getPlayerState(self.player)
    if not state or not state.armed or not state.armedJob then
        return nil
    end
    local job = tostring(state.armedJob)
    local title = IKST_HubNav and IKST_HubNav.labelForNav and IKST_HubNav.labelForNav(job, state.navTool) or job
    return IKST.text("IGUI_IKST_Armed_Mode", "Mode") .. ": " .. title .. " · " .. IKST.text("IGUI_IKST_ClickWorld", "Click a square")
end

function IKST_JobsPanel:enterNav(modeId, toolId)
    modeId = modeId or IKST.VIEW.favorites
    if IKST_HubNav.isHomeView(modeId) then
        self:goHome()
        return
    end
    if not IKST_Access.canUseWorkspace(self.player, modeId) then
        return
    end
    self:disarmAllWorldTools()
    local state = IKST.getPlayerState(self.player)
    if state then
        IKST_HubNav.applyNav(state, modeId, toolId)
        modeId = state.navMode or modeId
        toolId = state.navTool or toolId
    end
    self.view = modeId
    self:refreshJobUI()
    IKST_HubNav.onNavEntered(self, modeId, toolId)
end

function IKST_JobsPanel:enterTab(tab, subMode)
    local mode, tool = IKST_HubNav.resolveView(tab)
    if subMode then
        tool = subMode
    end
    self:enterNav(mode, tool)
end

function IKST_JobsPanel:enterJob(view)
    local mode, tool = IKST_HubNav.resolveView(view)
    self:enterNav(mode, tool)
end

function IKST_JobsPanel:goHome()
    self:disarmAllWorldTools()
    local state = IKST.getPlayerState(self.player)
    if state then
        IKST_HubNav.applyNav(state, IKST.VIEW.favorites, nil)
    end
    self.view = IKST.VIEW.favorites
    self:refreshJobUI()
    if IKST_HudChip and IKST_HudChip.sync then
        IKST_HudChip.sync(self.player)
    end
end

function IKST_JobsPanel:goFavorites()
    self:goHome()
end

function IKST_JobsPanel:goHub()
    self:goFavorites()
end

function IKST_JobsPanel:onInspectResult(args)
    local state = IKST.getPlayerState(self.player)
    if state and args then
        state.lastInspect = args
    end
    self:refreshJobUI()
end

function IKST_JobsPanel:updateNav()
    if IKST_HubNav.buildSidebar then
        IKST_HubNav.buildSidebar(self)
    end
end

function IKST_JobsPanel:updateTarget()
    if not self.q2Panel then
        self._q2HasContent = false
        return
    end
    local state = IKST.getPlayerState(self.player)
    local tool = state and state.navTool
    local cc = IKUI_Chrome.colors
    local x = 8
    local y = 4
    local targetText = ""
    local subText = ""
    local icon = nil
    local hasContent = false

    if self.view == IKST.VIEW.tiles then
        if tool == "inspect" and state and state.lastInspect then
            targetText = "Square: " .. state.lastInspect.x .. ", " .. state.lastInspect.y .. ", " .. state.lastInspect.z
            subText = (state.lastInspect.objects or 0) .. " objects"
            hasContent = true
        end
    elseif self.view == IKST.VIEW.vehicles then
        local tool = state and state.navTool
        if tool == "spawn" or tool == "cleanup" or tool == "prune" then
            if not IKST_JobVehicle or not IKST_JobVehicle.listCache or #IKST_JobVehicle.listCache == 0 then
                if not self._vehicleListRequested then
                    self._vehicleListRequested = true
                    if IKST_JobVehicle and IKST_JobVehicle.requestList then
                        IKST_JobVehicle.requestList(self.player)
                    end
                end
                targetText = IKST.text("IGUI_IKST_LoadingVehicles", "Loading vehicles...")
                hasContent = true
            else
                targetText = IKST.text("IGUI_IKST_Vehicles_ListReady", "Vehicles")
                subText = tostring(#IKST_JobVehicle.listCache) .. " nearby"
                hasContent = true
            end
        else
            local v = IKST_VehicleOps and IKST_VehicleOps.resolveNearVehicle and IKST_VehicleOps.resolveNearVehicle(self.player)
            if v then
                targetText = v:getScript():getName() or "Vehicle"
                subText = "ID: " .. v:getId()
                hasContent = true
            end
        end
    elseif self.view == IKST.VIEW.loot then
        local preview = IKST_JobLoot and IKST_JobLoot.previewForPanel and IKST_JobLoot.previewForPanel(self)
        if preview and IKST_LootOps and IKST_LootOps.previewSummary then
            local line = IKST_LootOps.previewSummary(preview)
            if line and line ~= "" then
                targetText = IKST.text("IGUI_IKST_Loot_Affects", "Affects")
                subText = line
                hasContent = true
            end
        end
    end

    self._q2HasContent = hasContent == true
    if not hasContent then
        return
    end

    if not targetText or targetText == "" then
        targetText = IKST_HubNav.labelForNav(self.view, tool)
    end

    local titleColor = cc.textPrimary or cc.textMuted
    local title = ISLabel:new(x, y, 20, targetText, titleColor.r, titleColor.g, titleColor.b, 1, UIFont.Medium, true)
    title:initialise()
    self:addQ2Widget(title)
    if subText ~= "" then
        local sub = ISLabel:new(x, y + 20, 16, subText, cc.textMuted.r, cc.textMuted.g, cc.textMuted.b, 1, UIFont.Small, true)
        sub:initialise()
        self:addQ2Widget(sub)
    end
end

function IKST_JobsPanel:updateActions(preserveScroll)
    IKST_JobLayout.begin(self, { preserveScroll = preserveScroll == true })
    local contentY = 8
    if self.view == IKST.VIEW.utilities and IKST_JobUtilities then
        contentY = IKST_JobUtilities.build(self) or contentY
    elseif self.view == IKST.VIEW.claim and IKST_JobClaim then
        contentY = IKST_JobClaim.build(self) or contentY
    elseif self.view == IKST.VIEW.tiles and IKST_JobWorldEdit then
        contentY = IKST_JobWorldEdit.build(self) or contentY
    elseif self.view == IKST.VIEW.vehicles then
        if IKST.Plugins and IKST.Plugins.buildJobTool then
            local st = IKST.getPlayerState(self.player)
            local toolId = st and st.navTool
            contentY = IKST.Plugins.buildJobTool(self, toolId) or contentY
        elseif IKST_JobVehicle then
            contentY = IKST_JobVehicle.build(self) or contentY
        end
    elseif self.view == IKST.VIEW.economy and IKST.Plugins and IKST.Plugins.buildJobTool then
        contentY = IKST.Plugins.buildJobTool(self, "economy") or contentY
    elseif self.view == IKST.VIEW.loot and IKST.Plugins and IKST.Plugins.buildJobTool then
        contentY = IKST.Plugins.buildJobTool(self, "loot") or contentY
    elseif self.view == IKST.VIEW.admin and IKST.Plugins and IKST.Plugins.buildJobTool then
        contentY = IKST.Plugins.buildJobTool(self, "admin") or contentY
    elseif self.view == IKST.VIEW.everyone and IKST_JobEveryone then
        contentY = IKST_JobEveryone.build(self) or contentY
    elseif self.view == IKST.VIEW.build and IKST_JobWorldEdit then
        contentY = IKST_JobWorldEdit.build(self) or contentY
    elseif self.view == IKST.VIEW.server and IKST_JobWorldEdit then
        contentY = IKST_JobWorldEdit.buildForServer(self) or contentY
    elseif self.view == IKST.VIEW.quick and IKST_JobGadgets then
        contentY = IKST_JobGadgets.build(self) or contentY
    end
    self.bodyY = contentY
    IKST_JobLayout.finish(self, contentY)
end

function IKST_JobsPanel:updateLog()
    if self.logPanel then
        local widget = self.logPanel._ikstLogCard or self.logPanel
        if widget.parent and widget.parent.removeChild then
            widget.parent:removeChild(widget)
        end
    end
    self.logPanel = nil
    if self.q4Panel then
        self.q4Panel:setVisible(false)
    end
end

function IKST_JobsPanel:refreshJobUI(preserveScroll)
    -- Rebuild on the next prerender so a click/network result cannot mutate
    -- children while Java is still walking the UI list (IndexOutOfBounds).
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
    if not self.jobLayer then
        return
    end
    if IKST_HubNav.isHomeView(self.view) then
        self._q2HasContent = false
        -- Home draws via prerender (drawHome) + panel children (addHomeWidget).
        -- A visible clipped jobLayer stencils over that paint and leaves a blank body.
        self.jobLayer:setVisible(false)
        if self.q1Panel then
            self.q1Panel:setVisible(false)
        end
        if self.q2Panel then
            self.q2Panel:setVisible(false)
        end
        if self.q3Panel then
            self.q3Panel:setVisible(false)
        end
        if self.q4Panel then
            self.q4Panel:setVisible(false)
        end
        self:updateLog()
        IKST_JobLayout.syncHomeNav(self)
        if IKST_HubNav.buildDashboard then
            IKST_HubNav.buildDashboard(self)
        end
        return
    end
    self.jobLayer:setVisible(true)
    self:updateNav()
    self:updateTarget()
    self:updateActions(preserveScroll)
    self:updateLog()
    IKST_JobLayout.syncHomeNav(self)
    if IKST_Preview and IKST_Preview.syncForPanel then
        IKST_Preview.syncForPanel(self)
    end
    self._lastBuiltView = self.view
    self._lastBuiltTool = tool
end

function IKST_JobsPanel:drawHome(bodyY)
    self.homeHits = {}
    if IKST_HubNav.drawDashboard then
        IKST_HubNav.drawDashboard(self, bodyY)
    end
end

function IKST_JobsPanel:getHintText()
    if IKST_HubNav.isHomeView(self.view) then
        return IKST.text("IGUI_IKST_Tip_Home", "Tip: Open a dashboard card, then use the left tools.")
    end
    if self.view == IKST.VIEW.utilities then
        return IKST.text("IGUI_IKST_Tip_Utilities", "Tip: Admin utilities — pick a category on the left")
    end
    if self.view == IKST.VIEW.claim then
        return IKST.text("IGUI_IKST_Tip_Claim", "Tip: Claim land or register a vehicle")
    end
    if self.view == IKST.VIEW.tiles then
        local state = IKST.getPlayerState(self.player)
        local tool = state and state.navTool or "remove"
        if tool == "paint" then
            return IKST.text("IGUI_IKST_Tip_Painter", "Tip: Load a tile pack, pick a sprite, then paint")
        end
        if tool == "inspect" then
            return IKST.text("IGUI_IKST_Tip_Inspector", "Tip: Click a square to see what is on it")
        end
        if tool == "blueprints" then
            return IKST.text("IGUI_IKST_Tip_Blueprints", "Tip: Copy an 11x11 area, then paste where you stand")
        end
        if tool == "area" then
            return IKST.text("IGUI_IKST_Tip_Automation", "Tip: Pick area size S/M/L, stand in place, press a button")
        end
        return IKST.text("IGUI_IKST_Tip_Cleanup", "Tip: Pick what to remove, then right-click the ground")
    end
    if self.view == IKST.VIEW.everyone then
        return IKST.text("IGUI_IKST_Tip_Everyone", "Tip: Helpful info for all players on the server")
    end
    if self.view == IKST.VIEW.build then
        return IKST.text("IGUI_IKST_Tip_Server", "Tip: Use the list on the left to switch tools")
    end
    if self.view == IKST.VIEW.quick then
        return IKST.text("IGUI_IKST_Tip_Quick", "Tip: Common admin actions on one scrollable page")
    end
    if self.view == IKST.VIEW.cleanup then
        return IKST.text("IGUI_IKST_Tip_Cleanup", "Tip: Pick what to remove, then right-click the ground")
    end
    if self.view == IKST.VIEW.painter then
        return IKST.text("IGUI_IKST_Tip_Painter", "Tip: Load a tile pack, pick a sprite, then paint")
    end
    if self.view == IKST.VIEW.vehicles then
        return IKST.text("IGUI_IKST_Tip_Vehicle", "Tip: Nearby tab lists cars around you")
    end
    if self.view == IKST.VIEW.threat then
        return IKST.text("IGUI_IKST_Tip_Threat", "Tip: Scan counts zombies; Clear removes them")
    end
    if self.view == IKST.VIEW.inspector then
        return IKST.text("IGUI_IKST_Tip_Inspector", "Tip: Click a square to see what is on it")
    end
    if self.view == IKST.VIEW.staff then
        return IKST.text("IGUI_IKST_Tip_Staff", "Tip: Engine cheats (God, Build, etc.) show only with -debug in SP; always in MP")
    end
    if self.view == IKST.VIEW.claim then
        return IKST.text("IGUI_IKST_Tip_Claim", "Tip: Scroll the panel for long lists; right-click world objects for quick claim actions")
    end
    if self.view == IKST.VIEW.economy then
        return IKST.text("IGUI_IKST_Tip_Economy", "Tip: Needs IKappaID PhoneShop mod installed")
    end
    if self.view == IKST.VIEW.loot then
        return IKST.text("IGUI_IKST_Tip_Loot", "Tip: Repopulate here, or arm and click the ground. Right-click a container also works.")
    end
    if self.view == IKST.VIEW.admin then
        return IKST.text("IGUI_IKST_Tip_Admin", "Tip: Kick and ban use vanilla server lists. Spectator is Ghost mode.")
    end
    if self.view == IKST.VIEW.automation then
        return IKST.text("IGUI_IKST_Tip_Automation", "Tip: Pick area size S/M/L, stand in place, press a button")
    end
    if self.view == IKST.VIEW.guard then
        return IKST.text("IGUI_IKST_Tip_Guard", "Tip: Safe areas tab lets you claim land; Cars tab claims vehicles")
    end
    return IKST.text("IGUI_IKST_Tip_Home", "Tip: Pick a mode, then a tool on the left. Pinned actions are above.")
end

function IKST_JobsPanel:statusStripTexts()
    local player = self.player
    local leftText = ""
    local rightText = IKST.text("IGUI_IKST_Player", "Player")
    local rightAccent = false
    local textX = IKUI_Config.hubMargin
    local homeBtn = self.homeNavBtn
    if homeBtn and type(homeBtn.getIsVisible) == "function" and homeBtn:getIsVisible() then
        textX = (homeBtn:getX() or 0) + (homeBtn:getWidth() or 0) + IKUI_Config.s(10)
    end
    if player then
        local x, py, z = 0, 0, 0
        if type(player.getX) == "function" then
            x = player:getX() or 0
        end
        if type(player.getY) == "function" then
            py = player:getY() or 0
        end
        if type(player.getZ) == "function" then
            z = player:getZ() or 0
        end
        leftText = string.format("%d, %d, %d  ·  Cell %d,%d",
            math.floor(x), math.floor(py), z, math.floor(x / 300), math.floor(py / 300))
        if IKST_Access and type(IKST_Access.isAdmin) == "function" and IKST_Access.isAdmin(player) then
            rightText = IKST.text("IGUI_IKST_Admin", "Admin")
            rightAccent = true
        end
    end
    return leftText, rightText, rightAccent, textX
end

function IKST_JobsPanel:prerender()
    if self._pendingRefresh then
        self._pendingRefresh = false
        local preserve = self._pendingPreserveScroll
        self._pendingPreserveScroll = nil
        self._flushRefresh = true
        self:refreshJobUI(preserve)
        self._flushRefresh = false
    end
    IKUI_Chrome.drawDockedShell(self)
    ISCollapsableWindow.prerender(self)
    if IKST_JobTilesGuard and IKST_JobTilesGuard.pruneOnOffFlash then
        IKST_JobTilesGuard.pruneOnOffFlash(self)
    end
    local chromeY = self:titleBarHeight()
    IKUI_Chrome.drawAccentBar(self, chromeY, 2)
    IKST_JobLayout.syncHomeNav(self)
    local statusY = chromeY + 2
    local leftText, rightText, rightAccent, textX = self:statusStripTexts()
    IKUI_Chrome.drawStatusStrip(self, leftText, rightText, statusY, {
        textX = textX,
        rightAccent = rightAccent,
        stripH = IKST_JobLayout.STATUS_HEIGHT,
    })
    local bannerY = statusY + (IKST_JobLayout.STATUS_HEIGHT or 28)
    local modeText = self:armedModeLabel()
    self._armedStopHit = nil
    if modeText then
        IKUI_Chrome.drawArmedBanner(self, bannerY, modeText, {
            height = IKST_JobLayout.armedBannerHeight(self),
            gripReserve = IKST_JobLayout.RESIZE_GRIP,
        })
    end
    if IKUI_Chrome.syncArmedStopButton then
        IKUI_Chrome.syncArmedStopButton(self)
    end
    if IKST_HubNav.isHomeView(self.view) then
        self:drawHome(IKST_HubNav.homeContentY(self))
    end
    IKUI_Chrome.drawHintStrip(self, self:getHintText(), IKST_JobLayout.hintStripY(self), {
        stripH = IKST_JobLayout.HINT_HEIGHT,
        gripReserve = IKST_JobLayout.RESIZE_GRIP,
    })
    if IKST_DragHandle and type(IKST_DragHandle.syncTab) == "function" then
        IKST_DragHandle.syncTab(self)
    end
end

function IKST_JobsPanel:onMouseUp(_x, _y)
    if IKST_DragHandle and IKST_DragHandle.onMouseUp(self) then
        return true
    end
    return true
end

function IKST_JobsPanel:onMouseMove(dx, dy)
    if IKST_DragHandle and IKST_DragHandle.onMouseMove(self, dx, dy) then
        return true
    end
    return false
end

function IKST_JobsPanel:onMouseMoveOutside(dx, dy)
    if IKST_DragHandle and IKST_DragHandle.onMouseMove(self, dx, dy) then
        return true
    end
    return false
end

function IKST_JobsPanel:onMouseDown(x, y)
    if IKST_JobLayout.isResizeGrip(self, x, y) then
        return ISCollapsableWindow.onMouseDown(self, x, y)
    end
    if IKST_HubNav.isHomeView(self.view) then
        if self.homeHits then
            for _, hit in ipairs(self.homeHits) do
                if x >= hit.x and x <= hit.x + hit.w and y >= hit.y and y <= hit.y + hit.h then
                    if hit.mode then
                        self:enterNav(hit.mode, IKST_HubNav.defaultTool(hit.mode))
                    end
                    return true
                end
            end
        end
    end
    return ISCollapsableWindow.onMouseDown(self, x, y)
end

function IKST_JobsPanel:onMouseWheel(del)
    local lists = self._ikstSelectLists or {}
    for i = 1, #lists do
        local list = lists[i]
        if list and type(list.isMouseOver) == "function" and list:isMouseOver()
            and type(list.onMouseWheel) == "function" then
            return list:onMouseWheel(del)
        end
    end
    local scroll = self.jobScroll
    local overScroll = scroll and type(scroll.isMouseOver) == "function" and scroll:isMouseOver()
    if not IKST_HubNav.isHomeView(self.view) and overScroll and type(scroll.setYScroll) == "function" then
        local cur = scroll:getYScroll() or 0
        scroll:setYScroll(cur - (del * 40))
        return true
    end
    return ISCollapsableWindow.onMouseWheel(self, del)
end

function IKST_JobsPanel:onBatchProgress(args)
    if not args then
        return
    end
    local state = IKST.getPlayerState(self.player)
    if state then
        state.batchProgress = args
    end
    if self.updateLog then
        self:updateLog()
    end
    if IKST_ActionLogWindow and type(IKST_ActionLogWindow.refreshForPlayer) == "function" then
        IKST_ActionLogWindow.refreshForPlayer(self.player)
    end
end

function IKST_JobsPanel:onServerResult(args)
    if IKST_ActionLogWindow and type(IKST_ActionLogWindow.refreshForPlayer) == "function" then
        IKST_ActionLogWindow.refreshForPlayer(self.player)
    end
    if self.player and args and args.message and IKST.shouldNotifyResult(args.mode) then
        IKST.notify(self.player, IKST.formatServerResult(args.message, args), args.success == true)
    end
    if args and (args.mode == IKST.CMD.quickWater or args.mode == IKST.CMD.quickPower) then
        self:refreshJobUI()
    end
    if args and args.success and IKST_JobStaff and (args.mode == IKST.CMD.saveWaypoint or args.mode == IKST.CMD.delWaypoint) then
        IKST_JobStaff.requestWaypoints(self.player)
    end
    if args and IKST_JobVehicle and IKST_JobVehicle.onServerResult then
        IKST_JobVehicle.onServerResult(self, args)
    end
    if args and IKST_JobLoot and IKST_JobLoot.onServerResult then
        IKST_JobLoot.onServerResult(self, args)
    end
end

function IKST_JobsPanel.prepareOpen(player)
    player = IKST.resolvePlayer(player)
    if not player then
        return nil
    end
    if IKST_PreviewOverlay and IKST_PreviewOverlay.clear then
        IKST_PreviewOverlay.clear()
    end
    local state = IKST.getPlayerState(player)
    return state
end

function IKST_JobsPanel:close()
    self:disarmAllWorldTools()
    if IKST_UIPrefs and IKST_UIPrefs.savePanelGeometry then
        IKST_UIPrefs.savePanelGeometry(self)
    end
    if IKST_DragHandle and type(IKST_DragHandle.hidePanel) == "function" then
        IKST_DragHandle.hidePanel(self)
    else
        self:setVisible(false)
    end
    if IKST_ActionLogWindow and type(IKST_ActionLogWindow.close) == "function" then
        IKST_ActionLogWindow.close()
    end
end

function IKST_JobsPanel.ensure()
    if IKST_JobsPanel.instance then
        if IKST_DragHandle and type(IKST_DragHandle.ensureTab) == "function" then
            IKST_DragHandle.ensureTab(IKST_JobsPanel.instance)
        end
        return IKST_JobsPanel.instance
    end
    IKST_JobLayout.syncHyperOsMetrics()
    local defW, defH = IKST_JobLayout.defaultSize()
    IKST_JobsPanel.WIDTH = defW
    IKST_JobsPanel.HEIGHT = defH
    IKST_JobsPanel.MIN_WIDTH = IKST_JobLayout.MIN_WIDTH
    IKST_JobsPanel.MIN_HEIGHT = IKST_JobLayout.MIN_HEIGHT
    local core = getCore()
    local sw = core:getScreenWidth()
    local sh = core:getScreenHeight()
    local edge = IKST_JobLayout.SCREEN_EDGE or 12
    local w, h = defW, defH
    local x, y = IKST_JobLayout.defaultPosition(w, h)
    if IKST_UIPrefs and IKST_UIPrefs.loadPanelGeometry then
        local geo = IKST_UIPrefs.loadPanelGeometry()
        if geo.x then
            x = geo.x
        end
        if geo.y then
            y = geo.y
        end
    end
    x = math.max(edge, math.min(x, sw - edge - w))
    y = math.max(edge, math.min(y, sh - edge - h))
    local panel = IKST_JobsPanel:new(x, y, w, h)
    panel:initialise()
    panel:addToUIManager()
    if type(ISUIElement) == "table" and type(ISUIElement.setVisible) == "function" then
        ISUIElement.setVisible(panel, false)
    else
        panel:setVisible(false)
    end
    IKST_JobLayout.syncCompactMode(panel)
    IKST_JobsPanel.instance = panel
    IKST_JobLayout.clampDockPosition(panel)
    if IKST_DragHandle and type(IKST_DragHandle.ensureTab) == "function" then
        IKST_DragHandle.ensureTab(panel)
    end
    if IKST_DragHandle and type(IKST_DragHandle.syncTab) == "function" then
        IKST_DragHandle.syncTab(panel)
    end
    return panel
end

function IKST_JobsPanel.applyOpenView(panel, player)
    if not panel or not player then
        return
    end
    local mode, tool = IKST_HubNav.resolveOpenView(player)
    if IKST_HubNav.isHomeView(mode) then
        panel.view = IKST.VIEW.favorites
        local state = IKST.getPlayerState(player)
        if state then
            IKST_HubNav.applyNav(state, IKST.VIEW.favorites, nil)
        end
        panel:refreshJobUI()
        return
    end
    panel:enterNav(mode, tool)
end

function IKST_JobsPanel.open(player)
    player = IKST.resolvePlayer(player)
    if not player or not IKST_Access.canOpenPanel(player) then
        return
    end
    IKST_JobsPanel.prepareOpen(player)
    local panel = IKST_JobsPanel.ensure()
    panel.player = player
    if IKST_JobLayout and type(IKST_JobLayout.restorePanelPosition) == "function" then
        IKST_JobLayout.restorePanelPosition(panel)
    end
    IKST_JobLayout.syncCompactMode(panel)
    IKST_JobsPanel.applyOpenView(panel, player)
    if IKST_DragHandle and type(IKST_DragHandle.showPanel) == "function" then
        IKST_DragHandle.showPanel(panel)
    else
        panel:setVisible(true)
        if panel.bringToTop then
            panel:bringToTop()
        end
    end
    if IKST_ActionLogWindow and type(IKST_ActionLogWindow.open) == "function" then
        IKST_ActionLogWindow.open(player)
    end
    if IKST_HudChip and IKST_HudChip.sync then
        IKST_HudChip.sync(player)
    end
end

function IKST_JobsPanel.toggle(player)
    player = IKST.resolvePlayer(player)
    if not player or not IKST_Access.canOpenPanel(player) then
        return
    end
    local panel = IKST_JobsPanel.ensure()
    if panel:getIsVisible() then
        if IKST_UIPrefs and IKST_UIPrefs.savePanelGeometry then
            IKST_UIPrefs.savePanelGeometry(panel)
        end
        if IKST_DragHandle and type(IKST_DragHandle.hidePanel) == "function" then
            IKST_DragHandle.hidePanel(panel)
        else
            panel:setVisible(false)
        end
        if IKST_ActionLogWindow and type(IKST_ActionLogWindow.close) == "function" then
            IKST_ActionLogWindow.close()
        end
        if IKST_HudChip and IKST_HudChip.sync then
            IKST_HudChip.sync(player)
        end
        return
    end
    IKST_JobsPanel.prepareOpen(player)
    panel.player = player
    if IKST_JobLayout and type(IKST_JobLayout.restorePanelPosition) == "function" then
        IKST_JobLayout.restorePanelPosition(panel)
    end
    IKST_JobLayout.syncCompactMode(panel)
    IKST_JobsPanel.applyOpenView(panel, player)
    if IKST_DragHandle and type(IKST_DragHandle.showPanel) == "function" then
        IKST_DragHandle.showPanel(panel)
    else
        panel:setVisible(true)
        if panel.bringToTop then
            panel:bringToTop()
        end
    end
    if IKST_ActionLogWindow and type(IKST_ActionLogWindow.open) == "function" then
        IKST_ActionLogWindow.open(player)
    end
    if IKST_HudChip and IKST_HudChip.sync then
        IKST_HudChip.sync(player)
    end
end


local function onArmedEscapeKey(key)
    if not Keyboard or key ~= Keyboard.KEY_ESCAPE then
        return
    end
    local panel = IKST_JobsPanel.instance
    if not panel or not panel.getIsVisible or not panel:getIsVisible() then
        return
    end
    local state = IKST.getPlayerState(panel.player)
    if state and state.armed and state.armedJob then
        panel:stopArmedMode()
    end
end

if Events and Events.OnKeyPressed and Events.OnKeyPressed.Add then
    Events.OnKeyPressed.Add(onArmedEscapeKey)
end

