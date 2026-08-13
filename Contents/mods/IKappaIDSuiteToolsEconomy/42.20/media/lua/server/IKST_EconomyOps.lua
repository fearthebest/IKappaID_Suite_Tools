if type(isClient) == "function" and isClient() and type(isServer) == "function" and not isServer() then
    return
end

require "IKST_Shared"
require "IKST_Access"
require "IKST_Economy"
require "IKST_EconomyIdentity"
require "IKST_EconomyBridge"
require "IKST_Identity"
require "IKST_Grid"
require "IKST_StaffOps"
require "IKST_WorldOps"
require "IKST_Tickets"
require "IKST_Args"
require "IKST_EconomyOps_Place"

IKST_EconomyOps = IKST_EconomyOps or {}

function IKST_EconomyOps.placementBlocked(player, x, y, z)
    if not player then
        return false, nil
    end
    if not IKST_Policy then
        require "IKST_Policy"
    end
    local allowed, reason = IKST_Policy.locationAllowedAtCoord(player, x, y, z, "economy")
    if allowed == true then
        return false, nil
    end
    return true, reason or "square protected"
end

function IKST_EconomyOps.syncAdd(inv, item)
    if item and sendAddItemToContainer then
        sendAddItemToContainer(inv, item)
    end
end

function IKST_EconomyOps.syncRemove(inv, item)
    if item and sendRemoveItemFromContainer then
        sendRemoveItemFromContainer(inv, item)
    end
end

function IKST_EconomyOps.markDirty(inv)
    if inv and inv.setDrawDirty then
        inv:setDrawDirty(true)
    end
end

function IKST_EconomyOps.findPlayerByUsername(username)
    if IKST_Identity and IKST_Identity.findPlayerByUsername then
        return IKST_Identity.findPlayerByUsername(username)
    end
    if not username or username == "" then
        return nil
    end
    local list = getOnlinePlayers and getOnlinePlayers()
    if not list or not list.size then
        return nil
    end
    for i = 0, list:size() - 1 do
        local p = list:get(i)
        if p and type(p.getUsername) == "function" and p:getUsername() == username then
            return p
        end
    end
    return nil
end

function IKST_EconomyOps.findPlayerByAccountKey(key)
    if IKST_Identity and type(IKST_Identity.findPlayerByAccountKey) == "function" then
        return IKST_Identity.findPlayerByAccountKey(key)
    end
    return nil
end

function IKST_EconomyOps.sendSnapshot(player, extra)
    local snap = IKST_Economy.snapshot(player)
    if extra then
        for k, v in pairs(extra) do
            snap[k] = v
        end
    end
    if IKST.deliverClientCommand then
        IKST.deliverClientCommand(player, IKST.CMD.economySnapshotResult, snap)
    end
end

function IKST_EconomyOps.sendVendList(player, x, y, z, entries)
    local owner = IKST_EconomyOps.vendOwnerAt(x, y, z)
    local isVending = owner ~= nil and owner ~= ""
    local payload = {
        x = x, y = y, z = z,
        entries = entries or {},
        owner = owner,
        isVending = isVending,
        canClaim = not isVending,
        canManage = isVending and (
            IKST_Identity.playerOwnsKey(player, owner)
            or (IKST_Access and IKST_Access.canUseTools(player))
        ),
    }
    if IKST.deliverClientCommand then
        IKST.deliverClientCommand(player, IKST.CMD.economyVendListResult, payload)
    end
end

function IKST_EconomyOps.bankGate(player, x, y, z, action)
    if IKST_Economy.atmRequiredForBank() and not IKST_Economy.isAtmSquare(x, y, z) then
        return false, "use an ATM"
    end
    if IKST_Economy.isAtmSquare(x, y, z) and not IKST_Economy.atmAllows(x, y, z, action) then
        return false, "ATM action disabled"
    end
    if not IKST_Economy.playerNearCoord(player, x, y, z, IKST_Economy.shopMaxDistance() + 2) then
        return false, "too far"
    end
    if IKST_Economy.idCardBanking and IKST_Economy.idCardBanking() then
        if not IKST_EconomyIdentity.hasValidIdCard(player) then
            return false, "present your bank ID card"
        end
    end
    return true
end

function IKST_EconomyOps.findVendObject(x, y, z)
    local sq = IKST_Grid.getSquare(x, y, z)
    if not sq or not sq.getObjects then
        return nil
    end
    for i = 0, sq:getObjects():size() - 1 do
        local obj = sq:getObjects():get(i)
        if obj and type(obj.getContainer) == "function" and obj:getContainer() then
            local md = type(obj.getModData) == "function" and obj:getModData()
            if md and md[IKST_Economy.VEND_TAG] then
                return obj
            end
        end
    end
    return nil
end

function IKST_EconomyOps.vendOwnerAt(x, y, z)
    local obj = IKST_EconomyOps.findVendObject(x, y, z)
    if not obj then
        return nil
    end
    local md = obj:getModData()
    return md and md[IKST_Economy.VEND_OWNER]
end

function IKST_EconomyOps.collectVendList(x, y, z, includeAll)
    local obj = IKST_EconomyOps.findVendObject(x, y, z)
    if not obj then
        return {}
    end
    local container = obj:getContainer()
    if not container or not container.getItems then
        return {}
    end
    local shopMd = obj:getModData() or {}
    local items = container:getItems()
    local groups = {}
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and item.getFullType and item.getID then
            local itemType = item:getFullType()
            local price = IKST_Economy.effectiveVendPrice(shopMd, item)
            if includeAll then
                local label = type(item.getDisplayName) == "function" and item:getDisplayName() or itemType
                table.insert(groups, {
                    itemType = itemType,
                    itemId = item:getID(),
                    label = label .. IKST_Economy.freshnessSuffix(item),
                    price = price,
                    count = IKST_Economy.itemCount(item),
                    sellable = IKST_Economy.canSellInShop(item),
                })
            else
                local groupKey = IKST_Economy.vendListGroupKey(item, itemType)
                local row = groups[groupKey]
                if not row then
                    local label = type(item.getDisplayName) == "function" and item:getDisplayName() or itemType
                    row = {
                        itemType = itemType,
                        itemId = item:getID(),
                        label = label .. IKST_Economy.freshnessSuffix(item),
                        price = price,
                        count = 0,
                        sellable = IKST_Economy.canSellInShop(item),
                    }
                    groups[groupKey] = row
                end
                row.count = row.count + IKST_Economy.itemCount(item)
                if price > row.price then
                    row.price = price
                end
                if not row.itemId then
                    row.itemId = item:getID()
                end
                if IKST_Economy.canSellInShop(item) then
                    row.sellable = true
                end
            end
        end
    end
    local out = {}
    if includeAll then
        for _, row in ipairs(groups) do
            table.insert(out, row)
        end
    else
        for _, row in pairs(groups) do
            if row.price > 0 and row.sellable ~= false then
                table.insert(out, row)
            end
        end
    end
    table.sort(out, function(a, b)
        return tostring(a.label) < tostring(b.label)
    end)
    return out
end

function IKST_EconomyOps.findItemByType(container, itemType)
    return IKST_EconomyOps.findSellableItem(container, itemType, nil)
end

function IKST_EconomyOps.findSellableItem(container, itemType, itemId)
    if not container then
        return nil
    end
    if itemId then
        local byId = IKST_EconomyOps.findItemInContainer(container, itemId)
        if byId and IKST_Economy.canSellInShop(byId) then
            return byId
        end
        return nil
    end
    if not itemType or itemType == "" then
        return nil
    end
    local items = type(container.getItems) == "function" and container:getItems()
    if not items then
        return nil
    end
    local best = nil
    local bestAge = -1
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and type(item.getFullType) == "function" and item:getFullType() == itemType and IKST_Economy.canSellInShop(item) then
            local age = item.getAge and tonumber(item:getAge()) or 0
            if age >= bestAge then
                bestAge = age
                best = item
            end
        end
    end
    return best
end

function IKST_EconomyOps.splitOneFromStack(item)
    if not item or not item.getFullType or not instanceItem then
        return nil
    end
    local count = IKST_Economy.itemCount(item)
    if count <= 1 then
        return nil
    end
    local one = instanceItem(item:getFullType())
    if not one then
        return nil
    end
    if instanceof and instanceof(item, "Food") and one.copyFoodFromSplit then
        one:copyFoodFromSplit(item, 1)
    else
        item:setCount(count - 1)
        if one.setCount then
            one:setCount(1)
        end
        if one.inheritFoodAgeFrom then
            one:inheritFoodAgeFrom(item)
        elseif one.setAge and item.getAge then
            one:setAge(item:getAge())
        end
        if item.syncItemFields then
            item:syncItemFields()
        end
    end
    if one.syncItemFields then
        one:syncItemFields()
    end
    return one
end

function IKST_EconomyOps.clearLegacyItemPrices(container, itemType)
    if not container or not itemType or not container.getItems then
        return
    end
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and type(item.getFullType) == "function" and item:getFullType() == itemType and item.getModData then
            local md = item:getModData()
            md[IKST_Economy.VEND_PRICE] = nil
            if item.syncItemFields then
                item:syncItemFields()
            end
        end
    end
end

function IKST_EconomyOps.transferOneToPlayer(container, player, item)
    if not container or not player or not item then
        return false
    end
    local inv = player:getInventory()
    if not inv then
        return false
    end
    if not IKST_Economy.canSellInShop(item) then
        return false
    end
    local count = IKST_Economy.itemCount(item)
    if count <= 1 then
        -- Server-authorized shop purchase — TransferServer must not reverse this take.
        if IKST_TransferServer and type(IKST_TransferServer.allowItem) == "function" then
            IKST_TransferServer.allowItem(item)
        end
        container:Remove(item)
        IKST_EconomyOps.syncRemove(container, item)
        inv:AddItem(item)
        IKST_EconomyOps.syncAdd(inv, item)
        IKST_EconomyOps.markDirty(container)
        IKST_EconomyOps.markDirty(inv)
        return true
    end
    local one = IKST_EconomyOps.splitOneFromStack(item)
    if not one then
        return false
    end
    if IKST_TransferServer and type(IKST_TransferServer.allowItem) == "function" then
        IKST_TransferServer.allowItem(one)
    end
    inv:AddItem(one)
    IKST_EconomyOps.syncAdd(inv, one)
    IKST_EconomyOps.markDirty(container)
    IKST_EconomyOps.markDirty(inv)
    if item.syncItemFields then
        item:syncItemFields()
    end
    return true
end

function IKST_EconomyOps.findItemInContainer(container, itemId)
    if not container or not itemId then
        return nil
    end
    local items = type(container.getItems) == "function" and container:getItems()
    if not items then
        return nil
    end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and type(item.getID) == "function" and item:getID() == itemId then
            return item
        end
    end
    return nil
end

function IKST_EconomyOps.creditSeller(sellerKey, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or not sellerKey or sellerKey == "" then
        return
    end
    if not IKST_Identity.isAccountKey(sellerKey) then
        sellerKey = IKST_Identity.keyForLegacyName(sellerKey) or sellerKey
    end
    local online = IKST_EconomyOps.findPlayerByAccountKey(sellerKey)
    if online then
        IKST_Economy.addBank(online, amount)
        return
    end
    IKST_Economy.addPending(sellerKey, amount)
end

function IKST_EconomyOps.applyTax(amount)
    local pct = IKST_Economy.salesTaxPercent()
    if pct <= 0 then
        return 0
    end
    local tax = math.floor(amount * pct / 100)
    if tax <= 0 then
        return 0
    end
    local receiver = IKST_Economy.taxReceiver()
    local store = IKST_Economy.getStore()
    if receiver and store then
        local row = store.accounts[receiver]
        if not row then
            row = { bank = 0, pending = 0 }
            store.accounts[receiver] = row
        end
        row.bank = math.floor((tonumber(row.bank) or 0) + tax)
    elseif store then
        store.taxPool = math.floor((tonumber(store.taxPool) or 0) + tax)
    end
    IKST_Economy.persistStore()
    return tax
end

function IKST_EconomyOps.deposit(player, amount, x, y, z, args)
    amount = IKST.parseAmount(amount)
    if amount <= 0 then
        return false, "invalid amount"
    end
    local gateOk, gateMsg = IKST_EconomyOps.bankGate(player, x, y, z, "deposit")
    if not gateOk then
        return false, gateMsg or "use an ATM to deposit"
    end
    if IKST_Economy.idCardBanking and IKST_Economy.idCardBanking() then
        return false, "funds are already in your bank account"
    end
    local ok, err = IKST_EconomyBridge.payCash(player, amount)
    if not ok then
        return false, err or "not enough cash"
    end
    IKST_Economy.addBank(player, amount)
    if args then
        args.resultAmount = amount
    end
    return true, "deposit_ok"
end

function IKST_EconomyOps.withdraw(player, amount, x, y, z, args)
    amount = IKST.parseAmount(amount)
    if amount <= 0 then
        return false, "invalid amount"
    end
    local gateOk, gateMsg = IKST_EconomyOps.bankGate(player, x, y, z, "withdraw")
    if not gateOk then
        return false, gateMsg or "use an ATM to withdraw"
    end
    if IKST_Economy.idCardBanking and IKST_Economy.idCardBanking() then
        return false, "withdraw disabled — use wire or shop"
    end
    if not IKST_Economy.takeBank(player, amount) then
        return false, "not enough in bank"
    end
    if not IKST_EconomyBridge.giveCash(player, amount) then
        IKST_Economy.addBank(player, amount)
        return false, "could not give cash"
    end
    if args then
        args.resultAmount = amount
    end
    return true, "withdraw_ok"
end

function IKST_EconomyOps.wire(player, targetId, amount, args, forceCredit)
    amount = IKST.parseAmount(amount)
    if amount <= 0 then
        return false, "invalid amount"
    end
    local minAmt = IKST_Economy.wireMinAmount()
    if amount < minAmt then
        return false, "amount below minimum"
    end
    local target = IKST_StaffOps.findPlayerByOnlineID(targetId)
    if not target then
        return false, "player not found"
    end
    if target == player then
        return false, "cannot wire yourself"
    end
    local dist = IKST_Economy.wireMaxDistance()
    if not IKST_Economy.playerNearCoord(player, target:getX(), target:getY(), target:getZ(), dist) then
        return false, "too far to wire cash"
    end
    if forceCredit ~= true and not IKST_Economy.autoAcceptOn(target) then
        return false, "not accepting transfers"
    end
    local feePct = IKST_Economy.wireFeePercent()
    local fee = math.floor(amount * feePct / 100)
    local receive = amount - fee
    if receive <= 0 then
        return false, "fee exceeds amount"
    end
    if IKST_Economy.idCardBanking and IKST_Economy.idCardBanking() then
        if not IKST_Economy.takeBank(player, amount) then
            return false, "not enough in bank"
        end
        IKST_Economy.addBank(target, receive)
    else
        local ok, err = IKST_EconomyBridge.payCash(player, amount)
        if not ok then
            return false, err or "not enough cash"
        end
        if not IKST_EconomyBridge.giveCash(target, receive) then
            IKST_EconomyBridge.giveCash(player, amount)
            return false, "wire failed"
        end
    end
    if fee > 0 then
        local store = IKST_Economy.getStore()
        if store then
            store.taxPool = math.floor((tonumber(store.taxPool) or 0) + fee)
            IKST_Economy.persistStore()
        end
    end
    local label = IKST_StaffOps.playerLabel and IKST_StaffOps.playerLabel(target) or "player"
    local fromLabel = IKST_StaffOps.playerLabel and IKST_StaffOps.playerLabel(player) or "player"
    IKST_Economy.appendHistory(player, "-" .. IKST_Economy.formatAmount(amount) .. " to " .. label)
    IKST_Economy.appendHistory(target, "+" .. IKST_Economy.formatAmount(receive) .. " from " .. fromLabel)
    if args then
        args.resultReceive = receive
        args.resultTarget = label
        args.resultFee = fee
    end
    return true, "wire_ok"
end

function IKST_EconomyOps.setPref(player, args)
    args = args or {}
    local on = IKST_Args.readBool(args.autoAccept)
    if on == nil then
        return false, "bad_pref"
    end
    local row = IKST_Economy.getAccount(player)
    row.autoAccept = on == true
    IKST_Economy.persistStore()
    return true, "pref_ok"
end

function IKST_EconomyOps.payRequest(player, targetId, amount)
    amount = IKST.parseAmount(amount)
    if amount <= 0 then
        return false, "invalid amount"
    end
    local minAmt = IKST_Economy.wireMinAmount()
    if amount < minAmt then
        return false, "amount below minimum"
    end
    local target = IKST_StaffOps.findPlayerByOnlineID(targetId)
    if not target then
        return false, "player not found"
    end
    if target == player then
        return false, "cannot wire yourself"
    end
    local dist = IKST_Economy.wireMaxDistance()
    if not IKST_Economy.playerNearCoord(player, target:getX(), target:getY(), target:getZ(), dist) then
        return false, "too far to wire cash"
    end
    local row = IKST_Economy.getAccount(target)
    if type(row.payReq) == "table" then
        return false, "request pending"
    end
    local fromKey = IKST_Economy.accountKey(player)
    local fromName = "player"
    if IKST_Identity and type(IKST_Identity.username) == "function" then
        fromName = IKST_Identity.username(player) or fromName
    end
    fromName = IKST_Economy.historyLine(fromName)
    if #fromName > 32 then
        fromName = string.sub(fromName, 1, 32)
    end
    row.payReq = {
        fromKey = fromKey,
        fromName = fromName,
        amount = amount,
    }
    IKST_Economy.persistStore()
    IKST_EconomyOps.sendSnapshot(target)
    if IKST_WorldOps and type(IKST_WorldOps.sendResult) == "function" then
        IKST_WorldOps.sendResult(target, true, "pay_request_in", nil, nil, nil, IKST.CMD.economyPayRequest)
    end
    return true, "pay_request_ok"
end

function IKST_EconomyOps.payRespond(player, accept)
    local row = IKST_Economy.getAccount(player)
    local req = row.payReq
    if type(req) ~= "table" then
        return false, "no payment request"
    end
    local amount = math.floor(tonumber(req.amount) or 0)
    local fromKey = req.fromKey
    row.payReq = nil
    IKST_Economy.persistStore()
    if accept ~= true then
        local requester = nil
        if fromKey and type(IKST_EconomyOps.findPlayerByAccountKey) == "function" then
            requester = IKST_EconomyOps.findPlayerByAccountKey(fromKey)
        end
        if requester then
            IKST_EconomyOps.sendSnapshot(requester)
            if IKST_WorldOps and type(IKST_WorldOps.sendResult) == "function" then
                IKST_WorldOps.sendResult(requester, true, "pay_declined", nil, nil, nil, IKST.CMD.economyPayRespond)
            end
        end
        return true, "pay_declined"
    end
    if amount <= 0 or not fromKey then
        return false, "no payment request"
    end
    local requester = IKST_EconomyOps.findPlayerByAccountKey(fromKey)
    if not requester or type(requester.getOnlineID) ~= "function" then
        return false, "player not found"
    end
    local ok, msg = IKST_EconomyOps.wire(player, requester:getOnlineID(), amount, {}, true)
    if not ok then
        row.payReq = req
        IKST_Economy.persistStore()
        return false, msg
    end
    if requester then
        IKST_EconomyOps.sendSnapshot(requester)
    end
    return true, "pay_accepted"
end

function IKST_EconomyOps.submitTicket(player, message, label)
    if not IKST_Tickets or type(IKST_Tickets.submit) ~= "function" then
        return false, "tickets unavailable"
    end
    return IKST_Tickets.submit(player, message, label)
end

function IKST_EconomyOps.countPlayerItems(player, itemType)
    return IKST_Economy.countPlayerItems(player, itemType)
end

function IKST_EconomyOps.restoreValuableSnapshot(player, snapshot)
    if not player or not snapshot or #snapshot == 0 then
        return
    end
    local inv = player:getInventory()
    if not inv then
        return
    end
    for _, row in ipairs(snapshot) do
        local itemType = row.itemType
        local count = tonumber(row.count) or 0
        if itemType and count > 0 then
            if count > 1 and type(inv.AddItems) == "function" then
                inv:AddItems(itemType, count)
            else
                for _ = 1, count do
                    if type(inv.AddItem) == "function" then
                        inv:AddItem(itemType)
                    end
                end
            end
        end
    end
    IKST_EconomyOps.markDirty(inv)
end

function IKST_EconomyOps.snapshotPlayerValuables(player)
    local data = IKST_Economy.loadValuables()
    local snapshot = {}
    for _, entry in ipairs(data.list) do
        local count = IKST_EconomyOps.countPlayerItems(player, entry.itemType)
        if count > 0 then
            snapshot[#snapshot + 1] = {
                itemType = entry.itemType,
                count = count,
            }
        end
    end
    return snapshot
end

function IKST_EconomyOps.removeAllPlayerItems(player, itemType)
    if not player or not itemType then
        return 0
    end
    local inv = player:getInventory()
    if not inv then
        return 0
    end
    local removed = 0
    local function removeOne(item)
        if not item then
            return
        end
        local container = type(item.getContainer) == "function" and item:getContainer() or inv
        local n = IKST_Economy.itemCount(item)
        container:Remove(item)
        IKST_EconomyOps.syncRemove(container, item)
        removed = removed + n
    end
    local items = nil
    if type(inv.getItemsFromFullType) == "function" then
        items = inv:getItemsFromFullType(itemType, true)
    elseif type(inv.getItemsFromType) == "function" then
        items = inv:getItemsFromType(itemType, true)
    elseif type(inv.getItemsFromTypeRecurse) == "function" then
        items = inv:getItemsFromTypeRecurse(itemType, true)
    end
    if items and items.size then
        for i = items:size() - 1, 0, -1 do
            removeOne(items:get(i))
        end
    elseif type(inv.getItems) == "function" then
        items = inv:getItems()
        if items then
            for i = items:size() - 1, 0, -1 do
                local item = items:get(i)
                if item and type(item.getFullType) == "function" and item:getFullType() == itemType then
                    removeOne(item)
                end
            end
        end
    end
    if removed > 0 then
        IKST_EconomyOps.markDirty(inv)
    end
    return removed
end

function IKST_EconomyOps.playerIdCardReissue(player, x, y, z)
    if not IKST_Economy.idCardBanking or not IKST_Economy.idCardBanking() then
        return false, "ID card banking is off"
    end
    if not IKST_Economy.idCardPlayerReissue or not IKST_Economy.idCardPlayerReissue() then
        return false, "bank ID replacement disabled"
    end
    if not IKST_Economy.isAtmSquare(x, y, z) then
        return false, "use an ATM to replace your bank ID"
    end
    if not IKST_Economy.atmAllows(x, y, z, "deposit") and not IKST_Economy.atmAllows(x, y, z, "withdraw") then
        return false, "ATM cannot replace bank ID"
    end
    local remain = IKST_Economy.idCardReissueCooldownRemainMs(player)
    if remain > 0 then
        local hours = math.ceil(remain / 3600000)
        return false, "wait " .. tostring(hours) .. "h before replacing bank ID again"
    end
    local fee = IKST_Economy.idCardReissueFee()
    if fee > 0 then
        if not IKST_Economy.takeBank(player, fee) then
            return false, "need " .. IKST_Economy.formatAmount(fee) .. " in bank for replacement fee"
        end
    end
    local ok, msg = IKST_EconomyIdentity.reissueIdCard(player, { recordCooldown = true, bumpSerial = true, notifyPlayer = true })
    if not ok and fee > 0 then
        IKST_Economy.addBank(player, fee)
    end
    if ok then
        local out = "Bank ID replaced"
        if fee > 0 then
            out = out .. " (fee " .. IKST_Economy.formatAmount(fee) .. ")"
        end
        return true, out
    end
    return false, msg or "replacement failed"
end

function IKST_EconomyOps.exchangeGate(player, x, y, z)
    if IKST_Economy.atmRequiredForBank() and not IKST_Economy.isAtmSquare(x, y, z) then
        return false, "use an ATM"
    end
    if not IKST_Economy.atmAllows(x, y, z, "valuables") then
        return false, "ATM cannot exchange valuables"
    end
    if IKST_Economy.idCardBanking and IKST_Economy.idCardBanking() then
        if not IKST_EconomyIdentity.hasValidIdCard(player) then
            return false, "present your bank ID card"
        end
    end
    return true
end

function IKST_EconomyOps.exchange(player, itemType, x, y, z, args)
    if not IKST_Economy.valuablesEnabled() then
        return false, "valuables exchange disabled"
    end
    local gateOk, gateMsg = IKST_EconomyOps.exchangeGate(player, x, y, z)
    if not gateOk then
        return false, gateMsg
    end
    local entry = IKST_Economy.valuableEntry(itemType)
    if not entry then
        return false, "not a valuable"
    end
    if not PhoneShop.findItem or not IKST_EconomyBridge.giveCash then
        return false, "PhoneShop missing"
    end
    local inv, item = PhoneShop.findItem(player, itemType)
    if not inv or not item then
        return false, "item not found"
    end
    local count = IKST_Economy.itemCount(item)
    local payout = entry.price * count
    inv:Remove(item)
    IKST_EconomyOps.syncRemove(inv, item)
    IKST_EconomyOps.markDirty(player:getInventory())
    if not IKST_EconomyBridge.giveCash(player, payout) then
        if inv:AddItem(item) then
            IKST_EconomyOps.markDirty(inv)
        elseif count > 1 and inv.AddItems then
            inv:AddItems(itemType, count)
            IKST_EconomyOps.markDirty(inv)
        else
            inv:AddItem(itemType)
            IKST_EconomyOps.markDirty(inv)
        end
        return false, "payout failed"
    end
    if args then
        args.resultPayout = payout
    end
    return true, "exchange_ok"
end

function IKST_EconomyOps.exchangeAll(player, x, y, z, args)
    if not IKST_Economy.valuablesEnabled() then
        return false, "valuables exchange disabled"
    end
    local gateOk, gateMsg = IKST_EconomyOps.exchangeGate(player, x, y, z)
    if not gateOk then
        return false, gateMsg
    end
    if not IKST_EconomyBridge.giveCash then
        return false, "PhoneShop missing"
    end
    local data = IKST_Economy.loadValuables()
    local snapshot = IKST_EconomyOps.snapshotPlayerValuables(player)
    local totalPayout = 0
    local totalItems = 0
    for _, entry in ipairs(data.list) do
        local n = IKST_EconomyOps.removeAllPlayerItems(player, entry.itemType)
        if n > 0 then
            totalItems = totalItems + n
            totalPayout = totalPayout + (n * entry.price)
        end
    end
    if totalItems <= 0 then
        return false, "no valuables in inventory"
    end
    if not IKST_EconomyBridge.giveCash(player, totalPayout) then
        IKST_EconomyOps.restoreValuableSnapshot(player, snapshot)
        return false, "payout failed"
    end
    if args then
        args.resultCount = totalItems
        args.resultPayout = totalPayout
    end
    return true, "exchange_all_ok"
end

function IKST_EconomyOps.vendClaim(player, x, y, z)
    if not IKST_Economy.playerNearCoord(player, x, y, z, IKST_Economy.shopMaxDistance()) then
        return false, "too far from shop terminal"
    end
    local sq = IKST_Grid.getSquare(x, y, z)
    if not sq then
        return false, "bad square"
    end
    local obj = IKST_EconomyOps.findShopTileOnSquare(sq)
    if not obj then
        if IKST_Economy.shopTilesRequired() then
            return false, "use a shop terminal tile (vending machine)"
        end
        return false, "no shop terminal here"
    end
    if IKST_Economy.isVendObject(obj) then
        local owner = IKST_Economy.vendOwnerOfObject(obj)
        if owner and owner ~= "" then
            if IKST_Identity.playerOwnsKey(player, owner) then
                return false, "you already own this shop"
            end
            return false, "shop already claimed by someone else"
        end
    end
    local ok, msg = IKST_EconomyOps.vendEnable(player, x, y, z, IKST_Economy.accountName(player))
    if ok then
        return true, "shop opened"
    end
    return ok, msg
end

function IKST_EconomyOps.vendEnable(player, x, y, z, ownerName)
    local sq = IKST_Grid.getSquare(x, y, z)
    if not sq then
        return false, "bad square"
    end
    local blocked, reason = IKST_EconomyOps.placementBlocked(player, x, y, z)
    if blocked then
        return false, reason or "square protected"
    end
    local obj = IKST_EconomyOps.findShopTileOnSquare(sq)
    if not obj then
        if IKST_Economy.shopTilesRequired() then
            return false, "use a shop terminal tile (vending machine)"
        end
        return false, "no container here"
    end
    local md = obj:getModData()
    md[IKST_Economy.VEND_TAG] = true
    md[IKST_Economy.VEND_OWNER] = ownerName or IKST_Economy.accountName(player)
    if IKST_Economy.shopProtectEnabled() then
        md[IKST_Economy.VEND_PROTECT] = true
    end
    IKST_EconomyOps.ensureShopContainerCapacity(obj)
    if obj.transmitModData then
        obj:transmitModData()
    end
    return true, "Shop terminal enabled"
end

function IKST_EconomyOps.vendDisable(player, x, y, z)
    if not IKST_Economy.playerNearCoord(player, x, y, z, IKST_Economy.shopMaxDistance() + 2) then
        return false, "too far"
    end
    local obj = IKST_EconomyOps.findVendObject(x, y, z)
    if not obj then
        return false, "not a shop"
    end
    local md = obj:getModData()
    md[IKST_Economy.VEND_TAG] = nil
    md[IKST_Economy.VEND_OWNER] = nil
    md[IKST_Economy.VEND_PRICES] = nil
    md[IKST_Economy.VEND_PROTECT] = nil
    if obj.transmitModData then
        obj:transmitModData()
    end
    return true, "Shop disabled"
end

function IKST_EconomyOps.applyStackPrice(item, price)
    if not item or not item.getModData then
        return false
    end
    local md = item:getModData()
    if price <= 0 then
        md[IKST_Economy.VEND_PRICE] = nil
    else
        md[IKST_Economy.VEND_PRICE] = price
    end
    if item.syncItemFields then
        item:syncItemFields()
    end
    return true
end

function IKST_EconomyOps.applyTypePrice(shopMd, container, itemType, price)
    if not shopMd or not itemType or itemType == "" then
        return false
    end
    local catalog = IKST_Economy.getShopPriceTable(shopMd)
    if price <= 0 then
        catalog[itemType] = nil
    else
        catalog[itemType] = price
    end
    if container and container.getItems then
        local items = container:getItems()
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            if item and type(item.getFullType) == "function" and item:getFullType() == itemType and item.getModData then
                item:getModData()[IKST_Economy.VEND_PRICE] = nil
                if item.syncItemFields then
                    item:syncItemFields()
                end
            end
        end
    end
    IKST_EconomyOps.clearLegacyItemPrices(container, itemType)
    return true
end

function IKST_EconomyOps.vendSetPrice(player, x, y, z, args)
    args = args or {}
    if not IKST_Economy.playerNearCoord(player, x, y, z, IKST_Economy.shopMaxDistance() + 2) then
        return false, "too far"
    end
    local price = math.floor(tonumber(args.price) or 0)
    if price < 0 or price > IKST_Economy.maxVendPrice() then
        return false, "invalid price"
    end
    local scope = args.scope or "type"
    local obj = IKST_EconomyOps.findVendObject(x, y, z)
    if not obj then
        return false, "not a shop"
    end
    local owner = IKST_EconomyOps.vendOwnerAt(x, y, z)
    local me = IKST_Economy.accountName(player)
    if not owner and not IKST_Access.canUseTools(player) then
        return false, "claim shop first"
    end
    if owner and not IKST_Identity.playerOwnsKey(player, owner) and not IKST_Access.canUseTools(player) then
        return false, "not your shop"
    end
    local container = obj:getContainer()
    local shopMd = obj:getModData() or {}
    local itemId = args.itemId
    local itemType = args.itemType
    local itemIds = args.itemIds
    local touched = 0

    if scope == "one" then
        local item = IKST_EconomyOps.findItemInContainer(container, itemId)
        if not item and itemType and itemType ~= "" then
            item = IKST_EconomyOps.findSellableItem(container, itemType, itemId)
        end
        if not item then
            return false, "pick a stock row"
        end
        if price <= 0 then
            IKST_EconomyOps.applyStackPrice(item, 0)
            return true, "Price cleared for stack"
        end
        IKST_EconomyOps.applyStackPrice(item, price)
        if obj.transmitModData then
            obj:transmitModData()
        end
        return true, "Price set for 1 stack: " .. IKST_Economy.formatAmount(price)
    end

    if scope == "selected" then
        if type(itemIds) ~= "table" or #itemIds == 0 then
            return false, "pick one or more stock rows"
        end
        local maxIds = IKST_Economy.maxVendSelectedIds and IKST_Economy.maxVendSelectedIds() or 200
        if #itemIds > maxIds then
            return false, "too many items selected (max " .. tostring(maxIds) .. ")"
        end
        for i = 1, #itemIds do
            local item = IKST_EconomyOps.findItemInContainer(container, itemIds[i])
            if item then
                if price <= 0 then
                    IKST_EconomyOps.applyStackPrice(item, 0)
                else
                    IKST_EconomyOps.applyStackPrice(item, price)
                end
                touched = touched + 1
            end
        end
        if touched <= 0 then
            return false, "selected stock not found"
        end
        if obj.transmitModData then
            obj:transmitModData()
        end
        if price <= 0 then
            return true, "Cleared price on " .. tostring(touched) .. " stacks"
        end
        return true, "Price set on " .. tostring(touched) .. " stacks: " .. IKST_Economy.formatAmount(price)
    end

    if scope == "all" then
        local types = {}
        if container and container.getItems then
            local items = container:getItems()
            for i = 0, items:size() - 1 do
                local item = items:get(i)
                if item and item.getFullType then
                    types[item:getFullType()] = true
                end
            end
        end
        for t, _ in pairs(types) do
            IKST_EconomyOps.applyTypePrice(shopMd, container, t, price)
            touched = touched + 1
        end
        if touched <= 0 then
            return false, "shop is empty"
        end
        if obj.transmitModData then
            obj:transmitModData()
        end
        if price <= 0 then
            return true, "Cleared prices on all stocked types"
        end
        return true, "Price set on all stocked types (" .. tostring(touched) .. "): " .. IKST_Economy.formatAmount(price)
    end

    if not itemType or itemType == "" then
        local item = IKST_EconomyOps.findItemInContainer(container, itemId)
        if item and item.getFullType then
            itemType = item:getFullType()
        end
    end
    if not itemType or itemType == "" then
        return false, "pick an item type"
    end
    if not IKST_EconomyOps.findItemByType(container, itemType) then
        return false, "item not in shop"
    end
    IKST_EconomyOps.applyTypePrice(shopMd, container, itemType, price)
    if obj.transmitModData then
        obj:transmitModData()
    end
    return true, price > 0
        and ("Price set for all " .. itemType .. ": " .. IKST_Economy.formatAmount(price))
        or "Price cleared for " .. itemType
end

function IKST_EconomyOps.vendBuy(player, x, y, z, itemId, itemType, args)
    if not IKST_Economy.playerNearCoord(player, x, y, z, IKST_Economy.shopMaxDistance()) then
        return false, "too far from shop"
    end
    local obj = IKST_EconomyOps.findVendObject(x, y, z)
    if not obj then
        return false, "not a shop"
    end
    local container = obj:getContainer()
    local shopMd = obj:getModData() or {}
    local item = nil
    if itemId then
        item = IKST_EconomyOps.findSellableItem(container, itemType, itemId)
    end
    if not item and itemType and itemType ~= "" then
        item = IKST_EconomyOps.findSellableItem(container, itemType, nil)
    end
    if not item then
        return false, "sold out or rotten"
    end
    if not itemType or itemType == "" then
        itemType = item:getFullType()
    end
    local price = IKST_Economy.effectiveVendPrice(shopMd, item)
    if price <= 0 then
        return false, "not for sale — owner must set a price"
    end
    local seller = IKST_EconomyOps.vendOwnerAt(x, y, z)
    if seller and IKST_Identity.playerOwnsKey(player, seller) then
        return false, "cannot buy your own listing"
    end
    if not IKST_EconomyBridge.canAfford(player, price) then
        return false, "not enough money (cash + bank)"
    end
    local okPay, err = IKST_EconomyBridge.pay(player, price)
    if not okPay then
        return false, err or "cannot pay"
    end
    if not IKST_EconomyOps.transferOneToPlayer(container, player, item) then
        IKST_EconomyBridge.giveCash(player, price)
        return false, "could not take item from shop"
    end
    local tax = IKST_EconomyOps.applyTax(price)
    local payout = price - tax
    IKST_EconomyOps.creditSeller(seller, payout)
    if args then
        args.resultPrice = price
    end
    return true, "purchase_ok"
end

function IKST_EconomyOps.configureAtm(player, x, y, z, cfg)
    if not IKST_Access.canUseTools(player) then
        return false, "admin only"
    end
    local sq = IKST_Grid.getSquare(x, y, z)
    if not sq then
        return false, "bad square"
    end
    if IKST_Economy.isAtmSquare(x, y, z) then
        return IKST_EconomyOps.enableAtmAt(player, x, y, z, cfg)
    end
    if not IKST_Economy.findAtmObjectOnSquare(sq) then
        return false, "no bank ATM fixture on this square"
    end
    return IKST_EconomyOps.enableAtmAt(player, x, y, z, cfg)
end

function IKST_EconomyOps.handle(command, player, args)
    if not IKST_Economy.isEnabled() then
        return false, "economy disabled or PhoneShop missing"
    end
    args = args or {}
    local x = math.floor(tonumber(args.x) or player:getX())
    local y = math.floor(tonumber(args.y) or player:getY())
    local z = math.floor(tonumber(args.z) or player:getZ())

    if command == IKST.CMD.economySnapshot then
        IKST_EconomyOps.sendSnapshot(player)
        return true, "ok"
    end

    if command == IKST.CMD.economyDeposit then
        return IKST_EconomyOps.deposit(player, args.amount, x, y, z, args)
    end
    if command == IKST.CMD.economyWithdraw then
        return IKST_EconomyOps.withdraw(player, args.amount, x, y, z, args)
    end
    if command == IKST.CMD.economyWire then
        return IKST_EconomyOps.wire(player, args.target, args.amount, args)
    end
    if command == IKST.CMD.economySetPref then
        return IKST_EconomyOps.setPref(player, args)
    end
    if command == IKST.CMD.economyPayRequest then
        return IKST_EconomyOps.payRequest(player, args.target, args.amount)
    end
    if command == IKST.CMD.economyPayRespond then
        return IKST_EconomyOps.payRespond(player, IKST_Args.readBool(args.accept) == true)
    end
    if command == IKST.CMD.economyDelivery then
        return IKST_EconomyOps.submitTicket(player, args.message, "delivery")
    end
    if command == IKST.CMD.economyPlayerBounty then
        return IKST_EconomyOps.submitTicket(player, args.message, "bounty")
    end
    if command == IKST.CMD.economyExchange then
        return IKST_EconomyOps.exchange(player, args.itemType, x, y, z, args)
    end
    if command == IKST.CMD.economyExchangeAll then
        return IKST_EconomyOps.exchangeAll(player, x, y, z, args)
    end
    if command == IKST.CMD.economyIdCardReissue then
        return IKST_EconomyOps.playerIdCardReissue(player, x, y, z)
    end
    if command == IKST.CMD.economyVendList then
        if not IKST_Economy.playerNearCoord(player, x, y, z, IKST_Economy.shopMaxDistance()) then
            return false, "too far"
        end
        IKST_EconomyOps.sendVendList(player, x, y, z, IKST_EconomyOps.collectVendList(x, y, z, args.manage == true))
        return true, "listed"
    end
    if command == IKST.CMD.economyVendBuy then
        return IKST_EconomyOps.vendBuy(player, x, y, z, args.itemId, args.itemType, args)
    end
    if command == IKST.CMD.economyVendSetPrice then
        return IKST_EconomyOps.vendSetPrice(player, x, y, z, args)
    end
    if command == IKST.CMD.economyVendClaim then
        return IKST_EconomyOps.vendClaim(player, x, y, z)
    end
    if command == IKST.CMD.economyShopPlace then
        return IKST_EconomyOps.placeShopTerminal(player, x, y, z, args.itemId)
    end
    if command == IKST.CMD.economyVendEnable then
        if not IKST_Access.canUseStaffTools(player) then
            return false, "admin only"
        end
        local ownerKey = args.owner
        if ownerKey and ownerKey ~= "" then
            local found = IKST_Identity.findPlayerByUsername(ownerKey)
            if not found then
                found = IKST_Identity.findPlayerByAccountKey(ownerKey)
            end
            if found then
                ownerKey = IKST_Identity.accountKey(found)
            else
                ownerKey = IKST_Identity.resolveWhitelistKey(ownerKey)
            end
        else
            ownerKey = IKST_Economy.accountName(player)
        end
        return IKST_EconomyOps.vendEnable(player, x, y, z, ownerKey)
    end
    if command == IKST.CMD.economyVendDisable then
        local owner = IKST_EconomyOps.vendOwnerAt(x, y, z)
        if owner and not IKST_Identity.playerOwnsKey(player, owner) and not IKST_Access.canUseTools(player) then
            return false, "not your shop"
        end
        return IKST_EconomyOps.vendDisable(player, x, y, z)
    end
    if command == IKST.CMD.economyAtmConfigure then
        return IKST_EconomyOps.configureAtm(player, x, y, z, args)
    end
    if command == IKST.CMD.economyAtmPlace then
        return IKST_EconomyOps.placeAtmTerminal(player, x, y, z, args.itemId)
    end

    return false, "unknown economy command"
end
