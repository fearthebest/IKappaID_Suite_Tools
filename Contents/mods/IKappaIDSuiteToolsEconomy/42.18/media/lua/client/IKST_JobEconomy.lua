if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then

    return

end



require "ISUI/ISTextEntryBox"

require "ISUI/ISScrollingListBox"

require "IKST_Shared"

require "IKST_Economy"

require "IKST_EconomyBridge"

require "IKST_EconomyUI"

require "IKST_EconomyContext"

require "IKST_Chrome"

require "IKST_JobLayout"



IKST_JobEconomy = IKST_JobEconomy or {}

IKST_JobEconomy._vendEntries = {}



function IKST_JobEconomy.readEntry(entry)

    if entry and entry.getText then

        return string.gsub(entry:getText() or "", "^%s*(.-)%s*$", "%1")

    end

    return ""

end



function IKST_JobEconomy.ensureMode(panel)

    local state = IKST.getPlayerState(panel.player)

    if not state.economyMode then

        state.economyMode = "money"

    end

    return state.economyMode

end



function IKST_JobEconomy.isCtrlHeld()
    if not isCtrlKeyDown then
        return false
    end
    return isCtrlKeyDown(Keyboard.KEY_LCONTROL) or isCtrlKeyDown(Keyboard.KEY_RCONTROL)
end

function IKST_JobEconomy.dispatchSetPrice(panel, scope)
    local p = panel.player
    local price = IKST.parseAmount(IKST_JobEconomy.readEntry(panel.economyPriceEntry))
    if scope ~= "clear" and price <= 0 then
        IKST.notify(p, IKST.text("IGUI_IKST_Economy_EnterPrice", "Enter a price greater than 0."), false)
        return
    end
    local payload = {
        x = panel.economyVendX,
        y = panel.economyVendY,
        z = panel.economyVendZ,
        scope = scope,
        price = scope == "clear" and 0 or price,
    }
    if scope == "one" or scope == "type" then
        payload.itemType = panel.economySelectedItemType
        payload.itemId = panel.economySelectedItemId
    elseif scope == "selected" then
        local ids = {}
        local pick = panel.economyVendPick or {}
        for id, on in pairs(pick) do
            if on then
                ids[#ids + 1] = id
            end
        end
        if #ids == 0 and panel.economySelectedItemId then
            ids[1] = panel.economySelectedItemId
        end
        if #ids == 0 then
            IKST.notify(p, IKST.text("IGUI_IKST_Economy_PickShopRow", "Select an item from the list."), false)
            return
        end
        payload.itemIds = ids
    end
    if scope == "clear" then
        payload.scope = panel.economyPriceClearScope or "one"
    end
    IKST.dispatchCommand(p, IKST.CMD.economyVendSetPrice, payload)
end

function IKST_JobEconomy.onVendListSelect(panel, toggleMulti)
    local list = panel.economyVendList
    if not list or not list.items or not list.selected or list.selected < 1 then
        return
    end
    local row = list.items[list.selected]
    if not row or not row.item then
        return
    end
    local id = row.item.itemId
    if toggleMulti then
        panel.economyVendPick = panel.economyVendPick or {}
        if panel.economyVendPick[id] then
            panel.economyVendPick[id] = nil
        else
            panel.economyVendPick[id] = true
        end
    else
        panel.economyVendPick = { [id] = true }
    end
    panel.economySelectedItemType = row.item.itemType
    panel.economySelectedItemId = id
end

function IKST_JobEconomy.populateVendList(panel)
    local list = panel.economyVendList
    if not list then
        return
    end
    local keepType = panel.economySelectedItemType
    list:clear()
    for i = 1, #IKST_JobEconomy._vendEntries do
        local e = IKST_JobEconomy._vendEntries[i]
        local label = IKST_EconomyUI.formatShopRow(e)
        if panel.economyVendPick and panel.economyVendPick[e.itemId] then
            label = "[x] " .. label
        end
        list:addItem(label, e)
        if keepType and e.itemType == keepType then
            list.selected = i
        end
    end
    if list.selected < 1 and #list.items > 0 then
        list.selected = 1
    end
    IKST_JobEconomy.onVendListSelect(panel, false)
end

function IKST_JobEconomy.onVendList(args)

    IKST_JobEconomy._vendEntries = args and args.entries or {}

    if IKST_JobsPanel.instance then

        IKST_JobsPanel.instance:refreshJobUI()

    end

end



function IKST_JobEconomy.requestVendList(panel)

    if not panel.economyVendX then

        return

    end

    IKST.dispatchCommand(panel.player, IKST.CMD.economyVendList, {

        x = panel.economyVendX,

        y = panel.economyVendY,

        z = panel.economyVendZ,

        manage = true,

    })

end



function IKST_JobEconomy.buildModeRow(panel, y)

    local state = IKST.getPlayerState(panel.player)

    local mode = IKST_JobEconomy.ensureMode(panel)

    local modes = {

        { id = "money", label = IKST.text("IGUI_IKST_Economy_Tab_Money", "Money") },

        { id = "shop", label = IKST.text("IGUI_IKST_Economy_Tab_Shop", "Shops") },

        { id = "valuables", label = IKST.text("IGUI_IKST_Economy_Tab_Values", "Valuables") },

    }

    if IKST_Access.canUseTools(panel.player) then

        table.insert(modes, { id = "admin", label = IKST.text("IGUI_IKST_Economy_Tab_Admin", "Admin") })

    end

    local x = 12

    for _, m in ipairs(modes) do

        panel:makeJobButton(x, y, 72, 24, m.label, function()

            state.economyMode = m.id

            if m.id == "shop" then

                IKST_JobEconomy.requestVendList(panel)

            end

            panel:refreshJobUI()

        end, mode == m.id)

        x = x + 76

    end

    return y + 32

end



function IKST_JobEconomy.buildMoney(panel, y)
    local p = panel.player
    local cash, bank, pending = IKST_EconomyUI.getBalances(p)

    IKST_EconomyUI.addJobIconLabel(panel, 12, y, IKST_EconomyUI.cashItemType(),
        IKST.text("IGUI_IKST_Economy_Cash", "Cash") .. ": " .. IKST_Economy.formatAmount(cash), UIFont.Medium, 24)
    y = y + 26
    local bankLine = IKST.text("IGUI_IKST_Economy_Bank", "Bank") .. ": " .. IKST_Economy.formatAmount(bank)
        .. (pending > 0 and ("  (" .. IKST.text("IGUI_IKST_Economy_Pending", "pending") .. " " .. IKST_Economy.formatAmount(pending) .. ")") or "")
    IKST_EconomyUI.addJobIconLabel(panel, 12, y, IKST_EconomyUI.bankItemType(), bankLine, UIFont.Medium, 24)
    y = y + 30

    panel:makeJobButton(12, y, 100, 24, IKST.text("IGUI_IKST_Economy_Refresh", "Refresh"), function()
        IKST_EconomyUI.requestSnapshot(p, math.floor(p:getX()), math.floor(p:getY()), p:getZ())
    end, false)
    y = y + 32

    IKST_EconomyUI.addJobIconButton(panel, 12, y, 220, 24, IKST_EconomyUI.atmItemType(),
        IKST.text("IGUI_IKST_Economy_OpenWallet", "Open economy window"), function()
        IKST_EconomyUI.open(p, math.floor(p:getX()), math.floor(p:getY()), p:getZ())
    end, true)
    y = y + 32

    IKST_EconomyUI.addJobIconLabel(panel, 12, y, IKST_EconomyUI.atmItemType(),
        IKST.text("IGUI_IKST_Economy_WalletHint", "At an ATM: deposit, withdraw, wire cash, sell valuables."), UIFont.Small, 22, true)
    y = y + 24
    IKST_EconomyUI.addJobIconLabel(panel, 12, y, IKST_EconomyUI.phoneItemType(),
        IKST.text("IGUI_IKST_Economy_PhoneHint", "NPC buy/sell stays in PhoneShop (Cordless Phone)."), UIFont.Small, 22, true)
    return y + 28
end



function IKST_JobEconomy.buildShop(panel, y)

    local p = panel.player

    IKST_EconomyUI.addJobIconLabel(panel, 12, y, IKST_EconomyUI.shopItemType(),
        IKST.text("IGUI_IKST_Economy_ShopHelp", "Craft a Shop Terminal Kit (2 planks, 4 nails, scrap metal — no skill), place it, then Open my shop here. Stock it and set prices below."), UIFont.Small, 22, true)

    y = y + 26

    IKST_EconomyUI.addJobIconLabel(panel, 12, y, IKST_EconomyUI.shopItemType(),
        IKST.text("IGUI_IKST_Economy_ShopKitCraft", "Assemble Shop Terminal Kit (Crafting menu, no skill)"), UIFont.Small, 22, true)

    y = y + 24

    IKST_EconomyUI.addJobIconLabel(panel, 12, y, IKST_EconomyUI.shopItemType(),
        IKST.text("IGUI_IKST_Economy_ShopPerishHint", "Perishables: stock same-age stacks; buyers get the real freshness. Rotten stock is hidden from buyers."), UIFont.Small, 22, true)

    y = y + 24

    local shopCap = IKST_Economy.shopContainerCapacity and IKST_Economy.shopContainerCapacity() or 100
    local capHint = IKST.text("IGUI_IKST_Economy_ShopCapacityHint",
        "Each shop terminal holds up to %1 encumbrance (heavy items and furniture). Server sandbox can raise this.")
    capHint = string.gsub(capHint, "%%1", tostring(shopCap))
    IKST_EconomyUI.addJobIconLabel(panel, 12, y, IKST_EconomyUI.shopItemType(), capHint, UIFont.Small, 22, true)

    y = y + 28

    if not panel.economyVendX then
        local shopObj, sx, sy, sz = IKST_EconomyContext.shopObjectAtPlayer(p)
        if shopObj and IKST_EconomyContext.canClaimShop(shopObj) then
            panel:makeJobButton(12, y, 180, 22, IKST.text("IGUI_IKST_Economy_ClaimShop", "Open my shop here"), function()
                IKST_EconomyContext.claimShop(p, sx, sy, sz)
                panel.economyVendX = sx
                panel.economyVendY = sy
                panel.economyVendZ = sz
                panel:refreshJobUI()
            end, false)
            y = y + 28
        elseif shopObj and IKST_EconomyContext.isShopOwner(p, shopObj) then
            panel.economyVendX = sx
            panel.economyVendY = sy
            panel.economyVendZ = sz
            IKST_JobEconomy.requestVendList(panel)
        else
            IKST_EconomyUI.addJobIconLabel(panel, 12, y, IKST_EconomyUI.shopItemType(),
                IKST.text("IGUI_IKST_Economy_ShopPick", "Stand at your shop terminal or right-click it > Manage shop prices."), UIFont.Small, 22, true)
            return y + 28
        end
    end

    if not panel.economyVendX then
        return y
    end

    IKST_EconomyUI.addJobIconLabel(panel, 12, y, IKST_EconomyUI.shopItemType(),
        IKST.text("IGUI_IKST_Economy_ShopAt", "Shop at") .. " " .. panel.economyVendX .. "," .. panel.economyVendY, UIFont.Small, 22)

    y = y + 24

    panel:makeJobButton(12, y, 100, 22, IKST.text("IGUI_IKST_RefreshList", "Refresh"), function()

        IKST_JobEconomy.requestVendList(panel)

    end, false)

    y = y + 28

    panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Economy_ShopStock", "Stock — Ctrl+click to multi-select. Set price per stack, selection, type, or all."), UIFont.Small)

    y = y + 20

    local listW = panel.contentW or (panel.width - 24)
    local listH = math.min(180, math.max(96, math.floor((panel.scrollHeight or 180) * 0.42)))
    panel.economyVendList = ISScrollingListBox:new(IKST_JobLayout.MARGIN, y, listW, listH)
    panel.economyVendList:initialise()
    panel.economyVendList:instantiate()
    panel.economyVendList.itemheight = 22
    panel.economyVendList.font = UIFont.Small
    panel.economyVendList.drawBorder = true
    panel.economyVendList.onmousedown = function(target, mx, my)
        if target and target.onMouseDown then
            target:onMouseDown(mx, my)
        end
        IKST_JobEconomy.onVendListSelect(panel, IKST_JobEconomy.isCtrlHeld())
        IKST_JobEconomy.populateVendList(panel)
    end
    panel:addJobWidget(panel.economyVendList)
    IKST_JobEconomy.populateVendList(panel)

    y = y + listH + 10

    if panel.economySelectedItemType then

        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Economy_PriceEach", "Price each") .. ":", UIFont.Small)

        y = y + 18

        if not panel.economyPriceEntry then

            panel.economyPriceEntry = ISTextEntryBox:new("", 12, y, 88, 22)

            panel.economyPriceEntry:initialise()

            panel.economyPriceEntry:instantiate()

            panel:addJobWidget(panel.economyPriceEntry)

        else

            panel.economyPriceEntry:setY(y)

        end

        panel:makeJobButton(108, y, 88, 24, IKST.text("IGUI_IKST_Economy_SetPriceOne", "1 stack"), function()
            IKST_JobEconomy.dispatchSetPrice(panel, "one")
        end, true)

        panel:makeJobButton(200, y, 88, 24, IKST.text("IGUI_IKST_Economy_SetPricePick", "Selected"), function()
            IKST_JobEconomy.dispatchSetPrice(panel, "selected")
        end, false)

        panel:makeJobButton(292, y, 72, 24, IKST.text("IGUI_IKST_Economy_SetPriceType", "Type"), function()
            IKST_JobEconomy.dispatchSetPrice(panel, "type")
        end, false)

        y = y + 28

        panel:makeJobButton(108, y, 88, 24, IKST.text("IGUI_IKST_Economy_SetPriceAll", "All stock"), function()
            IKST_JobEconomy.dispatchSetPrice(panel, "all")
        end, false)

        panel:makeJobButton(200, y, 88, 24, IKST.text("IGUI_IKST_Economy_ClearPrice", "Clear"), function()
            panel.economyPriceClearScope = "one"
            IKST_JobEconomy.dispatchSetPrice(panel, "clear")
        end, false)

        y = y + 30

    else

        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Economy_ShopPickRow", "Select a stock row, then set price."), UIFont.Small)

        y = y + 22

    end

    return y

end



function IKST_JobEconomy.buildValuables(panel, y)
    local p = panel.player
    IKST_EconomyUI.addJobIconLabel(panel, 12, y, IKST_EconomyUI.atmItemType(),
        IKST.text("IGUI_IKST_Economy_ValuableHelp", "Sell junk for cash — use Open economy at an ATM."), UIFont.Small, 22, true)
    y = y + 24

    local rows = IKST_EconomyUI.buildValuableRows(p)
    for i, row in ipairs(rows) do
        if i > 8 then
            break
        end
        local owned = row.count or 0
        local label = row.label .. "  ×" .. tostring(owned) .. "   " .. row.priceLabel
        IKST_EconomyUI.addJobIconButton(panel, 12, y, panel.contentW or 300, 24, row.itemType, label, function()
            if owned <= 0 then
                IKST.notify(p, IKST.text("IGUI_IKST_Economy_NoItem", "You do not have that item."), false)
                return
            end
            IKST.dispatchCommand(p, IKST.CMD.economyExchange, {
                itemType = row.itemType,
                x = math.floor(p:getX()),
                y = math.floor(p:getY()),
                z = p:getZ(),
            })
        end, owned > 0)
        y = y + 26
    end

    IKST_EconomyUI.addJobIconButton(panel, 12, y, 160, 24, IKST_EconomyUI.cashItemType(),
        IKST.text("IGUI_IKST_Economy_SellAll", "Sell all"), function()
        IKST.dispatchCommand(p, IKST.CMD.economyExchangeAll, {
            x = math.floor(p:getX()),
            y = math.floor(p:getY()),
            z = p:getZ(),
        })
    end, true)
    y = y + 32

    IKST_EconomyUI.addJobIconButton(panel, 12, y, 220, 24, IKST_EconomyUI.atmItemType(),
        IKST.text("IGUI_IKST_Economy_OpenWallet", "Open economy window"), function()
        IKST_EconomyUI.open(p, math.floor(p:getX()), math.floor(p:getY()), p:getZ())
    end, false)
    return y + 30
end



function IKST_JobEconomy.buildAdmin(panel, y)

    local p = panel.player

    local balance = IKST_EconomyBridge.getBalance(p)

    IKST_EconomyUI.addJobIconLabel(panel, 12, y, IKST_EconomyUI.cashItemType(),
        IKST.text("IGUI_IKST_Economy_Balance", "Your balance") .. ": " .. IKST_Economy.formatAmount(balance), UIFont.Medium, 24)

    y = y + 30

    panel:makeJobButton(12, y, 120, 24, IKST.text("IGUI_IKST_Economy_Refresh", "Refresh"), function()

        IKST.dispatchCommand(p, IKST.CMD.economySnapshot, {})

    end, false)

    y = y + 32

    if not panel.economyAmount then

        panel.economyAmount = ISTextEntryBox:new("1000", 12, y, 100, 22)

        panel.economyAmount:initialise()

        panel.economyAmount:instantiate()

        panel:addJobWidget(panel.economyAmount)

    else

        panel.economyAmount:setY(y)

    end

    panel:makeJobButton(120, y, 100, 22, IKST.text("IGUI_IKST_Economy_GiveSelf", "Give cash"), function()

        IKST.dispatchCommand(p, IKST.CMD.economyGive, {

            amount = IKST.parseAmount(IKST_JobEconomy.readEntry(panel.economyAmount)),

        })

        panel:refreshJobUI()

    end, true)

    y = y + 32

    if IKST.isMultiplayerSession() and IKST_JobStaff then

        panel:makeJobButton(12, y, 160, 24, IKST.text("IGUI_IKST_Economy_GiveTarget", "Give target $"), function()

            local target = IKST_JobStaff.getSelectedTarget(panel)

            if not target then

                IKST.notify(p, IKST.text("IGUI_IKST_NoTarget", "Select a player in Staff tab first"), false)

                return

            end

            IKST.dispatchCommand(p, IKST.CMD.economyGiveTarget, {

                target = target.id,

                amount = IKST.parseAmount(IKST_JobEconomy.readEntry(panel.economyAmount)),

            })

        end, false)

        y = y + 34

    end

    panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Economy_TaxNote", "Sales tax % and receiver: sandbox options."), UIFont.Small)

    y = y + 22

    local curNote = IKST.text("IGUI_IKST_Economy_CurrencyNote", "Currency name: %1 (sandbox).")

    curNote = string.gsub(curNote, "%%1", IKST_Economy.currencyName())

    panel:makeJobLabel(12, y, curNote, UIFont.Small)

    y = y + 22

    if IKST_Economy.zombieBountyEnabled() then

        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Economy_BountyNote", "Zombie kill bounty is on (sandbox)."), UIFont.Small)

        y = y + 22

    end

    if IKST_Economy.idCardBanking and IKST_Economy.idCardBanking() and IKST_Access.canUseTools(p) then

        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Economy_IdCardAdminNote",
            "Strict mode: dropped IDs die on relog; bank IDs cannot leave the player inventory. Admin reissue revokes all old cards."), UIFont.Small)

        y = y + 22

        panel:makeJobButton(12, y, 160, 24, IKST.text("IGUI_IKST_Economy_ReissueIdSelf", "Reissue my bank ID"), function()

            IKST.dispatchCommand(p, IKST.CMD.economyReissueId, {})

        end, false)

        y = y + 30

        if IKST.isMultiplayerSession() and IKST_JobStaff then

            panel:makeJobButton(12, y, 200, 24, IKST.text("IGUI_IKST_Economy_ReissueIdTarget", "Reissue target bank ID"), function()

                local target = IKST_JobStaff.getSelectedTarget(panel)

                if not target then

                    IKST.notify(p, IKST.text("IGUI_IKST_NoTarget", "Select a player in Staff tab first"), false)

                    return

                end

                IKST.dispatchCommand(p, IKST.CMD.economyReissueIdTarget, { target = target.id })

            end, false)

            y = y + 34

        end

    end

    return y

end



function IKST_JobEconomy.build(panel)

    local y = 8

    local p = panel.player

    local available = IKST_Economy.isEnabled()



    if not available then

        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Economy_Missing", "Install IKappaID PhoneShop for economy tools."), UIFont.Medium)

        y = y + 28

        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Economy_MissingHint", "PhoneShop provides cash items; IKST adds bank, shops, and wire."), UIFont.Small)

        y = y + 40

        IKST_ActionLog.dock(panel, p, y)

        return y

    end



    y = IKST_JobEconomy.buildModeRow(panel, y)

    local mode = IKST_JobEconomy.ensureMode(panel)

    if mode == "money" then

        y = IKST_JobEconomy.buildMoney(panel, y)

    elseif mode == "shop" then

        y = IKST_JobEconomy.buildShop(panel, y)

    elseif mode == "valuables" then

        y = IKST_JobEconomy.buildValuables(panel, y)

    elseif mode == "admin" then

        y = IKST_JobEconomy.buildAdmin(panel, y)

    end



    IKST_ActionLog.dock(panel, p, y)

    return y

end


