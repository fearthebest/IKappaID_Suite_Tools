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
require "IKappaID_UI_Framework/IKUI_Chrome"
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
    if IKST_Hub and type(IKST_Hub.refreshActive) == "function" then
        IKST_Hub.refreshActive()
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

function IKST_JobEconomy.ensureShopAtPlayer(panel)
    if not panel or not panel.player then
        return false
    end
    if panel.economyVendX then
        return true
    end
    if not IKST_EconomyContext or type(IKST_EconomyContext.shopObjectAtPlayer) ~= "function" then
        return false
    end
    local shopObj, sx, sy, sz = IKST_EconomyContext.shopObjectAtPlayer(panel.player)
    if not shopObj or sx == nil or sy == nil then
        return false
    end
    panel.economyVendX = sx
    panel.economyVendY = sy
    panel.economyVendZ = sz or 0
    IKST_JobEconomy.requestVendList(panel)
    return true
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

-- Soft Money transfer: amount field + single nearby player (no floating EconomyUI).
function IKST_JobEconomy.openSoftWire(player, hub)
    if not player then
        return
    end
    local amount = 0
    if hub and hub.economyAmountEntry and type(hub.economyAmountEntry.getText) == "function" then
        amount = IKST.parseAmount(hub.economyAmountEntry:getText())
    end
    if amount <= 0 then
        IKST.notify(player, IKST.text("IGUI_IKST_Economy_InvalidAmount", "Invalid amount."), false)
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
    if #nearby > 1 then
        IKST.notify(player, IKST.text("IGUI_IKST_Economy_WireOneNear",
            "Stand near one player to transfer, or use Open window."), false)
        return
    end
    local target = nearby[1]
    if not target or not target.id then
        return
    end
    IKST.dispatchCommand(player, IKST.CMD.economyWire, {
        target = target.id,
        amount = amount,
    })
end

function IKST_JobEconomy.build(panel)
    if IKST_SoftTool_Economy and type(IKST_SoftTool_Economy.build) == "function" then
        return IKST_SoftTool_Economy.build(panel)
    end
    return 8
end
