require "IKST_Plugins"
require "IKST_Access"

local ADMIN_COMMANDS = {
    kickPlayer = true,
    banPlayer = true,
}

local function adminAfterServer(command, player, args, ok, msg)
    if IKST_WorldOps and IKST_WorldOps.sendResult then
        IKST_WorldOps.sendResult(player, ok, msg, nil, nil, nil, command)
    end
end

IKST.Plugins.register("admin", {
    modId = "IKappaIDSuiteToolsAdmin",
    adminCommands = ADMIN_COMMANDS,
    canUseAdmin = function(player)
        return IKST_Access.canUseStaffTools(player) == true
    end,
    handleServer = function(command, player, args)
        if not IKST_AdminOps or not IKST_AdminOps.handle then
            return false, "admin server missing"
        end
        return IKST_AdminOps.handle(command, player, args)
    end,
    afterServer = adminAfterServer,
    hubTool = {
        mode = IKST.VIEW.admin,
        id = "admin",
        titleKey = "IGUI_IKST_WS_Admin",
        title = "Admin",
        order = 10,
    },
    jobTool = "admin",
    buildJob = function(panel)
        if IKST_JobAdmin and IKST_JobAdmin.build then
            return IKST_JobAdmin.build(panel)
        end
        return 8
    end,
    onNavEntered = function(panel, modeId, toolId)
        if modeId == IKST.VIEW.admin and panel and panel.player
            and IKST_JobStaff and IKST_JobStaff.requestPlayers then
            IKST_JobStaff.requestPlayers(panel.player)
        end
    end,
})
