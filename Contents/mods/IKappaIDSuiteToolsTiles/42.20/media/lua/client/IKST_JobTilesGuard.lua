if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISTextEntryBox"
require "IKST_Shared"
require "IKappaID_UI/IKUI_Chrome"
require "IKST_ActionLog"
require "IKST_JobLayout"
require "IKST_WorldPick"

IKST_JobTilesGuard = IKST_JobTilesGuard or {}
IKST_JobTilesGuard.tiles = {}
IKST_JobTilesGuard.total = 0
IKST_JobTilesGuard.readonlyTotal = 0
IKST_JobTilesGuard.blueprints = {}

function IKST_JobTilesGuard.requestList(player)
    IKST.dispatchCommand(player, IKST.CMD.protectList, {
        x = math.floor(player:getX()), y = math.floor(player:getY()), z = player:getZ(),
        radius = IKST.getVehicleListRadius(),
    })
end

function IKST_JobTilesGuard.readEntry(entry)
    if not entry or type(entry.getText) ~= "function" then
        return ""
    end
    return entry:getText() or ""
end

function IKST_JobTilesGuard.coords(player)
    return { x = math.floor(player:getX()), y = math.floor(player:getY()), z = player:getZ() }
end

function IKST_JobTilesGuard.pickActive(state, command)
    if not state or not state.armed then
        return false
    end
    if state.armedJob ~= IKST.VIEW.guard and state.armedJob ~= IKST.VIEW.tiles then
        return false
    end
    if command then
        return state.worldPickCommand == command
    end
    return state.worldPickCommand ~= nil
        or (state.worldPickOnClick and type(state.worldPickOnClick) == "function")
end

function IKST_JobTilesGuard.pickActiveReadonly(state, on)
    if not IKST_JobTilesGuard.pickActive(state, IKST.CMD.setReadonly) then
        return false
    end
    local extra = state.worldPickExtra
    if not extra then
        return false
    end
    return (extra.on == true) == (on == true)
end

function IKST_JobTilesGuard.nowMs()
    if type(getTimestampMs) == "function" then
        return getTimestampMs()
    end
    return 0
end

-- On/Off feedback: selected stays orange while armed; Off flashes ~1s when chosen.
function IKST_JobTilesGuard.setOnOffFeedback(panel, groupId, isOn)
    if not panel then
        return
    end
    panel._onOffChoice = panel._onOffChoice or {}
    local flashUntil = 0
    if not isOn then
        flashUntil = IKST_JobTilesGuard.nowMs() + 1000
    end
    panel._onOffChoice[groupId] = { on = isOn == true, flashUntil = flashUntil }
end

function IKST_JobTilesGuard.onOffPrimary(panel, groupId, isOn)
    if not panel or not panel._onOffChoice then
        return false
    end
    local choice = panel._onOffChoice[groupId]
    if not choice then
        return false
    end
    if (choice.on == true) ~= (isOn == true) then
        return false
    end
    if isOn then
        return true
    end
    return (choice.flashUntil or 0) > IKST_JobTilesGuard.nowMs()
end

function IKST_JobTilesGuard.pruneOnOffFlash(panel)
    if not panel or not panel._onOffChoice or panel._onOffFlashRefreshing then
        return
    end
    local now = IKST_JobTilesGuard.nowMs()
    local dirty = false
    for _, choice in pairs(panel._onOffChoice) do
        if choice and choice.on ~= true and (choice.flashUntil or 0) > 0 and choice.flashUntil <= now then
            choice.flashUntil = 0
            dirty = true
        end
    end
    if dirty and panel.refreshJobUI then
        panel._onOffFlashRefreshing = true
        panel:refreshJobUI(true)
        panel._onOffFlashRefreshing = false
    end
end

function IKST_JobTilesGuard.armSquarePick(panel, command, extra, notifyKey, after, onClick)
    local p = panel.player
    if not p or not IKST_WorldPick or not IKST_WorldPick.armCommand then
        return
    end
    IKST_WorldPick.armCommand(p, IKST.VIEW.tiles, command, extra, {
        notifyKey = notifyKey,
        after = after,
        onClick = onClick,
    })
    panel:refreshJobUI()
end

function IKST_JobTilesGuard.dispatchRadius(panel, cmd, extra)
    local p = panel.player
    local state = IKST.getPlayerState(p)
    local radius = state and state.guardRadius or IKST.RADIUS_PRESETS.M
    local args = { x = math.floor(p:getX()), y = math.floor(p:getY()), z = p:getZ(), radius = radius }
    if extra then
        for k, v in pairs(extra) do
            args[k] = v
        end
    end
    IKST.dispatchCommand(p, cmd, args)
end

function IKST_JobTilesGuard.buildTiles(panel, contentTop)
    local p = panel.player
    local state = IKST.getPlayerState(p)
    if not state then
        return 8
    end
    if not state.guardRadius then
        state.guardRadius = IKST.RADIUS_PRESETS.M
    end

    local rect = IKST_JobLayout.toolContentRect(panel)
    if contentTop and contentTop > rect.y then
        local shrink = contentTop - rect.y
        rect.y = contentTop
        rect.h = math.max(80, rect.h - shrink)
    end
    local gap = 6
    local bands = IKST_JobLayout.splitBands(rect.y, rect.h, 4, gap)
    local inner = IKST_JobLayout.SECTION_INNER
    local padY = IKST_JobLayout.CONTENT_PAD_Y
    local btnH = IKST_JobLayout.STANDARD_BTN_H

    local function openBand(band, title)
        local card, contentY = IKST_JobLayout.placeSectionCard(panel, rect.x, band.y, rect.w, band.h, nil, title)
        local areaX = inner
        local areaW = math.max(40, rect.w - inner * 2)
        local areaY = contentY + padY
        local areaH = math.max(btnH, band.h - contentY - padY * 2)
        return card, areaX, areaY, areaW, areaH
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[1], IKST.text("IGUI_IKST_Protect_Square", "Square"))
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, {
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
        local card, ax, ay, aw, ah = openBand(bands[2], IKST.text("IGUI_IKST_SectionCircle", "Circle"))
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
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, items)
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[3], IKST.text("IGUI_IKST_Protect_ReadonlySection", "Readonly & locks"))
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, {
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
        local card, ax, ay, aw, ah = openBand(bands[4], IKST.text("IGUI_IKST_Guard_Blacklist", "Sprite blacklist"))
        local draft = ""
        if type(panel.draftEntryText) == "function" then
            draft = panel:draftEntryText("guardSpriteEntry", "")
        end
        IKST_JobLayout.placeFieldActionCorner(panel, card, ax, ay, aw, ah, {
            { text = draft, fieldName = "guardSpriteEntry" },
        }, IKST.text("IGUI_IKST_Guard_Blacklist", "Add rule"), function()
            IKST.dispatchCommand(p, IKST.CMD.addSpriteBlacklist, {
                sprite = IKST_JobTilesGuard.readEntry(panel.guardSpriteEntry),
            })
        end)
    end

    panel._ikstToolFit = true
    return rect.y + rect.h
end

function IKST_JobTilesGuard.buildContainers(panel, y)
    local p = panel.player
    local state = IKST.getPlayerState(p)
    y = panel:makeJobHeader(12, y, IKST.text("IGUI_IKST_Protect_DropboxSection", "Dropbox"))
    panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Protect_ContainerNote", "Click a square in the world. Transfers enforced."), UIFont.Small)
    y = y + 20
    panel.guardOwnerEntry = ISTextEntryBox:new(panel:draftEntryText("guardOwnerEntry", ""), 12, y, 160, 22)
    panel.guardOwnerEntry:initialise()
    panel.guardOwnerEntry:instantiate()
    panel:addJobWidget(panel.guardOwnerEntry)
    panel:makeJobButton(180, y, 90, 22, IKST.text("IGUI_IKST_Guard_Dropbox", "Dropbox"), function()
        IKST_JobTilesGuard.armSquarePick(panel, IKST.CMD.setDropbox, {
            owner = IKST_JobTilesGuard.readEntry(panel.guardOwnerEntry),
        }, "IGUI_IKST_Guard_ClickDropbox")
    end, IKST_JobTilesGuard.pickActive(state, IKST.CMD.setDropbox))
    y = y + 30

    y = panel:makeJobHeader(12, y, IKST.text("IGUI_IKST_Protect_KeypadSection", "Keypad lock"))
    panel.guardLockEntry = ISTextEntryBox:new(panel:draftEntryText("guardLockEntry", ""), 12, y, 120, 22)
    panel.guardLockEntry:initialise()
    panel.guardLockEntry:instantiate()
    panel:addJobWidget(panel.guardLockEntry)
    panel:makeJobButton(140, y, 90, 22, IKST.text("IGUI_IKST_Guard_Lock", "Lock"), function()
        IKST_JobTilesGuard.armSquarePick(panel, IKST.CMD.lockSetPassword, {
            password = IKST_JobTilesGuard.readEntry(panel.guardLockEntry),
        }, "IGUI_IKST_Guard_ClickLock")
    end, IKST_JobTilesGuard.pickActive(state, IKST.CMD.lockSetPassword))
    panel:makeJobButton(236, y, 70, 22, IKST.text("IGUI_IKST_Guard_Clear", "Clear"), function()
        IKST_JobTilesGuard.armSquarePick(panel, IKST.CMD.lockClear, nil, "IGUI_IKST_Guard_ClickLockClear")
    end, IKST_JobTilesGuard.pickActive(state, IKST.CMD.lockClear))
    y = y + 30
    panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Protect_ReadonlyMoved", "Storage lock (readonly) is on the Ground tab."), UIFont.Small)
    return y + 22
end

function IKST_JobTilesGuard.buildFarming(panel, y)
    local state = IKST.getPlayerState(panel.player)
    if not state.guardRadius then
        state.guardRadius = IKST.RADIUS_PRESETS.M
    end
    local x = 12
    for _, preset in ipairs({ IKST.RADIUS_PRESETS.S, IKST.RADIUS_PRESETS.M, IKST.RADIUS_PRESETS.L }) do
        panel:makeJobButton(x, y, 70, 22, tostring(preset), function()
            state.guardRadius = preset
            panel:refreshJobUI()
        end, state.guardRadius == preset)
        x = x + 74
    end
    y = y + 28
    panel:makeJobButton(12, y, 140, 24, IKST.text("IGUI_IKST_Guard_FarmRevive", "Revitalize"), function()
        IKST_JobTilesGuard.dispatchRadius(panel, IKST.CMD.farmRevitalize, nil)
    end, true)
    panel:makeJobButton(158, y, 140, 24, IKST.text("IGUI_IKST_Guard_FarmHarvest", "Harvest all"), function()
        IKST_JobTilesGuard.dispatchRadius(panel, IKST.CMD.farmHarvestAll, nil)
    end, false)
    return y + 34
end

function IKST_JobTilesGuard.buildBlueprints(panel, contentTop)
    local p = panel.player
    local state = IKST.getPlayerState(p)
    local half = 5

    local rect = IKST_JobLayout.toolContentRect(panel)
    if contentTop and contentTop > rect.y then
        local shrink = contentTop - rect.y
        rect.y = contentTop
        rect.h = math.max(80, rect.h - shrink)
    end
    local gap = 6
    local bands = IKST_JobLayout.splitBands(rect.y, rect.h, 3, gap)
    local inner = IKST_JobLayout.SECTION_INNER
    local padY = IKST_JobLayout.CONTENT_PAD_Y
    local btnH = IKST_JobLayout.STANDARD_BTN_H

    local function openBand(band, title)
        local card, contentY = IKST_JobLayout.placeSectionCard(panel, rect.x, band.y, rect.w, band.h, nil, title)
        local areaX = inner
        local areaW = math.max(40, rect.w - inner * 2)
        local areaY = contentY + padY
        local areaH = math.max(btnH, band.h - contentY - padY * 2)
        return card, areaX, areaY, areaW, areaH
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[1], IKST.text("IGUI_IKST_Guard_BpCopy", "Cursor"))
        local copyArmed = state and state.worldPickOnClick ~= nil
            and (state.armedJob == IKST.VIEW.guard or state.armedJob == IKST.VIEW.tiles)
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, {
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
        local card, ax, ay, aw, ah = openBand(bands[2], IKST.text("IGUI_IKST_Guard_BpLibrary", "Library"))
        IKST_JobLayout.placeFieldActionCorner(panel, card, ax, ay, aw, ah, {
            { text = panel.bpLibraryName or "Pad", fieldName = "bpNameEntry" },
        }, IKST.text("IGUI_IKST_WaypointSave", "Save"), function()
            local name = IKST_JobTilesGuard.readEntry(panel.bpNameEntry)
            panel.bpLibraryName = name
            IKST.dispatchCommand(p, IKST.CMD.blueprintSave, { name = name })
        end)
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[3], IKST.text("IGUI_IKST_Guard_BpLibrary", "Named"))
        local listH, pillH, gapLP = IKST_JobLayout.listPillSplit(ah, 1)
        local pillY = ay + listH + gapLP
        local pillAreaH = math.max(btnH, pillH)
        local list = IKST_JobTilesGuard.blueprints or {}
        local rows = {}
        for i, row in ipairs(list) do
            if i > 24 then
                break
            end
            rows[#rows + 1] = {
                id = tostring(row.name),
                label = tostring(row.name) .. " (" .. tostring(row.tiles or 0) .. ")",
                data = row,
            }
        end
        if #rows == 0 then
            rows[1] = {
                id = "_empty",
                label = IKST.text("IGUI_IKST_Guard_BpEmpty", "No named blueprints yet."),
                data = nil,
            }
        end
        IKST_JobLayout.makeSelectList(panel, card, ax, ay, aw, listH, rows, {
            selectedId = panel.bpLibraryName,
            onSelect = function(row)
                if row and row.data and row.data.name then
                    panel.bpLibraryName = row.data.name
                    if panel.bpNameEntry and type(panel.bpNameEntry.setText) == "function" then
                        panel.bpNameEntry:setText(tostring(row.data.name))
                    end
                end
            end,
        })
        IKST_JobLayout.placePillGroup(panel, card, ax, pillY, aw, pillAreaH, {
            {
                label = IKST.text("IGUI_IKST_Guard_BpLoad", "Load"),
                primary = true,
                onClick = function()
                    local name = IKST_JobTilesGuard.readEntry(panel.bpNameEntry)
                    if name == "" then
                        name = panel.bpLibraryName
                    end
                    panel.bpLibraryName = name
                    IKST.dispatchCommand(p, IKST.CMD.blueprintLoad, { name = name })
                end,
            },
            {
                label = IKST.text("IGUI_IKST_WaypointDel", "Delete"),
                onClick = function()
                    local name = IKST_JobTilesGuard.readEntry(panel.bpNameEntry)
                    if name == "" then
                        name = panel.bpLibraryName
                    end
                    IKST.dispatchCommand(p, IKST.CMD.blueprintDelete, { name = name })
                    IKST.dispatchCommand(p, IKST.CMD.blueprintList, {})
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

    panel._ikstToolFit = true
    return rect.y + rect.h
end

function IKST_JobTilesGuard.onBlueprintListResult(args)
    IKST_JobTilesGuard.blueprints = (args and args.blueprints) or {}
    if IKST_JobsPanel and IKST_JobsPanel.instance then
        IKST_JobsPanel.instance:refreshJobUI()
    end
end

function IKST_JobTilesGuard.buildRestore(panel, y)
    local p = panel.player
    panel:makeJobButton(12, y, 140, 24, IKST.text("IGUI_IKST_Guard_SnapSave", "Save snapshot"), function()
        IKST.dispatchCommand(p, IKST.CMD.createSnapshot, {})
    end, true)
    panel:makeJobButton(158, y, 140, 24, IKST.text("IGUI_IKST_Guard_SnapRestore", "Restore snapshot"), function()
        IKST.dispatchCommand(p, IKST.CMD.restoreSnapshot, {})
    end, false)
    return y + 34
end

function IKST_JobTilesGuard.buildProtect(panel, y)
    local state = IKST.getPlayerState(panel.player)
    if not state then
        return y or 8
    end
    local modes = { "tiles", "containers", "farming" }
    if not state.guardMode or state.guardMode == "safehouses" or state.guardMode == "vehicles" or state.guardMode == "tools" then
        state.guardMode = "tiles"
    end
    y = y or 8
    local modeSpecs = {}
    for _, mode in ipairs(modes) do
        local id = mode
        modeSpecs[#modeSpecs + 1] = {
            label = IKST.text("IGUI_IKST_Guard_" .. id, id),
            w = 88,
            primary = state.guardMode == id,
            fn = function()
                state.guardMode = id
                if id == "tiles" then
                    IKST_JobTilesGuard.requestList(panel.player)
                end
                panel:refreshJobUI()
            end,
        }
    end
    y = IKST_JobLayout.flowRow(panel, y, modeSpecs, 6, 24)

    if state.guardMode == "tiles" then
        return IKST_JobTilesGuard.buildTiles(panel, y)
    elseif state.guardMode == "containers" then
        y = IKST_JobTilesGuard.buildContainers(panel, y)
    elseif state.guardMode == "farming" then
        y = IKST_JobTilesGuard.buildFarming(panel, y)
    end
    if state.armed and (state.armedJob == IKST.VIEW.guard or state.armedJob == IKST.VIEW.tiles
        or IKST_JobTilesGuard.pickActive(state)) then
        panel:makeJobButton(12, y, 100, 24, IKST.text("IGUI_IKST_Disarm", "STOP"), function()
            if IKST_WorldPick and type(IKST_WorldPick.disarm) == "function" then
                IKST_WorldPick.disarm(panel.player)
            end
            panel:refreshJobUI()
        end, true)
        y = y + 30
    end
    return y
end

function IKST_JobTilesGuard.onListResult(args)
    IKST_JobTilesGuard.tiles = (args and args.tiles) or {}
    IKST_JobTilesGuard.total = (args and args.total) or 0
    IKST_JobTilesGuard.readonlyTotal = (args and args.readonlyTotal) or 0
    if IKST_JobsPanel and IKST_JobsPanel.instance then
        IKST_JobsPanel.instance:refreshJobUI()
    end
end
