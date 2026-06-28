if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISTextEntryBox"
require "IKST_Shared"
require "IKST_Chrome"
require "IKST_ActionLog"
require "IKST_JobLayout"
require "IKST_JobStaff"
require "IKST_JobThreat"
require "IKST_QuickActions"
require "IKST_ClientStaff"

IKST_JobUtilities = IKST_JobUtilities or {}

function IKST_JobUtilities.buildServerTools(panel)
    local p = panel.player
    local state = IKST.getPlayerState(p)
    local y = 8

    panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Util_ServerTools", "Server tools"), UIFont.Small)
    y = y + 18
    panel:makeJobButton(12, y, 100, 24, IKST.text("IGUI_IKST_Save", "Save world"), function()
        IKST.dispatchCommand(p, IKST.CMD.quickSave, {})
    end, false)
    panel:makeJobButton(118, y, 100, 24, IKST.text("IGUI_IKST_Broadcast", "Broadcast"), function()
        local msg = "Admin message"
        if state and state.lastBroadcast and state.lastBroadcast ~= "" then
            msg = state.lastBroadcast
        end
        IKST.dispatchCommand(p, IKST.CMD.quickBroadcast, { message = msg })
    end, false)
    y = y + 32

    panel:makeJobButton(12, y, 120, 24, IKST.text("IGUI_IKST_Water", "Water"), function()
        IKST_QuickActions.run(p, "quickWater")
        panel:refreshJobUI()
    end, IKST.isWaterOn())
    panel:makeJobButton(138, y, 120, 24, IKST.text("IGUI_IKST_Power", "Power"), function()
        IKST_QuickActions.run(p, "quickPower")
        panel:refreshJobUI()
    end, IKST.isPowerOn())
    y = y + 28
    panel:makeJobLabel(12, y, IKST.utilityStatusLine(), UIFont.Small)
    y = y + 24

    panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_TimeHour", "Hour (0-23)"), UIFont.Small)
    y = y + 16
    panel.staffHour = ISTextEntryBox:new("12", 12, y, 60, 22)
    panel.staffHour:initialise()
    panel.staffHour:instantiate()
    panel:addJobWidget(panel.staffHour)
    panel:makeJobButton(80, y, 80, 22, IKST.text("IGUI_IKST_SetTime", "Set time"), function()
        IKST_ClientStaff.runSetTime(p, IKST_JobStaff.readNumber(panel.staffHour, 12))
    end, true)
    y = y + 30
    local wx = 12
    for _, preset in ipairs({ "Clear", "Rain", "Storm", "Fog" }) do
        panel:makeJobButton(wx, y, 70, 24, preset, function()
            IKST_ClientStaff.runWeather(p, preset)
        end, false)
        wx = wx + 76
    end
    y = y + 28
    panel:makeJobButton(12, y, 120, 24, IKST.text("IGUI_IKST_ClearWeather", "Clear weather"), function()
        IKST_ClientStaff.runClearWeather(p)
    end, false)
    y = y + 34

    if IKST_ActionLog and IKST_ActionLog.dock then
        panel.logPanel = IKST_ActionLog.dock(panel, p, y)
    end
    return y
end

function IKST_JobUtilities.build(panel)
    local state = IKST.getPlayerState(panel.player)
    if not state then
        return 8
    end
    local tool = state.navTool or "self"

    if tool == "zombies" and IKST_JobThreat then
        return IKST_JobThreat.build(panel)
    end
    if tool == "servertools" then
        return IKST_JobUtilities.buildServerTools(panel)
    end

    if tool == "self" then
        state.staffMode = "self"
    elseif tool == "items" then
        state.staffMode = "items"
    elseif tool == "players" then
        state.staffMode = "players"
    elseif tool == "teleport" then
        state.staffMode = "waypoints"
    end

    if IKST_JobStaff and IKST_JobStaff.build then
        return IKST_JobStaff.build(panel) or 8
    end
    return 8
end
