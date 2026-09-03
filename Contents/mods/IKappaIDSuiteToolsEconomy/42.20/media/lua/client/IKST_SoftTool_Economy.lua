-- SoftTool Economy: soft-shell Economy workspace painted via IKUI_SoftBody.
-- Dispatch / shop / ticket helpers stay on IKST_JobEconomy.
if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISLabel"
require "ISUI/ISScrollingListBox"
require "IKST_Shared"
require "IKappaID_UI/IKUI_SoftBody"
require "IKappaID_UI/IKUI_Chrome"
require "IKST_JobLayout"
require "IKST_JobEconomy"
require "IKST_Economy"
require "IKST_EconomyCash"
require "IKST_EconomyUI"
require "IKST_EconomyContext"
require "IKST_Access"

IKST_SoftTool_Economy = IKST_SoftTool_Economy or {}

local function openBand(panel, rect, band, title)
    local inner = IKUI_SoftBody.SECTION_INNER
    local padY = 8
    local btnH = IKUI_SoftBody.STANDARD_BTN_H
    local card, contentY = IKUI_SoftBody.section(panel, rect.x, band.y, rect.w, band.h, title)
    return card, inner, contentY + padY, math.max(40, rect.w - inner * 2), math.max(btnH, band.h - contentY - padY * 2)
end

local function openWallet(panel)
    local p = panel.player
    if not p or not IKST_EconomyUI or type(IKST_EconomyUI.open) ~= "function" then
        return
    end
    IKST_EconomyUI.open(p, math.floor(p:getX()), math.floor(p:getY()), p:getZ())
end

local function dispatchAtmCoords(player)
    return IKST_Economy.commandAtmCoords(player, player:getX(), player:getY(), player:getZ())
end

local function playerTileKey(player)
    return math.floor(player:getX()) .. ":" .. math.floor(player:getY()) .. ":" .. tostring(player:getZ())
end

local function cachedAtAtm(panel, player)
    local key = playerTileKey(player)
    if panel._economyAtAtmKey == key then
        return panel._economyAtAtm == true
    end
    panel._economyAtAtmKey = key
    panel._economyAtAtm = IKST_Economy.resolveAtmCoord(player, player:getX(), player:getY(), player:getZ()) ~= nil
    return panel._economyAtAtm
end

local function quickActionPills(panel, p)
    return {
        {
            label = IKST.text("IGUI_IKST_EconomyTile_Transfer", "Transfer"),
            onClick = function()
                IKST_JobEconomy.openSoftWire(p, panel)
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
        {
            label = IKST.text("IGUI_IKST_Economy_Detach", "Open window"),
            onClick = function()
                openWallet(panel)
            end,
        },
        {
            label = IKST.text("IGUI_IKST_Economy_Tab_Values", "Valuables"),
            onClick = function()
                local st = IKST.getPlayerState(p)
                if st then
                    st.economyMode = "valuables"
                    st.navTool = "valuables"
                end
                panel:refreshJobUI()
            end,
        },
    }
end

function IKST_SoftTool_Economy.buildOverview(panel)
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
    local virtualBank = IKST_Economy.idCardBanking and IKST_Economy.idCardBanking()
    local atmRequired = IKST_Economy.atmRequiredForBank and IKST_Economy.atmRequiredForBank()
    local atAtm = cachedAtAtm(panel, p)
    local hasWallet = IKST_EconomyCash and type(IKST_EconomyCash.playerHasWallet) == "function"
        and IKST_EconomyCash.playerHasWallet(p) == true
    local needAtmHint = atmRequired and virtualBank and not atAtm

    local rect = IKUI_SoftBody.contentRect(panel)
    local gap = IKUI_SoftBody.BTN_GAP
    local btnH = IKUI_SoftBody.STANDARD_BTN_H
    local hintH = (atAtm or not hasWallet or needAtmHint) and IKUI_SoftBody.compactPillBandH(1) or 0
    local balanceH = IKUI_SoftBody.compactPillBandH(1)
    local quickH = IKUI_SoftBody.compactPillBandH(virtualBank and 1 or 2)
    local bountiesH = IKUI_SoftBody.fieldActionBandH(1)
    local shopsH = math.max(80, rect.h - hintH - gap - balanceH - gap - quickH - gap - bountiesH - gap)
    local yCursor = rect.y
    local bands = {}
    if hintH > 0 then
        bands[#bands + 1] = { y = yCursor, h = hintH }
        yCursor = yCursor + hintH + gap
    end
    bands[#bands + 1] = { y = yCursor, h = balanceH }
    yCursor = yCursor + balanceH + gap
    bands[#bands + 1] = { y = yCursor, h = quickH }
    yCursor = yCursor + quickH + gap
    bands[#bands + 1] = { y = yCursor, h = bountiesH }
    yCursor = yCursor + bountiesH + gap
    bands[#bands + 1] = { y = yCursor, h = shopsH }
    local stackBottom = bands[#bands].y + bands[#bands].h
    local balanceBand = bands[hintH > 0 and 2 or 1]
    local quickBand = bands[hintH > 0 and 3 or 2]
    local bountiesBand = bands[hintH > 0 and 4 or 3]
    local shopsBand = bands[#bands]

    if hintH > 0 then
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[1],
            IKST.text("IGUI_IKST_EconomyTile_SectionHints", "Tips"))
        local hints = {}
        if atAtm then
            local atmKey = virtualBank and "IGUI_IKST_Economy_AtAtmIdCard"
                or "IGUI_IKST_Economy_AtAtm"
            local atmFallback = virtualBank
                and "ATM — exchange valuables and wire transfers (ID card required)."
                or "ATM — deposit, withdraw, and exchange enabled here."
            hints[#hints + 1] = {
                label = IKST.text(atmKey, atmFallback),
                primary = true,
                onClick = function()
                    local st = IKST.getPlayerState(p)
                    if st then
                        st.economyMode = "valuables"
                        st.navTool = "valuables"
                    end
                    panel:refreshJobUI()
                end,
            }
        elseif needAtmHint then
            hints[#hints + 1] = {
                label = IKST.text("IGUI_IKST_Economy_NeedAtmIdCard", "Go to an ATM with your bank ID card."),
                onClick = function()
                    IKST.notify(p, IKST.text("IGUI_IKST_Economy_NeedAtmIdCard", "Go to an ATM with your bank ID card."), true)
                end,
            }
        end
        if not hasWallet then
            hints[#hints + 1] = {
                label = IKST.text("IGUI_IKST_Economy_CraftWallet", "Craft wallet (Miscellaneous)"),
                onClick = function()
                    IKST.notify(p, IKST.text("IGUI_IKST_Economy_WalletCraftHint",
                        "Craft a simple wallet from leather strips and thread. Store Base.Money inside for portable cash."), true)
                end,
            }
        end
        if #hints > 0 then
            IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, hints)
        end
    end

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, balanceBand, IKST.text("IGUI_IKST_EconomyTile_SectionBalance", "Balance"))
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
        local card, ax, ay, aw, ah = openBand(panel, rect, quickBand, IKST.text("IGUI_IKST_EconomyTile_SectionQuick", "Quick actions"))
        if virtualBank then
            IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, quickActionPills(panel, p))
        else
            local fieldH = IKUI_SoftBody.fieldActionBandH(1)
            local fieldAh = math.min(ah, fieldH)
            IKUI_SoftBody.fieldAction(panel, card, ax, ay, aw, fieldAh, {
                {
                    text = (panel.draftEntryText and panel:draftEntryText("economyAmountEntry", "")) or "",
                    fieldName = "economyAmountEntry",
                },
            }, IKST.text("IGUI_IKST_EconomyTile_Deposit", "Deposit"), function()
                local amount = 0
                if panel.economyAmountEntry and type(panel.economyAmountEntry.getText) == "function" then
                    amount = IKST.parseAmount(panel.economyAmountEntry:getText())
                end
                if amount <= 0 then
                    IKST.notify(p, IKST.text("IGUI_IKST_Economy_InvalidAmount", "Invalid amount."), false)
                    return
                end
                local cx, cy, cz = dispatchAtmCoords(p)
                IKST.dispatchCommand(p, IKST.CMD.economyDeposit, {
                    amount = amount,
                    x = cx, y = cy, z = cz,
                })
            end)
            local pillY = ay + fieldAh + 4
            local pillH = math.max(btnH, ah - fieldAh - 4)
            local pills = quickActionPills(panel, p)
            table.insert(pills, 1, {
                label = IKST.text("IGUI_IKST_EconomyTile_Withdraw", "Withdraw"),
                onClick = function()
                    local amount = IKST.parseAmount(
                        (panel.economyAmountEntry and type(panel.economyAmountEntry.getText) == "function"
                            and panel.economyAmountEntry:getText()) or "")
                    if amount <= 0 then
                        IKST.notify(p, IKST.text("IGUI_IKST_Economy_InvalidAmount", "Invalid amount."), false)
                        return
                    end
                    local cx, cy, cz = dispatchAtmCoords(p)
                    IKST.dispatchCommand(p, IKST.CMD.economyWithdraw, {
                        amount = amount,
                        x = cx, y = cy, z = cz,
                    })
                end,
            })
            IKUI_SoftBody.pillRow(panel, card, ax, pillY, aw, pillH, pills)
        end
    end

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bountiesBand, IKST.text("IGUI_IKST_EconomyTile_SectionBounties", "Bounties"))
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, {
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
        local card, ax, ay, aw, ah = openBand(panel, rect, shopsBand, IKST.text("IGUI_IKST_EconomyTile_SectionShops", "My shops"))
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

    return stackBottom + gap
end

function IKST_SoftTool_Economy.buildShop(panel)
    local p = panel.player
    if IKST_JobEconomy and type(IKST_JobEconomy.ensureShopAtPlayer) == "function" then
        IKST_JobEconomy.ensureShopAtPlayer(panel)
    end
    local rect = IKUI_SoftBody.contentRect(panel)
    local gap = IKUI_SoftBody.BTN_GAP
    local shopH = IKUI_SoftBody.compactPillBandH(1)
    local priceH = IKUI_SoftBody.fieldActionBandH(1)
    local bulkH = IKUI_SoftBody.compactPillBandH(2)
    local stockH = math.max(80, rect.h - shopH - gap - priceH - gap - bulkH - gap)
    local bands = {
        { y = rect.y, h = shopH },
        { y = rect.y + shopH + gap, h = stockH },
        { y = rect.y + shopH + gap + stockH + gap, h = priceH },
        { y = rect.y + shopH + gap + stockH + gap + priceH + gap, h = bulkH },
    }
    local stackBottom = bands[4].y + bands[4].h

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[1], IKST.text("IGUI_IKST_Economy_Tab_Shop", "Shop"))
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, {
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
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[2], IKST.text("IGUI_IKST_Economy_ShopStock", "Stock"))
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
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[3], IKST.text("IGUI_IKST_Economy_PriceEach", "Price"))
        IKUI_SoftBody.fieldAction(panel, card, ax, ay, aw, ah, {
            { text = "25", fieldName = "economyPriceEntry" },
        }, IKST.text("IGUI_IKST_Economy_SetPricePick", "Set selected"), function()
            IKST_JobEconomy.dispatchSetPrice(panel, "selected")
        end)
    end

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[4], IKST.text("IGUI_IKST_Economy_Bulk", "Bulk"))
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, {
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

    return stackBottom + gap
end

function IKST_SoftTool_Economy.buildValuables(panel)
    local p = panel.player
    if not p then
        return 8
    end
    local rect = IKUI_SoftBody.contentRect(panel)
    local gap = IKUI_SoftBody.BTN_GAP
    local actionH = IKUI_SoftBody.compactPillBandH(1)
    local bands = IKUI_SoftBody.pageBands(rect.y, rect.h, 120, { actionH }, gap)
    local stackBottom = rect.y + rect.h

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[1], IKST.text("IGUI_IKST_Economy_Tab_Values", "Valuables"))
        local rows = IKST_EconomyUI.buildValuableRows(p)
        local owned = {}
        for i = 1, #rows do
            local row = rows[i]
            if (row.count or 0) > 0 then
                owned[#owned + 1] = row
            end
        end
        if #owned == 0 then
            local empty = ISLabel:new(ax, ay, 16,
                IKST.text("IGUI_IKST_Economy_NoOwnedValuables", "No sellable valuables in inventory."),
                1, 1, 1, 1, UIFont.Small, true)
            empty:initialise()
            card:addChild(empty)
        else
            local list = ISScrollingListBox:new(ax, ay, aw, ah)
            list:initialise()
            list:instantiate()
            list.itemheight = IKST_JobLayout.listItemHeight()
            list.font = UIFont.Small
            list.drawBorder = true
            if IKUI_Chrome and type(IKUI_Chrome.styleListBox) == "function" then
                IKUI_Chrome.styleListBox(list)
            end
            if list.clipping ~= nil then
                list.clipping = true
            end
            for i = 1, #owned do
                local row = owned[i]
                local label = row.label .. "  ×" .. tostring(row.count) .. "   " .. tostring(row.priceLabel or "")
                list:addItem(label, row)
            end
            list.onmousedown = function(target, mx, my)
                if target and type(target.onMouseDown) == "function" then
                    target:onMouseDown(mx, my)
                end
            end
            card:addChild(list)
            panel._economyValList = list
            panel._ikstSelectLists = panel._ikstSelectLists or {}
            panel._ikstSelectLists[#panel._ikstSelectLists + 1] = list
        end
    end

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[2], IKST.text("IGUI_IKST_Economy_ExchangeTitle", "Exchange"))
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_Economy_Exchange", "Sell one"),
                primary = true,
                onClick = function()
                    local list = panel._economyValList
                    local row = nil
                    if list and list.selected and list.items and list.items[list.selected] then
                        row = list.items[list.selected].item
                    end
                    if not row or not row.itemType then
                        IKST.notify(p, IKST.text("IGUI_IKST_Economy_SelectValuable", "Select a valuable first."), false)
                        return
                    end
                    local ax, ay, az = dispatchAtmCoords(p)
                    IKST.dispatchCommand(p, IKST.CMD.economyExchange, {
                        itemType = row.itemType,
                        x = ax, y = ay, z = az,
                    })
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Economy_SellAll", "Sell all"),
                onClick = function()
                    local ax, ay, az = dispatchAtmCoords(p)
                    IKST.dispatchCommand(p, IKST.CMD.economyExchangeAll, {
                        x = ax, y = ay, z = az,
                    })
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Economy_Detach", "Open window"),
                onClick = function()
                    IKST_EconomyUI.open(p, math.floor(p:getX()), math.floor(p:getY()), p:getZ())
                end,
            },
        })
    end

    return stackBottom + gap
end

function IKST_SoftTool_Economy.buildAdmin(panel)
    local p = panel.player
    local rect = IKUI_SoftBody.contentRect(panel)
    local gap = IKUI_SoftBody.BTN_GAP
    local bands, stackBottom = IKUI_SoftBody.stack(rect.y, gap, { 1, 1, 1 })

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[1], IKST.text("IGUI_IKST_Economy_Snapshot", "Snapshot"))
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, {
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
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[2], IKST.text("IGUI_IKST_Economy_PlaceAtmAdmin", "ATM"))
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, {
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
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[3], IKST.text("IGUI_IKST_Economy_Ids", "IDs"))
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_Economy_ReissueIdSelf", "Reissue self"),
                onClick = function()
                    local ax, ay, az = dispatchAtmCoords(p)
                    IKST.dispatchCommand(p, IKST.CMD.economyIdCardReissue, {
                        x = ax, y = ay, z = az,
                    })
                end,
            },
        })
    end

    return stackBottom + gap
end

function IKST_SoftTool_Economy.build(panel)
    if not panel then
        return 8
    end
    local p = panel.player
    if not IKST_Economy or not IKST_Economy.isEnabled or not IKST_Economy.isEnabled() then
        local rect = IKUI_SoftBody.contentRect(panel)
        local card, ax, ay = openBand(panel, rect, { y = rect.y, h = 80 },
            IKST.text("IGUI_IKST_Economy_Missing", "Economy"))
        local line = ISLabel:new(ax, ay, 16,
            IKST.text("IGUI_IKST_Economy_Missing", "Install IKappaID PhoneShop for economy tools."),
            1, 1, 1, 1, UIFont.Small, true)
        line:initialise()
        card:addChild(line)
        return rect.y + 80
    end
    local state = IKST.getPlayerState(p)
    if state and state.navTool and (state.navTool == "money" or state.navTool == "shop"
        or state.navTool == "valuables" or state.navTool == "admin") then
        state.economyMode = state.navTool
    end
    local mode = IKST_JobEconomy.ensureMode(panel)
    local bottomY
    if mode == "shop" then
        bottomY = IKST_SoftTool_Economy.buildShop(panel)
    elseif mode == "admin" then
        bottomY = IKST_SoftTool_Economy.buildAdmin(panel)
    elseif mode == "valuables" then
        bottomY = IKST_SoftTool_Economy.buildValuables(panel)
    else
        bottomY = IKST_SoftTool_Economy.buildOverview(panel)
    end
    return bottomY
end
