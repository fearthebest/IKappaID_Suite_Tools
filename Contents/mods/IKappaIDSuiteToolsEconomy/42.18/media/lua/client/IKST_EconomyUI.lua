if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "ISUI/ISTextEntryBox"
require "ISUI/ISComboBox"
require "ISUI/ISPanel"
require "ISUI/ISScrollingListBox"
require "IKST_Shared"
require "IKST_Economy"
require "IKST_EconomyBridge"
require "IKST_Identity"
require "IKST_Access"
require "IKST_Chrome"
require "IKST_EconomyIcons"

IKST_EconomyUI = IKST_EconomyUI or {}
IKST_EconomyUI.Window = nil
IKST_EconomyUI.VendWindow = nil
IKST_EconomyUI._snap = { cash = 0, bank = 0, pending = 0 }
IKST_EconomyUI._texCache = {}

local WIN_W, WIN_H = 440, 580
local MIN_W, MIN_H = 400, 480
local MARGIN = 12
local ROW_H = 28
local FOOTER_BTN_H = 26
local FOOTER_STATUS_H = 40
local ICON_SZ = 22
local ICON_GAP = 6

local ATM_ICON_CANDIDATES = { "Base.CreditCard", "Base.MoneyBundle", "Base.ElectronicsScrap" }
local SHOP_ICON_CANDIDATES = { "IKST.ShopTerminalKit", "Base.Pop", "Base.Wood_Crate_Lvl1" }

local function resolveItemType(itemType)
    if not itemType or itemType == "" then
        return nil
    end
    if string.find(itemType, "%.") then
        return itemType
    end
    return "Base." .. itemType
end

function IKST_EconomyUI.cashItemType()
    if PhoneShopConfig and PhoneShopConfig.CurrencyItem then
        return resolveItemType(PhoneShopConfig.CurrencyItem)
    end
    return "Base.Money"
end

function IKST_EconomyUI.bankItemType()
    if PhoneShopConfig and PhoneShopConfig.BundleItem then
        return resolveItemType(PhoneShopConfig.BundleItem)
    end
    return "Base.MoneyBundle"
end

function IKST_EconomyUI.phoneItemType()
    local phone = PhoneShopConfig and PhoneShopConfig.PhoneItem or "CordlessPhone"
    return resolveItemType(phone)
end

function IKST_EconomyUI.firstItemTypeWithIcon(candidates, fallback)
    for _, itemType in ipairs(candidates) do
        if IKST_EconomyUI.itemTexture(itemType) then
            return itemType
        end
    end
    return fallback
end

function IKST_EconomyUI.atmItemType()
    if not IKST_EconomyUI._atmItemType then
        IKST_EconomyUI._atmItemType = IKST_EconomyUI.firstItemTypeWithIcon(ATM_ICON_CANDIDATES, IKST_EconomyUI.bankItemType())
    end
    return IKST_EconomyUI._atmItemType
end

function IKST_EconomyUI.shopItemType()
    if not IKST_EconomyUI._shopItemType then
        if IKST_EconomyIcons and IKST_EconomyIcons.SHOP_KIT_TYPE then
            IKST_EconomyUI._shopItemType = IKST_EconomyIcons.SHOP_KIT_TYPE
        else
            IKST_EconomyUI._shopItemType = IKST_EconomyUI.firstItemTypeWithIcon(SHOP_ICON_CANDIDATES, "IKST.ShopTerminalKit")
        end
    end
    return IKST_EconomyUI._shopItemType
end

function IKST_EconomyUI.shopTexture()
    if IKST_EconomyIcons and IKST_EconomyIcons.shopTexture then
        local tex = IKST_EconomyIcons.shopTexture()
        if tex then
            return tex
        end
    end
    return IKST_EconomyUI.itemTexture(IKST_EconomyUI.shopItemType())
end

function IKST_EconomyUI.isShopIconType(itemType)
    if not itemType then
        return false
    end
    return itemType == IKST_EconomyUI.shopItemType()
        or itemType == "IKST.ShopTerminalKit"
        or itemType == "ShopTerminalKit"
end

function IKST_EconomyUI.itemTexture(itemType)
    itemType = resolveItemType(itemType)
    if not itemType then
        return nil
    end
    if IKST_EconomyUI._texCache[itemType] ~= nil then
        local cached = IKST_EconomyUI._texCache[itemType]
        if cached == false then
            return nil
        end
        return cached
    end
    local tex = nil
    if getScriptManager then
        local script = getScriptManager():FindItem(itemType)
        if script and script.getIcon then
            local icon = script:getIcon()
            if icon and icon ~= "" and getTexture then
                tex = getTexture("media/textures/Item_" .. icon .. ".png")
                if not tex then
                    tex = getTexture("Item_" .. icon)
                end
            end
        end
        if not tex and script and script.getNormalTexture then
            tex = script:getNormalTexture()
        end
    end
    if not tex and instanceItem and getScriptManager then
        local script = getScriptManager():FindItem(itemType)
        local item = script and instanceItem(itemType) or nil
        if item then
            if item.getTex then
                tex = item:getTex()
            elseif item.getTexture then
                tex = item:getTexture()
            end
        end
    end
    IKST_EconomyUI._texCache[itemType] = tex or false
    return tex
end

function IKST_EconomyUI.drawIcon(panel, x, y, itemType, size)
    size = size or ICON_SZ
    local tex = nil
    if IKST_EconomyUI.isShopIconType(itemType) then
        tex = IKST_EconomyUI.shopTexture()
    end
    if not tex then
        tex = IKST_EconomyUI.itemTexture(itemType)
    end
    if tex then
        panel:drawTextureScaled(tex, x, y, size, size, 1, 1, 1, 1)
        return true
    end
    panel:drawRect(x, y, size, size, 0.45, 0.2, 0.2, 0.25)
    return false
end

function IKST_EconomyUI.drawIconText(panel, x, y, itemType, text, font, r, g, b, a, iconSz)
    iconSz = iconSz or ICON_SZ
    IKST_EconomyUI.drawIcon(panel, x, y, itemType, iconSz)
    local ty = y + math.max(0, math.floor((iconSz - 12) / 2))
    panel:drawText(text, x + iconSz + ICON_GAP, ty, r, g, b, a or 1, font or UIFont.Small)
end

function IKST_EconomyUI.addJobIconLabel(panel, x, y, itemType, text, font, tall, muted)
    if not panel or not panel.addJobWidget then
        return nil
    end
    tall = tall or 24
    local w = IKST_JobLayout and IKST_JobLayout.clampWidth(panel, x, panel.contentW or (panel.width - 24))
        or (panel.contentW or (panel.width - 24))
    local label = ISPanel:new(x, y, w, tall)
    label.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    label.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    label:initialise()
    local labelText = text
    local labelFont = font or UIFont.Small
    label.render = function(p)
        ISPanel.render(p)
        local cc = IKST_Chrome.colors
        local tr, tg, tb = cc.textPrimary.r, cc.textPrimary.g, cc.textPrimary.b
        if muted then
            tr, tg, tb = cc.textMuted.r, cc.textMuted.g, cc.textMuted.b
        end
        IKST_EconomyUI.drawIconText(p, 0, 2, itemType, labelText, labelFont, tr, tg, tb, 1, math.min(20, tall - 4))
    end
    return panel:addJobWidget(label)
end

function IKST_EconomyUI.applyIconButton(btn, itemType, label)
    if not btn then
        return
    end
    btn:setTitle("")
    local btnLabel = label
    local iconType = itemType
    btn.render = function(b)
        ISButton.render(b)
        if b.enable and b:isMouseOver() then
            b:drawRect(0, 0, b.width, b.height, 0.12, 1, 1, 1)
        end
        local tr, tg, tb = 0.95, 0.95, 0.95
        if not b.enable then
            tr, tg, tb = 0.55, 0.55, 0.55
        end
        IKST_EconomyUI.drawIconText(b, 4, math.max(2, math.floor((b.height - 18) / 2)), iconType, btnLabel, UIFont.Small, tr, tg, tb, 1, 16)
    end
end
function IKST_EconomyUI.addJobIconButton(panel, x, y, w, h, itemType, label, onClick, primary)
    if not panel or not panel.addJobWidget then
        return nil
    end
    w = IKST_JobLayout and IKST_JobLayout.clampWidth(panel, x, w) or w
    local btn = ISButton:new(x, y, w, h, "", panel, onClick)
    btn:initialise()
    if primary then
        IKST_Chrome.stylePrimaryButton(btn)
    else
        IKST_Chrome.styleSecondaryButton(btn)
    end
    IKST_EconomyUI.applyIconButton(btn, itemType, label)
    return panel:addJobWidget(btn)
end

IKST_EconomyNote = ISPanel:derive("IKST_EconomyNote")

function IKST_EconomyNote:new(x, y, w, h, itemType)
    local o = ISPanel.new(self, x, y, w, h)
    o.backgroundColor = IKST_Chrome.colors.bgCard
    o.borderColor = IKST_Chrome.colors.accentDim
    o.itemType = itemType
    o.noteText = ""
    o.muted = false
    return o
end

function IKST_EconomyNote:setNote(text, itemType, muted)
    self.noteText = text or ""
    if itemType then
        self.itemType = itemType
    end
    self.muted = muted == true
end

function IKST_EconomyNote:render()
    ISPanel.render(self)
    local cc = IKST_Chrome.colors
    local tr, tg, tb = cc.textPrimary.r, cc.textPrimary.g, cc.textPrimary.b
    if self.muted then
        tr, tg, tb = cc.textMuted.r, cc.textMuted.g, cc.textMuted.b
    end
    IKST_EconomyUI.drawIconText(self, 6, math.floor((self.height - 18) / 2), self.itemType, self.noteText, UIFont.Small, tr, tg, tb, 1, 18)
end

function IKST_EconomyUI.countOwned(player, itemType)
    if IKST_Economy and IKST_Economy.countPlayerItems then
        return IKST_Economy.countPlayerItems(player, itemType)
    end
    return 0
end

local function valuableItemExists(itemType)
    if not ScriptManager or not ScriptManager.instance or not ScriptManager.instance.FindItem then
        return true
    end
    return ScriptManager.instance:FindItem(itemType) ~= nil
end

function IKST_EconomyUI.buildValuableRows(player)
    local rows = {}
    local data = IKST_Economy.loadValuables()
    for _, entry in ipairs(data.list) do
        if valuableItemExists(entry.itemType) then
            local count = IKST_EconomyUI.countOwned(player, entry.itemType)
            rows[#rows + 1] = {
                itemType = entry.itemType,
                label = entry.label or entry.itemType,
                price = entry.price,
                count = count,
                priceLabel = IKST_Economy.formatAmount(entry.price) .. " each",
            }
        end
    end
    table.sort(rows, function(a, b)
        if (a.count or 0) > 0 and (b.count or 0) <= 0 then
            return true
        end
        if (a.count or 0) <= 0 and (b.count or 0) > 0 then
            return false
        end
        return (a.label or "") < (b.label or "")
    end)
    return rows
end

function IKST_EconomyUI.formatValuableListLine(row)
    if not row then
        return ""
    end
    local owned = tonumber(row.count) or 0
    local prefix = owned > 0 and "" or "— "
    return prefix .. tostring(row.label or "?") .. "  x" .. tostring(owned) .. "   " .. tostring(row.priceLabel or "")
end

function IKST_EconomyUI.nearbyPlayers(player, maxDist)
    player = IKST.resolvePlayer(player)
    maxDist = tonumber(maxDist) or IKST_Economy.wireMaxDistance()
    local out = {}
    if not player then
        return out
    end
    local list = getOnlinePlayers and getOnlinePlayers()
    if not list or not list.size then
        return out
    end
    local px, py = player:getX(), player:getY()
    for i = 0, list:size() - 1 do
        local p = list:get(i)
        if p and p ~= player and p.getUsername then
            local dx = p:getX() - px
            local dy = p:getY() - py
            if (dx * dx + dy * dy) <= (maxDist * maxDist) then
                out[#out + 1] = {
                    id = p.getOnlineID and p:getOnlineID() or i,
                    name = p:getUsername(),
                }
            end
        end
    end
    return out
end

function IKST_EconomyUI.getBalances(player)
    local snap = IKST_EconomyUI._snap or {}
    local cash = snap.cash
    if cash == nil then
        cash = IKST_EconomyBridge.getCash(player)
    end
    return tonumber(cash) or 0, tonumber(snap.bank) or 0, tonumber(snap.pending) or 0
end

function IKST_EconomyUI.formatShopRow(entry)
    if not entry then
        return ""
    end
    local count = tonumber(entry.count) or 1
    local qty = count > 1 and ("  ×" .. tostring(count)) or ""
    local price = tonumber(entry.price) or 0
    if price > 0 then
        return entry.label .. qty .. "   " .. IKST_Economy.formatAmount(price) .. " " .. IKST.text("IGUI_IKST_Economy_Each", "each")
    end
    return entry.label .. qty .. "   " .. IKST.text("IGUI_IKST_Economy_NoPrice", "no price")
end

function IKST_EconomyUI.requestSnapshot(player, atmX, atmY, atmZ)
    IKST.dispatchCommand(player, IKST.CMD.economySnapshot, {
        x = atmX, y = atmY, z = atmZ,
    })
end

IKST_EconomyPanel = ISCollapsableWindow:derive("IKST_EconomyPanel")

function IKST_EconomyPanel:new(x, y, w, h)
    local o = ISCollapsableWindow.new(self, x, y, w, h)
    o.title = IKST.text("IGUI_IKST_Economy_Title", "Economy")
    o.resizable = true
    o.minimumWidth = MIN_W
    o.minimumHeight = MIN_H
    o.player = nil
    o.atmX, o.atmY, o.atmZ = 0, 0, 0
    o.statusText = ""
    IKST_Chrome.applyPanelColors(o)
    return o
end

function IKST_EconomyPanel:initialise()
    ISCollapsableWindow.initialise(self)
    if self.setResizable then
        self:setResizable(true)
    end
    self:buildUI()
end

function IKST_EconomyPanel:selectedValuableRow()
    local list = self.valList
    if not list or list.selected == nil or list.selected < 0 then
        return nil
    end
    local entry = list.items and list.items[list.selected + 1]
    if entry and entry.item then
        return entry.item
    end
    return nil
end

function IKST_EconomyPanel:relayout()
    if not self.balancePanel then
        return
    end
    local w = self.width
    local innerW = w - MARGIN * 2
    local rightBtnX = w - MARGIN - 80
    local y = 34

    self.balancePanel:setX(MARGIN)
    self.balancePanel:setY(y)
    self.balancePanel:setWidth(innerW)
    self.balancePanel:setHeight(58)
    y = y + 64

    self.btnRefresh:setX(rightBtnX)
    self.btnRefresh:setY(y)
    self.atmNote:setX(MARGIN)
    self.atmNote:setY(y)
    self.atmNote:setWidth(math.max(120, rightBtnX - MARGIN - 8))
    self.atmNote:setHeight(24)
    y = y + 30

    self.amountIcon:setX(MARGIN)
    self.amountIcon:setY(y)
    self.amountEntry:setX(MARGIN + 28)
    self.amountEntry:setY(y)
    self.btnDeposit:setX(MARGIN + 88)
    self.btnDeposit:setY(y)
    self.btnWithdraw:setX(MARGIN + 182)
    self.btnWithdraw:setY(y)
    y = y + 30

    self.lblWire:setX(MARGIN)
    self.lblWire:setY(y)
    self.lblWire:setWidth(innerW)
    y = y + 24

    self.wireCombo:setX(MARGIN)
    self.wireCombo:setY(y)
    self.wireCombo:setWidth(math.max(120, innerW - 96))
    self.btnWire:setX(rightBtnX)
    self.btnWire:setY(y)
    y = y + 34

    self.lblVal:setX(MARGIN)
    self.lblVal:setY(y)
    self.lblVal:setWidth(innerW)
    y = y + 24

    self._listTopY = y
    local footerH = FOOTER_BTN_H + 8 + FOOTER_STATUS_H + MARGIN
    local listH = math.max(96, self.height - y - footerH)
    self.valList:setX(MARGIN)
    self.valList:setY(y)
    self.valList:setWidth(innerW)
    self.valList:setHeight(listH)
    y = y + listH + 8

    self.btnSell:setX(MARGIN)
    self.btnSell:setY(y)
    self.btnSell:setWidth(100)
    self.btnSellAll:setX(MARGIN + 106)
    self.btnSellAll:setY(y)
    self.btnSellAll:setWidth(120)
    local replaceW = math.min(150, math.max(110, innerW - 232))
    self.btnReplaceId:setX(MARGIN + 232)
    self.btnReplaceId:setY(y)
    self.btnReplaceId:setWidth(replaceW)
    y = y + FOOTER_BTN_H + 8

    self.statusPanel:setX(MARGIN)
    self.statusPanel:setY(math.max(y, self.height - FOOTER_STATUS_H - MARGIN))
    self.statusPanel:setWidth(innerW)
    self.statusPanel:setHeight(FOOTER_STATUS_H)
end

function IKST_EconomyPanel:onResize()
    ISCollapsableWindow.onResize(self)
    self:relayout()
end

function IKST_EconomyPanel:buildUI()
    local y = 34

    self.balancePanel = ISPanel:new(12, y, self.width - 24, 58)
    self.balancePanel.backgroundColor = IKST_Chrome.colors.bgCard
    self.balancePanel.borderColor = IKST_Chrome.colors.accentDim
    self.balancePanel:initialise()
    local owner = self
    self.balancePanel.render = function(p)
        ISPanel.render(p)
        local player = owner.player
        local cash, bank, pending = IKST_EconomyUI.getBalances(player)
        local cc = IKST_Chrome.colors
        local cashLine = IKST.text("IGUI_IKST_Economy_Cash", "Cash") .. ": " .. IKST_Economy.formatAmount(cash)
        local bankLine = IKST.text("IGUI_IKST_Economy_Bank", "Bank") .. ": " .. IKST_Economy.formatAmount(bank)
        IKST_EconomyUI.drawIconText(p, 8, 6, IKST_EconomyUI.cashItemType(), cashLine, UIFont.Medium, cc.accent.r, cc.accent.g, cc.accent.b, 1, 22)
        IKST_EconomyUI.drawIconText(p, 8, 32, IKST_EconomyUI.bankItemType(), bankLine, UIFont.Medium, cc.textPrimary.r, cc.textPrimary.g, cc.textPrimary.b, 1, 22)
        if pending > 0 then
            local pendingLine = "(" .. IKST.text("IGUI_IKST_Economy_Pending", "pending") .. " " .. IKST_Economy.formatAmount(pending) .. ")"
            p:drawText(pendingLine, p.width - 148, 36, cc.textMuted.r, cc.textMuted.g, cc.textMuted.b, 1, UIFont.Small)
        end
    end
    self:addChild(self.balancePanel)
    y = y + 64

    self.btnRefresh = ISButton:new(self.width - 92, y, 80, 22, IKST.text("IGUI_IKST_Economy_Refresh", "Refresh"), self, IKST_EconomyPanel.onRefresh)
    self.btnRefresh:initialise()
    IKST_Chrome.styleSecondaryButton(self.btnRefresh)
    self:addChild(self.btnRefresh)

    self.atmNote = IKST_EconomyNote:new(12, y, self.width - 112, 24, IKST_EconomyUI.atmItemType())
    self.atmNote:initialise()
    self:addChild(self.atmNote)
    y = y + 30

    self.amountIcon = ISPanel:new(12, y, 24, 22)
    self.amountIcon.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    self.amountIcon.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    self.amountIcon:initialise()
    self.amountIcon.render = function(p)
        ISPanel.render(p)
        IKST_EconomyUI.drawIcon(p, 2, 1, IKST_EconomyUI.cashItemType(), 20)
    end
    self:addChild(self.amountIcon)

    self.amountEntry = ISTextEntryBox:new("100", 40, y, 52, 22)
    self.amountEntry:initialise()
    self.amountEntry:instantiate()
    self:addChild(self.amountEntry)

    self.btnDeposit = ISButton:new(100, y, 88, 22, "", self, IKST_EconomyPanel.onDeposit)
    self.btnDeposit:initialise()
    IKST_Chrome.styleSecondaryButton(self.btnDeposit)
    IKST_EconomyUI.applyIconButton(self.btnDeposit, IKST_EconomyUI.bankItemType(), IKST.text("IGUI_IKST_Economy_Deposit", "Deposit"))
    self:addChild(self.btnDeposit)

    self.btnWithdraw = ISButton:new(194, y, 88, 22, "", self, IKST_EconomyPanel.onWithdraw)
    self.btnWithdraw:initialise()
    IKST_Chrome.styleSecondaryButton(self.btnWithdraw)
    IKST_EconomyUI.applyIconButton(self.btnWithdraw, IKST_EconomyUI.cashItemType(), IKST.text("IGUI_IKST_Economy_Withdraw", "Withdraw"))
    self:addChild(self.btnWithdraw)
    y = y + 30

    self.lblWire = IKST_EconomyNote:new(12, y, self.width - 24, 22, IKST_EconomyUI.cashItemType())
    self.lblWire.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    self.lblWire.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    self.lblWire:setNote(IKST.text("IGUI_IKST_Economy_WireHelp", "Wire — send physical cash to a nearby player (within range)."))
    self.lblWire:initialise()
    self:addChild(self.lblWire)
    y = y + 24

    self.wireCombo = ISComboBox:new(12, y, self.width - 110, 22)
    self.wireCombo:initialise()
    self:addChild(self.wireCombo)

    self.btnWire = ISButton:new(self.width - 92, y, 80, 22, "", self, IKST_EconomyPanel.onWire)
    self.btnWire:initialise()
    IKST_Chrome.stylePrimaryButton(self.btnWire)
    IKST_EconomyUI.applyIconButton(self.btnWire, IKST_EconomyUI.cashItemType(), IKST.text("IGUI_IKST_Economy_WireBtn", "Wire"))
    self:addChild(self.btnWire)
    y = y + 34

    self.lblVal = IKST_EconomyNote:new(12, y, self.width - 24, 22, IKST_EconomyUI.atmItemType())
    self.lblVal.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    self.lblVal.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    self.lblVal:setNote(IKST.text("IGUI_IKST_Economy_ValuableHelp", "Exchange — sell junk for cash (at ATM when required)."))
    self.lblVal:initialise()
    self:addChild(self.lblVal)
    y = y + 24

    self.valList = ISScrollingListBox:new(MARGIN, y, self.width - MARGIN * 2, 120)
    self.valList:initialise()
    self.valList:instantiate()
    self.valList.itemheight = ROW_H
    self.valList.font = UIFont.Small
    self.valList.drawBorder = true
    self.valList.backgroundColor = IKST_Chrome.colors.bgCard
    self.valList.borderColor = IKST_Chrome.colors.accentDim
    self:addChild(self.valList)

    self.btnSell = ISButton:new(MARGIN, y, 100, FOOTER_BTN_H, "", self, IKST_EconomyPanel.onExchange)
    self.btnSell:initialise()
    IKST_Chrome.styleSecondaryButton(self.btnSell)
    IKST_EconomyUI.applyIconButton(self.btnSell, IKST_EconomyUI.cashItemType(), IKST.text("IGUI_IKST_Economy_Exchange", "Sell 1"))
    self:addChild(self.btnSell)

    self.btnSellAll = ISButton:new(MARGIN + 106, y, 120, FOOTER_BTN_H, "", self, IKST_EconomyPanel.onExchangeAll)
    self.btnSellAll:initialise()
    IKST_Chrome.stylePrimaryButton(self.btnSellAll)
    IKST_EconomyUI.applyIconButton(self.btnSellAll, IKST_EconomyUI.cashItemType(), IKST.text("IGUI_IKST_Economy_SellAll", "Sell all"))
    self:addChild(self.btnSellAll)

    self.btnReplaceId = ISButton:new(MARGIN + 232, y, 130, FOOTER_BTN_H, "", self, IKST_EconomyPanel.onReplaceIdCard)
    self.btnReplaceId:initialise()
    IKST_Chrome.styleSecondaryButton(self.btnReplaceId)
    IKST_EconomyUI.applyIconButton(self.btnReplaceId, "Base.IDcard", IKST.text("IGUI_IKST_Economy_ReplaceId", "Replace bank ID"))
    self:addChild(self.btnReplaceId)

    self.statusPanel = ISPanel:new(MARGIN, y, self.width - MARGIN * 2, FOOTER_STATUS_H)
    self.statusPanel.backgroundColor = IKST_Chrome.colors.bgCard
    self.statusPanel.borderColor = IKST_Chrome.colors.accentDim
    self.statusPanel:initialise()
    local statusOwner = self
    self.statusPanel.render = function(p)
        ISPanel.render(p)
        local msg = statusOwner.statusText or ""
        if msg == "" then
            return
        end
        local cc = IKST_Chrome.colors
        p:drawText(msg, 6, 4, cc.textMuted.r, cc.textMuted.g, cc.textMuted.b, 1, UIFont.Small)
    end
    self:addChild(self.statusPanel)

    self:relayout()
    self:refreshAll()
end

function IKST_EconomyPanel:readAmount()
    local t = self.amountEntry and self.amountEntry:getText() or "0"
    return IKST.parseAmount(t)
end

function IKST_EconomyPanel:refreshAtmNote()
    local atAtm = IKST_Economy.isAtmSquare(self.atmX, self.atmY, self.atmZ)
    local note
    local muted = false
    if IKST_Economy.idCardBanking and IKST_Economy.idCardBanking() then
        if atAtm then
            note = IKST.text("IGUI_IKST_Economy_AtAtmIdCard", "ATM — exchange valuables and wire transfers (ID card required).")
        elseif IKST_Economy.atmRequiredForBank() then
            note = IKST.text("IGUI_IKST_Economy_NeedAtmIdCard", "Go to an ATM with your bank ID card.")
            muted = true
        else
            note = IKST.text("IGUI_IKST_Economy_IdCardBank", "Virtual bank — all credits are in your account.")
        end
    elseif atAtm then
        note = IKST.text("IGUI_IKST_Economy_AtAtm", "ATM — deposit, withdraw, and exchange enabled here.")
    elseif IKST_Economy.atmRequiredForBank() then
        note = IKST.text("IGUI_IKST_Economy_NeedAtm", "Go to an ATM for bank deposit, withdraw, and exchange.")
        muted = true
    else
        note = IKST.text("IGUI_IKST_Economy_AnywhereBank", "Bank services available here (ATM not required).")
    end
    if self.atmNote and self.atmNote.setNote then
        self.atmNote:setNote(note, IKST_EconomyUI.atmItemType(), muted)
    end
    local virtualBank = IKST_Economy.idCardBanking and IKST_Economy.idCardBanking()
    if self.btnDeposit then
        self.btnDeposit:setVisible(not virtualBank)
    end
    if self.btnWithdraw then
        self.btnWithdraw:setVisible(not virtualBank)
    end
    local showReplace = virtualBank
        and IKST_Economy.idCardPlayerReissue and IKST_Economy.idCardPlayerReissue()
        and atAtm
    if self.btnReplaceId then
        self.btnReplaceId:setVisible(showReplace == true)
        if showReplace then
            local remain = IKST_Economy.idCardReissueCooldownRemainMs and IKST_Economy.idCardReissueCooldownRemainMs(self.player)
            if remain and remain > 0 then
                local hours = math.ceil(remain / 3600000)
                self.btnReplaceId.enable = false
                self:setStatus(IKST.text("IGUI_IKST_Economy_ReplaceIdCooldown",
                    "Replace bank ID available in %1 hours."):gsub("%%1", tostring(hours)))
            else
                self.btnReplaceId.enable = true
            end
        end
    end
    self:relayout()
end

function IKST_EconomyPanel:refreshWireCombo()
    if not self.wireCombo then
        return
    end
    self.wireTargets = {}
    self.wireCombo:clear()
    local nearby = IKST_EconomyUI.nearbyPlayers(self.player)
    if #nearby == 0 then
        self.wireCombo:addOption(IKST.text("IGUI_IKST_Economy_NoPlayersNear", "No players nearby"))
    else
        for _, row in ipairs(nearby) do
            self.wireCombo:addOption(row.name)
            self.wireTargets[#self.wireTargets + 1] = row.id
        end
    end
end

function IKST_EconomyPanel:refreshValuables()
    if not self.valList then
        return
    end
    local rows = IKST_EconomyUI.buildValuableRows(self.player)
    self.valList:clear()
    for _, row in ipairs(rows) do
        self.valList:addItem(IKST_EconomyUI.formatValuableListLine(row), row)
    end
    if #rows == 0 then
        self.valList:addItem(IKST.text("IGUI_IKST_Economy_NoValuables", "No valuables configured."), nil)
    end
end

function IKST_EconomyPanel:refreshBalances()
    if self.balancePanel then
        -- trigger re-render
    end
    self:refreshAtmNote()
    self:refreshWireCombo()
    self:refreshValuables()
end

function IKST_EconomyPanel:refreshAll()
    self:refreshBalances()
    IKST_EconomyUI.requestSnapshot(self.player, self.atmX, self.atmY, self.atmZ)
end

function IKST_EconomyPanel:onRefresh()
    self:refreshAll()
    self:setStatus(IKST.text("IGUI_IKST_Economy_Refreshing", "Refreshing balances…"))
end

function IKST_EconomyPanel:setStatus(msg)
    self.statusText = tostring(msg or "")
end

function IKST_EconomyPanel:onDeposit()
    IKST.dispatchCommand(self.player, IKST.CMD.economyDeposit, {
        amount = self:readAmount(),
        x = self.atmX, y = self.atmY, z = self.atmZ,
    })
end

function IKST_EconomyPanel:onWithdraw()
    IKST.dispatchCommand(self.player, IKST.CMD.economyWithdraw, {
        amount = self:readAmount(),
        x = self.atmX, y = self.atmY, z = self.atmZ,
    })
end

function IKST_EconomyPanel:onReplaceIdCard()
    IKST.dispatchCommand(self.player, IKST.CMD.economyIdCardReissue, {
        x = self.atmX, y = self.atmY, z = self.atmZ,
    })
end

function IKST_EconomyPanel:onWire()
    local targetId = nil
    if self.wireCombo and self.wireTargets and self.wireCombo.selected then
        targetId = self.wireTargets[self.wireCombo.selected]
    end
    if not targetId then
        self:setStatus(IKST.text("IGUI_IKST_Economy_WireFail", "Pick a nearby player from the list."))
        return
    end
    IKST.dispatchCommand(self.player, IKST.CMD.economyWire, {
        target = targetId,
        amount = self:readAmount(),
    })
end

function IKST_EconomyPanel:onExchange()
    local row = self:selectedValuableRow()
    if not row or not row.itemType then
        self:setStatus(IKST.text("IGUI_IKST_Economy_PickValuable", "Select a valuable to sell."))
        return
    end
    if (row.count or 0) <= 0 then
        self:setStatus(IKST.text("IGUI_IKST_Economy_NoItem", "You do not have that item."))
        return
    end
    IKST.dispatchCommand(self.player, IKST.CMD.economyExchange, {
        itemType = row.itemType,
        x = self.atmX, y = self.atmY, z = self.atmZ,
    })
end

function IKST_EconomyPanel:onExchangeAll()
    IKST.dispatchCommand(self.player, IKST.CMD.economyExchangeAll, {
        x = self.atmX, y = self.atmY, z = self.atmZ,
    })
end

function IKST_EconomyUI.onSnapshot(args)
    if not args then
        return
    end
    IKST_EconomyUI._snap.cash = args.cash or args.cashBalance or 0
    IKST_EconomyUI._snap.bank = args.bank or 0
    IKST_EconomyUI._snap.pending = args.pending or 0
    local player = getPlayer()
    if player and IKST_Economy and IKST_Economy.cacheClientBalances then
        IKST_Economy.cacheClientBalances(player, IKST_EconomyUI._snap.bank, IKST_EconomyUI._snap.pending)
    end
    if IKST_EconomyUI.Window then
        IKST_EconomyUI.Window:refreshBalances()
        IKST_EconomyUI.Window:setStatus(IKST.text("IGUI_IKST_Economy_BalancesUpdated", "Balances updated."))
    end
    if IKST_JobsPanel and IKST_JobsPanel.instance then
        IKST_JobsPanel.instance:refreshJobUI()
    end
end

function IKST_EconomyUI.open(player, atmX, atmY, atmZ)
    if not IKST_Access.canUseEconomy(player) then
        IKST.notify(player, IKST.text("IGUI_IKST_Economy_Missing", "Install IKappaID PhoneShop for economy tools."), false)
        return
    end
    player = IKST.resolvePlayer(player)
    atmX = math.floor(tonumber(atmX) or player:getX())
    atmY = math.floor(tonumber(atmY) or player:getY())
    atmZ = math.floor(tonumber(atmZ) or player:getZ())
    if IKST_EconomyUI.Window then
        IKST_EconomyUI.Window.player = player
        IKST_EconomyUI.Window.atmX = atmX
        IKST_EconomyUI.Window.atmY = atmY
        IKST_EconomyUI.Window.atmZ = atmZ
        IKST_EconomyUI.Window:setVisible(true)
        IKST_EconomyUI.Window:bringToTop()
        IKST_EconomyUI.Window:refreshAll()
        return
    end
    local sw = getCore():getScreenWidth()
    local sh = getCore():getScreenHeight()
    local win = IKST_EconomyPanel:new(math.floor((sw - WIN_W) / 2), math.floor((sh - WIN_H) / 2), WIN_W, WIN_H)
    win.player = player
    win.atmX, win.atmY, win.atmZ = atmX, atmY, atmZ
    win:initialise()
    win:addToUIManager()
    IKST_EconomyUI.Window = win
end

IKST_VendShop = ISCollapsableWindow:derive("IKST_VendShop")

function IKST_VendShop:new(x, y, w, h)
    local o = ISCollapsableWindow.new(self, x, y, w, h)
    o.title = IKST.text("IGUI_IKST_Economy_ShopTitle", "Player shop")
    o.resizable = false
    o.player = nil
    o.shopX, o.shopY, o.shopZ = 0, 0, 0
    o.entries = {}
    o.selected = -1
    o.manageMode = false
    o.priceEntry = nil
    o.listScrollY = 0
    o.statusText = ""
    o.statusOk = true
    IKST_Chrome.applyPanelColors(o)
    return o
end

function IKST_VendShop:setStatus(msg, ok)
    self.statusText = tostring(msg or "")
    self.statusOk = ok ~= false
end

function IKST_VendShop:initialise()
    ISCollapsableWindow.initialise(self)
    if self.manageMode then
        self.priceEntry = ISTextEntryBox:new("", 12, self.height - 72, 80, 22)
        self.priceEntry:initialise()
        self.priceEntry:instantiate()
        self:addChild(self.priceEntry)
        self.btnSetPrice = ISButton:new(100, self.height - 72, 140, 22,
            IKST.text("IGUI_IKST_Economy_SetPriceAll", "Set price (all)"), self, IKST_VendShop.onSetPrice)
        self.btnSetPrice:initialise()
        IKST_Chrome.styleSecondaryButton(self.btnSetPrice)
        self:addChild(self.btnSetPrice)
        self.btnClearPrice = ISButton:new(248, self.height - 72, 80, 22,
            IKST.text("IGUI_IKST_Economy_ClearPrice", "Clear"), self, IKST_VendShop.onClearPrice)
        self.btnClearPrice:initialise()
        IKST_Chrome.styleSecondaryButton(self.btnClearPrice)
        self:addChild(self.btnClearPrice)
    end
    local btnLabel = self.manageMode and IKST.text("IGUI_IKST_RefreshList", "Refresh") or IKST.text("IGUI_IKST_Economy_BuyOne", "Buy 1")
    local btnFn = self.manageMode and IKST_VendShop.requestList or IKST_VendShop.onBuy
    self.btnBuy = ISButton:new(12, self.height - 40, self.width - 24, 28, btnLabel, self, btnFn)
    self.btnBuy:initialise()
    IKST_Chrome.stylePrimaryButton(self.btnBuy)
    self:addChild(self.btnBuy)
    self:setStatus(IKST.text("IGUI_IKST_Economy_ShopPickRow", "Select a row, then buy or set price."), true)
    self:requestList()
end

function IKST_VendShop:onClearPrice()
    if self.selected < 1 or self.selected > #self.entries then
        self:setStatus(IKST.text("IGUI_IKST_Economy_PickShopRow", "Select an item from the list."), false)
        return
    end
    local e = self.entries[self.selected]
    IKST.dispatchCommand(self.player, IKST.CMD.economyVendSetPrice, {
        x = self.shopX, y = self.shopY, z = self.shopZ,
        itemType = e.itemType,
        itemId = e.itemId,
        price = 0,
        scope = "one",
    })
end

function IKST_VendShop:onSetPrice()
    if self.selected < 1 or self.selected > #self.entries or not self.priceEntry then
        self:setStatus(IKST.text("IGUI_IKST_Economy_PickShopRow", "Select an item from the list."), false)
        return
    end
    local e = self.entries[self.selected]
    local price = IKST.parseAmount(self.priceEntry:getText())
    if price <= 0 then
        self:setStatus(IKST.text("IGUI_IKST_Economy_EnterPrice", "Enter a price greater than 0."), false)
        return
    end
    IKST.dispatchCommand(self.player, IKST.CMD.economyVendSetPrice, {
        x = self.shopX, y = self.shopY, z = self.shopZ,
        itemType = e.itemType,
        itemId = e.itemId,
        price = price,
        scope = "one",
    })
end

function IKST_VendShop:requestList()
    IKST.dispatchCommand(self.player, IKST.CMD.economyVendList, {
        x = self.shopX, y = self.shopY, z = self.shopZ,
        manage = self.manageMode == true,
    })
end

function IKST_VendShop:setEntries(entries, owner)
    self.entries = entries or {}
    self.owner = owner
    self.selected = -1
    self.listScrollY = 0
end

function IKST_VendShop:selectedEntry()
    return self.entries[self.selected]
end

function IKST_VendShop:listTop()
    return 76
end

function IKST_VendShop:listBottom()
    return self.height - (self.manageMode and 100 or 52)
end

function IKST_VendShop:render()
    ISCollapsableWindow.render(self)
    local cc = IKST_Chrome.colors
    local y = 32
    self:drawText(IKST.text("IGUI_IKST_Economy_ShopOwner", "Owner") .. ": " .. tostring(
        (IKST_Identity and IKST_Identity.labelForKey and IKST_Identity.labelForKey(self.owner)) or self.owner or "?"),
        12, y, cc.textMuted.r, cc.textMuted.g, cc.textMuted.b, 1, UIFont.Small)
    y = y + 20
    if not self.manageMode and self.player then
        local balance = IKST_EconomyBridge.getBalance(self.player)
        local balanceKey = (IKST_Economy.idCardBanking and IKST_Economy.idCardBanking())
            and "IGUI_IKST_Economy_ShopBankBalance" or "IGUI_IKST_Economy_ShopBalance"
        local balanceFallback = (IKST_Economy.idCardBanking and IKST_Economy.idCardBanking())
            and "Bank balance" or "You can pay with cash + bank"
        self:drawText(IKST.text(balanceKey, balanceFallback) .. ": " .. IKST_Economy.formatAmount(balance),
            12, y, cc.textPrimary.r, cc.textPrimary.g, cc.textPrimary.b, 1, UIFont.Small)
        y = y + 18
    end
    if self.statusText and self.statusText ~= "" then
        local sr, sg, sb = cc.textMuted.r, cc.textMuted.g, cc.textMuted.b
        if self.statusOk then
            sr, sg, sb = cc.accent.r, cc.accent.g, cc.accent.b
        else
            sr, sg, sb = 0.95, 0.35, 0.3
        end
        self:drawText(self.statusText, 12, y, sr, sg, sb, 1, UIFont.Small)
        y = y + 18
    end
    local listTop = math.max(y, self:listTop())
    local listBottom = self:listBottom()
    if #self.entries == 0 then
        self:drawText(IKST.text("IGUI_IKST_Economy_ShopEmpty", "Nothing for sale"), 12, listTop, cc.textMuted.r, cc.textMuted.g, cc.textMuted.b, 1, UIFont.Small)
        return
    end
    local rowH = 26
    for i, e in ipairs(self.entries) do
        local rowY = listTop + (i - 1) * rowH - self.listScrollY
        if rowY + rowH > listTop and rowY < listBottom then
            local sel = self.selected == i
            if sel then
                self:drawRect(8, rowY - 2, self.width - 16, rowH, 0.35, cc.accent.r, cc.accent.g, cc.accent.b)
            end
            local itemType = e.itemType or e.label
            IKST_EconomyUI.drawIcon(self, 12, rowY, itemType, 20)
            local line = IKST_EconomyUI.formatShopRow(e)
            self:drawText(line, 38, rowY + 4, cc.textPrimary.r, cc.textPrimary.g, cc.textPrimary.b, 1, UIFont.Small)
            if not self.manageMode and self.player and (e.price or 0) > 0 then
                local afford = IKST_EconomyBridge.canAfford(self.player, e.price)
                if not afford then
                    self:drawText(IKST.text("IGUI_IKST_Economy_CantAfford", "need more $"), self.width - 96, rowY + 4, 0.9, 0.35, 0.3, 1, UIFont.Small)
                end
            end
        end
    end
end

function IKST_VendShop:onMouseWheel(del)
    local rowH = 26
    local listTop = self:listTop()
    local listBottom = self:listBottom()
    local max = math.max(0, #self.entries * rowH - (listBottom - listTop))
    self.listScrollY = math.max(0, math.min(self.listScrollY - del * rowH * 2, max))
    return true
end

function IKST_VendShop:onMouseDown(x, y)
    local listTop = self:listTop()
    local listBottom = self:listBottom()
    if y < listTop or y > listBottom then
        return ISCollapsableWindow.onMouseDown(self, x, y)
    end
    local idx = math.floor((y - listTop + self.listScrollY) / 26) + 1
    if idx >= 1 and idx <= #self.entries then
        self.selected = idx
        local e = self.entries[idx]
        if e and self.priceEntry and e.price and e.price > 0 then
            self.priceEntry:setText(tostring(e.price))
        end
    end
    return true
end

function IKST_VendShop:onBuy()
    if self.selected < 1 or self.selected > #self.entries then
        self:setStatus(IKST.text("IGUI_IKST_Economy_PickShopRow", "Select an item from the list."), false)
        return
    end
    local e = self.entries[self.selected]
    if (e.price or 0) <= 0 then
        self:setStatus(IKST.text("IGUI_IKST_Economy_NotForSale", "That item is not for sale."), false)
        return
    end
    if self.player and not IKST_EconomyBridge.canAfford(self.player, e.price) then
        self:setStatus(IKST.text("IGUI_IKST_Economy_NotEnoughMoney", "Not enough money (cash + bank)."), false)
        return
    end
    IKST.dispatchCommand(self.player, IKST.CMD.economyVendBuy, {
        x = self.shopX, y = self.shopY, z = self.shopZ,
        itemType = e.itemType,
        itemId = e.itemId,
    })
end

function IKST_EconomyUI.onVendList(args)
    if not args then
        return
    end
    if IKST_EconomyUI.VendWindow then
        IKST_EconomyUI.VendWindow:setEntries(args.entries, args.owner)
    end
end

function IKST_EconomyUI.openVendShop(player, x, y, z, manageMode)
    player = IKST.resolvePlayer(player)
    if not IKST_Access.canUseEconomy(player) then
        return
    end
    manageMode = manageMode == true
    if IKST_EconomyUI.VendWindow then
        IKST_EconomyUI.VendWindow.player = player
        IKST_EconomyUI.VendWindow.shopX = x
        IKST_EconomyUI.VendWindow.shopY = y
        IKST_EconomyUI.VendWindow.shopZ = z
        IKST_EconomyUI.VendWindow.manageMode = manageMode
        IKST_EconomyUI.VendWindow:setVisible(true)
        IKST_EconomyUI.VendWindow:requestList()
        return
    end
    local sw = getCore():getScreenWidth()
    local sh = getCore():getScreenHeight()
    local win = IKST_VendShop:new(math.floor((sw - 400) / 2), math.floor((sh - 420) / 2), 400, 420)
    win.player = player
    win.shopX, win.shopY, win.shopZ = x, y, z
    win.manageMode = manageMode
    win:initialise()
    win:addToUIManager()
    IKST_EconomyUI.VendWindow = win
end

function IKST_EconomyUI.onServerResult(args)
    if not args then
        return
    end
    if args.cash ~= nil or args.bank ~= nil then
        IKST_EconomyUI.onSnapshot(args)
    end
    if IKST_EconomyUI.Window then
        if args.message then
            IKST_EconomyUI.Window:setStatus(args.message)
        end
        IKST_EconomyUI.Window:refreshBalances()
    end
    local shopCmd = args.mode == IKST.CMD.economyVendBuy or args.mode == IKST.CMD.economyVendSetPrice
    if shopCmd and IKST_EconomyUI.VendWindow then
        if args.message then
            IKST_EconomyUI.VendWindow:setStatus(args.message, args.success == true)
        end
        if args.success then
            IKST_EconomyUI.VendWindow:requestList()
        end
    end
    if shopCmd and args.success and IKST_JobsPanel and IKST_JobsPanel.instance then
        IKST_JobEconomy.requestVendList(IKST_JobsPanel.instance)
        IKST_JobsPanel.instance:refreshJobUI()
    end
end

local function onInventoryRefresh(playerNum)
    local win = IKST_EconomyUI.Window
    if not win or not win.getIsVisible or not win:isVisible() then
        return
    end
    local who = getSpecificPlayer and getSpecificPlayer(playerNum) or nil
    local panelPlayer = win.player and IKST.resolvePlayer(win.player) or nil
    if who and panelPlayer and who == panelPlayer then
        win:refreshValuables()
    end
end

if Events and Events.OnRefreshInventoryWindowContents and Events.OnRefreshInventoryWindowContents.Add then
    Events.OnRefreshInventoryWindowContents.Add(onInventoryRefresh)
end
