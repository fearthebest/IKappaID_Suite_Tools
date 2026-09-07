if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Plugins"
require "IKappaID_UI_Framework/IKUI_Chrome"
require "IKST_JobLayout"
require "IKST_JobGuard"
require "IKST_JobAutomation"
require "IKST_JobCleanup"
require "IKST_JobPainter"
require "IKST_JobInspector"
require "IKST_JobStaff"
require "IKST_JobTilesGuard"
require "IKST_WorldPick"

IKST_JobWorldEdit = IKST_JobWorldEdit or {}

function IKST_JobWorldEdit.build(panel)
    if IKST_SoftTool_Tiles and type(IKST_SoftTool_Tiles.build) == "function" then
        return IKST_SoftTool_Tiles.build(panel)
    end
    return 8
end

function IKST_JobWorldEdit.buildOverview(panel)
    if IKST_SoftTool_Tiles and type(IKST_SoftTool_Tiles.buildOverview) == "function" then
        return IKST_SoftTool_Tiles.buildOverview(panel)
    end
    return 8
end
function IKST_JobWorldEdit.buildForServer(panel)
    if IKST_SoftTool_Tiles and type(IKST_SoftTool_Tiles.buildForServer) == "function" then
        return IKST_SoftTool_Tiles.buildForServer(panel)
    end
    if IKST_SoftTool_Tiles and type(IKST_SoftTool_Tiles.build) == "function" then
        return IKST_SoftTool_Tiles.build(panel)
    end
    return 8
end
