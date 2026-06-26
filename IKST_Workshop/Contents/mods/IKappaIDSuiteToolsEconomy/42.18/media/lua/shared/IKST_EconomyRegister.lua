require "IKST_Plugins"
require "IKST_Access"
require "IKST_Economy"
require "IKST_EconomyBridge"

local PLAYER_COMMANDS = {
    economySnapshot = true,
    economyDeposit = true,
    economyWithdraw = true,
    economyWire = true,
    economyExchange = true,
    economyExchangeAll = true,
    economyIdCardReissue = true,
    economyVendBuy = true,
    economyVendList = true,
    economyVendSetPrice = true,
    economyVendClaim = true,
    economyShopPlace = true,
    economyVendDisable = true,
}

local ADMIN_COMMANDS = {
    economyVendEnable = true,
    economyAtmConfigure = true,
    economyAtmPlace = true,
}

local function economyAfterServer(command, player, args, ok, msg, isAdmin)
    if not IKST_EconomyOps or not IKST_WorldOps then
        return
    end
    args = args or {}
    if isAdmin then
        IKST_WorldOps.sendResult(player, ok, msg, args.x, args.y, args.z, command)
        return
    end
    if command ~= IKST.CMD.economySnapshot and command ~= IKST.CMD.economyVendList then
        IKST_EconomyOps.sendSnapshot(player)
        IKST_WorldOps.sendResult(player, ok, msg, args.x, args.y, args.z, command, IKST_Economy.snapshot(player))
    end
end

IKST.Plugins.register("economy", {
    modId = "IKappaIDSuiteToolsEconomy",
    playerCommands = PLAYER_COMMANDS,
    adminCommands = ADMIN_COMMANDS,
    canUsePlayer = function(player)
        return IKST_Access.canUseEconomy(player)
    end,
    canUseAdmin = function(player)
        return IKST_Access.canUseTools(player) and IKST_Access.canUseEconomy(player)
    end,
    handleServer = function(command, player, args)
        if not IKST_EconomyOps or not IKST_EconomyOps.handle then
            return false, "economy server missing"
        end
        return IKST_EconomyOps.handle(command, player, args)
    end,
    afterServer = economyAfterServer,
    hubTool = {
        mode = IKST.VIEW.economy,
        id = "economy",
        titleKey = "IGUI_IKST_Tab_Economy",
        title = "Economy",
        order = 10,
    },
    jobTool = "economy",
    buildJob = function(panel)
        if IKST_JobEconomy and IKST_JobEconomy.build then
            return IKST_JobEconomy.build(panel)
        end
        return 8
    end,
    onNavEntered = function(panel, modeId, toolId)
        if modeId == IKST.VIEW.economy and panel and panel.player then
            IKST_EconomyUI.requestSnapshot(panel.player)
        end
    end,
    onServerCommand = function(command, args, player)
        if command == IKST.CMD.economySnapshotResult then
            if IKST_EconomyUI and IKST_EconomyUI.onSnapshot then
                IKST_EconomyUI.onSnapshot(args)
            end
            return true
        end
        if command == IKST.CMD.economyVendListResult then
            if IKST_EconomyUI and IKST_EconomyUI.onVendList then
                IKST_EconomyUI.onVendList(args)
            end
            if IKST_JobEconomy and IKST_JobEconomy.onVendList then
                IKST_JobEconomy.onVendList(args)
            end
            return true
        end
        return false
    end,
})
