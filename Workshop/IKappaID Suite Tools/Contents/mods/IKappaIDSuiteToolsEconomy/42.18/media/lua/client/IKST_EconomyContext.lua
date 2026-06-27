if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Access"
require "IKST_Economy"
require "IKST_Identity"
require "IKST_Grid"
require "IKST_EconomyUI"
require "IKST_EconomyIcons"
require "IKST_JobsPanel"
require "IKST_EconomyShopKit"
require "IKST_EconomyAtmKit"

IKST_EconomyContext = IKST_EconomyContext or {}

function IKST_EconomyContext.containerFromWorldObjects(worldobjects)
    if not worldobjects then
        return nil, nil
    end
    for _, obj in ipairs(worldobjects) do
        if obj and obj.getContainer and obj:getContainer() then
            return obj, obj:getContainer()
        end
    end
    return nil, nil
end

function IKST_EconomyContext.objectsOnSquare(square)
    if square and square.getObjects then
        return square:getObjects()
    end
    return nil
end

function IKST_EconomyContext.shopObjectOnSquare(square)
    local objects = IKST_EconomyContext.objectsOnSquare(square)
    if not objects then
        return nil
    end
    local fallback = nil
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj and obj.getContainer and obj:getContainer() then
            if IKST_Economy.isBuiltShopTerminal(obj) then
                return obj
            end
            if IKST_Economy.isVendObject(obj) then
                return obj
            end
            if IKST_Economy.isShopTileObject(obj) then
                fallback = obj
            elseif not fallback then
                fallback = obj
            end
        end
    end
    return fallback
end

function IKST_EconomyContext.shopObjectAtPlayer(player)
    player = IKST.resolvePlayer(player)
    if not player or not player.getCurrentSquare then
        return nil, nil, nil, nil
    end
    local square = player:getCurrentSquare()
    if not square then
        return nil, nil, nil, nil
    end
    local obj = IKST_EconomyContext.shopObjectOnSquare(square)
    return obj, square:getX(), square:getY(), square:getZ()
end

function IKST_EconomyContext.isVending(obj)
    if not obj or not obj.getModData then
        return false
    end
    local md = obj:getModData()
    return md and md[IKST_Economy.VEND_TAG] == true
end

function IKST_EconomyContext.canClaimShop(obj)
    if not obj or not IKST_Economy.isShopTileObject(obj) then
        return false
    end
    if not IKST_EconomyContext.isVending(obj) then
        return true
    end
    local owner = IKST_Economy.vendOwnerOfObject(obj)
    return not owner or owner == ""
end

function IKST_EconomyContext.isShopOwner(player, obj)
    if not player or not obj then
        return false
    end
    if not IKST_EconomyContext.isVending(obj) then
        return false
    end
    return IKST_Identity.playerOwnsKey(player, IKST_Economy.vendOwnerOfObject(obj))
end

function IKST_EconomyContext.claimShop(player, x, y, z)
    IKST.dispatchCommand(player, IKST.CMD.economyVendClaim, {
        x = math.floor(tonumber(x) or 0),
        y = math.floor(tonumber(y) or 0),
        z = math.floor(tonumber(z) or 0),
    })
end

function IKST_EconomyContext.addShopOption(sub, label, player, fn)
    local opt = sub:addOption(label, player, fn)
    if IKST_EconomyIcons then
        IKST_EconomyIcons.applyContextIcon(opt, IKST_EconomyIcons.SHOP)
    end
    return opt
end

function IKST_EconomyContext.fillEconomyMenu(sub, player, square, worldobjects)
    if not IKST_Access.canUseEconomy(player) then
        return
    end
    local x = square and square:getX() or math.floor(player:getX())
    local y = square and square:getY() or math.floor(player:getY())
    local z = square and square:getZ() or player:getZ()

    sub:addOption(IKST.text("IGUI_IKST_Economy_OpenWallet", "Open economy"), player, function()
        IKST_EconomyUI.open(player, x, y, z)
    end)

    if IKST_Economy.isAtmSquare(x, y, z) then
        sub:addOption(IKST.text("IGUI_IKST_Economy_UseAtm", "Use ATM"), player, function()
            IKST_EconomyUI.open(player, x, y, z)
        end)
    end

    if IKST_EconomyShopKit.playerHasKit(player) and not IKST_EconomyContext.shopObjectOnSquare(square) then
        IKST_EconomyContext.addShopOption(sub, IKST.text("IGUI_IKST_Economy_PlaceShopKit", "Place shop terminal"), player, function()
            IKST_EconomyShopKit.placeAt(player, x, y, z)
        end)
    end

    local obj = IKST_EconomyContext.shopObjectOnSquare(square)
    if not obj then
        obj = IKST_EconomyContext.containerFromWorldObjects(worldobjects)
    end

    if obj and IKST_EconomyContext.canClaimShop(obj) then
        IKST_EconomyContext.addShopOption(sub, IKST.text("IGUI_IKST_Economy_ClaimShop", "Open my shop here"), player, function()
            IKST_EconomyContext.claimShop(player, x, y, z)
        end)
    end

    if obj and IKST_EconomyContext.isVending(obj) then
        IKST_EconomyContext.addShopOption(sub, IKST.text("IGUI_IKST_Economy_BrowseShop", "Browse shop"), player, function()
            IKST_EconomyUI.openVendShop(player, x, y, z)
        end)
        if IKST_EconomyContext.isShopOwner(player, obj) or IKST_Access.canUseTools(player) then
            IKST_EconomyContext.addShopOption(sub, IKST.text("IGUI_IKST_Economy_ManageShop", "Manage shop prices"), player, function()
                if IKST_Access.canUseTools(player) then
                    IKST_JobsPanel.open(player)
                    local panel = IKST_JobsPanel.instance
                    if panel then
                        panel:enterNav(IKST.VIEW.economy, "economy")
                        panel.economyVendX = x
                        panel.economyVendY = y
                        panel.economyVendZ = z
                        local state = IKST.getPlayerState(player)
                        if state then
                            state.economyMode = "shop"
                        end
                        panel:refreshJobUI()
                        IKST_JobEconomy.requestVendList(panel)
                    end
                else
                    IKST_EconomyUI.openVendShop(player, x, y, z, true)
                end
            end)
        end
        if IKST_EconomyContext.isShopOwner(player, obj) then
            IKST_EconomyContext.addShopOption(sub, IKST.text("IGUI_IKST_Economy_CloseShop", "Close my shop"), player, function()
                IKST.dispatchCommand(player, IKST.CMD.economyVendDisable, { x = x, y = y, z = z })
            end)
        end
    end

    if IKST_Access.canUseTools(player) then
        if not IKST_Economy.isAtmSquare(x, y, z) and not IKST_Economy.findAtmObjectOnSquare(square) then
            if IKST_EconomyAtmKit.playerHasKit(player) then
                sub:addOption(IKST.text("IGUI_IKST_Economy_PlaceAtmKit", "Place ATM fixture"), player, function()
                    IKST_EconomyAtmKit.placeAt(player, x, y, z)
                end)
            else
                sub:addOption(IKST.text("IGUI_IKST_Economy_PlaceAtmAdmin", "Place ATM fixture (admin)"), player, function()
                    IKST.dispatchCommand(player, IKST.CMD.economyAtmPlace, { x = x, y = y, z = z })
                end)
            end
        end
        if IKST_Economy.findAtmObjectOnSquare(square) and not IKST_Economy.isAtmSquare(x, y, z) then
            sub:addOption(IKST.text("IGUI_IKST_Economy_EnableAtm", "Enable ATM on bank fixture"), player, function()
                IKST.dispatchCommand(player, IKST.CMD.economyAtmConfigure, {
                    x = x, y = y, z = z,
                    deposit = true, withdraw = true, valuables = true,
                })
            end)
        end
    end

    if IKST_Access.canUseTools(player) and obj then
        if IKST_Economy.isShopTileObject(obj) and not IKST_EconomyContext.isVending(obj) then
            IKST_EconomyContext.addShopOption(sub, IKST.text("IGUI_IKST_Economy_EnableShop", "Enable shop terminal (admin)"), player, function()
                IKST.dispatchCommand(player, IKST.CMD.economyVendEnable, { x = x, y = y, z = z })
            end)
        end
        if IKST_EconomyContext.isVending(obj) then
            IKST_EconomyContext.addShopOption(sub, IKST.text("IGUI_IKST_Economy_DisableShop", "Disable player shop (admin)"), player, function()
                IKST.dispatchCommand(player, IKST.CMD.economyVendDisable, { x = x, y = y, z = z })
            end)
        end
    end
end

function IKST_EconomyContext.onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    if test then
        return false
    end
    local player = IKST.resolvePlayer(playerNum)
    if not player or not context or not IKST_Access.canUseEconomy(player) then
        return
    end
    local square = IKST_Grid.squareFromWorldObjects(worldobjects)
    local label = IKST.text("IGUI_IKST_Economy_Menu", "Economy")
    local root = context:addOption(label)
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(root, sub)
    IKST_EconomyContext.fillEconomyMenu(sub, player, square, worldobjects)
end

if Events and Events.OnFillWorldObjectContextMenu then
    Events.OnFillWorldObjectContextMenu.Add(IKST_EconomyContext.onFillWorldObjectContextMenu)
end
