-- SoftTool Loot: soft-shell Loot workspace painted via IKUI_SoftBody.
-- Arm / preview / dispatch helpers stay on IKST_JobLoot.
if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISLabel"
require "IKST_Shared"
require "IKappaID_UI_Framework/IKUI_SoftBody"
require "IKST_JobLoot"
require "IKST_WorldPick"
require "IKST_LootOps"

IKST_SoftTool_Loot = IKST_SoftTool_Loot or {}

local function openBand(panel, rect, band, title)
    local inner = IKUI_SoftBody.SECTION_INNER
    local padY = 8
    local btnH = IKUI_SoftBody.STANDARD_BTN_H
    local card, contentY = IKUI_SoftBody.section(panel, rect.x, band.y, rect.w, band.h, title)
    return card, inner, contentY + padY, math.max(40, rect.w - inner * 2), math.max(btnH, band.h - contentY - padY * 2)
end

function IKST_SoftTool_Loot.build(panel)
    if not panel then
        return 8
    end
    local p = panel.player
    local state = IKST.getPlayerState(p)
    if not state then
        return 8
    end
    if IKST.ensureLootPlayerState then
        IKST.ensureLootPlayerState(state)
    end
    if panel.lootDryMode == nil then
        panel.lootDryMode = true
    end

    local scope = IKST.getLootScope(state)
    local lootTable = IKST.readLootTableId(state.lootTable)
    local radius = tonumber(state.cleanupRadius) or IKST.RADIUS_PRESETS.M

    local rect = IKUI_SoftBody.contentRect(panel)
    local gap = IKUI_SoftBody.BTN_GAP
    local btnH = IKUI_SoftBody.STANDARD_BTN_H
    local bands, stackBottom = IKUI_SoftBody.stack(rect.y, gap, { 1, 2, 2, 2, 120 })

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[1], IKST.text("IGUI_IKST_LootTile_Mode", "Mode"))
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_LootTile_DryRun", "Dry run"),
                primary = panel.lootDryMode == true,
                onClick = function()
                    panel.lootDryMode = true
                    local preview = IKST_JobLoot.previewAtPlayer(panel)
                    IKST_JobLoot.notifyPreview(p, preview, preview and preview.count and preview.count > 0)
                    panel:refreshJobUI()
                end,
            },
            {
                label = IKST.text("IGUI_IKST_LootTile_RefillNow", "Refill"),
                primary = panel.lootDryMode ~= true,
                onClick = function()
                    panel.lootDryMode = false
                    IKST_JobLoot.repopulateHere(panel)
                    panel:refreshJobUI()
                end,
            },
        })
    end

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[2], IKST.text("IGUI_IKST_LootTile_SectionScope", "Scope"))
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_LootTile_ScopeSingle", "Single"),
                primary = scope == IKST.CLEANUP_SCOPES.single,
                onClick = function()
                    IKST_JobLoot.selectScope(panel, IKST.CLEANUP_SCOPES.single)
                end,
            },
            {
                label = IKST.text("IGUI_IKST_LootTile_ScopeBuilding", "This building"),
                primary = scope == IKST.CLEANUP_SCOPES.building,
                onClick = function()
                    IKST_JobLoot.selectScope(panel, IKST.CLEANUP_SCOPES.building)
                end,
            },
            {
                label = IKST.text("IGUI_IKST_LootTile_ScopeRadius", "Radius"),
                primary = scope == IKST.CLEANUP_SCOPES.radius
                    and radius ~= 5 and radius ~= 10 and radius ~= 20,
                onClick = function()
                    IKST_JobLoot.selectScope(panel, IKST.CLEANUP_SCOPES.radius)
                end,
            },
            {
                label = "R 5",
                primary = scope == IKST.CLEANUP_SCOPES.radius and radius == 5,
                onClick = function()
                    IKST_JobLoot.selectRadius(panel, 5)
                end,
            },
            {
                label = "R 10",
                primary = scope == IKST.CLEANUP_SCOPES.radius and radius == 10,
                onClick = function()
                    IKST_JobLoot.selectRadius(panel, 10)
                end,
            },
            {
                label = "R 20",
                primary = scope == IKST.CLEANUP_SCOPES.radius and radius == 20,
                onClick = function()
                    IKST_JobLoot.selectRadius(panel, 20)
                end,
            },
        })
    end

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[3], IKST.text("IGUI_IKST_LootTile_SectionTable", "Loot table"))
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_LootTile_TableResidential", "Vanilla residential"),
                primary = lootTable == "residential",
                onClick = function()
                    IKST_JobLoot.selectLootTable(panel, "residential")
                end,
            },
            {
                label = IKST.text("IGUI_IKST_LootTile_TableMedical", "Vanilla medical"),
                primary = lootTable == "medical",
                onClick = function()
                    IKST_JobLoot.selectLootTable(panel, "medical")
                end,
            },
            {
                label = IKST.text("IGUI_IKST_LootTile_TableGrocery", "Vanilla grocery"),
                primary = lootTable == "grocery",
                onClick = function()
                    IKST_JobLoot.selectLootTable(panel, "grocery")
                end,
            },
            {
                label = IKST.text("IGUI_IKST_LootTile_TableMilitary", "Custom: military"),
                primary = lootTable == "military",
                onClick = function()
                    IKST_JobLoot.selectLootTable(panel, "military")
                end,
            },
            {
                label = IKST.text("IGUI_IKST_LootTile_TableEvent", "Custom: event stash"),
                primary = lootTable == "event",
                onClick = function()
                    IKST_JobLoot.selectLootTable(panel, "event")
                end,
            },
        })
    end

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[4], IKST.text("IGUI_IKST_LootTile_SectionFilters", "Filters"))
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_LootTile_OnlyEmpty", "Only empty"),
                primary = state.lootOnlyEmpty == true,
                onClick = function()
                    IKST_JobLoot.toggleFilter(panel, "lootOnlyEmpty")
                end,
            },
            {
                label = IKST.text("IGUI_IKST_LootTile_SkipLocked", "Skip locked"),
                primary = state.lootSkipLocked == true,
                onClick = function()
                    IKST_JobLoot.toggleFilter(panel, "lootSkipLocked")
                end,
            },
            {
                label = IKST.text("IGUI_IKST_LootTile_SkipClaimed", "Skip claimed"),
                primary = state.lootSkipClaimed == true,
                onClick = function()
                    IKST_JobLoot.toggleFilter(panel, "lootSkipClaimed")
                end,
            },
            {
                label = IKST.text("IGUI_IKST_LootTile_Preserve", "Preserve"),
                primary = state.lootPreserveExisting == true,
                onClick = function()
                    IKST_JobLoot.toggleFilter(panel, "lootPreserveExisting")
                end,
            },
        })
    end

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[5], IKST.text("IGUI_IKST_LootTile_SectionPreview", "Preview & arm"))
        local listH, pillH, gapLP = IKUI_SoftBody.listPillSplit(ah, 1)
        local preview = IKST_JobLoot.previewForPanel(panel)
        local previewLine = ""
        if IKST_LootOps and type(IKST_LootOps.previewSummary) == "function" then
            previewLine = IKST_LootOps.previewSummary(preview)
        end
        if previewLine == "" then
            previewLine = IKST.text("IGUI_IKST_Loot_Preview_None", "No containers in scope")
        end
        local countText = IKST.text("IGUI_IKST_LootTile_EstContainers", "Estimated containers")
            .. ": " .. tostring((preview and preview.count) or 0)
        local countLbl = ISLabel:new(ax, ay, 16, countText, 1, 1, 1, 1, UIFont.Small, true)
        countLbl:initialise()
        card:addChild(countLbl)
        local sumLbl = ISLabel:new(ax, ay + 18, 14, previewLine, 1, 1, 1, 1, UIFont.Small, true)
        sumLbl:initialise()
        card:addChild(sumLbl)

        local pickArmed = state.armed and state.armedJob == IKST.VIEW.loot
            and IKST_WorldPick and type(IKST_WorldPick.isCommandPickArmed) == "function"
            and IKST_WorldPick.isCommandPickArmed(p)
        local actionY = ay + listH + gapLP
        local actionH = math.max(btnH, pillH)
        IKUI_SoftBody.pillRow(panel, card, ax, actionY, aw, actionH, {
            {
                label = IKST.text("IGUI_IKST_Loot_Arm", "Arm"),
                primary = true,
                onClick = function()
                    if panel.lootDryMode == true then
                        local preview2 = IKST_JobLoot.previewAtPlayer(panel)
                        IKST_JobLoot.notifyPreview(p, preview2, preview2 and preview2.count and preview2.count > 0)
                    end
                    IKST_JobLoot.armPick(panel, false)
                    panel:refreshJobUI()
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Disarm", "STOP"),
                primary = pickArmed == true,
                onClick = function()
                    if panel.stopArmedMode then
                        panel:stopArmedMode()
                    elseif IKST_WorldPick and type(IKST_WorldPick.disarm) == "function" then
                        IKST_WorldPick.disarm(p)
                        panel:refreshJobUI()
                    end
                end,
            },
        })
    end

    return stackBottom + gap
end
