require "IKST_Plugins"
require "IKST_Access"

-- SoftTool / JobAdmin live in lua/client and auto-load after shared.
-- Do not require them from shared (shared phase cannot load client files).

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
    hubTools = {
        { mode = IKST.VIEW.admin, id = "ghost", titleKey = "IGUI_IKST_AdminGhostSelf", title = "Ghost", order = 10 },
        { mode = IKST.VIEW.admin, id = "kick", titleKey = "IGUI_IKST_UtilTile_KickPlayer", title = "Kick", order = 20 },
        { mode = IKST.VIEW.admin, id = "ban", titleKey = "IGUI_IKST_UtilTile_BanPlayer", title = "Ban", order = 30 },
    },
    jobTools = {
        ghost = true,
        kick = true,
        ban = true,
        admin = true,
    },
    buildJobTools = {
        ghost = function(panel)
            if IKST_SoftTool_Admin and IKST_SoftTool_Admin.buildGhost then
                return IKST_SoftTool_Admin.buildGhost(panel)
            end
            if IKST_JobAdmin and IKST_JobAdmin.buildGhost then
                return IKST_JobAdmin.buildGhost(panel)
            end
            return IKST_JobAdmin and IKST_JobAdmin.build and IKST_JobAdmin.build(panel) or 8
        end,
        kick = function(panel)
            if IKST_SoftTool_Admin and IKST_SoftTool_Admin.buildKick then
                return IKST_SoftTool_Admin.buildKick(panel)
            end
            if IKST_JobAdmin and IKST_JobAdmin.buildKick then
                return IKST_JobAdmin.buildKick(panel)
            end
            return 8
        end,
        ban = function(panel)
            if IKST_SoftTool_Admin and IKST_SoftTool_Admin.buildBan then
                return IKST_SoftTool_Admin.buildBan(panel)
            end
            if IKST_JobAdmin and IKST_JobAdmin.buildBan then
                return IKST_JobAdmin.buildBan(panel)
            end
            return 8
        end,
        admin = function(panel)
            if IKST_SoftTool_Admin and IKST_SoftTool_Admin.build then
                return IKST_SoftTool_Admin.build(panel)
            end
            if IKST_JobAdmin and IKST_JobAdmin.build then
                return IKST_JobAdmin.build(panel)
            end
            return 8
        end,
    },
    onNavEntered = function(panel, modeId, toolId)
        if modeId == IKST.VIEW.admin and panel and panel.player
            and IKST_JobStaff and IKST_JobStaff.requestPlayers then
            IKST_JobStaff.requestPlayers(panel.player)
        end
    end,
})
