if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then

    return

end



require "ISUI/ISCollapsableWindow"

require "ISUI/ISPanel"

require "ISUI/ISButton"

require "IKST_Shared"

require "IKST_Access"

require "IKST_Chrome"

require "IKST_JobLayout"
require "IKST_HubNav"



IKST_JobsPanel = ISCollapsableWindow:derive("IKST_JobsPanel")

IKST_JobsPanel.instance = nil

IKST_JobsPanel.WIDTH = 520

IKST_JobsPanel.HEIGHT = 720

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

    o.resizable = true

    o.minimumWidth = IKST_JobsPanel.MIN_WIDTH

    o.minimumHeight = IKST_JobsPanel.MIN_HEIGHT

    o.bodyY = 0

    o.hubHits = {}

    o.jobWidgets = {}

    o.chromeWidgets = {}

    o.logPanel = nil

    o._lastScrollContentH = 0

    IKST_Chrome.applyPanelColors(o)

    o:setTitle(IKST.text("IGUI_IKST_Title", "IKappaID Suite Tools"))

    return o

end



function IKST_JobsPanel:initialise()

    ISCollapsableWindow.initialise(self)

    if self.setResizable then

        self:setResizable(true)

    end

end



function IKST_JobsPanel:createChildren()

    ISCollapsableWindow.createChildren(self)

    self.jobLayer = ISPanel:new(0, 0, self.width, self.height)

    self.jobLayer.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }

    self.jobLayer.borderColor = { r = 0, g = 0, b = 0, a = 0 }

    self.jobLayer:initialise()

    self:addChild(self.jobLayer)

    self.jobLayer:setVisible(false)



    self.jobScroll = ISPanel:new(0, 0, self.width, self.height)

    self.jobScroll.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }

    self.jobScroll.borderColor = { r = 0, g = 0, b = 0, a = 0 }

    self.jobScroll:initialise()

    self.jobScroll:setScrollChildren(true)

    self.jobLayer:addChild(self.jobScroll)

    self.homeNavBtn = ISButton:new(6, 0, 52, 20, IKST.text("IGUI_IKST_BackHome", "Home"), self, IKST_JobsPanel.onHomeNavClick)
    self.homeNavBtn:initialise()
    IKST_Chrome.styleSecondaryButton(self.homeNavBtn)
    self:addChild(self.homeNavBtn)
    self.homeNavBtn:setVisible(false)

end



function IKST_JobsPanel.onHomeNavClick(_btn)
    if IKST_JobsPanel.instance then
        IKST_JobsPanel.instance:goHome()
    end
end



function IKST_JobsPanel:clearJobLayer()

    local list = self.jobWidgets or {}

    for i = #list, 1, -1 do

        local widget = list[i]

        if widget and self.jobScroll and self.jobScroll.removeChild then

            self.jobScroll:removeChild(widget)

        end

        list[i] = nil

    end

    self.jobWidgets = {}



    local chrome = self.chromeWidgets or {}

    for i = #chrome, 1, -1 do

        local widget = chrome[i]

        if widget and self.jobLayer and self.jobLayer.removeChild then

            self.jobLayer:removeChild(widget)

        end

        chrome[i] = nil

    end

    self.chromeWidgets = {}

    self.logPanel = nil

end



function IKST_JobsPanel:addChromeWidget(widget)

    if not widget or not self.jobLayer then

        return widget

    end

    table.insert(self.chromeWidgets, widget)

    self.jobLayer:addChild(widget)

    return widget

end



function IKST_JobsPanel:addJobWidget(widget)

    if not widget or not self.jobScroll then

        return widget

    end

    table.insert(self.jobWidgets, widget)

    self.jobScroll:addChild(widget)

    return widget

end



function IKST_JobsPanel:makeJobButton(x, y, w, h, label, onClick, primary)

    w = IKST_JobLayout.clampWidth(self, x, w)

    local btn = ISButton:new(x, y, w, h, label, self, onClick)

    btn:initialise()

    if primary then

        IKST_Chrome.stylePrimaryButton(btn)

    else

        IKST_Chrome.styleSecondaryButton(btn)

    end

    return self:addJobWidget(btn)

end



function IKST_JobsPanel:makeChromeButton(x, y, w, h, label, onClick, primary)

    local btn = ISButton:new(x, y, w, h, label, self, onClick)

    btn:initialise()

    if primary then

        IKST_Chrome.stylePrimaryButton(btn)

    else

        IKST_Chrome.styleSecondaryButton(btn)

    end

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

        if tm.MeasureStringX and tm:MeasureStringX(labelFont, labelText) > w then

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

        local cc = IKST_Chrome.colors

        local ly = 0

        for line in string.gmatch(wrapped .. "\n", "(.-)\n") do

            p:drawText(line, 0, ly, cc.textMuted.r, cc.textMuted.g, cc.textMuted.b, 1, labelFont)

            ly = ly + lineH

        end

    end

    return self:addJobWidget(label)

end



function IKST_JobsPanel:onResize()

    ISCollapsableWindow.onResize(self)

    IKST_JobLayout.relayoutJobLayer(self)

    IKST_JobLayout.syncHomeNav(self)

    if IKST_HubNav.isHomeView(self.view) then
        return
    end

    self:refreshJobUI(true)

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

    local state = IKST.getPlayerState(self.player)

    local buildTool = toolId or (state and state.navTool)

    if modeId == IKST.VIEW.tiles then
        buildTool = toolId or (state and state.navTool) or "remove"
        if buildTool ~= "paint" and IKST_PaintCursorManager and IKST_PaintCursorManager.disarm then
            IKST_PaintCursorManager.disarm(self.player)
        end
        if buildTool ~= "remove" and buildTool ~= "inspect" and IKST_WorldPick and IKST_WorldPick.disarm then
            IKST_WorldPick.disarm(self.player)
        end
    else

        if IKST_PaintCursorManager and IKST_PaintCursorManager.disarm then

            IKST_PaintCursorManager.disarm(self.player)

        end

        if IKST_WorldPick and IKST_WorldPick.disarm then

            IKST_WorldPick.disarm(self.player)

        end

    end

    if modeId ~= IKST.VIEW.loot and IKST_LootWorldPick and IKST_LootWorldPick.disarm then

        IKST_LootWorldPick.disarm(self.player)

    end

    if state then

        IKST_HubNav.applyNav(state, modeId, toolId)

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

    if IKST_WorldPick and IKST_WorldPick.disarm then

        IKST_WorldPick.disarm(self.player)

    end

    if IKST_LootWorldPick and IKST_LootWorldPick.disarm then

        IKST_LootWorldPick.disarm(self.player)

    end

    if IKST_PaintCursorManager and IKST_PaintCursorManager.disarm then

        IKST_PaintCursorManager.disarm(self.player)

    end

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



function IKST_JobsPanel:refreshJobUI(preserveScroll)

    local state = IKST.getPlayerState(self.player)

    local tool = state and state.navTool

    if preserveScroll == nil then

        preserveScroll = (self._lastBuiltView == self.view and self._lastBuiltTool == tool)

    end

    self:clearJobLayer()

    if not self.jobLayer then

        return

    end

    if IKST_HubNav.isHomeView(self.view) then

        self.jobLayer:setVisible(false)

        IKST_JobLayout.syncHomeNav(self)

        return

    end

    self.jobLayer:setVisible(true)

    self._logHeightOverride = nil

    if self.view == IKST.VIEW.claim then

        self._logHeightOverride = 72

    end

    IKST_JobLayout.begin(self, { preserveScroll = preserveScroll == true })

    if IKST_HubNav.buildSidebar then

        IKST_HubNav.buildSidebar(self)

    end

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

    IKST_JobLayout.syncHomeNav(self)



    if IKST_Preview and IKST_Preview.syncForPanel then

        IKST_Preview.syncForPanel(self)

    end

    self._lastBuiltView = self.view

    self._lastBuiltTool = tool

end



function IKST_JobsPanel:drawHome(bodyY)

    self.homeHits = {}

    if IKST_HubNav.drawHomeModes then

        IKST_HubNav.drawHomeModes(self, bodyY)

    end

end



function IKST_JobsPanel:getHintText()

    if IKST_HubNav.isHomeView(self.view) then

        return IKST.text("IGUI_IKST_Tip_Home", "Tip: Pick a workspace, then a tool on the left.")

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

        return IKST.text("IGUI_IKST_Tip_Staff", "Tip: You tab heals you; Weather tab changes time and rain")

    end

    if self.view == IKST.VIEW.claim then

        return IKST.text("IGUI_IKST_Tip_Claim", "Tip: Scroll the panel for long lists; right-click world objects for quick claim actions")

    end

    if self.view == IKST.VIEW.economy then

        return IKST.text("IGUI_IKST_Tip_Economy", "Tip: Needs IKappaID PhoneShop mod installed")

    end

    if self.view == IKST.VIEW.loot then

        return IKST.text("IGUI_IKST_Tip_Loot", "Tip: Right-click a container, or pick a scope and click the ground")

    end

    if self.view == IKST.VIEW.automation then

        return IKST.text("IGUI_IKST_Tip_Automation", "Tip: Pick area size S/M/L, stand in place, press a button")

    end

    if self.view == IKST.VIEW.guard then

        return IKST.text("IGUI_IKST_Tip_Guard", "Tip: Safe areas tab lets you claim land; Cars tab claims vehicles")

    end

    return IKST.text("IGUI_IKST_Tip_Home", "Tip: Pick a mode, then a tool on the left. Pinned actions are above.")

end



function IKST_JobsPanel:prerender()

    IKST_Chrome.applyPanelColors(self)

    ISCollapsableWindow.prerender(self)

    local chromeY = self:titleBarHeight()

    IKST_Chrome.drawAccentBar(self, chromeY, 2)

    IKST_Chrome.drawStatusStrip(self, self.player, chromeY + 2)

    IKST_JobLayout.syncHomeNav(self)

    if IKST_HubNav.isHomeView(self.view) then

        self:drawHome(IKST_HubNav.homeContentY(self))

    end

    IKST_Chrome.drawHintStrip(self, self:getHintText(), self.height - IKST_JobLayout.HINT_HEIGHT)

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

    if self.view ~= IKST.VIEW.favorites and self.view ~= IKST.VIEW.hub and self.jobScroll and self.jobScroll.onMouseWheel then

        return self.jobScroll:onMouseWheel(del)

    end

    return ISCollapsableWindow.onMouseWheel(self, del)

end



function IKST_JobsPanel:onServerResult(args)

    if self.logPanel and IKST_ActionLog then

        IKST_ActionLog.refresh(self.logPanel, self.player)

    end

    if self.player and args and args.message and IKST.shouldNotifyResult(args.mode) then

        IKST.notify(self.player, tostring(args.message), args.success == true)

    end

    if args and (args.mode == IKST.CMD.quickWater or args.mode == IKST.CMD.quickPower) then

        self:refreshJobUI()

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

    self:setVisible(false)

end



function IKST_JobsPanel.ensure()

    if IKST_JobsPanel.instance then

        return IKST_JobsPanel.instance

    end

    local core = getCore()

    local sw = core:getScreenWidth()

    local sh = core:getScreenHeight()

    local x = math.floor((sw - IKST_JobsPanel.WIDTH) / 2)

    local y = math.floor((sh - IKST_JobsPanel.HEIGHT) / 2)

    local panel = IKST_JobsPanel:new(x, y)

    panel:initialise()

    panel:addToUIManager()

    panel:setVisible(false)

    IKST_JobsPanel.instance = panel

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

    IKST_JobsPanel.applyOpenView(panel, player)

    panel:setVisible(true)

    if panel.bringToTop then

        panel:bringToTop()

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

        panel:setVisible(false)

        if IKST_HudChip and IKST_HudChip.sync then

            IKST_HudChip.sync(player)

        end

        return

    end

    IKST_JobsPanel.prepareOpen(player)

    panel.player = player

    IKST_JobsPanel.applyOpenView(panel, player)

    panel:setVisible(true)

    if panel.bringToTop then

        panel:bringToTop()

    end

    if IKST_HudChip and IKST_HudChip.sync then

        IKST_HudChip.sync(player)

    end

end


