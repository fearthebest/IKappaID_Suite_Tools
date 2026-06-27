if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Plugins"
require "IKST_ActionLog"
require "IKST_JobGuard"
require "IKST_JobAutomation"
require "IKST_JobCleanup"
require "IKST_JobPainter"
require "IKST_JobInspector"
require "IKST_JobStaff"
require "IKST_JobTilesGuard"

IKST_JobWorldEdit = IKST_JobWorldEdit or {}

function IKST_JobWorldEdit.build(panel)
    local state = IKST.getPlayerState(panel.player)
    if not state then
        return 8
    end
    local tool = state.navTool or "remove"
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
    if IKST.Plugins and IKST.Plugins.buildJobTool then
        local y = IKST.Plugins.buildJobTool(panel, tool)
        if y then
            return y
        end
    end
    return 8
end
