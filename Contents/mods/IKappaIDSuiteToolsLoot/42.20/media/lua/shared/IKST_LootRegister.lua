require "IKST_Plugins"
require "IKST_Access"
require "IKST_Loot"

-- SoftTool_Loot lives in lua/client and auto-loads after shared.

local ADMIN_COMMANDS = {
    lootRepopulateContainer = true,
    lootRepopulateZone = true,
}

local function lootAfterServer(command, player, args, ok, msg)
    if args and args._deferResult then
        return
    end
    if IKST_WorldOps and IKST_WorldOps.sendResult then
        local extra = nil
        if args and (args.resultCount ~= nil or args.resultSuffix ~= nil or args.resultLabel ~= nil) then
            extra = {
                resultCount = args.resultCount,
                resultSuffix = args.resultSuffix,
                resultLabel = args.resultLabel,
            }
        end
        IKST_WorldOps.sendResult(player, ok, msg, args and args.x, args and args.y, args and args.z, command, extra)
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
    onServerCommand = function(command, args, player)
        if command == IKST.CMD.lootContainerRefresh then
            if not IKST_LootClientRefresh then
                require "IKST_LootClientRefresh"
            end
            if IKST_LootClientRefresh and IKST_LootClientRefresh.applyRefresh then
                IKST_LootClientRefresh.applyRefresh(args)
            end
            return true
        end
        return false
    end,
    hubTool = {
        mode = IKST.VIEW.loot,
        id = "loot",
        titleKey = "IGUI_IKST_WS_Loot",
        title = "Loot",
        order = 10,
    },
    jobTool = "loot",
    buildJob = function(panel)
        if IKST_SoftTool_Loot and IKST_SoftTool_Loot.build then
            return IKST_SoftTool_Loot.build(panel)
        end
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
