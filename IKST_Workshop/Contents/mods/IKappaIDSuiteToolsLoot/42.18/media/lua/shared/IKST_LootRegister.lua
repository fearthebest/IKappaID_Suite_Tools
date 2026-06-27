require "IKST_Plugins"
require "IKST_Access"
require "IKST_Loot"

local ADMIN_COMMANDS = {
    lootRepopulateContainer = true,
    lootRepopulateZone = true,
}

local function lootAfterServer(command, player, args, ok, msg)
    if IKST_WorldOps and IKST_WorldOps.sendResult then
        IKST_WorldOps.sendResult(player, ok, msg, args and args.x, args and args.y, args and args.z, command)
    end
end

IKST.Plugins.register("loot", {
    modId = "IKappaIDSuiteToolsLoot",
    adminCommands = ADMIN_COMMANDS,
    canUseAdmin = function(player)
        return IKST_Access.canUseStaffTools(player) and IKST_Access.canUseLoot(player)
    end,
    handleServer = function(command, player, args)
        if not IKST_LootOps or not IKST_LootOps.handle then
            return false, "loot server missing"
        end
        return IKST_LootOps.handle(command, player, args)
    end,
    afterServer = lootAfterServer,
    hubTool = {
        mode = IKST.VIEW.loot,
        id = "loot",
        titleKey = "IGUI_IKST_WS_Loot",
        title = "Loot",
        order = 10,
    },
    jobTool = "loot",
    buildJob = function(panel)
        if IKST_JobLoot and IKST_JobLoot.build then
            return IKST_JobLoot.build(panel)
        end
        return 8
    end,
    onNavEntered = function(panel, modeId, toolId)
        if modeId == IKST.VIEW.loot and panel and IKST_JobLoot and IKST_JobLoot.enter then
            IKST_JobLoot.enter(panel)
        end
    end,
})
