if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISTextEntryBox"
require "IKST_Shared"
require "IKST_Chrome"
require "IKST_ActionLog"
require "IKST_JobLayout"

IKST_JobTilesGuard = IKST_JobTilesGuard or {}
IKST_JobTilesGuard.tiles = {}
IKST_JobTilesGuard.total = 0

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
    local c = IKST_JobTilesGuard.coords(p)
    local state = IKST.getPlayerState(p)
    panel:makeJobButton(12, y, 100, 24, IKST.text("IGUI_IKST_RefreshList", "Refresh"), function()
        IKST_JobTilesGuard.requestList(p)
    end, false)
    panel:makeJobLabel(130, y + 4, IKST.text("IGUI_IKST_Protect_Total", "Total") .. ": " .. tostring(IKST_JobTilesGuard.total), UIFont.Small)
    y = y + 28
    panel:makeJobButton(12, y, 110, 24, IKST.text("IGUI_IKST_Protect_Here", "Protect here"), function()
        IKST.dispatchCommand(p, IKST.CMD.protectSquare, c)
        IKST_JobTilesGuard.requestList(p)
    end, true)
    panel:makeJobButton(128, y, 110, 24, IKST.text("IGUI_IKST_Protect_Unhere", "Unprotect"), function()
        IKST.dispatchCommand(p, IKST.CMD.unprotectSquare, c)
        IKST_JobTilesGuard.requestList(p)
    end, false)
    y = y + 28
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
    y = y + 26
    panel:makeJobButton(12, y, 130, 24, IKST.text("IGUI_IKST_Protect_Radius", "Protect radius"), function()
        IKST.dispatchCommand(p, IKST.CMD.protectRadius, { x = c.x, y = c.y, z = c.z, radius = state.guardRadius })
        IKST_JobTilesGuard.requestList(p)
    end, true)
    panel:makeJobButton(148, y, 130, 24, IKST.text("IGUI_IKST_Protect_Unradius", "Unprotect radius"), function()
        IKST.dispatchCommand(p, IKST.CMD.unprotectRadius, { x = c.x, y = c.y, z = c.z, radius = state.guardRadius })
        IKST_JobTilesGuard.requestList(p)
    end, false)
    y = y + 30
    panel:makeJobButton(12, y, 150, 24, IKST.text("IGUI_IKST_Guard_NoDestroy", "Global no-destroy"), function()
        IKST.dispatchCommand(p, IKST.CMD.setWorldRule, { rule = "disableDestroy", on = true })
    end, false)
    panel:makeJobButton(168, y, 150, 24, IKST.text("IGUI_IKST_Guard_AllowDestroy", "Allow destroy"), function()
        IKST.dispatchCommand(p, IKST.CMD.setWorldRule, { rule = "disableDestroy", on = false })
    end, false)
    y = y + 30
    panel.guardSpriteEntry = ISTextEntryBox:new("", 12, y, 160, 22)
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
    local c = IKST_JobTilesGuard.coords(p)
    panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Protect_ContainerNote", "Square under feet. Transfers enforced."), UIFont.Small)
    y = y + 20
    panel.guardOwnerEntry = ISTextEntryBox:new("", 12, y, 160, 22)
    panel.guardOwnerEntry:initialise()
    panel.guardOwnerEntry:instantiate()
    panel:addJobWidget(panel.guardOwnerEntry)
    panel:makeJobButton(180, y, 90, 22, IKST.text("IGUI_IKST_Guard_Dropbox", "Dropbox"), function()
        IKST.dispatchCommand(p, IKST.CMD.setDropbox, { x = c.x, y = c.y, z = c.z, owner = IKST_JobTilesGuard.readEntry(panel.guardOwnerEntry) })
    end, true)
    y = y + 30
    panel:makeJobButton(12, y, 130, 24, IKST.text("IGUI_IKST_Protect_ReadonlyOn", "Readonly ON"), function()
        IKST.dispatchCommand(p, IKST.CMD.setReadonly, { x = c.x, y = c.y, z = c.z, on = true })
    end, true)
    panel:makeJobButton(148, y, 130, 24, IKST.text("IGUI_IKST_Protect_ReadonlyOff", "Readonly OFF"), function()
        IKST.dispatchCommand(p, IKST.CMD.setReadonly, { x = c.x, y = c.y, z = c.z, on = false })
    end, false)
    y = y + 30
    panel.guardLockEntry = ISTextEntryBox:new("", 12, y, 120, 22)
    panel.guardLockEntry:initialise()
    panel.guardLockEntry:instantiate()
    panel:addJobWidget(panel.guardLockEntry)
    panel:makeJobButton(140, y, 90, 22, IKST.text("IGUI_IKST_Guard_Lock", "Lock"), function()
        IKST.dispatchCommand(p, IKST.CMD.lockSetPassword, { x = c.x, y = c.y, z = c.z, password = IKST_JobTilesGuard.readEntry(panel.guardLockEntry) })
    end, false)
    panel:makeJobButton(236, y, 70, 22, IKST.text("IGUI_IKST_Guard_Clear", "Clear"), function()
        IKST.dispatchCommand(p, IKST.CMD.lockClear, { x = c.x, y = c.y, z = c.z })
    end, false)
    return y + 30
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
    local c = IKST_JobTilesGuard.coords(p)
    local half = 5
    panel:makeJobButton(12, y, 160, 24, IKST.text("IGUI_IKST_Guard_BpCopy", "Copy 11x11 here"), function()
        IKST.dispatchCommand(p, IKST.CMD.blueprintCopy, {
            x1 = c.x - half, y1 = c.y - half, x2 = c.x + half, y2 = c.y + half, z = c.z,
        })
    end, true)
    panel:makeJobButton(178, y, 140, 24, IKST.text("IGUI_IKST_Guard_BpPaste", "Paste here"), function()
        IKST.dispatchCommand(p, IKST.CMD.blueprintPaste, c)
    end, false)
    return y + 34
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
    panel.logPanel = IKST_ActionLog.dock(panel, panel.player, y)
    return y
end

function IKST_JobTilesGuard.onListResult(args)
    IKST_JobTilesGuard.tiles = (args and args.tiles) or {}
    IKST_JobTilesGuard.total = (args and args.total) or 0
    if IKST_JobsPanel and IKST_JobsPanel.instance then
        IKST_JobsPanel.instance:refreshJobUI()
    end
end
