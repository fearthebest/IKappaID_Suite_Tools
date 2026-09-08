require "IKST_Plugins"
require "IKST_Access"
require "IKST_Economy"
require "IKST_EconomyBridge"

-- SoftTool_Economy lives in lua/client and auto-loads after shared.

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
    economySetPref = true,
    economyPayRequest = true,
    economyPayRespond = true,
    economyDelivery = true,
    economyPlayerBounty = true,
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
        local extra = IKST_Economy.snapshot(player)
        if args.resultAmount ~= nil then
            extra.resultAmount = args.resultAmount
        end
        if args.resultReceive ~= nil then
            extra.resultReceive = args.resultReceive
        end
        if args.resultTarget ~= nil then
            extra.resultTarget = args.resultTarget
        end
        if args.resultFee ~= nil then
            extra.resultFee = args.resultFee
        end
        if args.resultPrice ~= nil then
            extra.resultPrice = args.resultPrice
        end
        if args.resultPayout ~= nil then
            extra.resultPayout = args.resultPayout
        end
        if args.resultCount ~= nil then
            extra.resultCount = args.resultCount
        end
        IKST_WorldOps.sendResult(player, ok, msg, args.x, args.y, args.z, command, extra)
    end
end

local function buildEconomyTool(panel, mode)
    local st = IKST.getPlayerState(panel and panel.player)
    if st and mode then
        st.economyMode = mode
    end
    if IKST_SoftTool_Economy and IKST_SoftTool_Economy.build then
        return IKST_SoftTool_Economy.build(panel)
    end
    if IKST_JobEconomy and IKST_JobEconomy.build then
        return IKST_JobEconomy.build(panel)
    end
    return 8
end

IKST.Plugins.register("economy", {
    modId = "IKappaIDSuiteToolsEconomy",
    playerCommands = PLAYER_COMMANDS,
    adminCommands = ADMIN_COMMANDS,
    canUsePlayer = function(player)
        return IKST_Access.canUseEconomy(player)
    end,
    canUseAdmin = function(player)
        return IKST_Access.canUseStaffTools(player) and IKST_Access.canUseEconomy(player)
    end,
    handleServer = function(command, player, args)
        if not IKST_EconomyOps or not IKST_EconomyOps.handle then
            return false, "economy server missing"
        end
        return IKST_EconomyOps.handle(command, player, args)
    end,
    afterServer = economyAfterServer,
    hubTools = {
        { mode = IKST.VIEW.economy, id = "money", titleKey = "IGUI_IKST_Economy_Tab_Money", title = "Money", order = 10 },
        { mode = IKST.VIEW.economy, id = "shop", titleKey = "IGUI_IKST_Economy_Tab_Shop", title = "Shops", order = 20 },
        { mode = IKST.VIEW.economy, id = "valuables", titleKey = "IGUI_IKST_Economy_Tab_Values", title = "Valuables", order = 30 },
        { mode = IKST.VIEW.economy, id = "admin", titleKey = "IGUI_IKST_Economy_Tab_Admin", title = "Admin", order = 40, adminOnly = true },
    },
    jobTools = {
        money = true,
        shop = true,
        valuables = true,
        admin = true,
        economy = true,
    },
    buildJobTools = {
        money = function(panel)
            return buildEconomyTool(panel, "money")
        end,
        shop = function(panel)
            return buildEconomyTool(panel, "shop")
        end,
        valuables = function(panel)
            return buildEconomyTool(panel, "valuables")
        end,
        admin = function(panel)
            return buildEconomyTool(panel, "admin")
        end,
        economy = function(panel)
            return buildEconomyTool(panel, nil)
        end,
    },
    onNavEntered = function(panel, modeId, toolId)
        if modeId == IKST.VIEW.economy and panel and panel.player then
            local st = IKST.getPlayerState(panel.player)
            if st and toolId and toolId ~= "economy" then
                st.economyMode = toolId
            end
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
            if IKST_EconomyVendClient and IKST_EconomyVendClient.onVendListResult then
                IKST_EconomyVendClient.onVendListResult(args)
            end
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
