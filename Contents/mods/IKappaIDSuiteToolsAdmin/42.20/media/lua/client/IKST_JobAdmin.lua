if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"

IKST_JobAdmin = IKST_JobAdmin or {}

function IKST_JobAdmin.buildGhost(panel)
    if IKST_SoftTool_Admin and type(IKST_SoftTool_Admin.buildGhost) == "function" then
        return IKST_SoftTool_Admin.buildGhost(panel)
    end
    return 8
end

function IKST_JobAdmin.buildKick(panel)
    if IKST_SoftTool_Admin and type(IKST_SoftTool_Admin.buildKick) == "function" then
        return IKST_SoftTool_Admin.buildKick(panel)
    end
    return 8
end

function IKST_JobAdmin.buildBan(panel)
    if IKST_SoftTool_Admin and type(IKST_SoftTool_Admin.buildBan) == "function" then
        return IKST_SoftTool_Admin.buildBan(panel)
    end
    return 8
end

function IKST_JobAdmin.build(panel)
    if IKST_SoftTool_Admin and type(IKST_SoftTool_Admin.build) == "function" then
        return IKST_SoftTool_Admin.build(panel)
    end
    return 8
end
