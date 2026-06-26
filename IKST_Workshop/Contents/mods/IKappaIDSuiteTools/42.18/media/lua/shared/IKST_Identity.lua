-- Stable player identity (Steam ID / SP local id) for claims, economy, and permissions.
-- Never use display name or username alone as authority in MP.

require "IKST_Shared"

IKST_Identity = IKST_Identity or {}

IKST_Identity.PREFIX_STEAM = "steam:"
IKST_Identity.PREFIX_LOCAL = "local:"
IKST_Identity.PREFIX_LEGACY = "user:"

IKST_Identity.MD_PLAYER_ID = "IKST_accountId"
IKST_Identity.MD_OWNER_KEY = "IKST_ownerKey"
IKST_Identity.MD_CARD_SERIAL = "IKST_cardSerial"

IKST_Identity.ID_CARD_TYPE = "Base.IDcard"

local function trim(s)
    if not s then
        return ""
    end
    return tostring(s):match("^%s*(.-)%s*$") or ""
end

function IKST_Identity.isAccountKey(value)
    local s = tostring(value or "")
    if s == "" then
        return false
    end
    return string.sub(s, 1, #IKST_Identity.PREFIX_STEAM) == IKST_Identity.PREFIX_STEAM
        or string.sub(s, 1, #IKST_Identity.PREFIX_LOCAL) == IKST_Identity.PREFIX_LOCAL
        or string.sub(s, 1, #IKST_Identity.PREFIX_LEGACY) == IKST_Identity.PREFIX_LEGACY
end

function IKST_Identity.legacyKey(username)
    username = trim(username)
    if username == "" then
        return nil
    end
    return IKST_Identity.PREFIX_LEGACY .. string.lower(username)
end

function IKST_Identity.newLocalId()
    local n = ZombRand and ZombRand(100000000, 999999999) or 0
    local t = getTimeInMillis and getTimeInMillis() or 0
    return tostring(n) .. "-" .. tostring(t)
end

function IKST_Identity.steamId(player)
    if not player or not player.getSteamID then
        return nil
    end
    local id = player:getSteamID()
    if not id or id == "" or id == "0" then
        return nil
    end
    return tostring(id)
end

function IKST_Identity.username(player)
    if not player then
        return nil
    end
    if player.getUsername then
        local u = player:getUsername()
        if u and u ~= "" then
            return u
        end
    end
    return nil
end

function IKST_Identity.displayLabel(player)
    local u = IKST_Identity.username(player)
    if u and u ~= "" then
        return u
    end
    if player and player.getOnlineID then
        return "Player " .. tostring(player:getOnlineID())
    end
    return "player"
end

function IKST_Identity.ensureLocalPlayerId(player)
    if not player or not player.getModData then
        return nil
    end
    local md = player:getModData()
    if not md then
        return nil
    end
    local id = md[IKST_Identity.MD_PLAYER_ID]
    if not id or id == "" then
        id = IKST_Identity.newLocalId()
        md[IKST_Identity.MD_PLAYER_ID] = id
        if player.transmitModData then
            player:transmitModData()
        end
    end
    return tostring(id)
end

function IKST_Identity.accountKey(player)
    if not player then
        return "local:anonymous"
    end
    local steam = IKST_Identity.steamId(player)
    if steam then
        return IKST_Identity.PREFIX_STEAM .. steam
    end
    if IKST.isMultiplayerSession and IKST.isMultiplayerSession() then
        local u = IKST_Identity.username(player)
        if u and u ~= "" then
            return IKST_Identity.legacyKey(u)
        end
        return "local:anonymous"
    end
    local localId = IKST_Identity.ensureLocalPlayerId(player)
    if localId and localId ~= "" then
        return IKST_Identity.PREFIX_LOCAL .. localId
    end
    return "local:anonymous"
end

function IKST_Identity.keysEqual(a, b)
    if not a or not b then
        return false
    end
    if tostring(a) == tostring(b) then
        return true
    end
    local sa = tostring(a)
    local sb = tostring(b)
    if string.sub(sa, 1, #IKST_Identity.PREFIX_LEGACY) == IKST_Identity.PREFIX_LEGACY
        and string.sub(sb, 1, #IKST_Identity.PREFIX_LEGACY) == IKST_Identity.PREFIX_LEGACY then
        return string.lower(string.sub(sa, #IKST_Identity.PREFIX_LEGACY + 1))
            == string.lower(string.sub(sb, #IKST_Identity.PREFIX_LEGACY + 1))
    end
    if not IKST_Identity.isAccountKey(sa) and not IKST_Identity.isAccountKey(sb) then
        return string.lower(sa) == string.lower(sb)
    end
    return false
end

function IKST_Identity.playerOwnsKey(player, storedKey)
    if not player or not storedKey or storedKey == "" then
        return false
    end
    local key = IKST_Identity.accountKey(player)
    if IKST_Identity.keysEqual(key, storedKey) then
        return true
    end
    local uname = IKST_Identity.username(player)
    if not uname or uname == "" then
        return false
    end
    if not IKST_Identity.isAccountKey(storedKey) then
        return string.lower(tostring(storedKey)) == string.lower(uname)
    end
    if string.sub(tostring(storedKey), 1, #IKST_Identity.PREFIX_LEGACY) == IKST_Identity.PREFIX_LEGACY then
        local legacy = string.sub(tostring(storedKey), #IKST_Identity.PREFIX_LEGACY + 1)
        return string.lower(uname) == string.lower(legacy)
    end
    return false
end

function IKST_Identity.labelForKey(key)
    if not key or key == "" then
        return "?"
    end
    local online = IKST_Identity.findPlayerByAccountKey(key)
    if online then
        return IKST_Identity.displayLabel(online)
    end
    if string.sub(tostring(key), 1, #IKST_Identity.PREFIX_LEGACY) == IKST_Identity.PREFIX_LEGACY then
        return string.sub(tostring(key), #IKST_Identity.PREFIX_LEGACY + 1)
    end
    if string.sub(tostring(key), 1, #IKST_Identity.PREFIX_STEAM) == IKST_Identity.PREFIX_STEAM then
        return string.sub(tostring(key), #IKST_Identity.PREFIX_STEAM + 1)
    end
    if string.sub(tostring(key), 1, #IKST_Identity.PREFIX_LOCAL) == IKST_Identity.PREFIX_LOCAL then
        return "SP " .. string.sub(tostring(key), #IKST_Identity.PREFIX_LOCAL + 1)
    end
    return tostring(key)
end

function IKST_Identity.iterOnlinePlayers(visitor)
    if not visitor then
        return
    end
    local list = getOnlinePlayers and getOnlinePlayers()
    if list and list.size and list.get then
        for i = 0, list:size() - 1 do
            visitor(list:get(i))
        end
        return
    end
    if getSpecificPlayer then
        local p = getSpecificPlayer(0)
        if p then
            visitor(p)
        end
    end
end

function IKST_Identity.findPlayerByUsername(username)
    username = trim(username)
    if username == "" then
        return nil
    end
    local found = nil
    IKST_Identity.iterOnlinePlayers(function(p)
        if found then
            return
        end
        local u = IKST_Identity.username(p)
        if u and string.lower(u) == string.lower(username) then
            found = p
        end
    end)
    return found
end

function IKST_Identity.findPlayerByAccountKey(key)
    if not key or key == "" then
        return nil
    end
    local found = nil
    IKST_Identity.iterOnlinePlayers(function(p)
        if found then
            return
        end
        if IKST_Identity.playerOwnsKey(p, key) then
            found = p
        end
    end)
    return found
end

function IKST_Identity.resolveWhitelistKey(nameOrKey)
    nameOrKey = trim(nameOrKey)
    if nameOrKey == "" then
        return nil
    end
    if IKST_Identity.isAccountKey(nameOrKey) then
        return nameOrKey
    end
    local online = IKST_Identity.findPlayerByUsername(nameOrKey)
    if online then
        return IKST_Identity.accountKey(online)
    end
    return IKST_Identity.legacyKey(nameOrKey)
end

function IKST_Identity.findUserPerms(users, player)
    if not users or not player then
        return nil, nil
    end
    local key = IKST_Identity.accountKey(player)
    if key and users[key] then
        return users[key], key
    end
    for storedKey, perms in pairs(users) do
        if IKST_Identity.playerOwnsKey(player, storedKey) then
            return perms, storedKey
        end
    end
    return nil, nil
end

function IKST_Identity.findUserKey(users, nameOrKey)
    if not users or not nameOrKey or nameOrKey == "" then
        return nil
    end
    if users[nameOrKey] ~= nil then
        return nameOrKey
    end
    local resolved = IKST_Identity.resolveWhitelistKey(nameOrKey)
    if resolved and users[resolved] ~= nil then
        return resolved
    end
    local lower = string.lower(tostring(nameOrKey))
    for key in pairs(users) do
        if string.lower(tostring(key)) == lower then
            return key
        end
        if IKST_Identity.keysEqual(key, resolved) then
            return key
        end
    end
    return nil
end

function IKST_Identity.identityMapStore()
    if not ModData or not ModData.getOrCreate then
        return nil
    end
    local data = ModData.getOrCreate("IKST_Identity")
    if not data.nameToKey then
        data.nameToKey = {}
    end
    return data
end

function IKST_Identity.registerPlayerMapping(player)
    if not player or not IKST.runsOnServerJvm or not IKST.runsOnServerJvm() then
        return
    end
    local store = IKST_Identity.identityMapStore()
    if not store then
        return
    end
    local u = IKST_Identity.username(player)
    local key = IKST_Identity.accountKey(player)
    if u and u ~= "" and key then
        store.nameToKey[string.lower(u)] = key
    end
end

function IKST_Identity.keyForLegacyName(name)
    name = trim(name)
    if name == "" then
        return nil
    end
    local store = IKST_Identity.identityMapStore()
    if store and store.nameToKey then
        local mapped = store.nameToKey[string.lower(name)]
        if mapped and mapped ~= "" then
            return mapped
        end
    end
    local online = IKST_Identity.findPlayerByUsername(name)
    if online then
        return IKST_Identity.accountKey(online)
    end
    return IKST_Identity.legacyKey(name)
end

function IKST_Identity.isIdCardItem(item)
    if not item or not item.getFullType then
        return false
    end
    return item:getFullType() == IKST_Identity.ID_CARD_TYPE
end

function IKST_Identity.iterInventoryItems(inv, visitor)
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
            if item.getInventory and item:getInventory() then
                IKST_Identity.iterInventoryItems(item:getInventory(), visitor)
            end
        end
    end
end

function IKST_Identity.findPlayerIdCard(player)
    if not player or not player.getInventory then
        return nil
    end
    local found = nil
    IKST_Identity.iterInventoryItems(player:getInventory(), function(item)
        if not found and IKST_Identity.isIdCardItem(item) then
            found = item
        end
    end)
    return found
end

function IKST_Identity.cardSerialFromItem(item)
    if not item or not item.getModData then
        return nil
    end
    local md = item:getModData()
    if not md then
        return nil
    end
    return tonumber(md[IKST_Identity.MD_CARD_SERIAL])
end

function IKST_Identity.cardOwnerKeyFromItem(item)
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

function IKST_Identity.getActiveCardSerial(accountKey)
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

function IKST_Identity.setActiveCardSerial(accountKey, serial)
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

function IKST_Identity.ensureCardSerial(accountKey)
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

function IKST_Identity.stampIdCard(item, player)
    if not item or not player or not IKST.runsOnServerJvm or not IKST.runsOnServerJvm() then
        return false
    end
    if not IKST_Identity.isIdCardItem(item) then
        return false
    end
    local key = IKST_Identity.accountKey(player)
    local serial = IKST_Identity.ensureCardSerial(key)
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

function IKST_Identity.isStampedBankCard(item)
    if not IKST_Identity.isIdCardItem(item) then
        return false
    end
    local key = IKST_Identity.cardOwnerKeyFromItem(item)
    return key ~= nil and key ~= ""
end

function IKST_Identity.iterPlayerContainers(inv, visitor)
    if not inv or not visitor then
        return
    end
    visitor(inv)
    IKST_Identity.iterInventoryItems(inv, function(item)
        if item.getInventory then
            local sub = item:getInventory()
            if sub then
                IKST_Identity.iterPlayerContainers(sub, visitor)
            end
        end
    end)
end

function IKST_Identity.containerBelongsToPlayer(container, player)
    if not container or not player or not player.getInventory then
        return false
    end
    local match = false
    IKST_Identity.iterPlayerContainers(player:getInventory(), function(c)
        if c == container then
            match = true
        end
    end)
    return match
end

function IKST_Identity.bankCardTransferAllowed(item, srcContainer, destContainer, player, quiet)
    if not item or not player or not IKST_Identity.isStampedBankCard(item) then
        return true
    end
    if IKST_Access and IKST_Access.canUseTools and IKST_Access.canUseTools(player) then
        return true
    end
    local ownerKey = IKST_Identity.cardOwnerKeyFromItem(item)
    if ownerKey and not IKST_Identity.playerOwnsKey(player, ownerKey) then
        if not quiet and IKST.notify then
            IKST.notify(player, IKST.text("IGUI_IKST_Economy_IdCardNotYours",
                "That bank ID belongs to another account."), false)
        end
        return false
    end
    if not destContainer or not IKST_Identity.containerBelongsToPlayer(destContainer, player) then
        if not quiet and IKST.notify then
            IKST.notify(player, IKST.text("IGUI_IKST_Economy_IdCardBindPlayer",
                "Your bank ID cannot be dropped or stored outside your inventory."), false)
        end
        return false
    end
    return true
end

function IKST_Identity.removePlayerBankCards(player, exceptItem)
    if not player or not player.getInventory or not IKST.runsOnServerJvm or not IKST.runsOnServerJvm() then
        return 0
    end
    local toRemove = {}
    IKST_Identity.iterInventoryItems(player:getInventory(), function(item)
        if item ~= exceptItem and IKST_Identity.isStampedBankCard(item) then
            if IKST_Identity.playerOwnsKey(player, IKST_Identity.cardOwnerKeyFromItem(item)) then
                toRemove[#toRemove + 1] = item
            end
        end
    end)
    local n = 0
    for i = 1, #toRemove do
        local item = toRemove[i]
        local container = item.getContainer and item:getContainer()
        if container then
            container:Remove(item)
            if sendRemoveItemFromContainer then
                sendRemoveItemFromContainer(container, item)
            end
            n = n + 1
        end
    end
    if n > 0 and player.getInventory().setDrawDirty then
        player:getInventory():setDrawDirty(true)
    end
    return n
end

function IKST_Identity.prunePlayerBankCards(player)
    if not player or not IKST.runsOnServerJvm or not IKST.runsOnServerJvm() then
        return
    end
    local keep = nil
    local toRemove = {}
    IKST_Identity.iterInventoryItems(player:getInventory(), function(item)
        if not IKST_Identity.isStampedBankCard(item) then
            return
        end
        if not IKST_Identity.playerOwnsKey(player, IKST_Identity.cardOwnerKeyFromItem(item)) then
            return
        end
        if IKST_Identity.cardMatchesPlayer(item, player) then
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
        local container = item.getContainer and item:getContainer()
        if container then
            container:Remove(item)
            if sendRemoveItemFromContainer then
                sendRemoveItemFromContainer(container, item)
            end
        end
    end
end

function IKST_Identity.strictEnsureIdCardOnConnect(player)
    if not player or not IKST.runsOnServerJvm or not IKST.runsOnServerJvm() then
        return false, "server only"
    end
    IKST_Identity.prunePlayerBankCards(player)
    if IKST_Identity.hasValidIdCard(player) then
        return true, "bank ID ok"
    end
    return IKST_Identity.reissueIdCard(player, { recordCooldown = false, bumpSerial = true })
end

function IKST_Identity.invalidateActiveCard(player)
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

function IKST_Identity.cardMatchesPlayer(item, player)
    if not item or not player then
        return false
    end
    if not IKST_Identity.isIdCardItem(item) then
        return false
    end
    local ownerKey = IKST_Identity.cardOwnerKeyFromItem(item)
    if not ownerKey or not IKST_Identity.playerOwnsKey(player, ownerKey) then
        return false
    end
    local serial = IKST_Identity.cardSerialFromItem(item)
    local active = IKST_Identity.getActiveCardSerial(IKST_Identity.accountKey(player))
    if serial == nil or active == nil then
        return false
    end
    return math.floor(serial) == math.floor(active)
end

function IKST_Identity.hasValidIdCard(player)
    local card = IKST_Identity.findPlayerIdCard(player)
    if not card then
        return false
    end
    return IKST_Identity.cardMatchesPlayer(card, player)
end

function IKST_Identity.issueIdCard(player)
    if not player or not IKST.runsOnServerJvm or not IKST.runsOnServerJvm() then
        return false, "server only"
    end
    local inv = player:getInventory()
    if not inv then
        return false, "no inventory"
    end
    local existing = IKST_Identity.findPlayerIdCard(player)
    if existing and IKST_Identity.cardMatchesPlayer(existing, player) then
        return true, "already have ID"
    end
    if not instanceItem then
        return false, "cannot create item"
    end
    local card = instanceItem(IKST_Identity.ID_CARD_TYPE)
    if not card then
        return false, "cannot create ID card"
    end
    IKST_Identity.stampIdCard(card, player)
    if not inv:AddItem(card) then
        return false, "inventory full"
    end
    if sendAddItemToContainer then
        sendAddItemToContainer(inv, card)
    end
    return true, "ID card issued"
end

function IKST_Identity.reissueIdCard(player, options)
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
    IKST_Identity.removePlayerBankCards(player, nil)
    local ok, msg = IKST_Identity.issueIdCard(player)
    if ok and IKST.notify and options.notifyPlayer ~= false then
        IKST.notify(player, IKST.text("IGUI_IKST_Economy_IdCardReissued", "Bank ID card reissued."), true)
    end
    return ok, msg or (ok and "ID card reissued" or "reissue failed")
end

function IKST_Identity.migrateAccountRow(store, fromKey, toKey)
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

function IKST_Identity.migrateEconomyAccounts(store)
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

function IKST_Identity.migrateOwnerField(owner)
    if not owner or owner == "" then
        return owner
    end
    if IKST_Identity.isAccountKey(owner) then
        return owner
    end
    local mapped = IKST_Identity.keyForLegacyName(owner)
    return mapped or IKST_Identity.legacyKey(owner)
end

function IKST_Identity.migratePlayerOnConnect(player)
    if not player or not IKST.runsOnServerJvm or not IKST.runsOnServerJvm() then
        return
    end
    IKST_Identity.registerPlayerMapping(player)
    local key = IKST_Identity.accountKey(player)
    local uname = IKST_Identity.username(player)

    if IKST_Economy and IKST_Economy.getStore then
        local estore = IKST_Economy.getStore()
        if estore then
            if uname and uname ~= "" and not IKST_Identity.isAccountKey(uname) then
                IKST_Identity.migrateAccountRow(estore, uname, key)
                IKST_Identity.migrateAccountRow(estore, IKST_Identity.legacyKey(uname), key)
            end
            if IKST_Economy.persistStore then
                IKST_Economy.persistStore()
            end
        end
    end

    if IKST_VehicleClaim and IKST_VehicleClaim.store then
        local data = IKST_VehicleClaim.store()
        if data and data.byId then
            for _, entry in pairs(data.byId) do
                if entry and entry.owner and not IKST_Identity.isAccountKey(entry.owner) then
                    if IKST_Identity.playerOwnsKey(player, entry.owner)
                        or (uname and string.lower(tostring(entry.owner)) == string.lower(uname)) then
                        local oldOwner = entry.owner
                        entry.owner = key
                        if IKST_VehicleClaim.removeFromOwnerList and IKST_VehicleClaim.addToOwnerList then
                            IKST_VehicleClaim.removeFromOwnerList(oldOwner, tostring(entry.id))
                            IKST_VehicleClaim.addToOwnerList(key, tostring(entry.id))
                        end
                    end
                end
            end
            if IKST_VehicleClaim.transmit then
                IKST_VehicleClaim.transmit()
            end
        end
    end

    if IKST_ClaimPolicy and IKST_ClaimPolicy.safehouseMetaStore then
        local meta = IKST_ClaimPolicy.safehouseMetaStore()
        for _, row in pairs(meta) do
            if row and row.owner and not IKST_Identity.isAccountKey(row.owner) then
                if IKST_Identity.playerOwnsKey(player, row.owner)
                    or (uname and string.lower(tostring(row.owner)) == string.lower(uname)) then
                    row.owner = key
                end
            end
        end
        if IKST.transmitModData and IKST.ModDataKeys then
            IKST.transmitModData(IKST.ModDataKeys.worldRules)
        end
    end
end
