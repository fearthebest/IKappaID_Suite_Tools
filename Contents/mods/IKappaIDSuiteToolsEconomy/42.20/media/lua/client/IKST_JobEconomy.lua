if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISTextEntryBox"
require "ISUI/ISScrollingListBox"
require "ISUI/ISButton"
require "ISUI/ISLabel"
require "ISUI/ISPanel"
require "ISUI/ISTextBox"
require "ISUI/ISComboBox"
require "IKST_Shared"
require "IKST_Economy"
require "IKST_EconomyBridge"
require "IKST_EconomyUI"
require "IKST_EconomyVendClient"
require "IKST_EconomyContext"
require "IKappaID_UI/IKUI_Chrome"
require "IKST_UI_Layout"
require "IKST_JobLayout"
require "IKST_ScrollArea"
IKST_JobEconomy = IKST_JobEconomy or {}
IKST_JobEconomy._vendEntries = {}

function IKST_JobEconomy.readEntry(entry)
    if entry and type(entry.getText) == "function" then
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
    if IKST_EconomyVendClient and IKST_EconomyVendClient.onVendListResult then
        IKST_EconomyVendClient.onVendListResult(args)
    end
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
        IKST.text("IGUI_IKST_Economy_Detach", "Detach economy window"), function()
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

function IKST_JobEconomy.ensureShopAtPlayer(panel)
    local p = panel.player
    if panel.economyVendX then
        return true
    end
    if not IKST_EconomyContext or type(IKST_EconomyContext.shopObjectAtPlayer) ~= "function" then
        return false
    end
    local shopObj, sx, sy, sz = IKST_EconomyContext.shopObjectAtPlayer(p)
    if shopObj and type(IKST_EconomyContext.isShopOwner) == "function" and IKST_EconomyContext.isShopOwner(p, shopObj) then
        panel.economyVendX = sx
        panel.economyVendY = sy
        panel.economyVendZ = sz
        IKST_JobEconomy.requestVendList(panel)
        return true
    end
    return false
end

function IKST_JobEconomy.buildShop(panel, contentTop)
    local p = panel.player
    IKST_JobEconomy.ensureShopAtPlayer(panel)

    local rect = IKST_JobLayout.toolContentRect(panel)
    if contentTop and contentTop > rect.y then
        local shrink = contentTop - rect.y
        rect.y = contentTop
        rect.h = math.max(80, rect.h - shrink)
    end
    local gap = 6
    local bands = IKST_JobLayout.splitBands(rect.y, rect.h, 4, gap)
    local inner = IKST_JobLayout.SECTION_INNER
    local padY = IKST_JobLayout.CONTENT_PAD_Y
    local btnH = IKST_JobLayout.STANDARD_BTN_H

    local function openBand(band, title)
        local card, contentY = IKST_JobLayout.placeSectionCard(panel, rect.x, band.y, rect.w, band.h, nil, title)
        local areaX = inner
        local areaW = math.max(40, rect.w - inner * 2)
        local areaY = contentY + padY
        local areaH = math.max(btnH, band.h - contentY - padY * 2)
        return card, areaX, areaY, areaW, areaH
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[1], IKST.text("IGUI_IKST_Economy_Tab_Shop", "Shop"))
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_Economy_ClaimShop", "Claim / Open"),
                primary = true,
                onClick = function()
                    local shopObj, sx, sy, sz = nil, nil, nil, nil
                    if IKST_EconomyContext and type(IKST_EconomyContext.shopObjectAtPlayer) == "function" then
                        shopObj, sx, sy, sz = IKST_EconomyContext.shopObjectAtPlayer(p)
                    end
                    if shopObj and IKST_EconomyContext.canClaimShop and IKST_EconomyContext.canClaimShop(shopObj) then
                        IKST_EconomyContext.claimShop(p, sx, sy, sz)
                        panel.economyVendX = sx
                        panel.economyVendY = sy
                        panel.economyVendZ = sz
                    elseif not IKST_JobEconomy.ensureShopAtPlayer(panel) then
                        IKST.notify(p, IKST.text("IGUI_IKST_Economy_ShopPick",
                            "Stand at your shop terminal or right-click it > Manage shop prices."), false)
                    end
                    panel:refreshJobUI()
                end,
            },
            {
                label = IKST.text("IGUI_IKST_RefreshList", "Refresh"),
                onClick = function()
                    IKST_JobEconomy.requestVendList(panel)
                end,
            },
        })
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[2], IKST.text("IGUI_IKST_Economy_ShopStock", "Stock"))
        if not panel.economyVendX then
            local empty = ISLabel:new(ax, ay, 16,
                IKST.text("IGUI_IKST_Economy_ShopPick", "Stand at your shop terminal or right-click it > Manage shop prices."),
                1, 1, 1, 1, UIFont.Small, true)
            empty:initialise()
            card:addChild(empty)
        else
            panel.economyVendList = ISScrollingListBox:new(ax, ay, aw, ah)
            panel.economyVendList:initialise()
            panel.economyVendList:instantiate()
            panel.economyVendList.itemheight = IKST_JobLayout.listItemHeight()
            panel.economyVendList.font = UIFont.Small
            panel.economyVendList.drawBorder = true
            if IKUI_Chrome and type(IKUI_Chrome.styleListBox) == "function" then
                IKUI_Chrome.styleListBox(panel.economyVendList)
            end
            panel.economyVendList.onmousedown = function(target, mx, my)
                if target and type(target.onMouseDown) == "function" then
                    target:onMouseDown(mx, my)
                end
                IKST_JobEconomy.onVendListSelect(panel, IKST_JobEconomy.isCtrlHeld())
                IKST_JobEconomy.populateVendList(panel)
            end
            card:addChild(panel.economyVendList)
            IKST_JobEconomy.populateVendList(panel)
        end
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[3], IKST.text("IGUI_IKST_Economy_PriceEach", "Price"))
        IKST_JobLayout.placeFieldActionCorner(panel, card, ax, ay, aw, ah, {
            { text = "25", fieldName = "economyPriceEntry" },
        }, IKST.text("IGUI_IKST_Economy_SetPricePick", "Set selected"), function()
            IKST_JobEconomy.dispatchSetPrice(panel, "selected")
        end)
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[4], IKST.text("IGUI_IKST_Economy_Bulk", "Bulk"))
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_Economy_SetPriceOne", "1 stack"),
                onClick = function()
                    IKST_JobEconomy.dispatchSetPrice(panel, "one")
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Economy_SetPriceType", "Type"),
                onClick = function()
                    IKST_JobEconomy.dispatchSetPrice(panel, "type")
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Economy_SetPriceAll", "All"),
                onClick = function()
                    IKST_JobEconomy.dispatchSetPrice(panel, "all")
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Economy_ClearPrice", "Clear"),
                onClick = function()
                    panel.economyPriceClearScope = "one"
                    IKST_JobEconomy.dispatchSetPrice(panel, "clear")
                end,
            },
        })
    end

    panel._ikstToolFit = true
    return rect.y + rect.h
end

function IKST_JobEconomy.buildValuables(panel, y)
    local p = panel.player
    IKST_EconomyUI.addJobIconLabel(panel, 12, y, IKST_EconomyUI.atmItemType(),
        IKST.text("IGUI_IKST_Economy_ValuableHelp", "Sell items from media/ikst/sell_list.txt (ATM exchange)."), UIFont.Small, 22, true)
    y = y + 24
    local rows = IKST_EconomyUI.buildValuableRows(p)
    local shown = 0
    for i = 1, #rows do
        local row = rows[i]
        local owned = row.count or 0
        if owned > 0 then
            shown = shown + 1
            local label = row.label .. "  ×" .. tostring(owned) .. "   " .. row.priceLabel
            IKST_EconomyUI.addJobIconButton(panel, 12, y, panel.contentW or 300, 24, row.itemType, label, function()
                IKST.dispatchCommand(p, IKST.CMD.economyExchange, {
                    itemType = row.itemType,
                    x = math.floor(p:getX()),
                    y = math.floor(p:getY()),
                    z = p:getZ(),
                })
            end, true)
            y = y + 26
        end
    end
    if shown == 0 then
        IKST_EconomyUI.addJobIconLabel(panel, 12, y,
            IKST.text("IGUI_IKST_Economy_NoOwnedValuables", "No sellable valuables in inventory."), UIFont.Small, 22, true)
        y = y + 24
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
        IKST.text("IGUI_IKST_Economy_Detach", "Detach economy window"), function()
        IKST_EconomyUI.open(p, math.floor(p:getX()), math.floor(p:getY()), p:getZ())
    end, false)
    return y + 30
end

function IKST_JobEconomy.buildAdmin(panel, contentTop)
    local p = panel.player

    local rect = IKST_JobLayout.toolContentRect(panel)
    if contentTop and contentTop > rect.y then
        local shrink = contentTop - rect.y
        rect.y = contentTop
        rect.h = math.max(80, rect.h - shrink)
    end
    local gap = 6
    local bands = IKST_JobLayout.splitBands(rect.y, rect.h, 3, gap)
    local inner = IKST_JobLayout.SECTION_INNER
    local padY = IKST_JobLayout.CONTENT_PAD_Y
    local btnH = IKST_JobLayout.STANDARD_BTN_H

    local function openBand(band, title)
        local card, contentY = IKST_JobLayout.placeSectionCard(panel, rect.x, band.y, rect.w, band.h, nil, title)
        local areaX = inner
        local areaW = math.max(40, rect.w - inner * 2)
        local areaY = contentY + padY
        local areaH = math.max(btnH, band.h - contentY - padY * 2)
        return card, areaX, areaY, areaW, areaH
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[1], IKST.text("IGUI_IKST_Economy_Snapshot", "Snapshot"))
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_Economy_Refresh", "Refresh"),
                primary = true,
                onClick = function()
                    IKST.dispatchCommand(p, IKST.CMD.economySnapshot, {})
                    panel:refreshJobUI()
                end,
            },
        })
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[2], IKST.text("IGUI_IKST_Economy_PlaceAtmAdmin", "ATM"))
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_Economy_PlaceAtmAdmin", "Place ATM fixture (admin)"),
                primary = true,
                onClick = function()
                    if not IKST_EconomyAtmKit then
                        require "IKST_EconomyAtmKit"
                    end
                    if IKST_EconomyAtmKit and type(IKST_EconomyAtmKit.placeAt) == "function" then
                        IKST_EconomyAtmKit.placeAt(p, p:getX(), p:getY(), p:getZ())
                    else
                        IKST.dispatchCommand(p, IKST.CMD.economyAtmPlace, {
                            x = math.floor(p:getX()),
                            y = math.floor(p:getY()),
                            z = math.floor(p:getZ() or 0),
                        })
                    end
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Economy_VendEnable", "Enable shop here"),
                onClick = function()
                    IKST.dispatchCommand(p, IKST.CMD.economyVendEnable, {
                        x = math.floor(p:getX()),
                        y = math.floor(p:getY()),
                        z = math.floor(p:getZ() or 0),
                    })
                end,
            },
        })
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[3], IKST.text("IGUI_IKST_Economy_Ids", "IDs"))
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_Economy_ReissueIdSelf", "Reissue self"),
                onClick = function()
                    IKST.dispatchCommand(p, IKST.CMD.economyIdCardReissue, {})
                end,
            },
        })
    end

    panel._ikstToolFit = true
    return rect.y + rect.h
end

-- Economy landing — hand-laid Q3 bands matching canvas disposition.

local function openWallet(panel)
    local p = panel.player
    if not p or not IKST_EconomyUI or type(IKST_EconomyUI.open) ~= "function" then
        return
    end
    IKST_EconomyUI.open(p, math.floor(p:getX()), math.floor(p:getY()), p:getZ())
end

function IKST_JobEconomy.openTicketBox(player, prompt, command, emptyMsg)
    if not player then
        return
    end
    if not IKST.isMultiplayerSession or not IKST.isMultiplayerSession() then
        IKST.notify(player, IKST.text("IGUI_IKST_Economy_TicketMpOnly",
            "Delivery and player bounty tickets need multiplayer. Staff review them in F1 See Tickets."), false)
        return
    end
    if not ISTextBox or type(ISTextBox.new) ~= "function" then
        return
    end
    local playerNum = 0
    if type(player.getPlayerNum) == "function" then
        playerNum = player:getPlayerNum()
    end
    local modal = ISTextBox:new(0, 0, 320, 180, prompt, "", nil, function(_, button)
        if not button or button.internal ~= "OK" then
            return
        end
        local parent = button.parent
        local entry = parent and parent.entry
        if not entry or type(entry.getText) ~= "function" then
            return
        end
        local msg = entry:getText()
        msg = tostring(msg or "")
        msg = string.gsub(msg, "^%s*(.-)%s*$", "%1")
        if msg == "" then
            IKST.notify(player, emptyMsg, false)
            return
        end
        IKST.dispatchCommand(player, command, { message = msg })
    end, playerNum)
    modal:initialise()
    if type(modal.setMultipleLine) == "function" then
        modal:setMultipleLine(true)
    end
    if type(modal.setNumberOfLines) == "function" then
        modal:setNumberOfLines(4)
    end
    modal:addToUIManager()
end

function IKST_JobEconomy.closePayPick()
    local panel = IKST_JobEconomy._payPickPanel
    if not panel then
        return
    end
    if type(panel.removeFromUIManager) == "function" then
        panel:removeFromUIManager()
    end
    IKST_JobEconomy._payPickPanel = nil
end

function IKST_JobEconomy.openPayRequestAmount(player, target)
    if not player or not target then
        return
    end
    if not ISTextBox or type(ISTextBox.new) ~= "function" then
        return
    end
    local playerNum = 0
    if type(player.getPlayerNum) == "function" then
        playerNum = player:getPlayerNum()
    end
    local prompt = IKST.text("IGUI_IKST_Economy_PayRequestPrompt", "Amount to request from")
        .. " " .. tostring(target.name or "player")
    local modal = ISTextBox:new(0, 0, 280, 140, prompt, "", nil, function(_, button)
        if not button or button.internal ~= "OK" then
            return
        end
        local parent = button.parent
        local entry = parent and parent.entry
        if not entry or type(entry.getText) ~= "function" then
            return
        end
        local amount = IKST.parseAmount(entry:getText())
        if amount <= 0 then
            IKST.notify(player, IKST.text("IGUI_IKST_Economy_InvalidAmount", "Invalid amount."), false)
            return
        end
        IKST.dispatchCommand(player, IKST.CMD.economyPayRequest, {
            target = target.id,
            amount = amount,
        })
    end, playerNum)
    modal:initialise()
    modal:addToUIManager()
end

function IKST_JobEconomy.openPayRequestPicker(player, nearby)
    IKST_JobEconomy.closePayPick()
    local w, h = 280, 110
    local x, y = 200, 200
    local core = getCore and getCore()
    if core and type(core.getScreenWidth) == "function" and type(core.getScreenHeight) == "function" then
        x = math.floor((core:getScreenWidth() - w) / 2)
        y = math.floor((core:getScreenHeight() - h) / 2)
    end
    local panel = ISPanel:new(x, y, w, h)
    local cc = IKUI_Chrome.colors
    panel.backgroundColor = { r = cc.bgApp.r, g = cc.bgApp.g, b = cc.bgApp.b, a = 0.96 }
    panel.borderColor = cc.accent
    panel:initialise()
    panel:addToUIManager()

    local label = ISLabel:new(12, 10, 20, IKST.text("IGUI_IKST_Economy_PayRequestWho", "Who to request payment from"), 1, 1, 1, 1, UIFont.Small, true)
    label:initialise()
    panel:addChild(label)

    local combo = ISComboBox:new(12, 34, w - 24, 22)
    combo:initialise()
    for i = 1, #nearby do
        combo:addOption(tostring(nearby[i].name or "player"))
    end
    panel:addChild(combo)

    local ok = IKUI_Chrome.newActionButton(12, 70, 100, 22, IKST.text("IGUI_IKST_Economy_PayRequestPick", "Request"), panel, function()
        local idx = combo.selected or 1
        local target = nearby[idx]
        if not target then
            return
        end
        IKST_JobEconomy.closePayPick()
        IKST_JobEconomy.openPayRequestAmount(player, target)
    end, "primary")
    panel:addChild(ok)

    local cancel = IKUI_Chrome.newActionButton(120, 70, 80, 22, IKST.text("IGUI_IKST_Cancel", "Cancel"), panel, function()
        IKST_JobEconomy.closePayPick()
    end, "outline")
    panel:addChild(cancel)

    IKST_JobEconomy._payPickPanel = panel
end

function IKST_JobEconomy.openPayRequest(player)
    if not player then
        return
    end
    local nearby = {}
    if IKST_EconomyUI and type(IKST_EconomyUI.nearbyPlayers) == "function" then
        nearby = IKST_EconomyUI.nearbyPlayers(player)
    end
    if #nearby == 0 then
        IKST.notify(player, IKST.text("IGUI_IKST_Economy_NoPlayersNear", "No players nearby"), false)
        return
    end
    if #nearby == 1 then
        IKST_JobEconomy.openPayRequestAmount(player, nearby[1])
        return
    end
    IKST_JobEconomy.openPayRequestPicker(player, nearby)
end

function IKST_JobEconomy.buildOverview(panel, contentTop)
    local p = panel.player
    if not p then
        return 8
    end

    if not panel._economySnapRequested then
        panel._economySnapRequested = true
        if IKST_EconomyUI and type(IKST_EconomyUI.requestSnapshot) == "function" then
            IKST_EconomyUI.requestSnapshot(p, math.floor(p:getX()), math.floor(p:getY()), p:getZ())
        end
    end

    local cash, bank, pending = 0, 0, 0
    if IKST_EconomyUI and type(IKST_EconomyUI.getBalances) == "function" then
        cash, bank, pending = IKST_EconomyUI.getBalances(p)
    end

    local rect = IKST_JobLayout.toolContentRect(panel)
    if contentTop and contentTop > rect.y then
        local shrink = contentTop - rect.y
        rect.y = contentTop
        rect.h = math.max(80, rect.h - shrink)
    end
    local gap = 6
    local bands = IKST_JobLayout.splitBands(rect.y, rect.h, 4, gap)
    local inner = IKST_JobLayout.SECTION_INNER
    local padY = IKST_JobLayout.CONTENT_PAD_Y
    local btnH = IKST_JobLayout.STANDARD_BTN_H

    local function openBand(band, title)
        local card, contentY = IKST_JobLayout.placeSectionCard(panel, rect.x, band.y, rect.w, band.h, nil, title)
        local areaX = inner
        local areaW = math.max(40, rect.w - inner * 2)
        local areaY = contentY + padY
        local areaH = math.max(btnH, band.h - contentY - padY * 2)
        return card, areaX, areaY, areaW, areaH
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[1], IKST.text("IGUI_IKST_EconomyTile_SectionBalance", "Balance"))
        local detail = IKST.text("IGUI_IKST_Economy_Cash", "Cash") .. " " .. IKST_Economy.formatAmount(cash)
            .. "  ·  " .. IKST.text("IGUI_IKST_Economy_Bank", "Bank") .. " " .. IKST_Economy.formatAmount(bank)
        if pending and pending > 0 then
            detail = detail .. "  ·  " .. IKST.text("IGUI_IKST_Economy_Pending", "Pending") .. " " .. IKST_Economy.formatAmount(pending)
        end
        local line = ISLabel:new(ax, ay, 16, detail, 1, 1, 1, 1, UIFont.Small, true)
        line:initialise()
        card:addChild(line)
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[2], IKST.text("IGUI_IKST_EconomyTile_SectionQuick", "Quick actions"))
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_EconomyTile_Deposit", "Deposit"),
                primary = true,
                onClick = function()
                    openWallet(panel)
                end,
            },
            {
                label = IKST.text("IGUI_IKST_EconomyTile_Withdraw", "Withdraw"),
                onClick = function()
                    openWallet(panel)
                end,
            },
            {
                label = IKST.text("IGUI_IKST_EconomyTile_Transfer", "Transfer"),
                onClick = function()
                    openWallet(panel)
                end,
            },
            {
                label = IKST.text("IGUI_IKST_EconomyTile_RequestPay", "Request"),
                onClick = function()
                    IKST_JobEconomy.openPayRequest(p)
                end,
            },
            {
                label = IKST.text("IGUI_IKST_EconomyTile_History", "History"),
                onClick = function()
                    if IKST_EconomyUI and type(IKST_EconomyUI.requestSnapshot) == "function" then
                        IKST_EconomyUI.requestSnapshot(p, math.floor(p:getX()), math.floor(p:getY()), p:getZ())
                    end
                end,
            },
        })
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[3], IKST.text("IGUI_IKST_EconomyTile_SectionBounties", "Bounties"))
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_EconomyTile_Delivery", "Delivery contract"),
                onClick = function()
                    IKST_JobEconomy.openTicketBox(p,
                        IKST.text("IGUI_IKST_Economy_DeliveryPrompt",
                            "Describe the delivery. Staff will see a ticket labeled [delivery]."),
                        IKST.CMD.economyDelivery,
                        IKST.text("IGUI_IKST_Economy_TicketNeedMsg", "Enter a message."))
                end,
            },
            {
                label = IKST.text("IGUI_IKST_EconomyTile_PlayerBounty", "Player bounty"),
                onClick = function()
                    IKST_JobEconomy.openTicketBox(p,
                        IKST.text("IGUI_IKST_Economy_BountyPrompt",
                            "Name the target and terms. Staff will see a ticket labeled [bounty]."),
                        IKST.CMD.economyPlayerBounty,
                        IKST.text("IGUI_IKST_Economy_TicketNeedMsg", "Enter a message."))
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Cancel", "Cancel"),
                onClick = function()
                    local snap = IKST_EconomyUI and IKST_EconomyUI._snap or {}
                    local payReq = snap.payReq
                    if type(payReq) == "table" and tonumber(payReq.amount) then
                        IKST.dispatchCommand(p, IKST.CMD.economyPayRespond, { accept = false })
                    else
                        IKST.notify(p, IKST.text("IGUI_IKST_Economy_NoPayReq", "No pending payment request."), false)
                    end
                end,
            },
        })
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[4], IKST.text("IGUI_IKST_EconomyTile_SectionShops", "My shops"))
        local shopRows = {}
        if panel.economyVendX then
            shopRows[#shopRows + 1] = {
                id = "shop",
                label = IKST.text("IGUI_IKST_Economy_ShopAt", "Shop at")
                    .. " " .. tostring(panel.economyVendX) .. "," .. tostring(panel.economyVendY),
                manage = true,
            }
        else
            local shopObj, sx, sy, sz = nil, nil, nil, nil
            if IKST_EconomyContext and type(IKST_EconomyContext.shopObjectAtPlayer) == "function" then
                shopObj, sx, sy, sz = IKST_EconomyContext.shopObjectAtPlayer(p)
            end
            if shopObj and IKST_EconomyContext.canClaimShop and IKST_EconomyContext.canClaimShop(shopObj) then
                shopRows[#shopRows + 1] = {
                    id = "claim",
                    label = IKST.text("IGUI_IKST_Economy_ClaimShop", "Open my shop here")
                        .. " (" .. tostring(sx) .. ", " .. tostring(sy) .. ")",
                    claim = true,
                    sx = sx, sy = sy, sz = sz,
                }
            elseif shopObj and IKST_EconomyContext.isShopOwner and IKST_EconomyContext.isShopOwner(p, shopObj) then
                panel.economyVendX = sx
                panel.economyVendY = sy
                panel.economyVendZ = sz
                shopRows[#shopRows + 1] = {
                    id = "shop",
                    label = IKST.text("IGUI_IKST_Economy_ShopAt", "Shop at")
                        .. " " .. tostring(sx) .. "," .. tostring(sy),
                    manage = true,
                }
            end
        end
        if #shopRows == 0 then
            local empty = ISLabel:new(ax, ay, 16,
                IKST.text("IGUI_IKST_Economy_ShopPick", "Stand at your shop terminal or right-click it > Manage shop prices."),
                1, 1, 1, 1, UIFont.Small, true)
            empty:initialise()
            card:addChild(empty)
        else
            local visible = math.max(4, math.floor(ah / math.max(18, IKST_JobLayout.listItemHeight())))
            IKST_JobLayout.makeSelectList(panel, card, ax, ay, aw, IKST_JobLayout.selectListHeight(visible), shopRows, {
                onSelect = function(row)
                    local st = IKST.getPlayerState(p)
                    if row.claim and IKST_EconomyContext and type(IKST_EconomyContext.claimShop) == "function" then
                        IKST_EconomyContext.claimShop(p, row.sx, row.sy, row.sz)
                        panel.economyVendX = row.sx
                        panel.economyVendY = row.sy
                        panel.economyVendZ = row.sz
                    end
                    if st then
                        st.economyMode = "shop"
                    end
                    IKST_JobEconomy.requestVendList(panel)
                    panel:refreshJobUI()
                end,
            })
        end
    end

    panel._ikstToolFit = true
    return rect.y + rect.h
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
        return y
    end
    y = IKST_JobEconomy.buildModeRow(panel, y)
    local mode = IKST_JobEconomy.ensureMode(panel)
    if mode == "money" then
        return IKST_JobEconomy.buildOverview(panel, y)
    end
    if mode == "shop" then
        return IKST_JobEconomy.buildShop(panel, y)
    end
    if mode == "admin" then
        return IKST_JobEconomy.buildAdmin(panel, y)
    end
    if mode == "valuables" then
        return IKST_JobEconomy.buildValuables(panel, y)
    end
    return y
end
