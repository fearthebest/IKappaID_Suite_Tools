-- Bank ID card serials, reissue, and economy account migration (Economy addon).
require "IKST_Shared"
require "IKST_Identity"
require "IKST_Economy"

IKST_EconomyIdentity = IKST_EconomyIdentity or {}

IKST_EconomyIdentity.ID_CARD_TYPE = "Base.IDcard"

function IKST_EconomyIdentity.isIdCardItem(item)
    if not item or type(item.getFullType) ~= "function" then
        return false
    end
    return item:getFullType() == IKST_EconomyIdentity.ID_CARD_TYPE
end

function IKST_EconomyIdentity.iterInventoryItems(inv, visitor)
    if not inv or not visitor or not inv.getItems then
        return
    end
    local items = inv:getItems()
    if not items then
        return
    end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            visitor(item)
            if type(item.getInventory) == "function" and item:getInventory() then
                IKST_EconomyIdentity.iterInventoryItems(item:getInventory(), visitor)
            end
        end
    end
end

function IKST_EconomyIdentity.findPlayerIdCard(player)
    if not player or not player.getInventory then
        return nil
    end
    local found = nil
    IKST_EconomyIdentity.iterInventoryItems(player:getInventory(), function(item)
        if not found and IKST_EconomyIdentity.isIdCardItem(item) then
            found = item
        end
    end)
    return found
end

function IKST_EconomyIdentity.cardSerialFromItem(item)
    if not item or not item.getModData then
        return nil
    end
    local md = item:getModData()
    if not md then
        return nil
    end
    return tonumber(md[IKST_Identity.MD_CARD_SERIAL])
end

function IKST_EconomyIdentity.cardOwnerKeyFromItem(item)
    if not item or not item.getModData then
        return nil
    end
    local md = item:getModData()
    if not md then
        return nil
    end
    local key = md[IKST_Identity.MD_OWNER_KEY]
    if key and key ~= "" then
        return tostring(key)
    end
    return nil
end

function IKST_EconomyIdentity.getActiveCardSerial(accountKey)
    if not accountKey or accountKey == "" or not IKST_Economy or not IKST_Economy.getStore then
        return nil
    end
    local store = IKST_Economy.getStore()
    if not store or not store.accounts then
        return nil
    end
    local row = store.accounts[accountKey]
    if not row then
        return nil
    end
    return tonumber(row.activeCardSerial)
end

function IKST_EconomyIdentity.setActiveCardSerial(accountKey, serial)
    if not accountKey or not IKST_Economy or not IKST_Economy.getAccountByKey then
        return
    end
    local row = IKST_Economy.getAccountByKey(accountKey)
    if row then
        row.activeCardSerial = math.floor(tonumber(serial) or 1)
        if IKST_Economy.persistStore then
            IKST_Economy.persistStore()
        end
    end
end

function IKST_EconomyIdentity.ensureCardSerial(accountKey)
    if not accountKey or not IKST_Economy or not IKST_Economy.getAccountByKey then
        return 1
    end
    local row = IKST_Economy.getAccountByKey(accountKey)
    local serial = tonumber(row.activeCardSerial)
    if not serial or serial < 1 then
        serial = 1
        row.activeCardSerial = serial
        if IKST_Economy.persistStore then
            IKST_Economy.persistStore()
        end
    end
    return serial
end

function IKST_EconomyIdentity.stampIdCard(item, player)
    if not item or not player or not IKST.runsOnServerJvm or not IKST.runsOnServerJvm() then
        return false
    end
    if not IKST_EconomyIdentity.isIdCardItem(item) then
        return false
    end
    local key = IKST_Identity.accountKey(player)
    local serial = IKST_EconomyIdentity.ensureCardSerial(key)
    local md = item:getModData()
    if not md then
        return false
    end
    md[IKST_Identity.MD_OWNER_KEY] = key
    md[IKST_Identity.MD_CARD_SERIAL] = serial
    if item.syncItemFields then
        item:syncItemFields()
    end
    if item.setName then
        local label = IKST_Identity.displayLabel(player)
        item:setName(label .. " — Bank ID")
    end
    if item.setFavorite then
        item:setFavorite(true)
    end
    return true
end

function IKST_EconomyIdentity.isStampedBankCard(item)
    if not IKST_EconomyIdentity.isIdCardItem(item) then
        return false
    end
    local key = IKST_EconomyIdentity.cardOwnerKeyFromItem(item)
    return key ~= nil and key ~= ""
end

function IKST_EconomyIdentity.iterPlayerContainers(inv, visitor)
    if not inv or not visitor then
        return
    end
    visitor(inv)
    IKST_EconomyIdentity.iterInventoryItems(inv, function(item)
        if item.getInventory then
            local sub = item:getInventory()
            if sub then
                IKST_EconomyIdentity.iterPlayerContainers(sub, visitor)
            end
        end
    end)
end

function IKST_EconomyIdentity.containerBelongsToPlayer(container, player)
    if not container or not player or not player.getInventory then
        return false
    end
    local match = false
    IKST_EconomyIdentity.iterPlayerContainers(player:getInventory(), function(c)
        if c == container then
            match = true
        end
    end)
    return match
end

function IKST_EconomyIdentity.bankCardTransferAllowed(item, srcContainer, destContainer, player, quiet)
    if not item or not player or not IKST_EconomyIdentity.isStampedBankCard(item) then
        return true
    end
    if IKST_Access and IKST_Access.canUseTools and IKST_Access.canUseTools(player) then
        return true
    end
    local ownerKey = IKST_EconomyIdentity.cardOwnerKeyFromItem(item)
    if ownerKey and not IKST_Identity.playerOwnsKey(player, ownerKey) then
        if not quiet and IKST.notify then
            IKST.notify(player, IKST.text("IGUI_IKST_Economy_IdCardNotYours",
                "That bank ID belongs to another account."), false)
        end
        return false
    end
    if not destContainer or not IKST_EconomyIdentity.containerBelongsToPlayer(destContainer, player) then
        if not quiet and IKST.notify then
            IKST.notify(player, IKST.text("IGUI_IKST_Economy_IdCardBindPlayer",
                "Your bank ID cannot be dropped or stored outside your inventory."), false)
        end
        return false
    end
    return true
end

function IKST_EconomyIdentity.removePlayerBankCards(player, exceptItem)
    if not player or not player.getInventory or not IKST.runsOnServerJvm or not IKST.runsOnServerJvm() then
        return 0
    end
    local toRemove = {}
    IKST_EconomyIdentity.iterInventoryItems(player:getInventory(), function(item)
        if item ~= exceptItem and IKST_EconomyIdentity.isStampedBankCard(item) then
            if IKST_Identity.playerOwnsKey(player, IKST_EconomyIdentity.cardOwnerKeyFromItem(item)) then
                toRemove[#toRemove + 1] = item
            end
        end
    end)
    local n = 0
    for i = 1, #toRemove do
        local item = toRemove[i]
        local container = type(item.getContainer) == "function" and item:getContainer()
        if container then
            container:Remove(item)
            if sendRemoveItemFromContainer then
                sendRemoveItemFromContainer(container, item)
            end
            n = n + 1
        end
    end
    if n > 0 and player.getInventory then
        local inv = player:getInventory()
        if inv and inv.setDrawDirty then
            inv:setDrawDirty(true)
        end
    end
    return n
end

function IKST_EconomyIdentity.prunePlayerBankCards(player)
    if not player or not IKST.runsOnServerJvm or not IKST.runsOnServerJvm() then
        return
    end
    local keep = nil
    local toRemove = {}
    IKST_EconomyIdentity.iterInventoryItems(player:getInventory(), function(item)
        if not IKST_EconomyIdentity.isStampedBankCard(item) then
            return
        end
        if not IKST_Identity.playerOwnsKey(player, IKST_EconomyIdentity.cardOwnerKeyFromItem(item)) then
            return
        end
        if IKST_EconomyIdentity.cardMatchesPlayer(item, player) then
            if keep then
                toRemove[#toRemove + 1] = item
            else
                keep = item
            end
        else
            toRemove[#toRemove + 1] = item
        end
    end)
    for i = 1, #toRemove do
        local item = toRemove[i]
        local container = type(item.getContainer) == "function" and item:getContainer()
        if container then
            container:Remove(item)
            if sendRemoveItemFromContainer then
                sendRemoveItemFromContainer(container, item)
            end
        end
    end
end

function IKST_EconomyIdentity.strictEnsureIdCardOnConnect(player)
    if not player or not IKST.runsOnServerJvm or not IKST.runsOnServerJvm() then
        return false, "server only"
    end
    IKST_EconomyIdentity.prunePlayerBankCards(player)
    if IKST_EconomyIdentity.hasValidIdCard(player) then
        return true, "bank ID ok"
    end
    return IKST_EconomyIdentity.reissueIdCard(player, { recordCooldown = false, bumpSerial = true })
end

function IKST_EconomyIdentity.invalidateActiveCard(player)
    if not player or not IKST.runsOnServerJvm or not IKST.runsOnServerJvm() then
        return
    end
    if not IKST_Economy or not IKST_Economy.getAccountByKey then
        return
    end
    local key = IKST_Identity.accountKey(player)
    local row = IKST_Economy.getAccountByKey(key)
    local nextSerial = math.floor(tonumber(row.activeCardSerial) or 0) + 1
    if nextSerial < 1 then
        nextSerial = 1
    end
    row.activeCardSerial = nextSerial
    if IKST_Economy.persistStore then
        IKST_Economy.persistStore()
    end
end

function IKST_EconomyIdentity.cardMatchesPlayer(item, player)
    if not item or not player then
        return false
    end
    if not IKST_EconomyIdentity.isIdCardItem(item) then
        return false
    end
    local ownerKey = IKST_EconomyIdentity.cardOwnerKeyFromItem(item)
    if not ownerKey or not IKST_Identity.playerOwnsKey(player, ownerKey) then
        return false
    end
    local serial = IKST_EconomyIdentity.cardSerialFromItem(item)
    local active = IKST_EconomyIdentity.getActiveCardSerial(IKST_Identity.accountKey(player))
    if serial == nil or active == nil then
        return false
    end
    return math.floor(serial) == math.floor(active)
end

function IKST_EconomyIdentity.hasValidIdCard(player)
    local card = IKST_EconomyIdentity.findPlayerIdCard(player)
    if not card then
        return false
    end
    return IKST_EconomyIdentity.cardMatchesPlayer(card, player)
end

function IKST_EconomyIdentity.issueIdCard(player)
    if not player or not IKST.runsOnServerJvm or not IKST.runsOnServerJvm() then
        return false, "server only"
    end
    local inv = player:getInventory()
    if not inv then
        return false, "no inventory"
    end
    local existing = IKST_EconomyIdentity.findPlayerIdCard(player)
    if existing and IKST_EconomyIdentity.cardMatchesPlayer(existing, player) then
        return true, "already have ID"
    end
    if not instanceItem then
        return false, "cannot create item"
    end
    local card = instanceItem(IKST_EconomyIdentity.ID_CARD_TYPE)
    if not card then
        return false, "cannot create ID card"
    end
    IKST_EconomyIdentity.stampIdCard(card, player)
    if not inv:AddItem(card) then
        return false, "inventory full"
    end
    if sendAddItemToContainer then
        sendAddItemToContainer(inv, card)
    end
    return true, "ID card issued"
end

function IKST_EconomyIdentity.reissueIdCard(player, options)
    if not player or not IKST.runsOnServerJvm or not IKST.runsOnServerJvm() then
        return false, "server only"
    end
    options = options or {}
    local key = IKST_Identity.accountKey(player)
    local row = IKST_Economy and IKST_Economy.getAccountByKey and IKST_Economy.getAccountByKey(key)
    if not row then
        return false, "no account"
    end
    if options.bumpSerial ~= false then
        local nextSerial = math.floor(tonumber(row.activeCardSerial) or 0) + 1
        if nextSerial < 1 then
            nextSerial = 1
        end
        row.activeCardSerial = nextSerial
    end
    if options.recordCooldown == true and getTimeInMillis then
        row.lastCardReissueMs = getTimeInMillis()
    end
    if IKST_Economy.persistStore then
        IKST_Economy.persistStore()
    end
    IKST_EconomyIdentity.removePlayerBankCards(player, nil)
    local ok, msg = IKST_EconomyIdentity.issueIdCard(player)
    if ok and IKST.notify and options.notifyPlayer ~= false then
        IKST.notify(player, IKST.text("IGUI_IKST_Economy_IdCardReissued", "Bank ID card reissued."), true)
    end
    return ok, msg or (ok and "ID card reissued" or "reissue failed")
end

function IKST_EconomyIdentity.migrateAccountRow(store, fromKey, toKey)
    if not store or not store.accounts or not fromKey or not toKey then
        return
    end
    if fromKey == toKey or IKST_Identity.keysEqual(fromKey, toKey) then
        return
    end
    local src = store.accounts[fromKey]
    if not src then
        return
    end
    local dst = store.accounts[toKey]
    if not dst then
        dst = { bank = 0, pending = 0 }
        store.accounts[toKey] = dst
    end
    dst.bank = math.floor((tonumber(dst.bank) or 0) + (tonumber(src.bank) or 0))
    dst.pending = math.floor((tonumber(dst.pending) or 0) + (tonumber(src.pending) or 0))
    local srcSerial = tonumber(src.activeCardSerial)
    local dstSerial = tonumber(dst.activeCardSerial)
    if srcSerial and (not dstSerial or srcSerial > dstSerial) then
        dst.activeCardSerial = srcSerial
    end
    store.accounts[fromKey] = nil
end

function IKST_EconomyIdentity.migrateEconomyAccounts(store)
    if not store or not store.accounts then
        return
    end
    local keys = {}
    for key in pairs(store.accounts) do
        keys[#keys + 1] = key
    end
    for _, key in ipairs(keys) do
        if key and not IKST_Identity.isAccountKey(key) then
            local mapped = IKST_Identity.keyForLegacyName(key)
            if mapped and mapped ~= key then
                IKST_Identity.migrateAccountRow(store, key, mapped)
            end
        end
    end
end


function IKST_EconomyIdentity.migratePlayerAccounts(player, key, uname)
    if not player or not IKST.runsOnServerJvm or not IKST.runsOnServerJvm() then
        return
    end
    if not IKST_Economy or not IKST_Economy.getStore then
        return
    end
    local estore = IKST_Economy.getStore()
    if not estore then
        return
    end
    key = key or IKST_Identity.accountKey(player)
    uname = uname or IKST_Identity.username(player)
    if uname and uname ~= "" and not IKST_Identity.isAccountKey(uname) then
        IKST_EconomyIdentity.migrateAccountRow(estore, uname, key)
        IKST_EconomyIdentity.migrateAccountRow(estore, IKST_Identity.legacyKey(uname), key)
    end
    if IKST_Economy.persistStore then
        IKST_Economy.persistStore()
    end
end

