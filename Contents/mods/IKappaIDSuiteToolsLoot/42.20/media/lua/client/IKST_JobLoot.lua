if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISButton"
require "ISUI/ISLabel"
require "ISUI/ISPanel"
require "IKST_Shared"
require "IKST_Access"
require "IKST_Chrome"
require "IKST_UI_Layout"
require "IKST_JobLayout"
require "IKST_ActionLog"
require "IKST_Confirm"
require "IKST_Loot"
require "IKST_LootOps"

IKST_JobLoot = IKST_JobLoot or {}

function IKST_JobLoot.invalidatePreview()
    if IKST_LootOps and IKST_LootOps.invalidatePreviewCache then
        IKST_LootOps.invalidatePreviewCache()
    end
end

function IKST_JobLoot.selectScope(panel, scope)
    local state = IKST.getPlayerState(panel.player)
    if not state then
        return
    end
    state.lootScope = scope
    IKST_JobLoot.invalidatePreview()
    IKST_JobLoot.syncArm(panel)
    panel:refreshJobUI()
end

function IKST_JobLoot.selectRadius(panel, radius)
    local state = IKST.getPlayerState(panel.player)
    if not state then
        return
    end
    if IKST.clampLootRadius then
        radius = IKST.clampLootRadius(radius)
    end
    state.cleanupRadius = radius
    state.lootScope = IKST.CLEANUP_SCOPES.radius
    IKST_JobLoot.invalidatePreview()
    IKST_JobLoot.syncArm(panel)
    panel:refreshJobUI()
end

function IKST_JobLoot.filterArgs(state)
    if not state then
        return {}
    end
    if IKST.ensureLootPlayerState then
        IKST.ensureLootPlayerState(state)
    end
    return {
        onlyEmpty = state.lootOnlyEmpty == true,
        skipLocked = state.lootSkipLocked == true,
        skipClaimed = state.lootSkipClaimed == true,
        preserveExisting = state.lootPreserveExisting == true,
        lootTable = IKST.readLootTableId(state.lootTable),
    }
end

function IKST_JobLoot.toggleFilter(panel, field)
    local state = IKST.getPlayerState(panel and panel.player)
    if not state or not field then
        return
    end
    state[field] = not (state[field] == true)
    IKST_JobLoot.invalidatePreview()
    panel:refreshJobUI()
end

function IKST_JobLoot.selectLootTable(panel, tableId)
    local state = IKST.getPlayerState(panel and panel.player)
    if not state then
        return
    end
    if IKST.ensureLootPlayerState then
        IKST.ensureLootPlayerState(state)
    end
    state.lootTable = IKST.readLootTableId(tableId)
    IKST_JobLoot.invalidatePreview()
    panel:refreshJobUI()
end

function IKST_JobLoot.armPick(panel, silent)
    local player = panel and panel.player
    if not player or not IKST_WorldPick or not IKST_WorldPick.armCommand then
        if not silent then
            IKST.notify(player, IKST.text("IGUI_IKST_Loot_NeedsTiles", "Loot world pick needs Suite Tools Tiles"), false)
        end
        return false
    end
    if not IKST_Access.canUseLoot(player) then
        if not silent then
            IKST.notify(player, IKST.text("IGUI_IKST_Loot_NoAccess", "Loot repopulate is not available"), false)
        end
        return false
    end
    local state = IKST.getPlayerState(player)
    if not state then
        return false
    end
    IKST_WorldPick.armCommand(player, IKST.VIEW.loot, nil, {
        scope = IKST.getLootScope(state),
        radius = state.cleanupRadius,
    }, {
        silent = silent == true,
        notifyKey = "IGUI_IKST_ClickWorld",
        onClick = function(p, square)
            if not p or not square then
                return
            end
            local st = IKST.getPlayerState(p)
            if not st then
                return
            end
            IKST_JobLoot.tryDispatchZone(
                p,
                square:getX(),
                square:getY(),
                square:getZ(),
                IKST.getLootScope(st),
                st.cleanupRadius
            )
        end,
    })
    return true
end

function IKST_JobLoot.syncArm(panel)
    local state = IKST.getPlayerState(panel.player)
    if not state then
        return
    end
    if state.armed and state.armedJob == IKST.VIEW.loot then
        IKST_JobLoot.armPick(panel, true)
    end
    if IKST_Preview and IKST_Preview.syncForPanel then
        IKST_Preview.syncForPanel(panel)
    end
end

function IKST_JobLoot.repopulateHere(panel)
    local player = panel and panel.player
    if not player then
        return false
    end
    if not IKST_Access.canUseLoot(player) then
        IKST.notify(player, IKST.text("IGUI_IKST_Loot_NoAccess", "Loot repopulate is not available"), false)
        return false
    end
    local state = IKST.getPlayerState(player)
    if not state then
        return false
    end
    local scope = IKST.getLootScope(state)
    local function go()
        return IKST_JobLoot.tryDispatchZone(
            player,
            math.floor(player:getX()),
            math.floor(player:getY()),
            math.floor(player:getZ()),
            scope,
            state.cleanupRadius
        )
    end
    if scope == IKST.CLEANUP_SCOPES.cell then
        IKST_Confirm.showDestructive(
            IKST.text("IGUI_IKST_Confirm_LootCell",
                "Refill loaded containers in this map cell? Filters still apply."),
            go
        )
        return true
    end
    return go()
end

function IKST_JobLoot.buildScopeRow(panel, y, state)
    y = panel:makeJobHeader(IKST_JobLayout.MARGIN, y, IKST.text("IGUI_IKST_Scope_Label", "How big an area"))
    local specs = {}
    for _, scope in ipairs(IKST.LOOT_SCOPE_LIST) do
        local label = IKST.lootScopeLabel(scope, state)
        local w = getTextManager():MeasureStringX(UIFont.Small, label) + 20
        specs[#specs + 1] = {
            label = label,
            w = w,
            primary = IKST.getLootScope(state) == scope,
            fn = function()
                IKST_JobLoot.selectScope(panel, scope)
            end,
        }
    end
    y = IKST_JobLayout.flowRow(panel, y, specs, 6, 24)
    return y + 8
end

function IKST_JobLoot.buildSizeRow(panel, y, state)
    if IKST.getLootScope(state) ~= IKST.CLEANUP_SCOPES.radius then
        return y
    end
    y = panel:makeJobHeader(IKST_JobLayout.MARGIN, y, IKST.text("IGUI_IKST_Radius_Size", "Circle size"))
    local order = { "S", "M", "L" }
    local specs = {}
    for _, key in ipairs(order) do
        local radius = IKST.RADIUS_PRESETS[key]
        if radius then
            specs[#specs + 1] = {
                label = key .. " (" .. radius .. ")",
                w = 72,
                primary = state.cleanupRadius == radius,
                fn = function()
                    IKST_JobLoot.selectRadius(panel, radius)
                end,
            }
        end
    end
    y = IKST_JobLayout.flowRow(panel, y, specs, 6, 24)
    return y + 8
end

function IKST_JobLoot.describeState(state)
    return IKST.text("IGUI_IKST_Loot_Repopulate", "Repopulate loot") .. " · " .. IKST.lootScopeLabel(IKST.getLootScope(state), state)
end

function IKST_JobLoot.previewAt(panel, x, y, z)
    if not panel or not IKST_LootOps or not IKST_LootOps.previewZone then
        return nil
    end
    local state = IKST.getPlayerState(panel.player)
    if not state then
        return nil
    end
    return IKST_LootOps.previewZone(x, y, z, IKST.getLootScope(state), {
        radius = state.cleanupRadius,
    })
end

function IKST_JobLoot.previewAtPlayer(panel)
    local player = panel and panel.player
    if not player then
        return nil
    end
    return IKST_JobLoot.previewAt(panel, math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ()))
end

function IKST_JobLoot.previewForPanel(panel)
    local player = panel and panel.player
    if not player then
        return nil
    end
    local state = IKST.getPlayerState(player)
    if not state then
        return nil
    end
    local ax = math.floor(player:getX())
    local ay = math.floor(player:getY())
    local az = math.floor(player:getZ())
    if state.armed and state.armedJob == IKST.VIEW.loot
        and IKST_WorldPick and IKST_WorldPick.hoverSquare then
        local hs = IKST_WorldPick.hoverSquare
        if type(hs.getX) == "function" and type(hs.getY) == "function" then
            ax = hs:getX()
            ay = hs:getY()
            if type(hs.getZ) == "function" then
                az = hs:getZ()
            end
        end
    end
    return IKST_JobLoot.previewAt(panel, ax, ay, az)
end

function IKST_JobLoot.notifyPreview(player, preview, ok)
    if not player or not preview then
        return
    end
    local line = IKST_LootOps.previewSummary(preview)
    if line ~= "" then
        IKST.notify(player, line, ok == true)
    end
end

function IKST_JobLoot.tryDispatchZone(player, x, y, z, scope, radius)
    if not player then
        return false
    end
    if IKST_LootOps and IKST_LootOps.ensureLootPickerReady then
        IKST_LootOps.ensureLootPickerReady()
    end
    x = math.floor(tonumber(x) or 0)
    y = math.floor(tonumber(y) or 0)
    z = math.floor(tonumber(z) or 0)
    scope = scope or IKST.CLEANUP_SCOPES.single
    radius = radius or IKST.RADIUS_PRESETS.M
    local state = IKST.getPlayerState(player)
    local filters = IKST_JobLoot.filterArgs(state)

    -- Preview is advisory only.
    local preview = nil
    if IKST_LootOps and IKST_LootOps.previewZone then
        preview = IKST_LootOps.previewZone(x, y, z, scope, { radius = radius })
        if preview and preview.count == 0 and IKST_LootOps.squaresForScope then
            local squares = IKST_LootOps.squaresForScope(x, y, z, scope, { radius = radius })
            local loose = IKST_LootOps.collectContainersFromSquares(squares, {}, {}, false)
            local candidateCount = 0
            for i = 1, #loose do
                if IKST_LootOps.isRepopulateCandidate(loose[i]) then
                    candidateCount = candidateCount + 1
                end
            end
            if candidateCount > 0 then
                preview.count = candidateCount
            end
        end
        IKST_JobLoot.notifyPreview(player, preview, preview and preview.count and preview.count > 0)
    end

    if IKST_WorldPick and IKST_WorldPick.setPickCooldown then
        IKST_WorldPick.setPickCooldown()
    end
    if IKST.pushLog then
        local scopeLabel = IKST.lootScopeLabel and IKST.lootScopeLabel(scope, IKST.getPlayerState(player)) or tostring(scope)
        IKST.pushLog(player, "lootRepopulateZone " .. scopeLabel
            .. " @ " .. tostring(x) .. "," .. tostring(y) .. "," .. tostring(z), "progress")
    end
    IKST.dispatchCommand(player, IKST.CMD.lootRepopulateZone, {
        x = x,
        y = y,
        z = z,
        scope = scope,
        radius = radius,
        onlyEmpty = filters.onlyEmpty == true,
        skipLocked = filters.skipLocked == true,
        skipClaimed = filters.skipClaimed == true,
        preserveExisting = filters.preserveExisting == true,
        lootTable = filters.lootTable,
    })
    return true
end

function IKST_JobLoot.onServerResult(panel, args)
    if not args then
        return
    end
    if args.mode ~= IKST.CMD.lootRepopulateZone and args.mode ~= IKST.CMD.lootRepopulateContainer then
        return
    end
    local player = panel and panel.player
    if not player then
        return
    end
    local msg = IKST.formatServerResult(args.message, args)
    if msg and msg ~= "" then
        IKST.notify(player, msg, args.success == true)
    end
    if args.success == true and IKST_LootOps and IKST_LootOps.invalidatePreviewCache then
        IKST_LootOps.invalidatePreviewCache()
    end
    if args.success == true and IKST_Preview and IKST_Preview.syncForPanel then
        IKST_Preview.syncForPanel(panel)
    end
end

-- Loot landing (mockup: ikst-page-loot.png). Scopes, tables, filters, preview, refill.

local function lootBtn(parent, panel, x, y, w, h, label, kind, onClick)
    local btn = IKST_Chrome.newActionButton(x, y, w, h, label, panel, function()
        if onClick then
            onClick()
        end
    end, kind or "chip")
    parent:addChild(btn)
    return btn
end

local function lootFlowLayout(items, cardW, gap)
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

local function lootPillSection(panel, x, y, w, icon, titleKey, titleFallback, items)
    local rowH = math.max(26, IKST_UI_Layout.s(30))
    local gap = IKST_UI_Layout.s(8)
    local rows = lootFlowLayout(items, w, gap)
    local headerH = IKST_Chrome.sectionHeaderH()
    local bottomPad = IKST_UI_Layout.s(14)
    local contentH = (#rows * rowH) + (math.max(0, #rows - 1) * gap)
    if #rows == 0 then
        contentH = rowH
    end
    local cardH = headerH + contentH + bottomPad
    local card, contentY = IKST_Chrome.newSectionCardPanel(x, y, w, cardH, icon, IKST.text(titleKey, titleFallback))
    panel:addJobWidget(card)
    local cy = contentY
    for _, row in ipairs(rows) do
        for _, cell in ipairs(row) do
            local item = cell.item
            local kind = "chip"
            if item.primary or item.on then
                kind = "primary"
            elseif item.outline then
                kind = "outline"
            end
            lootBtn(card, panel, cell.x, cy, cell.w, rowH, item.label, kind, function()
                if item.onClick then
                    item.onClick()
                end
                panel:refreshJobUI()
            end)
        end
        cy = cy + rowH + gap
    end
    return y + cardH + (IKST_JobLayout.GAP or gap)
end

function IKST_JobLoot.build(panel)
    local p = panel.player
    local state = IKST.getPlayerState(p)
    if not state then
        return 8
    end
    if IKST.ensureLootPlayerState then
        IKST.ensureLootPlayerState(state)
    end

    local x = panel.contentX or IKST_JobLayout.MARGIN
    local w = math.max(220, panel.contentW or (panel.width - 24))
    local y = 8
    local gap = IKST_JobLayout.GAP or IKST_UI_Layout.s(12)
    local padX = IKST_UI_Layout.s(14)
    local headerBtnH = math.max(24, IKST_UI_Layout.s(28))
    local cc = IKST_Chrome.colors
    local scope = IKST.getLootScope(state)

    local title = IKST.text("IGUI_IKST_WS_Loot", "Loot")
    local titleLabel = ISLabel:new(x, y, 26, title, 1, 1, 1, 1, UIFont.Large, true)
    titleLabel:initialise()
    panel:addJobWidget(titleLabel)

    local refillLabel = IKST.text("IGUI_IKST_LootTile_RefillNow", "Refill now")
    local refillW = IKST_UI_Layout.buttonWidth(refillLabel, UIFont.Small, 100)
    local dryLabel = IKST.text("IGUI_IKST_LootTile_DryRun", "Dry run")
    local dryW = IKST_UI_Layout.buttonWidth(dryLabel, UIFont.Small, 80)
    local rightEdge = x + w
    local refillX = rightEdge - refillW
    local dryX = refillX - IKST_UI_Layout.s(8) - dryW

    local dryBtn = IKST_Chrome.newActionButton(dryX, y, dryW, headerBtnH, dryLabel, panel, function()
        local preview = IKST_JobLoot.previewAtPlayer(panel)
        IKST_JobLoot.notifyPreview(p, preview, preview and preview.count and preview.count > 0)
        panel:refreshJobUI()
    end, "primary")
    panel:addJobWidget(dryBtn)

    local refillBtn = IKST_Chrome.newActionButton(refillX, y, refillW, headerBtnH, refillLabel, panel, function()
        IKST_JobLoot.repopulateHere(panel)
        panel:refreshJobUI()
    end, "outline")
    panel:addJobWidget(refillBtn)

    y = y + math.max(26, headerBtnH) + gap

    -- SCOPE (LOOT_SCOPE_LIST + radius presets)
    local scopeItems = {}
    for _, s in ipairs(IKST.LOOT_SCOPE_LIST or {}) do
        local label = IKST.lootScopeLabel(s, state)
        if s == IKST.CLEANUP_SCOPES.single then
            label = IKST.text("IGUI_IKST_LootTile_ScopeSingle", "Single container")
        elseif s == IKST.CLEANUP_SCOPES.building then
            label = IKST.text("IGUI_IKST_LootTile_ScopeBuilding", "This building")
        elseif s == IKST.CLEANUP_SCOPES.room then
            label = IKST.text("IGUI_IKST_LootTile_ScopeRoom", "This room")
        elseif s == IKST.CLEANUP_SCOPES.radius then
            label = IKST.text("IGUI_IKST_LootTile_ScopeRadius", "Radius")
                .. " " .. tostring(state.cleanupRadius or IKST.RADIUS_PRESETS.M)
        elseif s == IKST.CLEANUP_SCOPES.cell then
            label = IKST.text("IGUI_IKST_LootTile_WholeCell", "Whole cell")
        end
        scopeItems[#scopeItems + 1] = {
            label = label,
            on = scope == s,
            onClick = function()
                IKST_JobLoot.selectScope(panel, s)
            end,
        }
    end
    if scope == IKST.CLEANUP_SCOPES.radius then
        local order = { "S", "M", "L" }
        for _, key in ipairs(order) do
            local radius = IKST.RADIUS_PRESETS[key]
            if radius then
                scopeItems[#scopeItems + 1] = {
                    label = key .. " (" .. tostring(radius) .. ")",
                    on = state.cleanupRadius == radius,
                    onClick = function()
                        IKST_JobLoot.selectRadius(panel, radius)
                    end,
                }
            end
        end
    end
    local lootRadii = IKST.LOOT_RADIUS_PRESETS or {}
    scopeItems[#scopeItems + 1] = {
        label = IKST.text("IGUI_IKST_LootTile_Radius50", "Radius 50"),
        on = scope == IKST.CLEANUP_SCOPES.radius and state.cleanupRadius == lootRadii.XL,
        onClick = function()
            IKST_JobLoot.selectRadius(panel, lootRadii.XL)
        end,
    }
    scopeItems[#scopeItems + 1] = {
        label = IKST.text("IGUI_IKST_LootTile_Radius200", "Radius 200"),
        on = scope == IKST.CLEANUP_SCOPES.radius and state.cleanupRadius == lootRadii.XXL,
        onClick = function()
            IKST_JobLoot.selectRadius(panel, lootRadii.XXL)
        end,
    }
    y = lootPillSection(panel, x, y, w, "media/ui/ikst/ws_loot.png",
        "IGUI_IKST_LootTile_SectionScope", "Scope", scopeItems)

    local lootTable = IKST.readLootTableId(state.lootTable)
    local tableItems = {
        {
            label = IKST.text("IGUI_IKST_LootTile_TableResidential", "Vanilla residential"),
            on = lootTable == "residential",
            onClick = function()
                IKST_JobLoot.selectLootTable(panel, "residential")
                IKST.notify(p, IKST.text("IGUI_IKST_LootTile_TableHint", "Uses vanilla loot for this room/container type."), true)
            end,
        },
        {
            label = IKST.text("IGUI_IKST_LootTile_TableGrocery", "Vanilla grocery"),
            on = lootTable == "grocery",
            onClick = function()
                IKST_JobLoot.selectLootTable(panel, "grocery")
            end,
        },
        {
            label = IKST.text("IGUI_IKST_LootTile_TableMedical", "Vanilla medical"),
            on = lootTable == "medical",
            onClick = function()
                IKST_JobLoot.selectLootTable(panel, "medical")
            end,
        },
        {
            label = IKST.text("IGUI_IKST_LootTile_TableEvent", "Custom: event stash"),
            on = lootTable == "event",
            onClick = function()
                IKST_JobLoot.selectLootTable(panel, "event")
            end,
        },
        {
            label = IKST.text("IGUI_IKST_LootTile_TableMilitary", "Custom: military"),
            on = lootTable == "military",
            onClick = function()
                IKST_JobLoot.selectLootTable(panel, "military")
            end,
        },
    }
    y = lootPillSection(panel, x, y, w, "media/ui/ikst/tool_items.png",
        "IGUI_IKST_LootTile_SectionTable", "Loot table", tableItems)

    local filterItems = {
        {
            label = IKST.text("IGUI_IKST_LootTile_SkipLocked", "Skip locked"),
            on = state.lootSkipLocked == true,
            onClick = function()
                IKST_JobLoot.toggleFilter(panel, "lootSkipLocked")
            end,
        },
        {
            label = IKST.text("IGUI_IKST_LootTile_OnlyEmpty", "Only empty"),
            on = state.lootOnlyEmpty == true,
            onClick = function()
                IKST_JobLoot.toggleFilter(panel, "lootOnlyEmpty")
            end,
        },
        {
            label = IKST.text("IGUI_IKST_LootTile_SkipClaimed", "Skip claimed"),
            on = state.lootSkipClaimed == true,
            onClick = function()
                IKST_JobLoot.toggleFilter(panel, "lootSkipClaimed")
            end,
        },
        {
            label = IKST.text("IGUI_IKST_LootTile_Preserve", "Preserve existing"),
            on = state.lootPreserveExisting == true,
            onClick = function()
                IKST_JobLoot.toggleFilter(panel, "lootPreserveExisting")
            end,
        },
    }
    y = lootPillSection(panel, x, y, w, "media/ui/ikst/tool_protect.png",
        "IGUI_IKST_LootTile_SectionFilters", "Filters", filterItems)

    -- PREVIEW (live)
    local preview = IKST_JobLoot.previewForPanel(panel)
    local previewLine = ""
    if IKST_LootOps and IKST_LootOps.previewSummary then
        previewLine = IKST_LootOps.previewSummary(preview)
    end
    if previewLine == "" then
        previewLine = IKST.text("IGUI_IKST_Loot_Preview_None", "No containers in scope")
    end
    local prevH = IKST_Chrome.sectionHeaderH() + IKST_UI_Layout.s(36) + IKST_UI_Layout.s(14)
    local prevCard, prevY = IKST_Chrome.newSectionCardPanel(x, y, w, prevH,
        "media/ui/ikst/tool_servertools.png",
        IKST.text("IGUI_IKST_LootTile_SectionPreview", "Preview"))
    panel:addJobWidget(prevCard)
    local countText = IKST.text("IGUI_IKST_LootTile_EstContainers", "Estimated containers")
        .. ": " .. tostring((preview and preview.count) or 0)
    local countLbl = ISLabel:new(padX, prevY + 4, 16, countText,
        cc.textPrimary.r, cc.textPrimary.g, cc.textPrimary.b, 1, UIFont.Small, true)
    countLbl:initialise()
    prevCard:addChild(countLbl)
    local sumLbl = ISLabel:new(padX, prevY + 20, 14, previewLine,
        cc.textMuted.r, cc.textMuted.g, cc.textMuted.b, 1, UIFont.Small, true)
    sumLbl:initialise()
    prevCard:addChild(sumLbl)
    y = y + prevH + gap

    local pickArmed = state.armed and state.armedJob == IKST.VIEW.loot
        and IKST_WorldPick and IKST_WorldPick.isCommandPickArmed
        and IKST_WorldPick.isCommandPickArmed(p)

    if pickArmed then
        local stopLabel = IKST.text("IGUI_IKST_Disarm", "STOP")
        local stopBtn = IKST_Chrome.newActionButton(x, y, w, headerBtnH, stopLabel, panel, function()
            if panel.stopArmedMode then
                panel:stopArmedMode()
            elseif IKST_WorldPick and IKST_WorldPick.disarm then
                IKST_WorldPick.disarm(p)
                panel:refreshJobUI()
            end
        end, "danger")
        panel:addJobWidget(stopBtn)
        y = y + headerBtnH + gap
    end

    local armLabel = IKST.text("IGUI_IKST_Loot_Arm", "Click ground to repopulate")
    local armBtn = IKST_Chrome.newActionButton(x, y, w, headerBtnH, armLabel, panel, function()
        IKST_JobLoot.armPick(panel, false)
        panel:refreshJobUI()
    end, pickArmed and "primary" or "chip")
    panel:addJobWidget(armBtn)
    y = y + headerBtnH + gap

    return y
end

function IKST_JobLoot.enter(panel)
    local state = IKST.getPlayerState(panel.player)
    if state then
        if IKST.ensureLootPlayerState then
            IKST.ensureLootPlayerState(state)
        end
        if not state.lootScope then
            state.lootScope = IKST.CLEANUP_SCOPES.single
        end
    end
    -- Do not mark armed unless world-pick actually attached (was fake-READY with no clicks).
    IKST_JobLoot.armPick(panel, true)
    if IKST_Preview and IKST_Preview.syncForPanel then
        IKST_Preview.syncForPanel(panel)
    end
end
