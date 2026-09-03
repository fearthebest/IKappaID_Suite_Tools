-- SoftTool Tiles: soft-shell World Edit workspace painted via IKUI_SoftBody.
-- World-arm / pack / protect helpers stay on JobCleanup / JobPainter / JobTilesGuard / etc.
if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISLabel"
require "IKST_Shared"
require "IKappaID_UI/IKUI_SoftBody"
require "IKappaID_UI/IKUI_Layout"
require "IKST_JobLayout"
require "IKST_JobWorldEdit"
require "IKST_JobCleanup"
require "IKST_JobPainter"
require "IKST_JobInspector"
require "IKST_JobAutomation"
require "IKST_JobTilesGuard"
require "IKST_WorldPick"
require "IKST_Rewind"
require "IKST_SpriteGrid"
require "IKST_PaintCursorManager"
require "IKST_UI_Layout"

IKST_SoftTool_Tiles = IKST_SoftTool_Tiles or {}

local function openBand(panel, rect, band, title)
    local inner = IKUI_SoftBody.SECTION_INNER
    local padY = 8
    local btnH = IKUI_SoftBody.STANDARD_BTN_H
    local bx = band.x or rect.x
    local bw = band.w or rect.w
    local card, contentY = IKUI_SoftBody.section(panel, bx, band.y, bw, band.h, title)
    return card, inner, contentY + padY, math.max(40, bw - inner * 2), math.max(btnH, band.h - contentY - padY * 2)
end

function IKST_SoftTool_Tiles.buildOverview(panel)
    local p = panel.player
    if not p then
        return 8
    end
    local rect = IKUI_SoftBody.contentRect(panel)
    local gap = IKUI_SoftBody.BTN_GAP
    local bands, stackBottom = IKUI_SoftBody.stack(rect.y, gap, { 1, 1, 2, 1, 2 })

    local function go(toolId)
        if panel and type(panel.enterNav) == "function" then
            panel:enterNav(IKST.VIEW.tiles, toolId)
        end
    end

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[1], IKST.text("IGUI_IKST_Job_Cleanup", "Remove Stuff"))
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.cleanupActionLabel(IKST.CLEANUP_MODES.removeObject),
                primary = true,
                onClick = function()
                    go("remove")
                end,
            },
            {
                label = IKST.cleanupActionLabel(IKST.CLEANUP_MODES.removeTile),
                onClick = function()
                    go("remove")
                end,
            },
            {
                label = IKST.cleanupActionLabel(IKST.CLEANUP_MODES.vegetation),
                onClick = function()
                    go("remove")
                end,
            },
        })
    end

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[2], IKST.text("IGUI_IKST_Job_Painter", "Paint Tiles"))
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_Paint", "Paint"),
                primary = true,
                onClick = function()
                    go("paint")
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Eyedropper", "Eyedropper"),
                onClick = function()
                    go("paint")
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Replace", "Replace tile"),
                onClick = function()
                    go("paint")
                end,
            },
        })
    end

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[3], IKST.text("IGUI_IKST_TilesTile_SectionInspect", "Inspect & build"))
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_Job_Inspector", "Inspect Tile"),
                primary = true,
                onClick = function()
                    go("inspect")
                end,
            },
            {
                label = IKST.text("IGUI_IKST_TilesTile_ContainerAudit", "Container audit"),
                onClick = function()
                    go("inspect")
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Guard_BpCopy", "Copy build"),
                onClick = function()
                    go("blueprints")
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Guard_BpPaste", "Paste build"),
                onClick = function()
                    go("blueprints")
                end,
            },
        })
    end

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[4], IKST.text("IGUI_IKST_Job_Automation", "Area jobs"))
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_Job_Automation", "Area jobs"),
                primary = true,
                onClick = function()
                    go("area")
                end,
            },
        })
    end

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[5], IKST.text("IGUI_IKST_Tool_Protect", "Protection"))
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_Protect_Square", "Protect square"),
                primary = true,
                onClick = function()
                    go("protect")
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Protect_Unhere", "Unprotect square"),
                onClick = function()
                    go("protect")
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Protect_KeypadSection", "Keypad lock"),
                onClick = function()
                    go("protect")
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Guard_Dropbox", "Drop box"),
                onClick = function()
                    go("protect")
                end,
            },
        })
    end

    return stackBottom + gap
end

function IKST_SoftTool_Tiles.buildRemove(panel)
    local state = IKST.getPlayerState(panel.player)
    if not state then
        return 8
    end
    local rect = IKUI_SoftBody.contentRect(panel)
    local gap = IKUI_SoftBody.BTN_GAP
    local btnH = IKUI_SoftBody.STANDARD_BTN_H
    local bands, stackBottom = IKUI_SoftBody.stack(rect.y, gap, { 3, 2, 1, 1 })

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[1], IKST.text("IGUI_IKST_Action_Label", "Action"))
        local items = {}
        for _, action in ipairs(IKST.CLEANUP_ACTIONS) do
            local id = action
            items[#items + 1] = {
                label = IKST.cleanupActionLabel(id),
                primary = IKST.getCleanupAction(state) == id,
                onClick = function()
                    IKST_JobCleanup.selectAction(panel, id)
                end,
            }
        end
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, items)
    end

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[2], IKST.text("IGUI_IKST_Scope_Label", "Scope"))
        local items = {}
        for _, scope in ipairs(IKST.CLEANUP_SCOPE_LIST) do
            local id = scope
            items[#items + 1] = {
                label = IKST.cleanupScopeLabel(id, state),
                primary = IKST.getCleanupScope(state) == id,
                onClick = function()
                    IKST_JobCleanup.selectScope(panel, id)
                end,
            }
        end
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, items)
    end

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[3], IKST.text("IGUI_IKST_Size_Label", "Size"))
        local scope = IKST.getCleanupScope(state)
        local useCube = scope == IKST.CLEANUP_SCOPES.cube
        local presets = useCube and IKST.CUBE_PRESETS or IKST.RADIUS_PRESETS
        local current = useCube and state.cleanupCubeHalf or state.cleanupRadius
        local items = {}
        for _, key in ipairs({ "S", "M", "L" }) do
            local val = presets[key]
            if val then
                local k = key
                local v = val
                items[#items + 1] = {
                    label = k,
                    primary = current == v,
                    onClick = function()
                        local sc = IKST.getCleanupScope(state)
                        if sc ~= IKST.CLEANUP_SCOPES.cube and sc ~= IKST.CLEANUP_SCOPES.radius then
                            state.cleanupScope = IKST.CLEANUP_SCOPES.radius
                            sc = IKST.CLEANUP_SCOPES.radius
                        end
                        if sc == IKST.CLEANUP_SCOPES.cube then
                            state.cleanupCubeHalf = IKST.CUBE_PRESETS[k] or v
                        else
                            state.cleanupRadius = IKST.RADIUS_PRESETS[k] or v
                        end
                        if IKST_PreviewOverlay then
                            IKST_PreviewOverlay.clear()
                        end
                        IKST_JobCleanup.syncArm(panel)
                        panel:refreshJobUI()
                    end,
                }
            end
        end
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, items)
    end

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[4], IKST.text("IGUI_IKST_Active", "Active"))
        local rewindCount = 0
        if IKST_Rewind and type(IKST_Rewind.count) == "function" then
            rewindCount = IKST_Rewind.count(panel.player) or 0
        end
        local rewindLabel = IKST.text("IGUI_IKST_Rewind", "REWIND")
        if rewindCount > 0 then
            rewindLabel = rewindLabel .. " (" .. tostring(rewindCount) .. ")"
        end
        local armed = state.armed and state.armedJob == IKST.VIEW.cleanup
        local active = IKST_JobCleanup.describeState(state)
        if armed then
            active = active .. " [" .. IKST.text("IGUI_IKST_Armed", "ARMED") .. "]"
        end
        local noteH = 16
        local note = ISLabel:new(ax, ay, noteH, active, 1, 1, 1, 1, UIFont.Small, true)
        note:initialise()
        card:addChild(note)
        IKUI_SoftBody.pillRow(panel, card, ax, ay + noteH + 4, aw, math.max(btnH, ah - noteH - 4), {
            {
                label = rewindLabel,
                primary = rewindCount > 0,
                onClick = function()
                    if IKST_WorldPick and type(IKST_WorldPick.disarm) == "function" then
                        IKST_WorldPick.disarm(panel.player)
                    end
                    IKST.dispatchCommand(panel.player, IKST.CMD.rewind, {})
                    panel:refreshJobUI()
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Disarm", "DISARM"),
                primary = true,
                onClick = function()
                    if IKST_WorldPick and type(IKST_WorldPick.disarm) == "function" then
                        IKST_WorldPick.disarm(panel.player)
                    end
                    panel:refreshJobUI()
                end,
            },
        })
    end

    return stackBottom + gap
end

function IKST_SoftTool_Tiles.buildInspect(panel)
    local state = IKST.getPlayerState(panel.player)
    if not state then
        return 8
    end
    local rect = IKUI_SoftBody.contentRect(panel)
    local gap = IKUI_SoftBody.BTN_GAP
    local armH = IKUI_SoftBody.compactPillBandH(1)
    local resultsH = math.max(80, rect.h - armH - gap)
    local bands = {
        { y = rect.y, h = armH },
        { y = rect.y + armH + gap, h = resultsH },
    }
    local stackBottom = bands[2].y + bands[2].h
    local armed = state.armed and state.armedJob == IKST.VIEW.inspector

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[1], IKST.text("IGUI_IKST_SectionArm", "Arm"))
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_ArmInspect", "Arm inspect"),
                primary = armed and not (state.inspectAudit == true),
                onClick = function()
                    if IKST_WorldPick and type(IKST_WorldPick.armInspect) == "function" then
                        IKST_WorldPick.armInspect(panel.player)
                    end
                    panel:refreshJobUI()
                end,
            },
            {
                label = IKST.text("IGUI_IKST_TilesTile_ContainerAudit", "Container audit"),
                primary = armed and state.inspectAudit == true,
                onClick = function()
                    if IKST_WorldPick and type(IKST_WorldPick.armInspect) == "function" then
                        IKST_WorldPick.armInspect(panel.player, false, true)
                    end
                    panel:refreshJobUI()
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Disarm", "Disarm"),
                onClick = function()
                    if IKST_WorldPick and type(IKST_WorldPick.disarm) == "function" then
                        IKST_WorldPick.disarm(panel.player)
                    end
                    panel:refreshJobUI()
                end,
            },
        })
    end

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[2], IKST.text("IGUI_IKST_SectionResults", "Results"))
        local inspect = state.lastInspect
        local header = IKST.text("IGUI_IKST_NoInspect", "Click a square to inspect objects and sprites.")
        if inspect and inspect.x then
            header = IKST.text("IGUI_IKST_Inspect_Square", "Square {1}, {2}, {3}")
            header = string.gsub(header, "{1}", tostring(inspect.x))
            header = string.gsub(header, "{2}", tostring(inspect.y))
            header = string.gsub(header, "{3}", tostring(inspect.z or 0))
        end
        local lineH = 16
        local note = ISLabel:new(ax, ay, lineH, header, 1, 1, 1, 1, UIFont.Small, true)
        note:initialise()
        card:addChild(note)
        local rows = {}
        if inspect and inspect.items then
            for i, item in ipairs(inspect.items) do
                if i > 24 then
                    break
                end
                local label = tostring(item.name or IKST.text("IGUI_IKST_Inspect_Object", "object"))
                if item.isFloor then
                    label = label .. " " .. IKST.text("IGUI_IKST_Inspect_Floor", "(floor)")
                end
                rows[#rows + 1] = { id = i, label = label, data = item }
                local extra = item.containerItems
                if type(extra) == "table" then
                    local max = #extra
                    if max > 6 then
                        max = 6
                    end
                    for n = 1, max do
                        local entry = extra[n]
                        rows[#rows + 1] = {
                            id = i .. ":" .. n,
                            label = "  " .. tostring(entry.count or 1) .. "x " .. tostring(entry.name or "?"),
                            data = entry,
                        }
                    end
                end
            end
        end
        local listY = ay + lineH + 6
        local listH = math.max(40, ah - lineH - 6)
        IKST_JobLayout.makeSelectList(panel, card, ax, listY, aw, listH, rows, {})
    end

    return stackBottom + gap
end

function IKST_SoftTool_Tiles.buildArea(panel)
    local state = IKST.getPlayerState(panel.player)
    if not state then
        return 8
    end
    if not state.autoRadius then
        state.autoRadius = IKST.RADIUS_PRESETS.M
    end
    local rect = IKUI_SoftBody.contentRect(panel)
    local gap = IKUI_SoftBody.BTN_GAP
    local bands, stackBottom = IKUI_SoftBody.stack(rect.y, gap, { 1, 3 })

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[1], IKST.text("IGUI_IKST_SectionRadius", "Radius"))
        local items = {}
        for _, key in ipairs({ "S", "M", "L" }) do
            local preset = IKST.RADIUS_PRESETS[key]
            if preset then
                local val = preset
                items[#items + 1] = {
                    label = key,
                    primary = state.autoRadius == val,
                    onClick = function()
                        state.autoRadius = val
                        panel:refreshJobUI()
                    end,
                }
            end
        end
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, items)
    end

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[2], IKST.text("IGUI_IKST_TilesTile_SectionAuto", "Actions"))
        local actions = {
            { cmd = IKST.CMD.autoGardener, label = IKST.text("IGUI_IKST_Auto_Gardener", "Gardener") },
            { cmd = IKST.CMD.autoLumberjack, label = IKST.text("IGUI_IKST_Auto_Lumberjack", "Lumberjack") },
            { cmd = IKST.CMD.autoGravel, label = IKST.text("IGUI_IKST_Auto_Gravel", "Gravel") },
            { cmd = IKST.CMD.autoCorpseStack, label = IKST.text("IGUI_IKST_Auto_Corpse", "Corpse"), primary = true },
            { cmd = IKST.CMD.autoHomeWreck, label = IKST.text("IGUI_IKST_Auto_HomeWreck", "Home wrecker") },
            { cmd = IKST.CMD.autoFarmer, label = IKST.text("IGUI_IKST_Auto_Farmer", "Farmer") },
            { cmd = IKST.CMD.autoUnloadContainers, label = IKST.text("IGUI_IKST_Auto_Unload", "Unload") },
        }
        local items = {}
        for i = 1, #actions do
            local action = actions[i]
            items[#items + 1] = {
                label = action.label,
                primary = action.primary == true,
                onClick = function()
                    IKST_JobAutomation.dispatchRadius(panel, action.cmd)
                end,
            }
        end
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, items)
    end

    return stackBottom + gap
end

function IKST_SoftTool_Tiles.buildProtect(panel)
    local p = panel.player
    local state = IKST.getPlayerState(p)
    if not state then
        return 8
    end
    if not state.guardRadius then
        state.guardRadius = IKST.RADIUS_PRESETS.M
    end
    local rect = IKUI_SoftBody.contentRect(panel)
    local gap = IKUI_SoftBody.BTN_GAP
    local bands, stackBottom = IKUI_SoftBody.stack(rect.y, gap, { 1, 2, 2, 1 })

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[1], IKST.text("IGUI_IKST_Protect_Square", "Square"))
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_Protect_ClickProtect", "Protect"),
                primary = IKST_JobTilesGuard.pickActive(state, IKST.CMD.protectSquare)
                    or IKST_JobTilesGuard.onOffPrimary(panel, "protectSquare", true),
                onClick = function()
                    IKST_JobTilesGuard.setOnOffFeedback(panel, "protectSquare", true)
                    IKST_JobTilesGuard.armSquarePick(panel, IKST.CMD.protectSquare, nil, "IGUI_IKST_Guard_ClickProtect", function()
                        IKST_JobTilesGuard.requestList(p)
                    end)
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Protect_ClickUnprotect", "Unprotect"),
                primary = IKST_JobTilesGuard.pickActive(state, IKST.CMD.unprotectSquare)
                    or IKST_JobTilesGuard.onOffPrimary(panel, "protectSquare", false),
                onClick = function()
                    IKST_JobTilesGuard.setOnOffFeedback(panel, "protectSquare", false)
                    IKST_JobTilesGuard.armSquarePick(panel, IKST.CMD.unprotectSquare, nil, "IGUI_IKST_Guard_ClickUnprotect", function()
                        IKST_JobTilesGuard.requestList(p)
                    end)
                end,
            },
        })
    end

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[2], IKST.text("IGUI_IKST_SectionCircle", "Circle"))
        local items = {}
        for _, preset in ipairs({ IKST.RADIUS_PRESETS.S, IKST.RADIUS_PRESETS.M, IKST.RADIUS_PRESETS.L }) do
            local val = preset
            items[#items + 1] = {
                label = "R " .. tostring(val),
                primary = state.guardRadius == val,
                onClick = function()
                    state.guardRadius = val
                    panel:refreshJobUI()
                end,
            }
        end
        items[#items + 1] = {
            label = IKST.text("IGUI_IKST_Protect_Radius", "Protect circle"),
            onClick = function()
                IKST_JobTilesGuard.dispatchRadius(panel, IKST.CMD.protectRadius, nil)
                IKST_JobTilesGuard.requestList(p)
            end,
        }
        items[#items + 1] = {
            label = IKST.text("IGUI_IKST_Protect_Unradius", "Unprotect circle"),
            onClick = function()
                IKST_JobTilesGuard.dispatchRadius(panel, IKST.CMD.unprotectRadius, nil)
                IKST_JobTilesGuard.requestList(p)
            end,
        }
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, items)
    end

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[3], IKST.text("IGUI_IKST_Protect_ReadonlySection", "Readonly & locks"))
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_Protect_ReadonlyOn", "Lock storage"),
                primary = IKST_JobTilesGuard.pickActiveReadonly(state, true)
                    or IKST_JobTilesGuard.onOffPrimary(panel, "readonly", true),
                onClick = function()
                    IKST_JobTilesGuard.setOnOffFeedback(panel, "readonly", true)
                    IKST_JobTilesGuard.armSquarePick(panel, IKST.CMD.setReadonly, { on = true }, "IGUI_IKST_Guard_ClickReadonlyOn", function()
                        IKST_JobTilesGuard.requestList(p)
                    end)
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Protect_ReadonlyOff", "Unlock storage"),
                primary = IKST_JobTilesGuard.pickActiveReadonly(state, false)
                    or IKST_JobTilesGuard.onOffPrimary(panel, "readonly", false),
                onClick = function()
                    IKST_JobTilesGuard.setOnOffFeedback(panel, "readonly", false)
                    IKST_JobTilesGuard.armSquarePick(panel, IKST.CMD.setReadonly, { on = false }, "IGUI_IKST_Guard_ClickReadonlyOff", function()
                        IKST_JobTilesGuard.requestList(p)
                    end)
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Protect_ReadonlyRadiusOn", "Lock circle"),
                onClick = function()
                    IKST_JobTilesGuard.dispatchRadius(panel, IKST.CMD.setReadonlyRadius, { on = true })
                    IKST_JobTilesGuard.requestList(p)
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Protect_ReadonlyRadiusOff", "Unlock circle"),
                onClick = function()
                    IKST_JobTilesGuard.dispatchRadius(panel, IKST.CMD.setReadonlyRadius, { on = false })
                    IKST_JobTilesGuard.requestList(p)
                end,
            },
        })
    end

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[4], IKST.text("IGUI_IKST_Guard_Blacklist", "Sprite blacklist"))
        local draft = ""
        if type(panel.draftEntryText) == "function" then
            draft = panel:draftEntryText("guardSpriteEntry", "")
        end
        IKUI_SoftBody.fieldAction(panel, card, ax, ay, aw, ah, {
            { text = draft, fieldName = "guardSpriteEntry" },
        }, IKST.text("IGUI_IKST_Guard_Blacklist", "Add rule"), function()
            IKST.dispatchCommand(p, IKST.CMD.addSpriteBlacklist, {
                sprite = IKST_JobTilesGuard.readEntry(panel.guardSpriteEntry),
            })
        end)
    end

    return stackBottom + gap
end

function IKST_SoftTool_Tiles.buildBlueprints(panel)
    local p = panel.player
    local state = IKST.getPlayerState(p)
    local half = 5
    local rect = IKUI_SoftBody.contentRect(panel)
    local gap = IKUI_SoftBody.BTN_GAP
    local btnH = IKUI_SoftBody.STANDARD_BTN_H
    local cursorH = IKUI_SoftBody.compactPillBandH(1)
    local saveH = IKUI_SoftBody.fieldActionBandH(1)
    local namedH = math.max(80, rect.h - cursorH - gap - saveH - gap)
    local bands = {
        { y = rect.y, h = cursorH },
        { y = rect.y + cursorH + gap, h = saveH },
        { y = rect.y + cursorH + gap + saveH + gap, h = namedH },
    }
    local stackBottom = bands[3].y + bands[3].h

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[1], IKST.text("IGUI_IKST_Guard_BpCopy", "Cursor"))
        local copyArmed = state and state.worldPickOnClick ~= nil
            and (state.armedJob == IKST.VIEW.guard or state.armedJob == IKST.VIEW.tiles)
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_Guard_BpCopy", "Copy"),
                primary = copyArmed == true,
                onClick = function()
                    IKST_JobTilesGuard.armSquarePick(panel, nil, nil, "IGUI_IKST_Guard_ClickBlueprintCopy", nil, function(player, square)
                        local x = square:getX()
                        local y0 = square:getY()
                        local z = square:getZ()
                        IKST.dispatchCommand(player, IKST.CMD.blueprintCopy, {
                            x1 = x - half, y1 = y0 - half, x2 = x + half, y2 = y0 + half, z = z,
                        })
                    end)
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Guard_BpPaste", "Paste"),
                primary = IKST_JobTilesGuard.pickActive(state, IKST.CMD.blueprintPaste),
                onClick = function()
                    IKST_JobTilesGuard.armSquarePick(panel, IKST.CMD.blueprintPaste, nil, "IGUI_IKST_Guard_ClickBlueprintPaste")
                end,
            },
        })
    end

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[2], IKST.text("IGUI_IKST_Guard_BpLibrary", "Library"))
        IKUI_SoftBody.fieldAction(panel, card, ax, ay, aw, ah, {
            { text = panel.bpLibraryName or "Pad", fieldName = "bpNameEntry" },
        }, IKST.text("IGUI_IKST_WaypointSave", "Save"), function()
            local name = IKST_JobTilesGuard.readEntry(panel.bpNameEntry)
            panel.bpLibraryName = name
            IKST.dispatchCommand(p, IKST.CMD.blueprintSave, { name = name })
        end)
    end

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[3], IKST.text("IGUI_IKST_Guard_BpLibrary", "Named"))
        local listH, pillH, gapLP = IKUI_SoftBody.listPillSplit(ah, 1)
        local list = IKST_JobTilesGuard.blueprints or {}
        local rows = {}
        for i, row in ipairs(list) do
            if i > 24 then
                break
            end
            rows[#rows + 1] = {
                id = tostring(row.name or i),
                label = tostring(row.name or ("#" .. tostring(i))),
                data = row,
            }
        end
        IKST_JobLayout.makeSelectList(panel, card, ax, ay, aw, listH, rows, {
            onSelect = function(row)
                if row and row.data and row.data.name then
                    panel.bpLibraryName = row.data.name
                    if panel.bpNameEntry and type(panel.bpNameEntry.setText) == "function" then
                        panel.bpNameEntry:setText(row.data.name)
                    end
                end
            end,
        })
        local pillY = ay + listH + gapLP
        local pillAreaH = math.max(btnH, pillH)
        IKUI_SoftBody.pillRow(panel, card, ax, pillY, aw, pillAreaH, {
            {
                label = IKST.text("IGUI_IKST_Guard_BpLoad", "Load"),
                primary = true,
                onClick = function()
                    IKST.dispatchCommand(p, IKST.CMD.blueprintLoad, {
                        name = IKST_JobTilesGuard.readEntry(panel.bpNameEntry),
                    })
                end,
            },
            {
                label = IKST.text("IGUI_IKST_RefreshList", "Refresh"),
                onClick = function()
                    IKST.dispatchCommand(p, IKST.CMD.blueprintList, {})
                end,
            },
        })
    end

    return stackBottom + gap
end

function IKST_SoftTool_Tiles.buildPaint(panel)
    local state = IKST_JobPainter.ensureState(panel)
    if not state then
        return 8
    end
    local rect = IKUI_SoftBody.contentRect(panel)
    local gap = IKUI_SoftBody.BTN_GAP
    local searchH = IKUI_SoftBody.fieldActionBandH(1)
    local modeH = IKUI_SoftBody.compactPillBandH(2)
    local modeBand = { y = rect.y, h = modeH, x = rect.x, w = rect.w }
    local packBand = { y = rect.y + modeH + gap, h = math.max(120, rect.h - modeH - searchH - gap * 2), x = rect.x, w = rect.w }
    local searchBand = { y = packBand.y + packBand.h + gap, h = searchH, x = rect.x, w = rect.w }
    local pick = state.currentPick
    local painterArmed = state.armed and state.armedJob == IKST.VIEW.painter
    local L = IKUI_Layout or IKST_UI_Layout

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, modeBand, IKST.text("IGUI_IKST_SectionModes", "Modes"))
        local modes = {
            { id = IKST.PAINTER_MODES.eyedropper, label = IKST.text("IGUI_IKST_Eyedropper", "Eyedropper") },
            { id = IKST.PAINTER_MODES.paint, label = IKST.text("IGUI_IKST_Paint", "Paint"), primary = true },
            { id = IKST.PAINTER_MODES.wall, label = IKST.text("IGUI_IKST_TilesTile_PaintWall", "Paint wall") },
            { id = IKST.PAINTER_MODES.remove, label = IKST.text("IGUI_IKST_Remove", "Remove") },
            { id = IKST.PAINTER_MODES.replace, label = IKST.text("IGUI_IKST_Replace", "Replace tile") },
        }
        local items = {}
        for i = 1, #modes do
            local m = modes[i]
            items[#items + 1] = {
                label = m.label,
                primary = painterArmed and state.painterMode == m.id,
                onClick = function()
                    if IKST_PaintCursorManager and type(IKST_PaintCursorManager.arm) == "function" then
                        IKST_PaintCursorManager.arm(panel.player, m.id)
                    end
                    panel:refreshJobUI()
                end,
            }
        end
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, items)
    end

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, packBand, IKST.text("IGUI_IKST_SectionPack", "Pack"))
        local area = L.box(ax, ay, aw, ah)
        local btnWStd, btnHStd = IKUI_SoftBody.standardPillSize(aw)
        local names = panel.packNames or {}
        local pageStart = ((panel.packPage or 1) - 1) * 4 + 1
        local packItems = {}
        for i = pageStart, math.min(pageStart + 3, #names) do
            local name = names[i]
            packItems[#packItems + 1] = {
                label = string.sub(name, 1, 18),
                primary = panel.selectedPack == name,
                onClick = function()
                    panel.selectedPack = name
                    panel.spriteGridPage = 1
                    IKST_JobPainter.loadSelectedPack(panel)
                    panel:refreshJobUI()
                end,
            }
        end
        local packH = btnHStd
        local actListH = btnHStd
        local actPackNavH = btnHStd
        local actTileNavH = btnHStd
        local labelH = 16
        local slotGap = 6
        local slots = L.columnIn(area, {
            { h = labelH },
            { h = packH },
            { h = actListH },
            { h = actPackNavH },
            { h = actTileNavH },
            { flex = 1 },
        }, { gap = slotGap, pad = 0 })

        local pickLabel = pick and pick.sprite or IKST.text("IGUI_IKST_NoPick", "No sprite selected")
        local info = ISLabel:new(slots[1].x, slots[1].y, labelH, pickLabel, 1, 1, 1, 1, UIFont.Small, true)
        info:initialise()
        card:addChild(info)

        if #packItems > 0 and slots[2] then
            IKUI_SoftBody.pillRow(panel, card, slots[2].x, slots[2].y, slots[2].w, slots[2].h, packItems)
        end
        if slots[3] then
            IKUI_SoftBody.pillRow(panel, card, slots[3].x, slots[3].y, slots[3].w, slots[3].h, {
                {
                    label = IKST.text("IGUI_IKST_ListPacks", "List packs"),
                    onClick = function()
                        IKST_JobPainter.listPacks(panel)
                        panel:refreshJobUI()
                    end,
                },
                {
                    label = IKST.text("IGUI_IKST_LoadPack", "Load"),
                    primary = true,
                    onClick = function()
                        IKST_JobPainter.loadSelectedPack(panel)
                        panel:refreshJobUI()
                    end,
                },
            })
        end
        if slots[4] then
            local packPage = panel.packPage or 1
            local packPages = IKST_JobPainter.packPageCount(panel)
            IKUI_SoftBody.pillNavRow(panel, card, slots[4].x, slots[4].y, slots[4].w, slots[4].h, {
                {
                    label = IKST.text("IGUI_IKST_PackPrev", "<"),
                    onClick = function()
                        IKST_JobPainter.shiftPackPage(panel, -1)
                    end,
                },
                {
                    label = string.format("%d / %d", packPage, packPages),
                    primary = "chip",
                    onClick = function()
                    end,
                },
                {
                    label = IKST.text("IGUI_IKST_PackNext", ">"),
                    onClick = function()
                        IKST_JobPainter.shiftPackPage(panel, 1)
                    end,
                },
            })
        end
        if slots[5] then
            local tilePage = panel.spriteGridPage or 1
            local tilePages = IKST_JobPainter.spritePageCount(panel)
            IKUI_SoftBody.pillNavRow(panel, card, slots[5].x, slots[5].y, slots[5].w, slots[5].h, {
                {
                    label = IKST.text("IGUI_IKST_TilesPrev", "<"),
                    onClick = function()
                        IKST_JobPainter.shiftSpritePage(panel, -1)
                    end,
                },
                {
                    label = string.format("%d / %d", tilePage, tilePages),
                    primary = "chip",
                    onClick = function()
                    end,
                },
                {
                    label = IKST.text("IGUI_IKST_TilesNext", ">"),
                    onClick = function()
                        IKST_JobPainter.shiftSpritePage(panel, 1)
                    end,
                },
            })
        end
        if slots[6] and slots[6].h >= 36 then
            local sprites = IKST_JobPainter.getGridSprites(panel)
            local grid = IKST_SpriteGrid:new(slots[6].x, slots[6].y, slots[6].w, slots[6].h, sprites, function(sprite)
                IKST_JobPainter.onSpritePicked(panel, sprite)
            end)
            if type(grid.layoutMetrics) == "function" then
                grid:layoutMetrics()
            end
            panel._spriteGridPerPage = math.max(1, grid.perPage or 8)
            grid.page = panel.spriteGridPage or 1
            grid.onPageChange = function(page)
                panel.spriteGridPage = page
            end
            if grid.clipping ~= nil then
                grid.clipping = true
            end
            grid:initialise()
            IKUI_SoftBody.attach(panel, card, grid)
            panel._ikstSelectLists = panel._ikstSelectLists or {}
            panel._ikstSelectLists[#panel._ikstSelectLists + 1] = grid
        end
    end

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, searchBand, IKST.text("IGUI_IKST_SpriteFilter", "Sprite"))
        local defaultText = panel.spriteFilter or ""
        if defaultText == "" and pick and pick.sprite then
            defaultText = pick.sprite
        end
        IKUI_SoftBody.fieldAction(panel, card, ax, ay, aw, ah, {
            { text = defaultText, fieldName = "spriteFilterEntry" },
        }, IKST.text("IGUI_IKST_UseSprite", "Use sprite"), function()
            local name = IKST_JobPainter.readEntryText(panel.spriteFilterEntry)
            if name == "" and pick and pick.sprite then
                name = pick.sprite
            end
            IKST_JobPainter.tryManualSprite(panel, name)
        end)
    end

    return rect.y + rect.h
end

function IKST_SoftTool_Tiles.build(panel)
    if not panel then
        return 8
    end
    local state = IKST.getPlayerState(panel.player)
    if not state then
        return 8
    end
    local tool = state.navTool or "overview"
    if tool == "remove" then
        return IKST_SoftTool_Tiles.buildRemove(panel)
    end
    if tool == "paint" then
        return IKST_SoftTool_Tiles.buildPaint(panel)
    end
    if tool == "inspect" then
        return IKST_SoftTool_Tiles.buildInspect(panel)
    end
    if tool == "blueprints" then
        return IKST_SoftTool_Tiles.buildBlueprints(panel)
    end
    if tool == "area" then
        return IKST_SoftTool_Tiles.buildArea(panel)
    end
    if tool == "protect" then
        return IKST_SoftTool_Tiles.buildProtect(panel)
    end
    return IKST_SoftTool_Tiles.buildOverview(panel)
end

function IKST_SoftTool_Tiles.buildForServer(panel)
    return IKST_SoftTool_Tiles.build(panel)
end
