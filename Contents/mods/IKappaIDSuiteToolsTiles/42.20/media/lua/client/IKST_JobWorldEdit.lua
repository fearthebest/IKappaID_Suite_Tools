if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISButton"
require "ISUI/ISLabel"
require "IKST_Shared"
require "IKST_Plugins"
require "IKST_Chrome"
require "IKST_UI_Layout"
require "IKST_ActionLog"
require "IKST_JobLayout"
require "IKST_JobGuard"
require "IKST_JobAutomation"
require "IKST_JobCleanup"
require "IKST_JobPainter"
require "IKST_JobInspector"
require "IKST_JobStaff"
require "IKST_JobTilesGuard"
require "IKST_Rewind"
require "IKST_WorldPick"
require "IKST_Confirm"

IKST_JobWorldEdit = IKST_JobWorldEdit or {}

-- Tiles landing page (mockup: ikst-page-tiles.png): sectioned pill grids that
-- call existing arm / nav / automation handlers. Placeholders listed in
-- docs/UI-PLACEHOLDERS.md.

local function flowLayout(items, cardW, gap)
    local padX = IKST_UI_Layout.s(14)
    local usableW = math.max(40, cardW - (padX * 2))
    local rows = {}
    local curRow = {}
    local curX = 0
    for _, item in ipairs(items) do
        local w = IKST_UI_Layout.buttonWidth(item.label, UIFont.Small, 96)
        if curX > 0 and curX + gap + w > usableW then
            rows[#rows + 1] = curRow
            curRow = {}
            curX = 0
        end
        if curX > 0 then
            curX = curX + gap
        end
        curRow[#curRow + 1] = { item = item, x = padX + curX, w = w }
        curX = curX + w
    end
    if #curRow > 0 then
        rows[#rows + 1] = curRow
    end
    return rows
end

local function renderPillRows(cardPanel, panel, rows, startY, rowH, gap)
    local y = startY
    for _, row in ipairs(rows) do
        for _, cell in ipairs(row) do
            local item = cell.item
            local kind = "chip"
            if item.danger then
                kind = "danger"
            elseif not item.placeholder and item.on == true then
                kind = "primary"
            end
            local btn = IKST_Chrome.newActionButton(cell.x, y, cell.w, rowH, item.label, panel, function()
                if item.onClick then
                    item.onClick()
                end
                panel:refreshJobUI()
            end, kind)
            cardPanel:addChild(btn)
        end
        y = y + rowH + gap
    end
    return y
end

local function buildPillSection(panel, x, y, w, icon, titleKey, titleFallback, items)
    local rowH = math.max(26, IKST_UI_Layout.s(30))
    local gap = IKST_UI_Layout.s(8)
    local rows = flowLayout(items, w, gap)
    local headerH = IKST_Chrome.sectionHeaderH()
    local bottomPad = IKST_UI_Layout.s(14)
    local contentH = (#rows * rowH) + (math.max(0, #rows - 1) * gap)
    if #rows == 0 then
        contentH = rowH
    end
    local cardH = headerH + contentH + bottomPad
    local title = IKST.text(titleKey, titleFallback)
    local card, contentY = IKST_Chrome.newSectionCardPanel(x, y, w, cardH, icon, title)
    panel:addJobWidget(card)
    renderPillRows(card, panel, rows, contentY, rowH, gap)
    return y + cardH + (IKST_JobLayout.GAP or gap)
end

local function armedLabel(state)
    if not state or not state.armed then
        return IKST.text("IGUI_IKST_TilesTile_ArmedNone", "Armed: none — pick a tool above")
    end
    local job = tostring(state.armedJob or "?")
    local detail = ""
    if state.armedJob == IKST.VIEW.cleanup then
        detail = IKST.cleanupActionLabel(IKST.getCleanupAction(state))
    elseif state.armedJob == IKST.VIEW.painter then
        detail = tostring(state.painterMode or "paint")
    elseif state.armedJob == IKST.VIEW.inspector then
        detail = IKST.text("IGUI_IKST_Job_Inspector", "Inspect tile")
    elseif state.worldPickCommand then
        detail = tostring(state.worldPickCommand)
    else
        detail = job
    end
    return IKST.text("IGUI_IKST_TilesTile_ArmedPrefix", "Armed:") .. " " .. detail
        .. " — " .. IKST.text("IGUI_IKST_TilesTile_ArmedHint", "click a tile in the world")
end

function IKST_JobWorldEdit.buildOverview(panel)
    local p = panel.player
    if not p then
        return 8
    end
    local state = IKST.getPlayerState(p)
    if not state then
        return 8
    end

    local x = panel.contentX or IKST_JobLayout.MARGIN
    local w = math.max(220, panel.contentW or (panel.width - 24))
    local y = 8
    local gap = IKST_JobLayout.GAP or IKST_UI_Layout.s(12)
    local headerBtnH = math.max(24, IKST_UI_Layout.s(28))
    local cc = IKST_Chrome.colors

    local title = IKST.text("IGUI_IKST_WS_World", "Tiles")
    local titleLabel = ISLabel:new(x, y, 26, title, 1, 1, 1, 1, UIFont.Large, true)
    titleLabel:initialise()
    panel:addJobWidget(titleLabel)

    local undoLabel = IKST.text("IGUI_IKST_TilesTile_Undo", "Undo last")
    local undoW = IKST_UI_Layout.buttonWidth(undoLabel, UIFont.Small, 90)
    local previewLabel = IKST.text("IGUI_IKST_TilesTile_Preview", "Preview mode")
    local previewW = IKST_UI_Layout.buttonWidth(previewLabel, UIFont.Small, 100)
    local rightEdge = x + w
    local undoX = rightEdge - undoW
    local previewX = undoX - IKST_UI_Layout.s(8) - previewW
    local rewindCount = (IKST_Rewind and IKST_Rewind.count and IKST_Rewind.count(p)) or 0
    if rewindCount > 0 then
        undoLabel = undoLabel .. " (" .. tostring(rewindCount) .. ")"
        undoW = IKST_UI_Layout.buttonWidth(undoLabel, UIFont.Small, 90)
        undoX = rightEdge - undoW
        previewX = undoX - IKST_UI_Layout.s(8) - previewW
    end

    local previewOn = panel._tilesPreviewMode == true
    local previewBtn = IKST_Chrome.newActionButton(previewX, y, previewW, headerBtnH, previewLabel, panel, function()
        panel._tilesPreviewMode = not (panel._tilesPreviewMode == true)
        if IKST_Preview and IKST_Preview.syncForPanel then
            IKST_Preview.syncForPanel(panel)
        end
        panel:refreshJobUI()
    end, previewOn and "primary" or "chip")
    panel:addJobWidget(previewBtn)

    local undoBtn = IKST_Chrome.newActionButton(undoX, y, undoW, headerBtnH, undoLabel, panel, function()
        if IKST_WorldPick and IKST_WorldPick.disarm then
            IKST_WorldPick.disarm(p)
        end
        IKST.dispatchCommand(p, IKST.CMD.rewind, {})
        panel:refreshJobUI()
    end, "outline")
    panel:addJobWidget(undoBtn)

    y = y + math.max(26, headerBtnH) + gap

    local cleanupArmed = state.armed and state.armedJob == IKST.VIEW.cleanup
    local painterArmed = state.armed and state.armedJob == IKST.VIEW.painter
    local inspectArmed = state.armed and state.armedJob == IKST.VIEW.inspector
    local protectArmed = IKST_JobTilesGuard and IKST_JobTilesGuard.pickActive
        and IKST_JobTilesGuard.pickActive(state, IKST.CMD.protectSquare)
    local lockArmed = IKST_JobTilesGuard and IKST_JobTilesGuard.pickActive
        and IKST_JobTilesGuard.pickActive(state, IKST.CMD.lockSetPassword)

    y = buildPillSection(panel, x, y, w, "media/ui/ikst/ws_world.png",
        "IGUI_IKST_TilesTile_SectionPaint", "Paint & remove", {
        {
            label = IKST.text("IGUI_IKST_Mode_RemoveTile", "Remove tile"),
            on = cleanupArmed and IKST.getCleanupAction(state) == IKST.CLEANUP_MODES.removeTile,
            onClick = function()
                if IKST_JobCleanup and IKST_JobCleanup.selectAction then
                    IKST_JobCleanup.selectAction(panel, IKST.CLEANUP_MODES.removeTile)
                end
            end,
        },
        {
            label = IKST.text("IGUI_IKST_TilesTile_PaintFloor", "Paint floor"),
            on = painterArmed and state.painterMode == IKST.PAINTER_MODES.paint,
            onClick = function()
                if IKST_PaintCursorManager and IKST_PaintCursorManager.arm then
                    IKST_PaintCursorManager.arm(p, IKST.PAINTER_MODES.paint)
                end
            end,
        },
        {
            label = IKST.text("IGUI_IKST_TilesTile_PaintWall", "Paint wall"),
            on = painterArmed and state.painterMode == IKST.PAINTER_MODES.wall,
            onClick = function()
                if IKST_PaintCursorManager and IKST_PaintCursorManager.arm then
                    IKST_PaintCursorManager.arm(p, IKST.PAINTER_MODES.wall)
                end
            end,
        },
        {
            label = IKST.text("IGUI_IKST_TilesTile_EraseZone", "Erase zone"),
            on = cleanupArmed and IKST.getCleanupAction(state) == IKST.CLEANUP_MODES.vegetation,
            onClick = function()
                if IKST_JobCleanup and IKST_JobCleanup.selectAction then
                    IKST_JobCleanup.selectAction(panel, IKST.CLEANUP_MODES.vegetation)
                end
            end,
        },
        {
            label = IKST.text("IGUI_IKST_TilesTile_PickSprite", "Pick sprite"),
            on = painterArmed and state.painterMode == IKST.PAINTER_MODES.eyedropper,
            onClick = function()
                if IKST_PaintCursorManager and IKST_PaintCursorManager.arm then
                    IKST_PaintCursorManager.arm(p, IKST.PAINTER_MODES.eyedropper)
                end
            end,
        },
    })

    y = buildPillSection(panel, x, y, w, "media/ui/ikst/tool_items.png",
        "IGUI_IKST_TilesTile_SectionInspect", "Inspect & build", {
        {
            label = IKST.text("IGUI_IKST_Job_Inspector", "Inspect tile"),
            on = inspectArmed,
            onClick = function()
                if IKST_WorldPick and IKST_WorldPick.armInspect then
                    IKST_WorldPick.armInspect(p)
                end
            end,
        },
        {
            label = IKST.text("IGUI_IKST_TilesTile_BlueprintGrab", "Blueprint grab"),
            onClick = function()
                if panel.enterNav then
                    panel:enterNav(IKST.VIEW.tiles, "blueprints")
                end
            end,
        },
        {
            label = IKST.text("IGUI_IKST_TilesTile_BlueprintPlace", "Blueprint place"),
            onClick = function()
                if panel.enterNav then
                    panel:enterNav(IKST.VIEW.tiles, "blueprints")
                end
            end,
        },
        {
            label = IKST.text("IGUI_IKST_TilesTile_ContainerAudit", "Container audit"),
            on = inspectArmed and state.inspectAudit == true,
            onClick = function()
                if panel.enterNav then
                    panel:enterNav(IKST.VIEW.tiles, "inspect")
                end
                if IKST_WorldPick and IKST_WorldPick.armInspect then
                    IKST_WorldPick.armInspect(p, false, true)
                end
            end,
        },
    })

    y = buildPillSection(panel, x, y, w, "media/ui/ikst/tool_protect.png",
        "IGUI_IKST_TilesTile_SectionProtect", "Protect & locks", {
        {
            label = IKST.text("IGUI_IKST_TilesTile_ProtectArea", "Protect area"),
            on = protectArmed == true,
            onClick = function()
                if IKST_JobTilesGuard and IKST_JobTilesGuard.armSquarePick then
                    IKST_JobTilesGuard.setOnOffFeedback(panel, "protectSquare", true)
                    IKST_JobTilesGuard.armSquarePick(panel, IKST.CMD.protectSquare, nil, "IGUI_IKST_Guard_ClickProtect", function()
                        IKST_JobTilesGuard.requestList(p)
                    end)
                end
            end,
        },
        {
            label = IKST.text("IGUI_IKST_TilesTile_PasswordLock", "Password lock"),
            on = lockArmed == true,
            onClick = function()
                if panel.enterNav then
                    panel:enterNav(IKST.VIEW.tiles, "protect")
                end
            end,
        },
        {
            label = IKST.text("IGUI_IKST_TilesTile_ContainerRules", "Container rules"),
            onClick = function()
                if panel.enterNav then
                    panel:enterNav(IKST.VIEW.tiles, "protect")
                end
            end,
        },
        {
            label = IKST.text("IGUI_IKST_TilesTile_AreaWhitelist", "Area whitelist"),
            on = IKST_JobTilesGuard and IKST_JobTilesGuard.pickActive
                and IKST_JobTilesGuard.pickActive(state, IKST.CMD.unprotectSquare),
            onClick = function()
                if IKST_JobTilesGuard and IKST_JobTilesGuard.armSquarePick then
                    IKST_JobTilesGuard.setOnOffFeedback(panel, "protectSquare", false)
                    IKST_JobTilesGuard.armSquarePick(panel, IKST.CMD.unprotectSquare, nil, "IGUI_IKST_Guard_ClickUnprotect", function()
                        IKST_JobTilesGuard.requestList(p)
                    end)
                end
            end,
        },
    })

    local autoItems = {
        {
            label = IKST.text("IGUI_IKST_TilesTile_AutoCleanup", "Auto cleanup"),
            onClick = function()
                if IKST_JobAutomation and IKST_JobAutomation.dispatchRadius then
                    IKST_JobAutomation.dispatchRadius(panel, IKST.CMD.autoGardener)
                end
            end,
        },
        {
            label = IKST.text("IGUI_IKST_TilesTile_ScheduleReset", "Schedule reset"),
            onClick = function()
                IKST_Confirm.show(
                    IKST.text("IGUI_IKST_TilesTile_ConfirmReset",
                        "Paste the last copied blueprint back onto its original tiles? Copy a build first if you have not."),
                    function()
                        IKST.dispatchCommand(p, IKST.CMD.blueprintPaste, {
                            x = math.floor(p:getX()),
                            y = math.floor(p:getY()),
                            z = p:getZ(),
                            reset = true,
                        })
                    end
                )
            end,
        },
        {
            label = IKST.text("IGUI_IKST_TilesTile_RegionWipe", "Region wipe"),
            danger = true,
            onClick = function()
                IKST_Confirm.showDestructive(
                    IKST.text("IGUI_IKST_TilesTile_ConfirmWipe", "Wipe all objects in radius? This cannot be undone easily."),
                    function()
                        if IKST_JobAutomation and IKST_JobAutomation.dispatchRadius then
                            IKST_JobAutomation.dispatchRadius(panel, IKST.CMD.autoHomeWreck)
                        end
                    end
                )
            end,
        },
    }
    y = buildPillSection(panel, x, y, w, "media/ui/ikst/tool_servertools.png",
        "IGUI_IKST_TilesTile_SectionAuto", "Automation", autoItems)

    local stripH = math.max(32, IKST_UI_Layout.s(36))
    local strip = ISPanel:new(x, y, w, stripH)
    strip:initialise()
    strip.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    strip.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    local label = armedLabel(state)
    strip.render = function(self)
        IKST_Chrome.drawRoundedCard(self, 0, 0, self.width, self.height, {
            fill = cc.bgToolbar,
            borderColor = cc.accent,
            borderWidth = 1,
            shadow = false,
        })
        local _, th = IKST_UI_Layout.textSize(label, UIFont.Small)
        self:drawText(label, IKST_UI_Layout.s(14), math.floor((self.height - th) / 2),
            cc.accent.r, cc.accent.g, cc.accent.b, 1, UIFont.Small)
    end
    panel:addJobWidget(strip)
    y = y + stripH + gap

    return y
end

function IKST_JobWorldEdit.build(panel)
    local state = IKST.getPlayerState(panel.player)
    if not state then
        return 8
    end
    local tool = state.navTool or "overview"
    if tool == "overview" and IKST_JobWorldEdit.buildOverview then
        return IKST_JobWorldEdit.buildOverview(panel)
    end
    if IKST.Plugins and IKST.Plugins.buildJobTool then
        local y = IKST.Plugins.buildJobTool(panel, tool)
        if y then
            return y
        end
    end
    return 8
end

function IKST_JobWorldEdit.buildForServer(panel)
    local state = IKST.getPlayerState(panel.player)
    if not state then
        return 8
    end
    local tool = state.navTool
    if tool == "safehouses" and IKST_JobGuard then
        return IKST_JobGuard.build(panel) or 8
    end
    if tool == "players" and IKST_JobStaff then
        return IKST_JobStaff.build(panel) or 8
    end
    if tool == "overview" and IKST_JobWorldEdit.buildOverview then
        return IKST_JobWorldEdit.buildOverview(panel)
    end
    if IKST.Plugins and IKST.Plugins.buildJobTool then
        local y = IKST.Plugins.buildJobTool(panel, tool)
        if y then
            return y
        end
    end
    return 8
end
