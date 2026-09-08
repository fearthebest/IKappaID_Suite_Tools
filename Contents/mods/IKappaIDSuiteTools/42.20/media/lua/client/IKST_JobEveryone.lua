if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"

IKST_JobEveryone = IKST_JobEveryone or {}

function IKST_JobEveryone.build(panel)
    if IKST_SoftTool_Everyone and type(IKST_SoftTool_Everyone.build) == "function" then
        return IKST_SoftTool_Everyone.build(panel)
    end
    return 8
end
