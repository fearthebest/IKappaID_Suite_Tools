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
require "IKST_Chrome"
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
        IKST.text("IGUI_IKST_Economy_Detach", "Detach economy window"), function()
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
        panel.economyAmount.onTextChange = function(entry)
            local raw = entry and type(entry.getText) == "function" and entry:getText() or ""
            local n = tonumber(raw)
            local c = IKST_Chrome and IKST_Chrome.colors
            if not n or n < 0 then
                if c and c.danger then
                    entry.borderColor = { r = c.danger.r, g = c.danger.g, b = c.danger.b, a = 1 }
                end
                entry.tooltip = IKST.text("IGUI_IKST_Economy_AmountInvalid", "Enter a positive number")
            else
                if c and c.accent then
                    entry.borderColor = { r = c.accent.r, g = c.accent.g, b = c.accent.b, a = 1 }
                end
                entry.tooltip = nil
            end
        end
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

-- Economy landing (mockup: ikst-page-economy.png). Wallet, shops, transfers, tickets.

local function economyBtn(parent, panel, x, y, w, h, label, kind, onClick)
    local btn = IKST_Chrome.newActionButton(x, y, w, h, label, panel, function()
        if onClick then
            onClick()
        end
    end, kind or "chip")
    parent:addChild(btn)
    return btn
end

local function economyFlowLayout(items, cardW, gap)
    local padX = IKST_UI_Layout.s(14)
    local usableW = math.max(40, cardW - (padX * 2))
    local rows = {}
    local curRow = {}
    local curX = 0
    for _, item in ipairs(items) do
        local w = IKST_UI_Layout.buttonWidth(item.label, UIFont.Small, 96)
        if curX > 0 and curX + gap + w > usableW then
            rows[#rows + 1] = curRow
            curRow = {}
            curX = 0
        end
        if curX > 0 then
            curX = curX + gap
        end
        curRow[#curRow + 1] = { item = item, x = padX + curX, w = w }
        curX = curX + w
    end
    if #curRow > 0 then
        rows[#rows + 1] = curRow
    end
    return rows
end

local function economyPillSection(panel, x, y, w, icon, titleKey, titleFallback, items)
    local rowH = math.max(26, IKST_UI_Layout.s(30))
    local gap = IKST_UI_Layout.s(8)
    local rows = economyFlowLayout(items, w, gap)
    local headerH = IKST_Chrome.sectionHeaderH()
    local bottomPad = IKST_UI_Layout.s(14)
    local contentH = (#rows * rowH) + (math.max(0, #rows - 1) * gap)
    if #rows == 0 then
        contentH = rowH
    end
    local cardH = headerH + contentH + bottomPad
    local card, contentY = IKST_Chrome.newSectionCardPanel(x, y, w, cardH, icon, IKST.text(titleKey, titleFallback))
    panel:addJobWidget(card)
    local cy = contentY
    for _, row in ipairs(rows) do
        for _, cell in ipairs(row) do
            local item = cell.item
            local kind = "chip"
            if item.primary then
                kind = "primary"
            elseif item.outline then
                kind = "outline"
            elseif item.on then
                kind = "primary"
            end
            economyBtn(card, panel, cell.x, cy, cell.w, rowH, item.label, kind, function()
                if item.onClick then
                    item.onClick()
                end
                panel:refreshJobUI()
            end)
        end
        cy = cy + rowH + gap
    end
    return y + cardH + (IKST_JobLayout.GAP or gap)
end

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
    local cc = IKST_Chrome.colors
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

    local ok = IKST_Chrome.newActionButton(12, 70, 100, 22, IKST.text("IGUI_IKST_Economy_PayRequestPick", "Request"), panel, function()
        local idx = combo.selected or 1
        local target = nearby[idx]
        if not target then
            return
        end
        IKST_JobEconomy.closePayPick()
        IKST_JobEconomy.openPayRequestAmount(player, target)
    end, "primary")
    panel:addChild(ok)

    local cancel = IKST_Chrome.newActionButton(120, 70, 80, 22, IKST.text("IGUI_IKST_Cancel", "Cancel"), panel, function()
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

function IKST_JobEconomy.buildOverview(panel)
    local p = panel.player
    if not p then
        return 8
    end

    local x = panel.contentX or IKST_JobLayout.MARGIN
    local w = math.max(220, panel.contentW or (panel.width - 24))
    local y = 8
    local gap = IKST_JobLayout.GAP or IKST_UI_Layout.s(12)
    local padX = IKST_UI_Layout.s(14)
    local headerBtnH = math.max(24, IKST_UI_Layout.s(28))
    local cc = IKST_Chrome.colors

    if not panel._economySnapRequested then
        panel._economySnapRequested = true
        if IKST_EconomyUI and IKST_EconomyUI.requestSnapshot then
            IKST_EconomyUI.requestSnapshot(p, math.floor(p:getX()), math.floor(p:getY()), p:getZ())
        end
    end

    local title = IKST.text("IGUI_IKST_WS_Economy", "Economy")
    local titleLabel = ISLabel:new(x, y, 26, title, 1, 1, 1, 1, UIFont.Large, true)
    titleLabel:initialise()
    panel:addJobWidget(titleLabel)

    local transferLabel = IKST.text("IGUI_IKST_EconomyTile_NewTransfer", "New transfer")
    local transferW = IKST_UI_Layout.buttonWidth(transferLabel, UIFont.Small, 100)
    local autoLabel = IKST.text("IGUI_IKST_EconomyTile_AutoAccept", "Auto-accept transfers")
    local autoW = IKST_UI_Layout.buttonWidth(autoLabel, UIFont.Small, 140)
    local rightEdge = x + w
    local transferX = rightEdge - transferW
    local autoX = transferX - IKST_UI_Layout.s(8) - autoW

    local snap = IKST_EconomyUI._snap or {}
    local autoOn = snap.autoAccept ~= false
    local autoBtn = IKST_Chrome.newActionButton(autoX, y, autoW, headerBtnH, autoLabel, panel, function()
        IKST.dispatchCommand(p, IKST.CMD.economySetPref, { autoAccept = not autoOn })
    end, autoOn and "primary" or "chip")
    panel:addJobWidget(autoBtn)

    local transferBtn = IKST_Chrome.newActionButton(transferX, y, transferW, headerBtnH, transferLabel, panel, function()
        openWallet(panel)
    end, "outline")
    panel:addJobWidget(transferBtn)

    y = y + math.max(26, headerBtnH) + gap

    -- BALANCE
    local cash, bank, pending = 0, 0, 0
    if IKST_EconomyUI and IKST_EconomyUI.getBalances then
        cash, bank, pending = IKST_EconomyUI.getBalances(p)
    end
    local total = (tonumber(cash) or 0) + (tonumber(bank) or 0)
    local balH = IKST_Chrome.sectionHeaderH() + IKST_UI_Layout.s(64) + IKST_UI_Layout.s(14)
    local balCard, balY = IKST_Chrome.newSectionCardPanel(x, y, w, balH,
        "media/ui/ikst/ws_economy.png",
        IKST.text("IGUI_IKST_EconomyTile_SectionBalance", "Balance"))
    panel:addJobWidget(balCard)
    local youLbl = ISLabel:new(padX, balY + 4, 16,
        IKST.text("IGUI_IKST_Economy_Balance", "Your balance"),
        cc.textMuted.r, cc.textMuted.g, cc.textMuted.b, 1, UIFont.Small, true)
    youLbl:initialise()
    balCard:addChild(youLbl)
    local amtText = IKST_Economy.formatAmount(total)
    local amtLbl = ISLabel:new(padX, balY + 22, 22, amtText,
        cc.textPrimary.r, cc.textPrimary.g, cc.textPrimary.b, 1, UIFont.Medium, true)
    amtLbl:initialise()
    balCard:addChild(amtLbl)
    local detail = IKST.text("IGUI_IKST_Economy_Cash", "Cash") .. " " .. IKST_Economy.formatAmount(cash)
        .. "  ·  " .. IKST.text("IGUI_IKST_Economy_Bank", "Bank") .. " " .. IKST_Economy.formatAmount(bank)
    if pending and pending > 0 then
        detail = detail .. "  ·  " .. IKST.text("IGUI_IKST_Economy_Pending", "pending") .. " " .. IKST_Economy.formatAmount(pending)
    end
    local detLbl = ISLabel:new(padX, balY + 44, 14, detail,
        cc.accent.r, cc.accent.g, cc.accent.b, 1, UIFont.Small, true)
    detLbl:initialise()
    balCard:addChild(detLbl)
    y = y + balH + gap

    -- QUICK ACTIONS
    local quick = {
        {
            label = IKST.text("IGUI_IKST_EconomyTile_Deposit", "Deposit"),
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
            label = IKST.text("IGUI_IKST_EconomyTile_Transfer", "Transfer to player"),
            primary = true,
            onClick = function()
                openWallet(panel)
            end,
        },
        {
            label = IKST.text("IGUI_IKST_EconomyTile_RequestPay", "Request payment"),
            onClick = function()
                IKST_JobEconomy.openPayRequest(p)
            end,
        },
        {
            label = IKST.text("IGUI_IKST_EconomyTile_History", "Transaction history"),
            onClick = function()
                if IKST_EconomyUI and type(IKST_EconomyUI.requestSnapshot) == "function" then
                    IKST_EconomyUI.requestSnapshot(p, math.floor(p:getX()), math.floor(p:getY()), p:getZ())
                end
            end,
        },
    }
    y = economyPillSection(panel, x, y, w, "media/ui/ikst/tool_self.png",
        "IGUI_IKST_EconomyTile_SectionQuick", "Quick actions", quick)

    local payReq = snap.payReq
    if type(payReq) == "table" and tonumber(payReq.amount) then
        local reqItems = {
            {
                label = IKST.text("IGUI_IKST_Economy_PayAccept", "Pay")
                    .. " " .. IKST_Economy.formatAmount(payReq.amount)
                    .. " (" .. tostring(payReq.fromName or "?") .. ")",
                primary = true,
                onClick = function()
                    IKST.dispatchCommand(p, IKST.CMD.economyPayRespond, { accept = true })
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Economy_PayDecline", "Decline request"),
                onClick = function()
                    IKST.dispatchCommand(p, IKST.CMD.economyPayRespond, { accept = false })
                end,
            },
        }
        y = economyPillSection(panel, x, y, w, "media/ui/ikst/tool_self.png",
            "IGUI_IKST_EconomyTile_SectionPayReq", "Payment request", reqItems)
    end

    local hist = snap.history
    if type(hist) ~= "table" then
        hist = {}
    end
    local histLines = math.max(1, math.min(#hist, 6))
    local histH = IKST_Chrome.sectionHeaderH() + (histLines * 16) + IKST_UI_Layout.s(18)
    local histCard, histY = IKST_Chrome.newSectionCardPanel(x, y, w, histH,
        "media/ui/ikst/tool_servertools.png",
        IKST.text("IGUI_IKST_EconomyTile_History", "Transaction history"))
    panel:addJobWidget(histCard)
    if #hist == 0 then
        local emptyH = ISLabel:new(padX, histY + 4, 16,
            IKST.text("IGUI_IKST_Economy_HistoryEmpty", "No player transfers yet."),
            cc.textMuted.r, cc.textMuted.g, cc.textMuted.b, 1, UIFont.Small, true)
        emptyH:initialise()
        histCard:addChild(emptyH)
    else
        local hy = histY
        local maxShow = math.min(#hist, 6)
        for i = 1, maxShow do
            local line = tostring(hist[i] or "")
            local hl = ISLabel:new(padX, hy, 16, line,
                cc.textPrimary.r, cc.textPrimary.g, cc.textPrimary.b, 1, UIFont.Small, true)
            hl:initialise()
            histCard:addChild(hl)
            hy = hy + 16
        end
    end
    y = y + histH + gap

    -- MY SHOPS
    local shopRows = {}
    if panel.economyVendX then
        shopRows[#shopRows + 1] = {
            title = IKST.text("IGUI_IKST_Economy_ShopAt", "Shop at")
                .. " " .. tostring(panel.economyVendX) .. "," .. tostring(panel.economyVendY),
            sub = IKST.text("IGUI_IKST_EconomyTile_ShopOpen", "OPEN"),
            manage = true,
        }
    else
        local shopObj, sx, sy, sz = nil, nil, nil, nil
        if IKST_EconomyContext and IKST_EconomyContext.shopObjectAtPlayer then
            shopObj, sx, sy, sz = IKST_EconomyContext.shopObjectAtPlayer(p)
        end
        if shopObj and IKST_EconomyContext.canClaimShop and IKST_EconomyContext.canClaimShop(shopObj) then
            shopRows[#shopRows + 1] = {
                title = IKST.text("IGUI_IKST_Economy_ClaimShop", "Open my shop here"),
                sub = tostring(sx) .. ", " .. tostring(sy),
                claim = true,
                sx = sx, sy = sy, sz = sz,
            }
        elseif shopObj and IKST_EconomyContext.isShopOwner and IKST_EconomyContext.isShopOwner(p, shopObj) then
            panel.economyVendX = sx
            panel.economyVendY = sy
            panel.economyVendZ = sz
            shopRows[#shopRows + 1] = {
                title = IKST.text("IGUI_IKST_Economy_ShopAt", "Shop at")
                    .. " " .. tostring(sx) .. "," .. tostring(sy),
                sub = IKST.text("IGUI_IKST_EconomyTile_ShopOpen", "OPEN"),
                manage = true,
            }
        end
    end

    local shopListH = math.max(1, #shopRows)
    local shopRowH = math.max(40, IKST_UI_Layout.s(44))
    local shopCardH = IKST_Chrome.sectionHeaderH()
        + (shopListH * (shopRowH + IKST_UI_Layout.s(6))) - IKST_UI_Layout.s(6)
        + IKST_UI_Layout.s(14)
    local shopCard, shopY = IKST_Chrome.newSectionCardPanel(x, y, w, shopCardH,
        "media/ui/ikst/shop_terminal.png",
        IKST.text("IGUI_IKST_EconomyTile_SectionShops", "My shops"))
    panel:addJobWidget(shopCard)
    if #shopRows == 0 then
        local empty = ISLabel:new(padX, shopY + 8, 16,
            IKST.text("IGUI_IKST_Economy_ShopPick", "Stand at your shop terminal or right-click it > Manage shop prices."),
            cc.textMuted.r, cc.textMuted.g, cc.textMuted.b, 1, UIFont.Small, true)
        empty:initialise()
        shopCard:addChild(empty)
    else
        local ry = shopY
        local manageLabel = IKST.text("IGUI_IKST_EconomyTile_Manage", "Manage")
        local manageW = IKST_UI_Layout.buttonWidth(manageLabel, UIFont.Small, 72)
        local btnH = math.max(24, IKST_UI_Layout.s(28))
        for _, row in ipairs(shopRows) do
            local nameLbl = ISLabel:new(padX, ry + 4, 16, row.title,
                cc.textPrimary.r, cc.textPrimary.g, cc.textPrimary.b, 1, UIFont.Small, true)
            nameLbl:initialise()
            shopCard:addChild(nameLbl)
            local subLbl = ISLabel:new(padX, ry + 20, 14, row.sub,
                cc.textMuted.r, cc.textMuted.g, cc.textMuted.b, 1, UIFont.Small, true)
            subLbl:initialise()
            shopCard:addChild(subLbl)
            economyBtn(shopCard, panel, w - padX - manageW, ry + math.floor((shopRowH - btnH) / 2),
                manageW, btnH, manageLabel, "chip", function()
                    local state = IKST.getPlayerState(p)
                    if row.claim and IKST_EconomyContext and IKST_EconomyContext.claimShop then
                        IKST_EconomyContext.claimShop(p, row.sx, row.sy, row.sz)
                        panel.economyVendX = row.sx
                        panel.economyVendY = row.sy
                        panel.economyVendZ = row.sz
                    end
                    if state then
                        state.economyMode = "shop"
                    end
                    IKST_JobEconomy.requestVendList(panel)
                end)
            ry = ry + shopRowH + IKST_UI_Layout.s(6)
        end
    end
    y = y + shopCardH + gap

    -- BOUNTIES
    local bountyOn = IKST_Economy.zombieBountyEnabled and IKST_Economy.zombieBountyEnabled()
    local bountyLabel = IKST.text("IGUI_IKST_EconomyTile_ZombieBounty", "Zombie bounty")
    if bountyOn and IKST_Economy.zombieBountyMin and IKST_Economy.zombieBountyMax then
        bountyLabel = bountyLabel .. " ("
            .. tostring(IKST_Economy.zombieBountyMin()) .. "-"
            .. tostring(IKST_Economy.zombieBountyMax()) .. ")"
    end
    local bounties = {
        {
            label = bountyLabel,
            on = bountyOn == true,
            onClick = function()
                if bountyOn then
                    IKST.notify(p, IKST.text("IGUI_IKST_Economy_BountyNote", "Zombie kill bounty is on (sandbox)."), true)
                else
                    IKST.notify(p, IKST.text("IGUI_IKST_EconomyTile_BountyOff", "Zombie bounty is off (sandbox)."), false)
                end
            end,
        },
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
    }
    y = economyPillSection(panel, x, y, w, "media/ui/ikst/tool_catch.png",
        "IGUI_IKST_EconomyTile_SectionBounties", "Bounties", bounties)

    -- Deep tabs (existing Money/Shop/Valuables/Admin builders)
    y = IKST_JobEconomy.buildModeRow(panel, y)
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
        return y
    end
    local mode = IKST_JobEconomy.ensureMode(panel)
    if mode == "money" then
        return IKST_JobEconomy.buildOverview(panel)
    end
    y = IKST_JobEconomy.buildModeRow(panel, y)
    if mode == "shop" then
        y = IKST_JobEconomy.buildShop(panel, y)
    elseif mode == "valuables" then
        y = IKST_JobEconomy.buildValuables(panel, y)
    elseif mode == "admin" then
        y = IKST_JobEconomy.buildAdmin(panel, y)
    end
    return y
end
