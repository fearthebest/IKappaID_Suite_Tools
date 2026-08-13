if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISTextEntryBox"
require "IKST_Shared"
require "IKST_Chrome"
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
    if not entry or not entry.getText then
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

function IKST_JobTilesGuard.buildTiles(panel, y)
    local p = panel.player
    local state = IKST.getPlayerState(p)
    if not state.guardRadius then
        state.guardRadius = IKST.RADIUS_PRESETS.M
    end

    y = panel:makeJobHeader(12, y, IKST.text("IGUI_IKST_Protect_Square", "Square protect"))
    panel:makeJobButton(12, y, 100, 24, IKST.text("IGUI_IKST_RefreshList", "Refresh"), function()
        IKST_JobTilesGuard.requestList(p)
    end, false)
    panel:makeJobLabel(130, y + 4, IKST.text("IGUI_IKST_Protect_Total", "Total") .. ": " .. tostring(IKST_JobTilesGuard.total)
        .. " / " .. IKST.text("IGUI_IKST_Protect_ReadonlyTotal", "Locked") .. ": " .. tostring(IKST_JobTilesGuard.readonlyTotal), UIFont.Small)
    y = y + 28
    panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Protect_OnOffHint", "On = protect click · Off = unprotect click"), UIFont.Small)
    y = y + 18

    y = IKST_JobLayout.flowRow(panel, y, {
        {
            label = IKST.text("IGUI_IKST_On", "On"),
            w = 72,
            primary = IKST_JobTilesGuard.pickActive(state, IKST.CMD.protectSquare)
                or IKST_JobTilesGuard.onOffPrimary(panel, "protectSquare", true),
            fn = function()
                IKST_JobTilesGuard.setOnOffFeedback(panel, "protectSquare", true)
                IKST_JobTilesGuard.armSquarePick(panel, IKST.CMD.protectSquare, nil, "IGUI_IKST_Guard_ClickProtect", function()
                    IKST_JobTilesGuard.requestList(p)
                end)
            end,
        },
        {
            label = IKST.text("IGUI_IKST_Off", "Off"),
            w = 72,
            primary = IKST_JobTilesGuard.pickActive(state, IKST.CMD.unprotectSquare)
                or IKST_JobTilesGuard.onOffPrimary(panel, "protectSquare", false),
            fn = function()
                IKST_JobTilesGuard.setOnOffFeedback(panel, "protectSquare", false)
                IKST_JobTilesGuard.armSquarePick(panel, IKST.CMD.unprotectSquare, nil, "IGUI_IKST_Guard_ClickUnprotect", function()
                    IKST_JobTilesGuard.requestList(p)
                end)
            end,
        },
    }, 6, 24)

    panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Protect_Radius", "Protect circle")
        .. " r=" .. tostring(state.guardRadius), UIFont.Small)
    y = y + 18
    local presetSpecs = {}
    for _, preset in ipairs({ IKST.RADIUS_PRESETS.S, IKST.RADIUS_PRESETS.M, IKST.RADIUS_PRESETS.L }) do
        presetSpecs[#presetSpecs + 1] = {
            label = tostring(preset),
            w = 48,
            primary = state.guardRadius == preset,
            fn = function()
                state.guardRadius = preset
                panel:refreshJobUI()
            end,
        }
    end
    y = IKST_JobLayout.flowRow(panel, y, presetSpecs, 6, 22)
    y = IKST_JobLayout.flowRow(panel, y, {
        {
            label = IKST.text("IGUI_IKST_Protect_Radius", "Protect circle"),
            w = 130,
            primary = false,
            fn = function()
                IKST_JobTilesGuard.dispatchRadius(panel, IKST.CMD.protectRadius, nil)
                IKST_JobTilesGuard.requestList(p)
            end,
        },
        {
            label = IKST.text("IGUI_IKST_Protect_Unradius", "Unprotect circle"),
            w = 140,
            primary = false,
            fn = function()
                IKST_JobTilesGuard.dispatchRadius(panel, IKST.CMD.unprotectRadius, nil)
                IKST_JobTilesGuard.requestList(p)
            end,
        },
    }, 6, 24)
    panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Protect_RadiusAtFeet", "Circle uses your current position."), UIFont.Small)
    y = y + 20

    y = panel:makeJobHeader(12, y, IKST.text("IGUI_IKST_Protect_ReadonlySection", "Storage lock (readonly)"))
    panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Protect_ReadonlyNote", "Blocks taking items from containers on those tiles."), UIFont.Small)
    y = y + 18
    y = IKST_JobLayout.flowRow(panel, y, {
        {
            label = IKST.text("IGUI_IKST_On", "On"),
            w = 72,
            primary = IKST_JobTilesGuard.pickActiveReadonly(state, true)
                or IKST_JobTilesGuard.onOffPrimary(panel, "readonly", true),
            fn = function()
                IKST_JobTilesGuard.setOnOffFeedback(panel, "readonly", true)
                IKST_JobTilesGuard.armSquarePick(panel, IKST.CMD.setReadonly, { on = true }, "IGUI_IKST_Guard_ClickReadonlyOn", function()
                    IKST_JobTilesGuard.requestList(p)
                end)
            end,
        },
        {
            label = IKST.text("IGUI_IKST_Off", "Off"),
            w = 72,
            primary = IKST_JobTilesGuard.pickActiveReadonly(state, false)
                or IKST_JobTilesGuard.onOffPrimary(panel, "readonly", false),
            fn = function()
                IKST_JobTilesGuard.setOnOffFeedback(panel, "readonly", false)
                IKST_JobTilesGuard.armSquarePick(panel, IKST.CMD.setReadonly, { on = false }, "IGUI_IKST_Guard_ClickReadonlyOff", function()
                    IKST_JobTilesGuard.requestList(p)
                end)
            end,
        },
    }, 6, 24)
    y = IKST_JobLayout.flowRow(panel, y, {
        {
            label = IKST.text("IGUI_IKST_Protect_ReadonlyRadiusOn", "Lock circle ON"),
            w = 130,
            primary = false,
            fn = function()
                IKST_JobTilesGuard.dispatchRadius(panel, IKST.CMD.setReadonlyRadius, { on = true })
                IKST_JobTilesGuard.requestList(p)
            end,
        },
        {
            label = IKST.text("IGUI_IKST_Protect_ReadonlyRadiusOff", "Lock circle OFF"),
            w = 140,
            primary = false,
            fn = function()
                IKST_JobTilesGuard.dispatchRadius(panel, IKST.CMD.setReadonlyRadius, { on = false })
                IKST_JobTilesGuard.requestList(p)
            end,
        },
    }, 6, 24)

    y = panel:makeJobHeader(12, y, IKST.text("IGUI_IKST_Protect_WorldRules", "World rules"))
    y = IKST_JobLayout.flowRow(panel, y, {
        {
            label = IKST.text("IGUI_IKST_Guard_NoDestroy", "Global no-destroy"),
            w = 150,
            fn = function()
                IKST.dispatchCommand(p, IKST.CMD.setWorldRule, { rule = "disableDestroy", on = true })
            end,
        },
        {
            label = IKST.text("IGUI_IKST_Guard_AllowDestroy", "Allow destroy"),
            w = 130,
            fn = function()
                IKST.dispatchCommand(p, IKST.CMD.setWorldRule, { rule = "disableDestroy", on = false })
            end,
        },
    }, 6, 24)
    panel.guardSpriteEntry = ISTextEntryBox:new(panel:draftEntryText("guardSpriteEntry", ""), 12, y, 160, 22)
    panel.guardSpriteEntry:initialise()
    panel.guardSpriteEntry:instantiate()
    panel:addJobWidget(panel.guardSpriteEntry)
    panel:makeJobButton(180, y, 100, 22, IKST.text("IGUI_IKST_Guard_Blacklist", "Blacklist"), function()
        IKST.dispatchCommand(p, IKST.CMD.addSpriteBlacklist, { sprite = IKST_JobTilesGuard.readEntry(panel.guardSpriteEntry) })
    end, false)
    return y + 30
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

function IKST_JobTilesGuard.buildBlueprints(panel, y)
    local p = panel.player
    local state = IKST.getPlayerState(p)
    local half = 5
    panel:makeJobButton(12, y, 160, 24, IKST.text("IGUI_IKST_Guard_BpCopy", "Copy 11x11 at click"), function()
        IKST_JobTilesGuard.armSquarePick(panel, nil, nil, "IGUI_IKST_Guard_ClickBlueprintCopy", nil, function(player, square)
            local x = square:getX()
            local y0 = square:getY()
            local z = square:getZ()
            IKST.dispatchCommand(player, IKST.CMD.blueprintCopy, {
                x1 = x - half, y1 = y0 - half, x2 = x + half, y2 = y0 + half, z = z,
            })
        end)
    end, state and state.worldPickOnClick ~= nil and state.armedJob == IKST.VIEW.guard)
    panel:makeJobButton(178, y, 140, 24, IKST.text("IGUI_IKST_Guard_BpPaste", "Paste at click"), function()
        IKST_JobTilesGuard.armSquarePick(panel, IKST.CMD.blueprintPaste, nil, "IGUI_IKST_Guard_ClickBlueprintPaste")
    end, IKST_JobTilesGuard.pickActive(state, IKST.CMD.blueprintPaste))
    y = y + 34
    panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Guard_BpLibrary", "Server blueprint library"), UIFont.Small)
    y = y + 18
    panel.bpNameEntry = ISTextEntryBox:new(panel.bpLibraryName or "Pad", 12, y, 140, 22)
    panel.bpNameEntry:initialise()
    panel.bpNameEntry:instantiate()
    panel:addJobWidget(panel.bpNameEntry)
    panel:makeJobButton(160, y, 55, 22, IKST.text("IGUI_IKST_WaypointSave", "Save"), function()
        local name = IKST_JobTilesGuard.readEntry(panel.bpNameEntry)
        panel.bpLibraryName = name
        IKST.dispatchCommand(p, IKST.CMD.blueprintSave, { name = name })
    end, false)
    panel:makeJobButton(220, y, 55, 22, IKST.text("IGUI_IKST_Guard_BpLoad", "Load"), function()
        local name = IKST_JobTilesGuard.readEntry(panel.bpNameEntry)
        panel.bpLibraryName = name
        IKST.dispatchCommand(p, IKST.CMD.blueprintLoad, { name = name })
    end, false)
    panel:makeJobButton(280, y, 55, 22, IKST.text("IGUI_IKST_WaypointDel", "Delete"), function()
        local name = IKST_JobTilesGuard.readEntry(panel.bpNameEntry)
        IKST.dispatchCommand(p, IKST.CMD.blueprintDelete, { name = name })
        IKST.dispatchCommand(p, IKST.CMD.blueprintList, {})
    end, false)
    y = y + 28
    panel:makeJobButton(12, y, 100, 22, IKST.text("IGUI_IKST_RefreshList", "Refresh"), function()
        IKST.dispatchCommand(p, IKST.CMD.blueprintList, {})
    end, false)
    y = y + 26
    local list = IKST_JobTilesGuard.blueprints or {}
    if #list == 0 then
        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Guard_BpEmpty", "No named blueprints yet."), UIFont.Small)
        y = y + 20
    else
        for i, row in ipairs(list) do
            if i > 8 then
                break
            end
            local label = tostring(row.name) .. " (" .. tostring(row.tiles or 0) .. ")"
            panel:makeJobButton(12, y, panel.contentW or (panel.width - 24), 22, label, function()
                panel.bpLibraryName = row.name
                IKST.dispatchCommand(p, IKST.CMD.blueprintLoad, { name = row.name })
            end, panel.bpLibraryName == row.name)
            y = y + 24
        end
    end
    return y
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
        return y
    end
    local modes = { "tiles", "containers", "farming" }
    if not state.guardMode or state.guardMode == "safehouses" or state.guardMode == "vehicles" or state.guardMode == "tools" then
        state.guardMode = "tiles"
    end
    local x = 12
    for _, mode in ipairs(modes) do
        local label = IKST.text("IGUI_IKST_Guard_" .. mode, mode)
        local w = getTextManager():MeasureStringX(UIFont.Small, label) + 16
        if w < 72 then
            w = 72
        end
        panel:makeJobButton(x, y, w, 22, label, function()
            state.guardMode = mode
            if mode == "tiles" then
                IKST_JobTilesGuard.requestList(panel.player)
            end
            panel:refreshJobUI()
        end, state.guardMode == mode)
        x = x + w + 6
    end
    y = y + 30
    if state.guardMode == "tiles" then
        y = IKST_JobTilesGuard.buildTiles(panel, y)
    elseif state.guardMode == "containers" then
        y = IKST_JobTilesGuard.buildContainers(panel, y)
    elseif state.guardMode == "farming" then
        y = IKST_JobTilesGuard.buildFarming(panel, y)
    end
    if state.armed and (state.armedJob == IKST.VIEW.guard or state.armedJob == IKST.VIEW.tiles
        or IKST_JobTilesGuard.pickActive(state)) then
        panel:makeJobButton(12, y, 100, 24, IKST.text("IGUI_IKST_Disarm", "STOP"), function()
            if IKST_WorldPick and IKST_WorldPick.disarm then
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
